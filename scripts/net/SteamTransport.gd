extends NetTransport
class_name SteamTransport

# Implémentation Steam du transport : lobby Steam pour la mise en relation,
# API P2P Steamworks (sendP2PPacket / readP2PPacket) pour les octets de jeu.
#
# - host() : crée un lobby public tagué "fatebound" ; la partie démarre quand
#   un second membre entre dans le lobby.
# - join() : rejoint un lobby précis ({"lobby_id": int}) ou, sans id, cherche
#   le premier lobby FateBound ouvert (partie rapide).
#
# Comme pour ENet, aucun identifiant Steam (SteamID64, lobby id) ne fuit hors
# de cette classe : le reste du jeu ne voit que l'interface NetTransport.
# Tous les appels au singleton Steam sont dynamiques (voir SteamService).

const LOBBY_GAME_KEY := "game"
const LOBBY_GAME_VALUE := "fatebound"
const LOBBY_OWNER_KEY := "owner_id"
const CHANNEL := 0

# Constantes Steamworks recopiées (le singleton n'existe pas à la compilation).
const LOBBY_TYPE_PUBLIC := 2
const LOBBY_OK := 1                    # CHAT_ROOM_ENTER_RESPONSE_SUCCESS
const CHAT_ENTERED := 1                # CHAT_MEMBER_STATE_CHANGE_ENTERED
const P2P_SEND_UNRELIABLE := 0
const P2P_SEND_RELIABLE := 2
const LOBBY_DISTANCE_WORLDWIDE := 3    # LOBBY_DISTANCE_FILTER_WORLDWIDE

# EP2PSessionError, pour rendre p2p_session_connect_fail lisible dans le log.
const P2P_ERRORS := {
	1: "l'autre joueur ne fait pas tourner le jeu",
	2: "pas les droits sur l'application",
	3: "l'autre joueur n'est pas connecté à Steam",
	4: "délai de connexion dépassé (NAT/pare-feu ?)",
}

var _steam: Object = null
var _lobby_id: int = 0
var _remote_id: int = 0  # SteamID64 du pair distant
var _is_host := false
var _got_first_packet := false

func host(_params: Dictionary) -> int:
	if not _init_steam():
		return ERR_UNAVAILABLE
	_is_host = true
	_steam.createLobby(LOBBY_TYPE_PUBLIC, 2)  # 2 membres : c'est du 1v1
	status.emit("Steam : création du lobby demandée…")
	return OK

func join(params: Dictionary) -> int:
	if not _init_steam():
		return ERR_UNAVAILABLE
	_is_host = false
	var lobby_id: int = params.get("lobby_id", 0)
	if lobby_id != 0:
		_steam.joinLobby(lobby_id)
		status.emit("Steam : rejoint le lobby %d…" % lobby_id)
	else:
		# Partie rapide : premier lobby FateBound disponible. Sans filtre de
		# distance, Steam ne renvoie que les lobbies « proches » — deux joueurs
		# éloignés ne se trouvaient pas. On force la portée mondiale.
		_steam.addRequestLobbyListStringFilter(LOBBY_GAME_KEY, LOBBY_GAME_VALUE, 0)  # 0 = égalité
		_steam.addRequestLobbyListDistanceFilter(LOBBY_DISTANCE_WORLDWIDE)
		_steam.requestLobbyList()
		status.emit("Steam : recherche d'un lobby FateBound (portée mondiale)…")
	return OK

func send(bytes: PackedByteArray, reliable: bool = true) -> void:
	if _steam == null or _remote_id == 0:
		return
	_steam.sendP2PPacket(_remote_id, bytes,
			P2P_SEND_RELIABLE if reliable else P2P_SEND_UNRELIABLE, CHANNEL)

func poll() -> void:
	if _steam == null:
		return
	SteamService.run_callbacks()
	while _steam.getAvailableP2PPacketSize(CHANNEL) > 0:
		var packet: Dictionary = _steam.readP2PPacket(
				_steam.getAvailableP2PPacketSize(CHANNEL), CHANNEL)
		var bytes: PackedByteArray = packet.get("data", PackedByteArray())
		if not _got_first_packet:
			# Preuve que le P2P entrant fonctionne : précieuse au diagnostic.
			_got_first_packet = true
			status.emit("Steam : premier paquet P2P reçu du pair ✓")
		# Les paquets vides servent uniquement à ouvrir la session P2P.
		if not bytes.is_empty():
			packet_received.emit(bytes)

func close() -> void:
	if _steam == null:
		return
	if _remote_id != 0:
		_steam.closeP2PSessionWithUser(_remote_id)
	if _lobby_id != 0:
		_steam.leaveLobby(_lobby_id)
	_disconnect_steam_signals()
	_steam = null
	_lobby_id = 0
	_remote_id = 0
	_got_first_packet = false

# ─── Interne ──────────────────────────────────────────────────────────────────

func _init_steam() -> bool:
	if not SteamService.ensure_init():
		push_warning("SteamTransport : Steam indisponible (extension absente ou client fermé)")
		return false
	_steam = SteamService.steam()
	_connect_steam_signals()
	return true

func _connect_steam_signals() -> void:
	_steam.connect("lobby_created", _on_lobby_created)
	_steam.connect("lobby_joined", _on_lobby_joined)
	_steam.connect("lobby_match_list", _on_lobby_match_list)
	_steam.connect("lobby_chat_update", _on_lobby_chat_update)
	_steam.connect("p2p_session_request", _on_p2p_session_request)
	_steam.connect("p2p_session_connect_fail", _on_p2p_session_connect_fail)

func _disconnect_steam_signals() -> void:
	if _steam.is_connected("lobby_created", _on_lobby_created):
		_steam.disconnect("lobby_created", _on_lobby_created)
		_steam.disconnect("lobby_joined", _on_lobby_joined)
		_steam.disconnect("lobby_match_list", _on_lobby_match_list)
		_steam.disconnect("lobby_chat_update", _on_lobby_chat_update)
		_steam.disconnect("p2p_session_request", _on_p2p_session_request)
		_steam.disconnect("p2p_session_connect_fail", _on_p2p_session_connect_fail)

# ── Côté hôte ──

func _on_lobby_created(result: int, lobby_id: int) -> void:
	if not _is_host:
		return
	if result != LOBBY_OK:
		status.emit("Steam : échec de création du lobby (code %d)" % result)
		disconnected.emit("steam_lobby_create_failed")
		return
	_lobby_id = lobby_id
	status.emit("Steam : lobby %d créé — en attente d'un adversaire…" % lobby_id)
	# Tag le lobby pour que la recherche « partie rapide » le trouve.
	_steam.setLobbyData(lobby_id, LOBBY_GAME_KEY, LOBBY_GAME_VALUE)
	# Publie le SteamID de l'hôte dans les données du lobby : contrairement à
	# getLobbyOwner (fiable seulement une fois membre), cette donnée est lisible
	# depuis les résultats de recherche et permet au client d'écarter ses
	# propres lobbies (cas « même compte », voir _on_lobby_match_list).
	_steam.setLobbyData(lobby_id, LOBBY_OWNER_KEY, str(_steam.getSteamID()))
	_steam.setLobbyJoinable(lobby_id, true)

# Un membre entre / sort du lobby (hôte : détecte l'arrivée de l'adversaire).
func _on_lobby_chat_update(lobby_id: int, changed_id: int, _making_change_id: int, chat_state: int) -> void:
	if lobby_id != _lobby_id:
		return
	# L'hôte reçoit aussi ce callback pour sa propre entrée dans le lobby
	# qu'il vient de créer : il faut l'ignorer, sinon _remote_id se retrouve
	# affecté au SteamID de l'hôte lui-même et le vrai pair n'est jamais pris
	# en compte (le P2P n'est alors jamais accepté côté hôte).
	if changed_id == _steam.getSteamID():
		return
	if chat_state == CHAT_ENTERED:
		status.emit("Steam : « %s » est entré dans le lobby" % _persona(changed_id))
		_adopt_remote_as_host(changed_id)
	elif changed_id == _remote_id:
		_remote_id = 0
		disconnected.emit("peer_left_lobby")

# Côté hôte, l'adversaire peut se manifester par DEUX callbacks dont l'ordre
# n'est pas garanti : lobby_chat_update (entrée dans le lobby) et
# p2p_session_request (son premier paquet — le HELLO du handshake). Si on
# n'écoutait que le premier, le HELLO pouvait être lu par poll() avant que
# `connected` ne soit émis, donc avant que le handshake local n'existe : le
# paquet était perdu et l'hôte restait bloqué au lobby. On émet donc
# `connected` à la première manifestation, quelle qu'elle soit.
func _adopt_remote_as_host(remote_id: int) -> void:
	if not _is_host or _remote_id != 0:
		return
	_remote_id = remote_id
	status.emit("Steam : pair adopté (%s) — connexion établie côté hôte" % _persona(remote_id))
	connected.emit()

# ── Côté client ──

func _on_lobby_match_list(lobbies: Array) -> void:
	if _is_host:
		return
	status.emit("Steam : %d lobby(s) FateBound trouvé(s)" % lobbies.size())
	# Écarte les lobbies créés par notre propre compte (test à deux instances
	# locales : le « rejoindre » retomberait sur le lobby de l'autre instance).
	var own_id := str(_steam.getSteamID())
	for lobby_id in lobbies:
		if _steam.getLobbyData(lobby_id, LOBBY_OWNER_KEY) != own_id:
			_steam.joinLobby(lobby_id)
			return
	disconnected.emit("steam_same_account" if not lobbies.is_empty() else "steam_no_lobby_found")

func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if _is_host:
		return
	if response != LOBBY_OK:
		status.emit("Steam : entrée dans le lobby refusée (code %d)" % response)
		disconnected.emit("steam_lobby_join_failed")
		return
	_lobby_id = lobby_id
	_remote_id = _steam.getLobbyOwner(lobby_id)
	status.emit("Steam : lobby %d rejoint, hôte = « %s »" % [lobby_id, _persona(_remote_id)])
	# Même compte Steam des deux côtés (deux instances locales sur un seul
	# client Steam) : joinLobby « réussit » car le compte est déjà membre du
	# lobby, mais l'hôte ne voit jamais de second joueur entrer et le P2P
	# bouclerait sur soi-même. On refuse explicitement plutôt que de laisser
	# le client croire qu'il est connecté.
	if _remote_id == _steam.getSteamID():
		_steam.leaveLobby(lobby_id)
		_lobby_id = 0
		_remote_id = 0
		disconnected.emit("steam_same_account")
		return
	# Paquet vide : ouvre la session P2P côté hôte (déclenche sa
	# p2p_session_request), le contenu est ignoré par poll().
	_steam.sendP2PPacket(_remote_id, PackedByteArray(), P2P_SEND_RELIABLE, CHANNEL)
	connected.emit()

# ── Commun ──

func _on_p2p_session_request(remote_id: int) -> void:
	# 1v1 : premier arrivé = notre pair ; ensuite on n'accepte que lui.
	if _remote_id == 0 or remote_id == _remote_id:
		_steam.acceptP2PSessionWithUser(remote_id)
		status.emit("Steam : session P2P acceptée avec « %s »" % _persona(remote_id))
		# Ce callback peut précéder lobby_chat_update : c'est alors lui qui
		# déclenche `connected` côté hôte (voir _adopt_remote_as_host).
		_adopt_remote_as_host(remote_id)
	else:
		status.emit("Steam : session P2P refusée (demandeur inattendu %d)" % remote_id)

func _on_p2p_session_connect_fail(steam_id: int, session_error: int) -> void:
	status.emit("Steam : échec P2P vers %d — %s" % [steam_id,
			P2P_ERRORS.get(session_error, "erreur %d" % session_error)])
	if steam_id == _remote_id and _remote_id != 0:
		_remote_id = 0
		disconnected.emit("steam_p2p_failed")

# Pseudo Steam lisible d'un joueur (pour le journal de diagnostic).
func _persona(steam_id: int) -> String:
	var name: String = _steam.getFriendPersonaName(steam_id)
	return name if name != "" else str(steam_id)
