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
# - host() : crée un lobby public tagué "wyrdane" ET un socket d'écoute P2P.
#   La partie démarre quand un second membre entre dans le lobby ET que sa
#   connexion P2P entrante est acceptée.
# - join() : rejoint un lobby PRÉCIS ({"lobby_id": int}) puis ouvre la connexion
#   P2P vers l'hôte. Il n'existe plus de variante « cherche un lobby ouvert » :
#   le lobby_id vient toujours de la file backend ou d'une invitation Steam
#   acceptée (voir join pour le détail de ce retrait).
#
# Aucun identifiant Steam (SteamID64, lobby id) ne fuit hors de cette classe :
# le reste du jeu ne voit que l'interface NetTransport.
# Tous les appels au singleton Steam sont dynamiques (voir SteamService).

const LOBBY_GAME_KEY := "game"
const LOBBY_GAME_VALUE := "wyrdane"
const LOBBY_OWNER_KEY := "owner_id"
const VIRTUAL_PORT := 0  # une seule connexion P2P possible par pair : 1v1

# Constantes Steamworks recopiées (le singleton n'existe pas à la compilation).
const LOBBY_TYPE_PUBLIC := 2
const LOBBY_OK := 1                    # CHAT_ROOM_ENTER_RESPONSE_SUCCESS
const CHAT_ENTERED := 1                # CHAT_MEMBER_STATE_CHANGE_ENTERED

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

# Rejoint un lobby PRÉCIS, jamais « celui qu'on trouve » : le lobby_id vient
# toujours d'une source qui sait avec qui on joue — la file backend (voir
# MatchmakingOverlay._on_queue_matched) ou une invitation Steam acceptée
# (_on_steam_join_requested).
#
# Il existait une variante sans lobby_id qui prenait le premier lobby Wyrdane de
# la liste Steam (portée mondiale). Supprimée le 2026-09-25 : cette liste est
# éventuellement cohérente et renvoyait des lobbies DÉJÀ FERMÉS, dont l'entrée
# échouait avec CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST — et comme les deux
# clients cherchaient et hébergeaient chacun de leur côté, ils détruisaient
# tour à tour le lobby que l'autre venait de trouver sans jamais tomber en
# phase. La file backend est désormais le seul point de rendez-vous.
func join(params: Dictionary) -> int:
	if not _init_steam():
		return ERR_UNAVAILABLE
	_is_host = false
	var lobby_id: int = params.get("lobby_id", 0)
	if lobby_id == 0:
		push_error("SteamTransport.join : lobby_id manquant — un lobby ne se cherche plus, il est fourni par la file backend ou une invitation")
		return ERR_INVALID_PARAMETER
	_steam.joinLobby(lobby_id)
	status.emit("Steam : rejoint le lobby %d…" % lobby_id)
	return OK

# Reconnexion directe au pair déjà connu (lobby/SteamID conservés après une
# coupure P2P transitoire) : évite de repasser par une entrée en lobby.
# Sans contexte de lobby connu (lobby lui-même quitté), on ne peut re-rejoindre
# que si l'appelant sait QUEL lobby viser (un invité garde son lobby_id ; un
# hôte, lui, n'a plus rien à rejoindre) — l'appelant réessaie de toute façon
# jusqu'à l'expiration du délai de grâce, voir
# NetworkManager.RECONNECT_GRACE_SECONDS.
func try_reconnect(params: Dictionary) -> int:
	if _steam == null or _lobby_id == 0 or _remote_id == 0:
		if int(params.get("lobby_id", 0)) == 0:
			return ERR_UNAVAILABLE
		return join(params)
	status.emit("Steam : nouvelle tentative de connexion P2P…")
	_connection_handle = _steam.connectP2P(_remote_id, VIRTUAL_PORT, {})
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

# Ouvre l'overlay Steam d'invitation d'amis pour le lobby en cours (hôte
# uniquement — un client n'a pas de lobby à proposer). No-op si aucun lobby
# n'est encore créé (host() pas encore confirmé par lobby_created).
func invite_friends() -> void:
	if _steam == null or _lobby_id == 0:
		return
	_steam.activateGameOverlayInviteDialog(_lobby_id)

func open_add_friend_overlay() -> void:
	if _steam == null or _remote_id == 0:
		return
	_steam.activateGameOverlayToUser("steamid_friend_add", _remote_id)

func remote_display_name() -> String:
	if _steam == null or _remote_id == 0:
		return ""
	# Contrairement à _persona() (diagnostic uniquement) : pas de repli sur le
	# SteamID64 brut ici, ce serait affiché tel quel à l'écran (voir écran VS,
	# MatchmakingOverlay._show_vs_screen) — laisser l'appelant retomber sur un libellé
	# générique ("Adversaire") est préférable à un numéro illisible.
	return _steam.getFriendPersonaName(_remote_id)

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
	_steam.connect("lobby_chat_update", _on_lobby_chat_update)
	_steam.connect("network_connection_status_changed", _on_network_connection_status_changed)

func _disconnect_steam_signals() -> void:
	if _steam.is_connected("lobby_created", _on_lobby_created):
		_steam.disconnect("lobby_created", _on_lobby_created)
		_steam.disconnect("lobby_joined", _on_lobby_joined)
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
	# Identifie le lobby comme étant du Wyrdane 1v1. Purement informatif depuis
	# que plus rien ne découvre un lobby par recherche (voir join) : conservé
	# parce que ça reste ce qui distingue un lobby de partie en inspection, et
	# que le coût est nul.
	_steam.setLobbyData(lobby_id, LOBBY_GAME_KEY, LOBBY_GAME_VALUE)
	_steam.setLobbyData(lobby_id, LOBBY_OWNER_KEY, str(_steam.getSteamID()))
	_steam.setLobbyJoinable(lobby_id, true)
	session_ready.emit(lobby_id)

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
		peer_identified.emit()
	elif changed_id == _remote_id:
		_remote_id = 0
		disconnected.emit("peer_left_lobby")

# ── Côté client ──

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
	peer_identified.emit()
	status.emit("Steam : ouverture de la connexion P2P vers l'hôte…")
	_connection_handle = _steam.connectP2P(_remote_id, VIRTUAL_PORT, {})

# ── Commun : suivi de la connexion P2P réelle ──

func _on_network_connection_status_changed(connect_handle: int, connection: Dictionary, _old_state: int) -> void:
	var state: int = connection.get("connection_state", 0)
	var remote_id := SteamP2PGuard.extract_remote_id(connection)
	match state:
		CONN_STATE_CONNECTING:
			# Connexion entrante sur notre socket d'écoute : uniquement pertinent
			# côté hôte. On n'accepte que le pair déjà identifié via le lobby
			# (1v1 : premier arrivé = notre pair).
			if not _is_host or connection.get("listen_socket", 0) != _listen_socket:
				return
			# Le lobby est PUBLIC et son LOBBY_OWNER_KEY lisible par quiconque liste
			# les lobbies "wyrdane" sans jamais le rejoindre : un tiers non invité
			# peut appeler connectP2P directement contre notre SteamID. Ne JAMAIS se
			# fier uniquement à `_remote_id` : il n'est peuplé que par
			# _on_lobby_chat_update (flux Steam indépendant, sans garantie d'ordre
			# avec cet évènement P2P) — tant qu'il vaut encore 0, l'ancienne garde
			# laissait passer n'importe quelle connexion entrante. On vérifie ici
			# l'appartenance RÉELLE au lobby au moment de la connexion, indépendamment
			# de l'état (peut-être en retard) de `_remote_id`.
			if remote_id == 0 or not SteamP2PGuard.is_lobby_member(_steam, _lobby_id, remote_id):
				status.emit("Steam : connexion P2P refusée (pair non membre du lobby)")
				_steam.closeConnection(connect_handle, 0, "unexpected peer", false)
				return
			if _remote_id != 0 and remote_id != _remote_id:
				status.emit("Steam : connexion P2P refusée (pair inattendu)")
				_steam.closeConnection(connect_handle, 0, "unexpected peer", false)
				return
			_remote_id = remote_id
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

# (Vérification d'appartenance au lobby et extraction d'identité : voir
# SteamP2PGuard, partagé avec ArenaSteamTransport.)

# Pseudo Steam d'un joueur (pour le journal de diagnostic).
func _persona(steam_id: int) -> String:
	var persona_name: String = _steam.getFriendPersonaName(steam_id)
	return persona_name if persona_name != "" else str(steam_id)
