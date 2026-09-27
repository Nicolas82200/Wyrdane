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
# - join() : rejoint un lobby précis ({"lobby_id": int}) ou, sans id, cherche
#   le premier lobby Wyrdane ouvert (partie rapide), puis ouvre la connexion
#   P2P vers l'hôte.
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

# Relance d'un joinLobby refusé en code 2 (DoesntExist), DANS le même transport
# (sans repasser par la file ni recréer de lobby). Sert autant de correctif que
# de diagnostic : si une relance 1–3 s plus tard réussit, le code 2 venait d'une
# course de propagation côté Steam juste après la création ; si toutes
# échouent, le lobby est réellement invisible pour ce client (AppID différent,
# client hors ligne...) — voir les lignes [SteamDiag] de SteamService.
const LOBBY_DOESNT_EXIST := 2
# 6 tentatives à 1,5 s = ~7,5 s de fenêtre. L'ancien réglage (4 × 1 s = 3,4 s)
# était sans rapport avec le temps que l'HÔTE accorde de son côté
# (HOST_PEER_WAIT_TIMEOUT = 60 s, voir MatchmakingOverlay) : l'invité renonçait
# 56 s avant que l'hôte ne renonce, repartait en file seul, et le décalage se
# rejouait à chaque cycle sans jamais converger. Rester tout de même très en
# dessous des 60 s de l'hôte : au-delà, insister n'apporte rien — si le lobby
# n'est pas apparu en quelques secondes, il est réellement mort et mieux vaut
# rendre l'appariement au backend (_abandon_matched_ticket) pour repartir propre.
const JOIN_MAX_ATTEMPTS := 6
const JOIN_RETRY_DELAY := 1.5
var _join_target: int = 0
var _join_attempt := 0
# Partie rapide : la liste de lobbies Steam est « éventuellement cohérente » et
# renvoie régulièrement des lobbies déjà fermés. Quand le lobby vient de cette
# liste, s'acharner dessus (JOIN_MAX_ATTEMPTS) n'a aucun sens — il faut relancer
# une recherche pour en trouver un autre, vivant. Ces deux champs distinguent ce
# cas du join sur un lobby_id fourni (file backend ou invitation), où le lobby
# est connu vivant et où le retry sur place est le bon réflexe.
const LIST_MAX_ATTEMPTS := 4
const LIST_RETRY_DELAY := 1.5
var _searching_lobby_list := false
var _list_attempt := 0
var _lobby_since_ms := 0  # instant d'entrée/création du lobby courant (log de close)

func host(_params: Dictionary) -> int:
	if not _init_steam():
		return ERR_UNAVAILABLE
	_is_host = true
	_listen_socket = _steam.createListenSocketP2P(VIRTUAL_PORT, {})
	print("[SteamDiag %s] createLobby demandé (%s, listen_socket=%d)" % [
		SteamService.ts(), SteamService.state_summary(), _listen_socket])
	_steam.createLobby(LOBBY_TYPE_PUBLIC, 2)  # 2 membres : c'est du 1v1
	status.emit("Steam : création du lobby demandée…")
	return OK

func join(params: Dictionary) -> int:
	if not _init_steam():
		return ERR_UNAVAILABLE
	_is_host = false
	var lobby_id: int = params.get("lobby_id", 0)
	if lobby_id != 0:
		_searching_lobby_list = false
		_join_target = lobby_id
		_join_attempt = 1
		print("[SteamDiag %s] joinLobby %d, tentative 1/%d (%s)" % [
			SteamService.ts(), lobby_id, JOIN_MAX_ATTEMPTS, SteamService.state_summary()])
		_steam.joinLobby(lobby_id)
		status.emit("Steam : rejoint le lobby %d…" % lobby_id)
	else:
		_list_attempt = 0
		_request_lobby_list()
	return OK

# Reconnexion directe au pair déjà connu (lobby/SteamID conservés après une
# coupure P2P transitoire) : évite de relancer une recherche/entrée de lobby.
# Sans contexte de lobby connu (ex. lobby lui-même quitté), retombe sur join().
func try_reconnect(params: Dictionary) -> int:
	if _steam == null or _lobby_id == 0 or _remote_id == 0:
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
	# Un transport jamais initialisé (host()/join() pas appelés, ou Steam
	# indisponible) n'a rien à fermer côté Steam, mais son état local doit quand
	# même repartir à zéro : l'ancienne sortie sèche laissait _lobby_id/_join_target
	# peuplés, qu'un appel ultérieur pouvait relire comme un lobby encore vivant.
	if _steam == null:
		_reset_state()
		return
	if _connection_handle != 0:
		_steam.closeConnection(_connection_handle, 0, "", false)
	if _listen_socket != 0:
		_steam.closeListenSocket(_listen_socket)
	if _lobby_id != 0:
		print("[SteamDiag %s] leaveLobby %d (%s, dans le lobby depuis %.1fs)" % [
			SteamService.ts(), _lobby_id, "hôte" if _is_host else "invité",
			(Time.get_ticks_msec() - _lobby_since_ms) / 1000.0])
		_steam.leaveLobby(_lobby_id)
	elif _join_target != 0:
		print("[SteamDiag %s] close() pendant un join non abouti vers %d (tentative %d)" % [
			SteamService.ts(), _join_target, _join_attempt])
	_disconnect_steam_signals()
	_reset_state()

func _reset_state() -> void:
	_steam = null
	_lobby_id = 0
	_remote_id = 0
	_listen_socket = 0
	_connection_handle = 0
	_join_target = 0
	_join_attempt = 0
	_searching_lobby_list = false
	_list_attempt = 0
	_lobby_since_ms = 0

# ─── Interne ──────────────────────────────────────────────────────────────────

func _init_steam() -> bool:
	if not SteamService.ensure_init():
		push_warning("SteamTransport : Steam indisponible (extension absente ou client fermé)")
		return false
	_steam = SteamService.steam()
	_connect_steam_signals()
	return true

# Les signaux vivent sur le singleton Steam GLOBAL, partagé par tous les
# transports (SteamTransport 1v1 et ArenaSteamTransport) : reconnecter un
# handler déjà branché est une erreur Godot. Ça arrive réellement, via
# try_reconnect() qui repasse par join() donc par _init_steam() sur un transport
# déjà initialisé — d'où la garde.
func _connect_steam_signals() -> void:
	if _steam.is_connected("lobby_created", _on_lobby_created):
		return
	_steam.connect("lobby_created", _on_lobby_created)
	_steam.connect("lobby_joined", _on_lobby_joined)
	_steam.connect("lobby_match_list", _on_lobby_match_list)
	_steam.connect("lobby_chat_update", _on_lobby_chat_update)
	_steam.connect("network_connection_status_changed", _on_network_connection_status_changed)

func _disconnect_steam_signals() -> void:
	if _steam == null:
		return
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
	print("[SteamDiag %s] lobby_created result=%d lobby=%d" % [SteamService.ts(), result, lobby_id])
	if result != LOBBY_OK:
		status.emit("Steam : échec de création du lobby (code %d)" % result)
		disconnected.emit("steam_lobby_create_failed")
		return
	_lobby_id = lobby_id
	_lobby_since_ms = Time.get_ticks_msec()
	status.emit("Steam : lobby %d créé — en attente d'un adversaire…" % lobby_id)
	print("[SteamDiag %s] lobby %d : owner=%s membres=%d (%s)" % [
		SteamService.ts(), lobby_id, str(_steam.getLobbyOwner(lobby_id)),
		_steam.getNumLobbyMembers(lobby_id), SteamService.state_summary()])
	# Tag le lobby pour que la recherche « partie rapide » le trouve (voir
	# _request_lobby_list) : c'est le seul filtre qui distingue un lobby Wyrdane
	# des autres lobbies de la liste Steam.
	_steam.setLobbyData(lobby_id, LOBBY_GAME_KEY, LOBBY_GAME_VALUE)
	# Publie le SteamID de l'hôte dans les données du lobby : contrairement à
	# getLobbyOwner (fiable seulement une fois membre), cette donnée est lisible
	# depuis les résultats de recherche et permet au client d'écarter ses
	# propres lobbies (cas « même compte », voir _on_lobby_match_list).
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
	print("[SteamDiag %s] lobby_chat_update lobby=%d changed=%d state=%d" % [
		SteamService.ts(), lobby_id, changed_id, chat_state])
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

# Demande à Steam la liste des lobbies Wyrdane ouverts. Sans filtre de distance,
# Steam ne renvoie que les lobbies « proches » — deux joueurs éloignés ne se
# trouvaient jamais. On force donc la portée mondiale.
func _request_lobby_list() -> void:
	_searching_lobby_list = true
	_join_target = 0
	_join_attempt = 0
	_list_attempt += 1
	print("[SteamDiag %s] requestLobbyList, recherche %d/%d (%s)" % [
		SteamService.ts(), _list_attempt, LIST_MAX_ATTEMPTS, SteamService.state_summary()])
	_steam.addRequestLobbyListStringFilter(LOBBY_GAME_KEY, LOBBY_GAME_VALUE, 0)  # 0 = égalité
	_steam.addRequestLobbyListDistanceFilter(LOBBY_DISTANCE_WORLDWIDE)
	_steam.requestLobbyList()
	status.emit("Steam : recherche d'un lobby Wyrdane (portée mondiale)…")

func _on_lobby_match_list(lobbies: Array) -> void:
	if _is_host:
		return
	status.emit("Steam : %d lobby(s) Wyrdane trouvé(s)" % lobbies.size())
	# Écarte les lobbies créés par notre propre compte (test à deux instances
	# locales : le « rejoindre » retomberait sur le lobby de l'autre instance).
	var own_id := str(_steam.getSteamID())
	for lobby_id in lobbies:
		if _steam.getLobbyData(lobby_id, LOBBY_OWNER_KEY) != own_id:
			_join_target = lobby_id
			_join_attempt = 1
			print("[SteamDiag %s] joinLobby %d issu de la liste, recherche %d/%d (%s)" % [
				SteamService.ts(), lobby_id, _list_attempt, LIST_MAX_ATTEMPTS,
				SteamService.state_summary()])
			_steam.joinLobby(lobby_id)
			return
	_searching_lobby_list = false
	disconnected.emit("steam_same_account" if not lobbies.is_empty() else "steam_no_lobby_found")

func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if _is_host:
		return
	print("[SteamDiag %s] lobby_joined lobby=%d response=%d tentative=%d/%d (%s)" % [
		SteamService.ts(), lobby_id, response, _join_attempt, JOIN_MAX_ATTEMPTS,
		SteamService.state_summary()])
	if response != LOBBY_OK:
		if response == LOBBY_DOESNT_EXIST and _searching_lobby_list:
			# Lobby périmé servi par la liste Steam : chercher ailleurs, pas plus fort.
			if _list_attempt >= LIST_MAX_ATTEMPTS:
				status.emit("Steam : aucun lobby joignable trouvé")
				_join_target = 0
				_searching_lobby_list = false
				disconnected.emit("steam_no_lobby_found")
				return
			status.emit("Steam : lobby %d périmé (code 2), nouvelle recherche…" % lobby_id)
			await get_tree().create_timer(LIST_RETRY_DELAY).timeout
			if _steam == null or not _searching_lobby_list:
				return
			_request_lobby_list()
			return
		if response == LOBBY_DOESNT_EXIST and _join_target != 0 and _join_attempt < JOIN_MAX_ATTEMPTS:
			var target := _join_target
			status.emit("Steam : lobby %d introuvable (code 2), nouvel essai dans %.0fs…" % [target, JOIN_RETRY_DELAY])
			await get_tree().create_timer(JOIN_RETRY_DELAY).timeout
			# Transport fermé ou autre join lancé pendant l'attente : abandon.
			if _steam == null or _join_target != target:
				return
			_join_attempt += 1
			print("[SteamDiag %s] joinLobby %d, tentative %d/%d (%s)" % [
				SteamService.ts(), target, _join_attempt, JOIN_MAX_ATTEMPTS, SteamService.state_summary()])
			_steam.joinLobby(target)
			return
		status.emit("Steam : entrée dans le lobby refusée (code %d)" % response)
		_join_target = 0
		disconnected.emit("steam_lobby_join_failed")
		return
	_join_target = 0
	_searching_lobby_list = false
	_lobby_id = lobby_id
	_lobby_since_ms = Time.get_ticks_msec()
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
