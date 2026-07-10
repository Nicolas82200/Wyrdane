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
const CHANNEL := 0

# Constantes Steamworks recopiées (le singleton n'existe pas à la compilation).
const LOBBY_TYPE_PUBLIC := 2
const LOBBY_OK := 1                    # CHAT_ROOM_ENTER_RESPONSE_SUCCESS
const CHAT_ENTERED := 1                # CHAT_MEMBER_STATE_CHANGE_ENTERED
const P2P_SEND_UNRELIABLE := 0
const P2P_SEND_RELIABLE := 2

var _steam: Object = null
var _lobby_id: int = 0
var _remote_id: int = 0  # SteamID64 du pair distant
var _is_host := false

func host(_params: Dictionary) -> int:
	if not _init_steam():
		return ERR_UNAVAILABLE
	_is_host = true
	_steam.createLobby(LOBBY_TYPE_PUBLIC, 2)  # 2 membres : c'est du 1v1
	return OK

func join(params: Dictionary) -> int:
	if not _init_steam():
		return ERR_UNAVAILABLE
	_is_host = false
	var lobby_id: int = params.get("lobby_id", 0)
	if lobby_id != 0:
		_steam.joinLobby(lobby_id)
	else:
		# Partie rapide : premier lobby FateBound disponible.
		_steam.addRequestLobbyListStringFilter(LOBBY_GAME_KEY, LOBBY_GAME_VALUE, 0)  # 0 = égalité
		_steam.requestLobbyList()
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
		disconnected.emit("steam_lobby_create_failed")
		return
	_lobby_id = lobby_id
	# Tag le lobby pour que la recherche « partie rapide » le trouve.
	_steam.setLobbyData(lobby_id, LOBBY_GAME_KEY, LOBBY_GAME_VALUE)
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
		if _is_host and _remote_id == 0:
			_remote_id = changed_id
			connected.emit()
	elif changed_id == _remote_id:
		_remote_id = 0
		disconnected.emit("peer_left_lobby")

# ── Côté client ──

func _on_lobby_match_list(lobbies: Array) -> void:
	if _is_host:
		return
	if lobbies.is_empty():
		disconnected.emit("steam_no_lobby_found")
		return
	_steam.joinLobby(lobbies[0])

func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if _is_host:
		return
	if response != LOBBY_OK:
		disconnected.emit("steam_lobby_join_failed")
		return
	_lobby_id = lobby_id
	_remote_id = _steam.getLobbyOwner(lobby_id)
	# Paquet vide : ouvre la session P2P côté hôte (déclenche sa
	# p2p_session_request), le contenu est ignoré par poll().
	_steam.sendP2PPacket(_remote_id, PackedByteArray(), P2P_SEND_RELIABLE, CHANNEL)
	connected.emit()

# ── Commun ──

func _on_p2p_session_request(remote_id: int) -> void:
	# 1v1 : on n'accepte que le pair attendu (l'hôte ne connaît le sien qu'à
	# l'entrée dans le lobby, déjà passée quand ce callback arrive).
	if _remote_id == 0 or remote_id == _remote_id:
		_steam.acceptP2PSessionWithUser(remote_id)

func _on_p2p_session_connect_fail(steam_id: int, _session_error: int) -> void:
	if steam_id == _remote_id and _remote_id != 0:
		_remote_id = 0
		disconnected.emit("steam_p2p_failed")
