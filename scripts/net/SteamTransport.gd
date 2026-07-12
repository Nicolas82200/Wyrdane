extends NetTransport
class_name SteamTransport

# Implémentation Steam du transport : lobby Steam pour la mise en relation,
# API Steam Networking Sockets (createListenSocketP2P / connectP2P /
# sendMessageToConnection / receiveMessagesOnConnection) pour les octets de
# jeu.
#
# On utilisait auparavant l'ancienne API P2P (sendP2PPacket), dépréciée par
# Valve : sa traversée NAT est moins fiable et elle ne bascule pas toujours
# proprement sur le relais Steam (SDR) quand la connexion directe échoue —
# symptôme observé : deux joueurs sur des réseaux différents restaient
# bloqués indéfiniment au handshake bien que le lobby les considère connectés.
# Networking Sockets gère ce basculement automatiquement et expose un vrai
# état de connexion (network_connection_status_changed), donc `connected`
# n'est émis qu'une fois la connexion P2P RÉELLEMENT établie — plus une
# simple présomption basée sur la présence dans le lobby.
#
# - host() : crée un lobby public tagué "fatebound" ET un socket d'écoute P2P.
#   La partie démarre quand un second membre entre dans le lobby ET que sa
#   connexion P2P entrante est acceptée.
# - join() : rejoint un lobby précis ({"lobby_id": int}) ou, sans id, cherche
#   le premier lobby Wyrdane ouvert (partie rapide), puis ouvre la connexion
#   P2P vers l'hôte.
#
# Comme pour ENet, aucun identifiant Steam (SteamID64, lobby id) ne fuit hors
# de cette classe : le reste du jeu ne voit que l'interface NetTransport.
# Tous les appels au singleton Steam sont dynamiques (voir SteamService).

const LOBBY_GAME_KEY := "game"
const LOBBY_GAME_VALUE := "fatebound"
const LOBBY_OWNER_KEY := "owner_id"
const VIRTUAL_PORT := 0  # une seule connexion P2P possible par pair : 1v1

# Constantes Steamworks recopiées (le singleton n'existe pas à la compilation).
const LOBBY_TYPE_PUBLIC := 2
const LOBBY_OK := 1                    # CHAT_ROOM_ENTER_RESPONSE_SUCCESS
const CHAT_ENTERED := 1                # CHAT_MEMBER_STATE_CHANGE_ENTERED
const LOBBY_DISTANCE_WORLDWIDE := 3    # LOBBY_DISTANCE_FILTER_WORLDWIDE

# ESteamNetworkingConnectionState (isteamnetworkingtypes.h).
const CONN_STATE_CONNECTING := 1
const CONN_STATE_FINDING_ROUTE := 2
const CONN_STATE_CONNECTED := 3
const CONN_STATE_CLOSED_BY_PEER := 4
const CONN_STATE_PROBLEM_DETECTED_LOCALLY := 5

# k_nSteamNetworkingSend_* (isteamnetworkingtypes.h).
const SEND_UNRELIABLE := 0
const SEND_RELIABLE := 8

var _steam: Object = null
var _lobby_id: int = 0
var _remote_id: int = 0        # SteamID64 du pair distant, connu dès le lobby
var _listen_socket: int = 0    # hôte seulement : socket d'écoute P2P
var _connection_handle: int = 0
var _is_host := false

func host(_params: Dictionary) -> int:
	if not _init_steam():
		return ERR_UNAVAILABLE
	_is_host = true
	_listen_socket = _steam.createListenSocketP2P(VIRTUAL_PORT, {})
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
		# Partie rapide : premier lobby Wyrdane disponible. Sans filtre de
		# distance, Steam ne renvoie que les lobbies « proches » — deux joueurs
		# éloignés ne se trouvaient pas. On force la portée mondiale.
		_steam.addRequestLobbyListStringFilter(LOBBY_GAME_KEY, LOBBY_GAME_VALUE, 0)  # 0 = égalité
		_steam.addRequestLobbyListDistanceFilter(LOBBY_DISTANCE_WORLDWIDE)
		_steam.requestLobbyList()
		status.emit("Steam : recherche d'un lobby Wyrdane (portée mondiale)…")
	return OK

func send(bytes: PackedByteArray, reliable: bool = true) -> void:
	if _steam == null or _connection_handle == 0:
		return
	_steam.sendMessageToConnection(_connection_handle, bytes,
			SEND_RELIABLE if reliable else SEND_UNRELIABLE)

func poll() -> void:
	if _steam == null:
		return
	SteamService.run_callbacks()
	if _connection_handle == 0:
		return
	var messages: Array = _steam.receiveMessagesOnConnection(_connection_handle, 32)
	for message in messages:
		var bytes: PackedByteArray = message.get("payload", message.get("data", PackedByteArray()))
		if not bytes.is_empty():
			packet_received.emit(bytes)

func close() -> void:
	if _steam == null:
		return
	if _connection_handle != 0:
		_steam.closeConnection(_connection_handle, 0, "", false)
	if _listen_socket != 0:
		_steam.closeListenSocket(_listen_socket)
	if _lobby_id != 0:
		_steam.leaveLobby(_lobby_id)
	_disconnect_steam_signals()
	_steam = null
	_lobby_id = 0
	_remote_id = 0
	_listen_socket = 0
	_connection_handle = 0

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
	_steam.connect("network_connection_status_changed", _on_network_connection_status_changed)

func _disconnect_steam_signals() -> void:
	if _steam.is_connected("lobby_created", _on_lobby_created):
		_steam.disconnect("lobby_created", _on_lobby_created)
		_steam.disconnect("lobby_joined", _on_lobby_joined)
		_steam.disconnect("lobby_match_list", _on_lobby_match_list)
		_steam.disconnect("lobby_chat_update", _on_lobby_chat_update)
		_steam.disconnect("network_connection_status_changed", _on_network_connection_status_changed)

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
# Ne fait QUE mémoriser son SteamID — la connexion P2P elle-même est initiée
# par le client (voir _on_lobby_joined) et confirmée par
# _on_network_connection_status_changed, seule source de vérité pour `connected`.
func _on_lobby_chat_update(lobby_id: int, changed_id: int, _making_change_id: int, chat_state: int) -> void:
	if lobby_id != _lobby_id:
		return
	# L'hôte reçoit aussi ce callback pour sa propre entrée dans le lobby
	# qu'il vient de créer : il faut l'ignorer.
	if changed_id == _steam.getSteamID():
		return
	if chat_state == CHAT_ENTERED:
		status.emit("Steam : « %s » est entré dans le lobby — en attente de sa connexion P2P…" % _persona(changed_id))
		_remote_id = changed_id
	elif changed_id == _remote_id:
		_remote_id = 0
		disconnected.emit("peer_left_lobby")

# ── Côté client ──

func _on_lobby_match_list(lobbies: Array) -> void:
	if _is_host:
		return
	status.emit("Steam : %d lobby(s) Wyrdane trouvé(s)" % lobbies.size())
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
	status.emit("Steam : ouverture de la connexion P2P vers l'hôte…")
	_connection_handle = _steam.connectP2P(_remote_id, VIRTUAL_PORT, {})

# ── Commun : suivi de la connexion P2P réelle ──

func _on_network_connection_status_changed(connect_handle: int, connection: Dictionary, _old_state: int) -> void:
	var state: int = connection.get("connection_state", 0)
	var remote_id := _extract_remote_id(connection)
	match state:
		CONN_STATE_CONNECTING:
			# Connexion entrante sur notre socket d'écoute : uniquement pertinent
			# côté hôte. On n'accepte que le pair déjà identifié via le lobby
			# (1v1 : premier arrivé = notre pair).
			if not _is_host or connection.get("listen_socket", 0) != _listen_socket:
				return
			if _remote_id != 0 and remote_id != 0 and remote_id != _remote_id:
				status.emit("Steam : connexion P2P refusée (pair inattendu)")
				_steam.closeConnection(connect_handle, 0, "unexpected peer", false)
				return
			_steam.acceptConnection(connect_handle)
			status.emit("Steam : connexion P2P entrante acceptée, en attente de confirmation…")
		CONN_STATE_CONNECTED:
			_connection_handle = connect_handle
			if remote_id != 0:
				_remote_id = remote_id
			status.emit("Steam : connexion P2P établie avec « %s » ✓" % _persona(_remote_id))
			connected.emit()
		CONN_STATE_CLOSED_BY_PEER, CONN_STATE_PROBLEM_DETECTED_LOCALLY:
			if connect_handle != _connection_handle and _connection_handle != 0:
				return
			var end_reason: int = connection.get("end_reason", 0)
			var end_debug: String = connection.get("end_debug", "")
			status.emit("Steam : connexion P2P perdue (code %d — %s)" % [end_reason, end_debug])
			_connection_handle = 0
			disconnected.emit("steam_p2p_failed")

# L'identité dans le dictionnaire "connection" peut être un SteamID64 brut ou
# un dictionnaire selon la version de GodotSteam — on gère les deux formes.
func _extract_remote_id(connection: Dictionary) -> int:
	var identity: Variant = connection.get("identity", 0)
	if identity is Dictionary:
		return int(identity.get("steam_id", identity.get("steamid", 0)))
	return int(identity)

# Pseudo Steam d'un joueur (pour le journal de diagnostic).
func _persona(steam_id: int) -> String:
	var name: String = _steam.getFriendPersonaName(steam_id)
	return name if name != "" else str(steam_id)
