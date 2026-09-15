extends ArenaNetTransport
class_name ArenaSteamTransport

# Implémentation Steam du transport Arena : même fondations que
# SteamTransport.gd (1v1 — lobby Steam + Steam Networking Sockets P2P),
# généralisées à une topologie ÉTOILE jusqu'à ArenaConstants.PARTICIPANT_COUNT
# joueurs : l'hôte ouvre une connexion P2P distincte vers chaque client
# (jusqu'à PARTICIPANT_COUNT - 1), chaque client n'ouvre qu'UNE connexion vers
# l'hôte. Pas de mesh complet (28 connexions à 8 joueurs) : l'hôte fait
# autorité et relaie (voir README « Réseau & Visibilité »).
#
# Tag de lobby distinct du 1v1 ("wyrdane-arena" contre "wyrdane") pour que les
# recherches de partie rapide 1v1/Arena ne se mélangent jamais.
#
# Fichier volontairement séparé de SteamTransport.gd (voir ArenaNetTransport) :
# seules les vérifications de sécurité P2P sont partagées, via SteamP2PGuard.

const LOBBY_GAME_KEY := "game"
const LOBBY_GAME_VALUE := "wyrdane-arena"
const LOBBY_OWNER_KEY := "owner_id"
const VIRTUAL_PORT := 0

const LOBBY_TYPE_PUBLIC := 2
const LOBBY_OK := 1
const CHAT_ENTERED := 1
const LOBBY_DISTANCE_WORLDWIDE := 3

const CONN_STATE_CONNECTING := 1
const CONN_STATE_FINDING_ROUTE := 2
const CONN_STATE_CONNECTED := 3
const CONN_STATE_CLOSED_BY_PEER := 4
const CONN_STATE_PROBLEM_DETECTED_LOCALLY := 5

const SEND_UNRELIABLE := 0
const SEND_RELIABLE := 8

var _steam: Object = null
var _lobby_id: int = 0
var _is_host := false
var _listen_socket: int = 0            # hôte uniquement
var _host_steam_id: int = 0            # client uniquement : SteamID de l'hôte
var _host_connection_handle: int = 0   # client uniquement

# Hôte uniquement : un pair par client connecté (topologie étoile, voir
# en-tête de fichier).
var _connections_by_steam_id: Dictionary = {}   # steam_id -> connection_handle
var _steam_id_by_connection: Dictionary = {}    # connection_handle -> steam_id

func host(_params: Dictionary) -> int:
	if not _init_steam():
		return ERR_UNAVAILABLE
	_is_host = true
	_listen_socket = _steam.createListenSocketP2P(VIRTUAL_PORT, {})
	_steam.createLobby(LOBBY_TYPE_PUBLIC, ArenaConstants.PARTICIPANT_COUNT)
	status.emit("Steam (Arena) : création de la table demandée…")
	return OK

func join(params: Dictionary) -> int:
	if not _init_steam():
		return ERR_UNAVAILABLE
	_is_host = false
	var lobby_id: int = params.get("lobby_id", 0)
	if lobby_id != 0:
		_steam.joinLobby(lobby_id)
		status.emit("Steam (Arena) : rejoint la table %d…" % lobby_id)
	else:
		# Pas de filtre de distance restrictif (portée mondiale, même choix que
		# le 1v1 — voir SteamTransport.join) : sans ça, deux joueurs éloignés ne
		# se trouveraient pas.
		_steam.addRequestLobbyListStringFilter(LOBBY_GAME_KEY, LOBBY_GAME_VALUE, 0)  # 0 = égalité
		_steam.addRequestLobbyListDistanceFilter(LOBBY_DISTANCE_WORLDWIDE)
		_steam.requestLobbyList()
		status.emit("Steam (Arena) : recherche d'une table Wyrdane (portée mondiale)…")
	return OK

func send(peer_id: int, bytes: PackedByteArray, reliable: bool = true) -> void:
	if _steam == null:
		return
	var handle: int = _connections_by_steam_id.get(peer_id, 0) if _is_host else _host_connection_handle
	if handle != 0:
		_steam.sendMessageToConnection(handle, bytes, SEND_RELIABLE if reliable else SEND_UNRELIABLE)

func broadcast(bytes: PackedByteArray, reliable: bool = true) -> void:
	if _steam == null or not _is_host:
		return
	for handle in _connections_by_steam_id.values():
		_steam.sendMessageToConnection(handle, bytes, SEND_RELIABLE if reliable else SEND_UNRELIABLE)

func poll() -> void:
	if _steam == null:
		return
	SteamService.run_callbacks()
	if _is_host:
		# .duplicate() : receiveMessagesOnConnection ne modifie pas le
		# dictionnaire, mais un message reçu pourrait en théorie déclencher (via
		# packet_received, traité plus haut dans la pile) une fermeture de
		# connexion côté appelant avant la fin de cette boucle — itérer sur une
		# copie évite toute mutation pendant l'itération.
		for connection_handle in _steam_id_by_connection.keys().duplicate():
			if not _steam_id_by_connection.has(connection_handle):
				continue
			var messages: Array = _steam.receiveMessagesOnConnection(connection_handle, 32)
			for message in messages:
				var bytes: PackedByteArray = message.get("payload", message.get("data", PackedByteArray()))
				if not bytes.is_empty():
					packet_received.emit(_steam_id_by_connection[connection_handle], bytes)
	else:
		if _host_connection_handle == 0:
			return
		var messages: Array = _steam.receiveMessagesOnConnection(_host_connection_handle, 32)
		for message in messages:
			var bytes: PackedByteArray = message.get("payload", message.get("data", PackedByteArray()))
			if not bytes.is_empty():
				packet_received.emit(_host_steam_id, bytes)

func close() -> void:
	if _steam == null:
		return
	for connection_handle in _steam_id_by_connection.keys():
		_steam.closeConnection(connection_handle, 0, "", false)
	if _host_connection_handle != 0:
		_steam.closeConnection(_host_connection_handle, 0, "", false)
	if _listen_socket != 0:
		_steam.closeListenSocket(_listen_socket)
	if _lobby_id != 0:
		_steam.leaveLobby(_lobby_id)
	_disconnect_steam_signals()
	_steam = null
	_lobby_id = 0
	_listen_socket = 0
	_host_steam_id = 0
	_host_connection_handle = 0
	_connections_by_steam_id.clear()
	_steam_id_by_connection.clear()

func invite_friends() -> void:
	if _steam == null or _lobby_id == 0:
		return
	_steam.activateGameOverlayInviteDialog(_lobby_id)

func open_add_friend_overlay(peer_id: int) -> void:
	if _steam == null or peer_id == 0:
		return
	_steam.activateGameOverlayToUser("steamid_friend_add", peer_id)

func connected_peer_ids() -> Array[int]:
	var ids: Array[int] = []
	if _is_host:
		for id in _connections_by_steam_id.keys():
			ids.append(id)
	elif _host_connection_handle != 0:
		ids.append(_host_steam_id)
	return ids

# ─── Interne ──────────────────────────────────────────────────────────────────

func _init_steam() -> bool:
	if not SteamService.ensure_init():
		push_warning("ArenaSteamTransport : Steam indisponible (extension absente ou client fermé)")
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
		status.emit("Steam (Arena) : échec de création de la table (code %d)" % result)
		disconnected.emit("steam_lobby_create_failed")
		return
	_lobby_id = lobby_id
	status.emit("Steam (Arena) : table %d créée — en attente d'adversaires…" % lobby_id)
	_steam.setLobbyData(lobby_id, LOBBY_GAME_KEY, LOBBY_GAME_VALUE)
	_steam.setLobbyData(lobby_id, LOBBY_OWNER_KEY, str(_steam.getSteamID()))
	_steam.setLobbyJoinable(lobby_id, true)
	session_ready.emit(lobby_id)

# Un membre entre/sort du lobby : contrairement au 1v1 (un seul `_remote_id`
# mémorisé à l'avance), rien à mémoriser ici avant coup — chaque connexion
# P2P entrante est validée indépendamment à son arrivée (voir
# _on_network_connection_status_changed). Un départ DU LOBBY avant même
# l'ouverture d'une connexion P2P (ex. changement d'avis pendant la
# recherche) n'a donc aucun pair à libérer ici.
func _on_lobby_chat_update(lobby_id: int, changed_id: int, _making_change_id: int, chat_state: int) -> void:
	if lobby_id != _lobby_id or not _is_host:
		return
	if changed_id == _steam.getSteamID():
		return
	if chat_state == CHAT_ENTERED:
		status.emit("Steam (Arena) : « %s » est entré dans la table — en attente de sa connexion P2P…" % _persona(changed_id))
	elif _connections_by_steam_id.has(changed_id):
		var connection_handle: int = _connections_by_steam_id[changed_id]
		_connections_by_steam_id.erase(changed_id)
		_steam_id_by_connection.erase(connection_handle)
		peer_left.emit(changed_id, "peer_left_lobby")

# ── Côté client ──

func _on_lobby_match_list(lobbies: Array) -> void:
	if _is_host:
		return
	status.emit("Steam (Arena) : %d table(s) Wyrdane trouvée(s)" % lobbies.size())
	# Écarte les tables créées par notre propre compte (voir SteamTransport,
	# même garde-fou de test à deux instances locales).
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
		status.emit("Steam (Arena) : entrée dans la table refusée (code %d)" % response)
		disconnected.emit("steam_lobby_join_failed")
		return
	_lobby_id = lobby_id
	_host_steam_id = _steam.getLobbyOwner(lobby_id)
	status.emit("Steam (Arena) : table %d rejointe, hôte = « %s »" % [lobby_id, _persona(_host_steam_id)])
	if _host_steam_id == _steam.getSteamID():
		_steam.leaveLobby(lobby_id)
		_lobby_id = 0
		_host_steam_id = 0
		disconnected.emit("steam_same_account")
		return
	status.emit("Steam (Arena) : ouverture de la connexion P2P vers l'hôte…")
	_host_connection_handle = _steam.connectP2P(_host_steam_id, VIRTUAL_PORT, {})

# ── Commun : suivi des connexions P2P réelles ──

func _on_network_connection_status_changed(connect_handle: int, connection: Dictionary, _old_state: int) -> void:
	var state: int = connection.get("connection_state", 0)
	var remote_id := SteamP2PGuard.extract_remote_id(connection)
	match state:
		CONN_STATE_CONNECTING:
			if not _is_host or connection.get("listen_socket", 0) != _listen_socket:
				return
			# Contrairement au 1v1 (un seul pair attendu, déjà identifié) :
			# n'importe quel membre RÉEL de la table peut initier sa connexion
			# P2P à tout moment — voir SteamP2PGuard pour la justification de
			# cette vérification (lobby public, propriétaire/membres lisibles
			# sans jamais le rejoindre).
			if remote_id == 0 or not SteamP2PGuard.is_lobby_member(_steam, _lobby_id, remote_id):
				status.emit("Steam (Arena) : connexion P2P refusée (pair non membre de la table)")
				_steam.closeConnection(connect_handle, 0, "unexpected peer", false)
				return
			if _connections_by_steam_id.has(remote_id):
				# Reconnexion d'un pair déjà connecté (ex. coupure transitoire,
				# détectée par le client avant que l'hôte n'ait lui-même reçu
				# CONN_STATE_CLOSED_BY_PEER pour l'ancienne connexion) : ferme
				# l'ancienne, orpheline, avant d'accepter la nouvelle — sans ça,
				# _steam_id_by_connection garderait une entrée pointant vers un
				# handle mort. Volontairement PAS de vérification de capacité
				# ici : ce pair occupe déjà un siège, cette connexion ne fait que
				# le remplacer, jamais en prendre un nouveau — sans ce `elif`
				# (plutôt qu'un `if` séparé), une table exactement pleine
				# rejetait à tort la reconnexion d'un pair qui y avait déjà sa
				# place (son propre ancien handle, encore compté dans .size()
				# puisque seul _steam_id_by_connection était nettoyé ci-dessus,
				# faisait lui-même passer le seuil "table complète").
				var stale_handle: int = _connections_by_steam_id[remote_id]
				_steam_id_by_connection.erase(stale_handle)
				_steam.closeConnection(stale_handle, 0, "", false)
			elif _connections_by_steam_id.size() >= ArenaConstants.PARTICIPANT_COUNT - 1:
				status.emit("Steam (Arena) : connexion P2P refusée (table déjà complète)")
				_steam.closeConnection(connect_handle, 0, "table full", false)
				return
			_steam.acceptConnection(connect_handle)
			status.emit("Steam (Arena) : connexion P2P entrante acceptée, en attente de confirmation…")
		CONN_STATE_CONNECTED:
			if _is_host:
				if remote_id == 0:
					return
				_connections_by_steam_id[remote_id] = connect_handle
				_steam_id_by_connection[connect_handle] = remote_id
				status.emit("Steam (Arena) : connexion P2P établie avec « %s » ✓" % _persona(remote_id))
				peer_joined.emit(remote_id, _persona(remote_id))
			else:
				if connect_handle != _host_connection_handle:
					return
				status.emit("Steam (Arena) : connexion P2P établie avec l'hôte ✓")
				peer_joined.emit(_host_steam_id, _persona(_host_steam_id))
		CONN_STATE_CLOSED_BY_PEER, CONN_STATE_PROBLEM_DETECTED_LOCALLY:
			var end_reason: int = connection.get("end_reason", 0)
			var end_debug: String = connection.get("end_debug", "")
			if _is_host:
				if not _steam_id_by_connection.has(connect_handle):
					return
				var lost_id: int = _steam_id_by_connection[connect_handle]
				_steam_id_by_connection.erase(connect_handle)
				_connections_by_steam_id.erase(lost_id)
				status.emit("Steam (Arena) : connexion P2P perdue avec « %s » (code %d — %s)" % [_persona(lost_id), end_reason, end_debug])
				peer_left.emit(lost_id, "steam_p2p_failed")
			else:
				if connect_handle != _host_connection_handle:
					return
				status.emit("Steam (Arena) : connexion P2P perdue avec l'hôte (code %d — %s)" % [end_reason, end_debug])
				_host_connection_handle = 0
				disconnected.emit("steam_p2p_failed")

# Pseudo Steam d'un joueur (pour le journal de diagnostic).
func _persona(steam_id: int) -> String:
	var persona_name: String = _steam.getFriendPersonaName(steam_id)
	return persona_name if persona_name != "" else str(steam_id)
