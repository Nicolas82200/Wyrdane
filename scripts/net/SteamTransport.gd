extends NetTransport
class_name SteamTransport

# Implémentation Steam du transport : API Steam Networking Sockets
# (createListenSocketP2P / connectP2P / sendMessageToConnection /
# receiveMessagesOnConnection) pour les octets de jeu, avec DEUX modes de
# rendez-vous — c'est-à-dire deux façons de savoir À QUI se connecter.
#
# ── Mode DIRECT (file d'attente backend : Normal/Classé) ─────────────────────
# Le backend connaît déjà les deux joueurs qu'il vient d'apparier, donc il
# connaît leurs deux SteamID64 (linked_accounts.external_id) : il les renvoie
# dans la réponse « matched » du poll de file. Il n'y a alors plus rien à
# découvrir côté Steam — l'hôte ouvre un socket d'écoute, l'invité appelle
# connectP2P sur le SteamID de l'hôte, terminé.
#
# C'est le mode par défaut depuis le 2026-09-28, et il remplace le rendez-vous
# par lobby Steam pour tout ce qui vient de la file. Raison : ConnectP2P
# n'exige NI amitié NI appartenance à un lobby (doc Steamworks
# ISteamNetworkingSockets — seul InitRelayNetworkAccess est recommandé, fait
# dans SteamService), donc le lobby n'apportait qu'un annuaire intermédiaire…
# et toute une classe d'échecs qui a coûté plusieurs sessions de debug :
#   - un transport qu'on ferme QUITTE son lobby, et un lobby quitté par son
#     dernier membre est détruit côté Steam : toute relance de recherche
#     rendait injoignable le lobby que le pair était en train de rejoindre,
#     qui recevait alors « entrée refusée (code 2) » (voir l'historique dans
#     CLAUDE.md / devlogs des 2026-09-25 et 2026-09-28) ;
#   - il fallait un aller-retour HTTP de plus (l'hôte publie son lobby_id, que
#     l'invité découvre à son poll suivant), avec son propre lot de réessais,
#     de délais et d'états intermédiaires ;
#   - un CSteamID 64 bits transporté en JSON se fait arrondir dès qu'un maillon
#     le lit comme un nombre (corrigé deux fois, côté driver MySQL puis côté
#     sérialisation) — un id de lobby ne traverse plus rien du tout ici.
# En mode direct, l'identité attendue vient d'une autorité de confiance (le
# backend) : la vérification de sécurité côté hôte est donc PLUS stricte
# qu'avec un lobby public (comparaison exacte au SteamID annoncé, au lieu
# d'une appartenance à un lobby que n'importe qui pouvait lister).
#
# ── Mode LOBBY (invitation d'un ami) ────────────────────────────────────────
# Conservé uniquement pour les invitations : un lobby Steam est ce qui rend le
# « Rejoindre la partie » natif de l'overlay Steam possible (un ami peut
# rejoindre depuis son propre client Steam, sans passer par la popup en jeu).
# L'hôte crée un lobby public tagué "wyrdane", l'invité le rejoint par son id
# puis ouvre la connexion P2P vers le propriétaire.
#
# Dans les deux modes, `connected` n'est émis qu'une fois la connexion P2P
# RÉELLEMENT établie (network_connection_status_changed), jamais sur une
# présomption d'appartenance à un lobby.
#
# Aucun identifiant Steam (SteamID64, lobby id) ne fuit hors de cette classe :
# le reste du jeu ne voit que l'interface NetTransport.
# Tous les appels au singleton Steam sont dynamiques (voir SteamService).

const LOBBY_GAME_KEY := "game"
const LOBBY_GAME_VALUE := "wyrdane"
const LOBBY_OWNER_KEY := "owner_id"
const VIRTUAL_PORT := 0  # une seule connexion P2P possible par pair : 1v1

# Comment ce transport apprend l'identité du pair (voir l'en-tête).
enum Rendezvous { DIRECT, LOBBY }

# Constantes Steamworks recopiées (le singleton n'existe pas à la compilation).
const LOBBY_TYPE_PUBLIC := 2

# EChatRoomEnterResponse (steam_api.h) — réponse de joinLobby.
const LOBBY_OK := 1                    # Success
const LOBBY_DOESNT_EXIST := 2          # « n'existe pas (probablement fermé) »
const LOBBY_FULL := 4                  # taille maximale atteinte
const LOBBY_RATE_LIMITED := 15         # trop de tentatives en peu de temps
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
var _mode: Rendezvous = Rendezvous.DIRECT
var _lobby_id: int = 0
var _remote_id: int = 0        # SteamID64 du pair distant
# Mode direct, hôte : seule identité autorisée à se connecter (donnée par le
# backend). Toute connexion entrante d'un autre SteamID est refermée.
var _expected_peer_id: int = 0
var _listen_socket: int = 0    # hôte seulement : socket d'écoute P2P
var _connection_handle: int = 0
var _is_host := false
# Vrai dès qu'une connexion P2P a abouti au moins une fois. Sert à distinguer
# « la connexion initiale n'est pas encore passée » (on réessaie en silence, le
# pair n'a peut-être pas encore ouvert son socket d'écoute) de « la connexion
# établie est tombée » (coupure réelle, à signaler).
var _ever_connected := false

# ── Relances de la connexion P2P sortante (mode direct, invité) ──────────────
# Les deux clients n'apprennent pas l'appariement au même instant : chacun le
# découvre à son propre poll de file (2 s de cadence), donc l'invité peut très
# bien appeler connectP2P AVANT que l'hôte n'ait ouvert son socket d'écoute.
# Steam refuse alors la connexion, ce qui est normal et attendu : on réessaie
# tranquillement jusqu'à ce que l'hôte soit prêt. Fenêtre volontairement plus
# courte que celle que l'hôte accorde de son côté
# (MatchmakingOverlay.HOST_PEER_WAIT_TIMEOUT), pour que l'invité renonce le
# premier et rende l'appariement au backend plutôt que les deux en même temps.
const DIRECT_CONNECT_RETRY_DELAY := 2.0
const DIRECT_CONNECT_MAX_ATTEMPTS := 12  # ≈ 24 s
var _connect_attempt := 0
var _connect_clock := 0.0

# ── Relance d'un joinLobby refusé en code 2 (mode lobby / invitation) ────────
# Un « code 2 » juste après la création du lobby peut venir d'une course de
# propagation côté Steam : une relance 2 s plus tard suffit alors. Si toutes
# échouent, le lobby est réellement mort (l'hôte l'a quitté) et il faut
# redemander une invitation. Cadence volontairement peu agressive :
# EChatRoomEnterResponse a une valeur dédiée aux abus (15, RatelimitExceeded),
# insister vite ferait empirer la situation au lieu de l'améliorer.
const JOIN_MAX_ATTEMPTS := 4
const JOIN_RETRY_DELAY := 2.0
var _join_target: int = 0
var _join_attempt := 0
var _lobby_since_ms := 0  # instant d'entrée/création du lobby courant (log de close)

# Héberge une session.
#   {"expected_peer_id": "<SteamID64>"} → mode DIRECT : aucun lobby, on ouvre
#     seulement un socket d'écoute et on n'accepte QUE ce SteamID.
#   {} (aucun paramètre)                → mode LOBBY : crée un lobby public
#     joignable par un ami (invitation), voir l'en-tête du fichier.
func host(params: Dictionary) -> int:
	if not _init_steam():
		return ERR_UNAVAILABLE
	_is_host = true
	_listen_socket = _steam.createListenSocketP2P(VIRTUAL_PORT, {})
	if _listen_socket == 0:
		push_error("SteamTransport.host : createListenSocketP2P a échoué")
		return ERR_CANT_CREATE
	_expected_peer_id = _parse_steam_id(params.get("expected_peer_id", ""))
	if _expected_peer_id != 0:
		_mode = Rendezvous.DIRECT
		# L'identité du pair est connue AVANT toute connexion (elle vient du
		# backend) : on peut donc déjà afficher son pseudo Steam, sans attendre
		# le P2P — voir NetTransport.peer_identified.
		_remote_id = _expected_peer_id
		peer_identified.emit()
		print("[SteamDiag %s] hôte direct : écoute P2P sur le port %d, pair attendu %d (%s)" % [
			SteamService.ts(), VIRTUAL_PORT, _expected_peer_id, SteamService.state_summary()])
		status.emit("Steam : en attente de la connexion de l'adversaire…")
		# Rien à publier ni à attendre côté Steam : la session est immédiatement
		# prête. session_ready reste émis pour les appelants qui veulent le
		# savoir, avec 0 (aucun identifiant de session à transmettre à un tiers).
		session_ready.emit(0)
		return OK
	_mode = Rendezvous.LOBBY
	print("[SteamDiag %s] createLobby demandé (%s, listen_socket=%d)" % [
		SteamService.ts(), SteamService.state_summary(), _listen_socket])
	_steam.createLobby(LOBBY_TYPE_PUBLIC, 2)  # 2 membres : c'est du 1v1
	status.emit("Steam : création du lobby demandée…")
	return OK

# Rejoint une session.
#   {"peer_id": "<SteamID64>"}  → mode DIRECT : connexion P2P immédiate vers ce
#     SteamID (identité fournie par la file backend), relancée jusqu'à ce que
#     l'hôte écoute (voir DIRECT_CONNECT_MAX_ATTEMPTS).
#   {"lobby_id": int}           → mode LOBBY : entre dans ce lobby précis puis
#     ouvre la connexion P2P vers son propriétaire (invitation d'ami).
#
# Il n'existe pas de variante « cherche un lobby ouvert » : elle a été retirée
# le 2026-09-25 (la liste de lobbies Steam est éventuellement cohérente et
# renvoyait des lobbies déjà fermés, et les deux clients se détruisaient
# mutuellement leur lobby sans jamais tomber en phase).
func join(params: Dictionary) -> int:
	if not _init_steam():
		return ERR_UNAVAILABLE
	_is_host = false
	var peer_id := _parse_steam_id(params.get("peer_id", ""))
	if peer_id != 0:
		_mode = Rendezvous.DIRECT
		if peer_id == _steam.getSteamID():
			# Deux instances sur le même compte Steam : la connexion P2P
			# bouclerait sur soi-même. Même refus explicite que côté lobby.
			disconnected.emit("steam_same_account")
			return OK
		_remote_id = peer_id
		peer_identified.emit()
		_start_direct_connect()
		return OK
	var lobby_id: int = int(params.get("lobby_id", 0))
	if lobby_id == 0:
		push_error("SteamTransport.join : ni peer_id (file backend) ni lobby_id (invitation) — un pair ne se cherche pas, il est fourni")
		return ERR_INVALID_PARAMETER
	_mode = Rendezvous.LOBBY
	_join_target = lobby_id
	_join_attempt = 1
	print("[SteamDiag %s] joinLobby %d, tentative 1/%d (%s)" % [
		SteamService.ts(), lobby_id, JOIN_MAX_ATTEMPTS, SteamService.state_summary()])
	_steam.joinLobby(lobby_id)
	status.emit("Steam : rejoint le lobby %d…" % lobby_id)
	return OK

# Reconnexion au pair déjà connu après une coupure P2P transitoire — appelée
# uniquement côté rejoignant (l'hôte reste passif, son socket d'écoute accepte
# déjà une connexion entrante sans action de sa part).
#
# En mode direct, le SteamID du pair suffit : aucun lobby à re-rejoindre, donc
# la reconnexion est toujours possible tant qu'on connaît le pair. En mode
# lobby, on retente d'abord le P2P direct si le contexte est intact, sinon on
# re-rejoint le lobby quand l'appelant sait lequel viser.
func try_reconnect(params: Dictionary) -> int:
	if _steam == null:
		return ERR_UNAVAILABLE
	if _remote_id != 0:
		status.emit("Steam : nouvelle tentative de connexion P2P…")
		_start_direct_connect()
		return OK
	if int(params.get("lobby_id", 0)) != 0 or str(params.get("peer_id", "")) != "":
		return join(params)
	return ERR_UNAVAILABLE

func send(bytes: PackedByteArray, reliable: bool = true) -> void:
	if _steam == null or _connection_handle == 0:
		return
	_steam.sendMessageToConnection(_connection_handle, bytes,
			SEND_RELIABLE if reliable else SEND_UNRELIABLE)

func poll() -> void:
	if _steam == null:
		return
	SteamService.run_callbacks()
	_tick_direct_connect(get_process_delta_time())
	if _connection_handle == 0:
		return
	var messages: Array = _steam.receiveMessagesOnConnection(_connection_handle, 32)
	for message in messages:
		var bytes: PackedByteArray = message.get("payload", message.get("data", PackedByteArray()))
		if not bytes.is_empty():
			packet_received.emit(bytes)

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
	_mode = Rendezvous.DIRECT
	_lobby_id = 0
	_remote_id = 0
	_expected_peer_id = 0
	_listen_socket = 0
	_connection_handle = 0
	_ever_connected = false
	_connect_attempt = 0
	_connect_clock = 0.0
	_join_target = 0
	_join_attempt = 0
	_lobby_since_ms = 0

# ─── Interne ──────────────────────────────────────────────────────────────────

# Un SteamID64 arrive toujours en CHAÎNE de chiffres (jamais en nombre) : il
# occupe 57 bits significatifs, or un float n'en garde que 53 — un id lu comme
# nombre quelque part sur le chemin est arrondi, silencieusement, et désigne
# alors quelqu'un d'autre. Même règle que pour les ids de lobby (voir
# BackendClient.parse_lobby_id et helper/steamLobbyId.ts côté backend).
# Retourne 0 si la valeur est absente ou n'est pas une chaîne de chiffres.
static func _parse_steam_id(raw: Variant) -> int:
	if raw is String:
		var text: String = raw
		return int(text) if text.is_valid_int() else 0
	if raw is int:
		# Toléré pour un appelant interne (test, reconnexion) mais jamais pour
		# une valeur venue du réseau : un entier Godot est bien 64 bits, le
		# risque n'existe que côté JSON.
		return raw
	return 0

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
	_steam.connect("lobby_chat_update", _on_lobby_chat_update)
	_steam.connect("network_connection_status_changed", _on_network_connection_status_changed)

func _disconnect_steam_signals() -> void:
	if _steam == null:
		return
	if _steam.is_connected("lobby_created", _on_lobby_created):
		_steam.disconnect("lobby_created", _on_lobby_created)
		_steam.disconnect("lobby_joined", _on_lobby_joined)
		_steam.disconnect("lobby_chat_update", _on_lobby_chat_update)
		_steam.disconnect("network_connection_status_changed", _on_network_connection_status_changed)

# ── Mode direct : connexion sortante vers le SteamID donné par le backend ──

func _start_direct_connect() -> void:
	_connect_attempt = 1
	_connect_clock = 0.0
	_open_direct_connection()

func _open_direct_connection() -> void:
	if _connection_handle != 0:
		# Une tentative précédente n'a pas encore été refermée par Steam : on la
		# ferme nous-mêmes, sinon deux connexions concurrentes vers le même pair
		# peuvent aboutir et seule l'une des deux serait lue.
		_steam.closeConnection(_connection_handle, 0, "retry", false)
		_connection_handle = 0
	print("[SteamDiag %s] connectP2P vers %d, tentative %d/%d (%s)" % [
		SteamService.ts(), _remote_id, _connect_attempt, DIRECT_CONNECT_MAX_ATTEMPTS,
		SteamService.state_summary()])
	_connection_handle = _steam.connectP2P(_remote_id, VIRTUAL_PORT, {})
	status.emit("Steam : connexion à l'adversaire (essai %d/%d)…" % [
		_connect_attempt, DIRECT_CONNECT_MAX_ATTEMPTS])

# Relance périodique tant que la connexion initiale n'a pas abouti (voir
# DIRECT_CONNECT_RETRY_DELAY). Volontairement piloté depuis poll() plutôt que
# par un Timer : poll() est déjà appelé chaque frame par NetworkManager, et un
# Timer de plus serait un état supplémentaire à démonter dans close().
func _tick_direct_connect(delta: float) -> void:
	# Vaut pour les DEUX modes : côté invité, la connexion sortante est la même
	# opération, qu'on ait appris l'identité de l'hôte par la file backend ou en
	# entrant dans son lobby.
	if _is_host or _ever_connected or _connect_attempt == 0:
		return
	_connect_clock += delta
	if _connect_clock < DIRECT_CONNECT_RETRY_DELAY:
		return
	_connect_clock = 0.0
	if _connect_attempt >= DIRECT_CONNECT_MAX_ATTEMPTS:
		_connect_attempt = 0
		status.emit("Steam : l'adversaire n'a pas répondu à la connexion P2P")
		print("[SteamDiag %s] abandon : %d tentatives de connectP2P vers %d sans réponse" % [
			SteamService.ts(), DIRECT_CONNECT_MAX_ATTEMPTS, _remote_id])
		disconnected.emit("steam_peer_unreachable")
		return
	_connect_attempt += 1
	_open_direct_connection()

# ── Côté hôte (mode lobby) ──

func _on_lobby_created(result: int, lobby_id: int) -> void:
	if not _is_host or _mode != Rendezvous.LOBBY:
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

# ── Côté client (mode lobby) ──

func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if _is_host or _mode != Rendezvous.LOBBY:
		return
	print("[SteamDiag %s] lobby_joined lobby=%d response=%d tentative=%d/%d (%s)" % [
		SteamService.ts(), lobby_id, response, _join_attempt, JOIN_MAX_ATTEMPTS,
		SteamService.state_summary()])
	if response != LOBBY_OK:
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
		# Chaque refus mène à un message différent côté joueur : un lobby plein
		# (un tiers est passé devant, ou le lobby appartient à un match déjà
		# commencé) n'a pas la même réponse qu'une limitation de débit Steam,
		# qu'insister ne ferait qu'aggraver (EChatRoomEnterResponse 15).
		match response:
			LOBBY_FULL:
				disconnected.emit("steam_lobby_full")
			LOBBY_RATE_LIMITED:
				disconnected.emit("steam_lobby_rate_limited")
			_:
				disconnected.emit("steam_lobby_join_failed")
		return
	_join_target = 0
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
	# Mêmes relances qu'en mode direct : l'hôte d'une invitation a créé son
	# socket d'écoute avant le lobby, mais une première tentative peut tout de
	# même échouer sur un réseau lent à établir le relais Steam.
	_start_direct_connect()

# ── Commun : suivi de la connexion P2P réelle ──

func _on_network_connection_status_changed(connect_handle: int, connection: Dictionary, _old_state: int) -> void:
	var state: int = connection.get("connection_state", 0)
	var remote_id := SteamP2PGuard.extract_remote_id(connection)
	match state:
		CONN_STATE_CONNECTING:
			# Connexion entrante sur notre socket d'écoute : uniquement pertinent
			# côté hôte.
			if not _is_host or connection.get("listen_socket", 0) != _listen_socket:
				return
			if remote_id == 0 or not _is_peer_authorized(remote_id):
				status.emit("Steam : connexion P2P refusée (pair non autorisé)")
				print("[SteamDiag %s] connexion entrante refusée : %d n'est pas le pair attendu" % [
					SteamService.ts(), remote_id])
				_steam.closeConnection(connect_handle, 0, "unexpected peer", false)
				return
			_remote_id = remote_id
			_steam.acceptConnection(connect_handle)
			status.emit("Steam : connexion P2P entrante acceptée, en attente de confirmation…")
		CONN_STATE_CONNECTED:
			_connection_handle = connect_handle
			_ever_connected = true
			_connect_attempt = 0
			if remote_id != 0:
				_remote_id = remote_id
			status.emit("Steam : connexion P2P établie avec « %s » ✓" % _persona(_remote_id))
			connected.emit()
		CONN_STATE_CLOSED_BY_PEER, CONN_STATE_PROBLEM_DETECTED_LOCALLY:
			if connect_handle != _connection_handle and _connection_handle != 0:
				return
			var end_reason: int = connection.get("end_reason", 0)
			var end_debug: String = connection.get("end_debug", "")
			print("[SteamDiag %s] connexion P2P fermée (état=%d code=%d — %s)" % [
				SteamService.ts(), state, end_reason, end_debug])
			_steam.closeConnection(connect_handle, 0, "", false)
			_connection_handle = 0
			# Échec AVANT toute connexion réussie : ce n'est pas une coupure, c'est
			# une tentative d'établissement qui n'a pas abouti — le plus souvent
			# parce que le pair n'a pas encore ouvert son socket d'écoute (il n'a
			# pas encore vu l'appariement de son côté, chacun le découvrant à son
			# propre poll de file). Cette phase appartient entièrement à la boucle
			# de relances : côté invité c'est _tick_direct_connect qui tranchera
			# (steam_peer_unreachable une fois les essais épuisés), côté hôte il
			# n'y a rien à faire sinon laisser l'invité réessayer. Émettre une
			# déconnexion ici ferait renoncer l'hôte au PREMIER essai manqué de
			# l'invité, alors que le suivant est à deux secondes.
			if not _ever_connected:
				status.emit("Steam : connexion P2P pas encore établie (code %d), nouvelle tentative…" % end_reason)
				return
			status.emit("Steam : connexion P2P perdue (code %d — %s)" % [end_reason, end_debug])
			disconnected.emit("steam_p2p_failed")

# Le pair a-t-il le droit de se connecter à notre socket d'écoute ?
#   - mode direct : une seule identité est acceptable, celle que le backend a
#     annoncée à l'appariement. C'est plus strict qu'un lobby (que n'importe qui
#     pouvait lister pour y lire notre SteamID).
#   - mode lobby : appartenance RÉELLE au lobby au moment de la connexion,
#     jamais seulement `_remote_id` — celui-ci n'est peuplé que par
#     _on_lobby_chat_update, un flux Steam indépendant sans garantie d'ordre
#     avec cet évènement P2P (tant qu'il vaut 0, une garde qui s'y fierait
#     laisserait passer n'importe qui).
func _is_peer_authorized(remote_id: int) -> bool:
	if _mode == Rendezvous.DIRECT:
		return remote_id == _expected_peer_id
	if not SteamP2PGuard.is_lobby_member(_steam, _lobby_id, remote_id):
		return false
	return _remote_id == 0 or remote_id == _remote_id

# (Vérification d'appartenance au lobby et extraction d'identité : voir
# SteamP2PGuard, partagé avec ArenaSteamTransport.)

# Pseudo Steam d'un joueur (pour le journal de diagnostic).
func _persona(steam_id: int) -> String:
	var persona_name: String = _steam.getFriendPersonaName(steam_id)
	return persona_name if persona_name != "" else str(steam_id)
