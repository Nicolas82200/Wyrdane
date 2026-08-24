extends Control

# Point d'entrée du multijoueur, entièrement backend Steam (lobby + P2P
# Steamworks — voir SteamTransport/SteamService). Sans l'extension GodotSteam
# installée ou sans client Steam lancé, les boutons restent affichés mais
# échouent proprement avec un message (voir NET_STEAM_UNAVAILABLE) plutôt que
# de disparaître : mieux vaut un échec explicite qu'un écran vide.
#
# « Héberger » crée un lobby public tagué Wyrdane et attend un adversaire.
# « Partie rapide » est un vrai matchmaking : elle cherche un lobby existant
# et, si aucun n'est trouvé, héberge automatiquement à la place (le joueur n'a
# qu'un bouton à presser, pas besoin de coordonner qui héberge).
# « Inviter un ami » ouvre l'overlay Steam pour le lobby en cours (hôte
# uniquement). Dès l'arrivée sur cet écran, on écoute aussi les demandes de
# rejoindre reçues via une invitation Steam acceptée (overlay ami, lien
# « Rejoindre la partie ») : le jeu doit déjà tourner et être sur cet écran —
# le cas « jeu pas encore lancé » (+connect_lobby en ligne de commande) n'est
# pas géré ici.
#
# UI reprise du même habillage que MainMenu (fond vidéo, vignette, panneau
# doré) : voir scenes/net/NetLobby.tscn.

const BATTLE_SCENE := "res://scenes/battle/Battle.tscn"
const MAIN_MENU_SCENE := "res://scenes/mainMenu/MainMenu.tscn"

@onready var host_button:        Button = $NavPanel/NavMargin/VBoxContainer/HostButton
@onready var quick_match_button: Button = $NavPanel/NavMargin/VBoxContainer/QuickMatchButton
@onready var ranked_button:      Button = $NavPanel/NavMargin/VBoxContainer/RankedButton
@onready var cancel_ranked_button: Button = $NavPanel/NavMargin/VBoxContainer/CancelRankedButton
@onready var invite_button:      Button = $NavPanel/NavMargin/VBoxContainer/InviteButton
@onready var back_button:        Button = $NavPanel/NavMargin/VBoxContainer/BackButton
@onready var title_label:        Label  = $TitleLabel
@onready var subtitle_label:     Label  = $SubtitleLabel
@onready var status_title_label: Label  = $StatusPanel/StatusMargin/StatusVBox/StatusTitleLabel
@onready var spinner_icon:       TextureRect = $StatusPanel/StatusMargin/StatusVBox/LoadingCenter/LoadingVBox/SpinnerIcon
@onready var phase_label:        Label  = $StatusPanel/StatusMargin/StatusVBox/LoadingCenter/LoadingVBox/PhaseLabel

const SPINNER_TURNS_PER_SECOND := 0.5

var _net: NetworkManager
var _handshake: NetHandshake
var _battle_sync: NetBattleSync
var _quick_matching := false  # bascule join→host en cours ; voir _on_peer_disconnected
var _lobby_hosted := false  # lobby Steam actif côté hôte ; condition réelle d'invite_friends()
var _status_key := "NET_LOADING_IDLE"  # clé de traduction affichée par phase_label
var _loading := false  # affiche le spinner tant qu'une connexion est en cours

# ─── Matchmaking classé ───────────────────────────────────────────────────────
# Contrat backend : docs/backend-contracts/ranked-matchmaking-and-retention.md
const RANKED_POLL_INTERVAL := 2.0
const RANKED_QUEUE_TIMEOUT := 180.0  # abandon après 3 min sans adversaire

var _ranked_ticket_id: String = ""
var _ranked_role: String = ""  # "host" | "guest", connu une fois apparié
var _ranked_elapsed := 0.0
var _ranked_poll_timer: Timer

func _ready() -> void:
	_net = NetworkManager.new()
	add_child(_net)
	_net.peer_connected.connect(_on_peer_connected)
	_net.peer_disconnected.connect(_on_peer_disconnected)
	# Détail technique (ids de lobby, codes de connexion P2P...) utile en debug
	# mais pas au joueur : direction console uniquement, jamais l'écran (voir
	# _set_status pour le texte réellement affiché, une phase à la fois).
	_net.status.connect(func(text: String) -> void: print("[NetLobby] " + text))
	host_button.pressed.connect(_on_steam_host_pressed)
	quick_match_button.pressed.connect(_on_steam_quick_pressed)
	ranked_button.pressed.connect(_on_ranked_pressed)
	cancel_ranked_button.pressed.connect(_on_cancel_ranked_pressed)
	invite_button.pressed.connect(_on_steam_invite_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_net.session_ready.connect(_on_session_ready)
	SettingsManager.language_changed.connect(func(_l): _retranslate())
	_retranslate()
	if SteamService.is_available():
		SteamService.watch_join_requests(_on_steam_join_requested)

func _process(delta: float) -> void:
	# Pompe les callbacks Steam même hors session active, pour capter une
	# invitation reçue pendant qu'on est simplement sur cet écran (voir
	# SteamService.watch_join_requests). Sans effet si Steam pas initialisé.
	if SteamService.is_available():
		SteamService.run_callbacks()
	if _loading:
		spinner_icon.rotation += delta * TAU * SPINNER_TURNS_PER_SECOND

# Remplace le texte de statut affiché (une seule phase à la fois, jamais un
# journal qui s'accumule — voir _net.status en debug console pour le détail).
func _set_status(key: String) -> void:
	_status_key = key
	phase_label.text = SettingsManager.t(key)

func _set_loading(active: bool) -> void:
	_loading = active
	spinner_icon.visible = active
	if not active:
		spinner_icon.rotation = 0.0

func _retranslate() -> void:
	title_label.text        = SettingsManager.t("MENU_MULTIPLAYER")
	subtitle_label.text     = SettingsManager.t("NET_LOBBY_SUBTITLE")
	status_title_label.text = SettingsManager.t("NET_STATUS_TITLE")
	phase_label.text        = SettingsManager.t(_status_key)
	host_button.text        = SettingsManager.t("NET_STEAM_HOST")
	quick_match_button.text = SettingsManager.t("NET_STEAM_QUICK")
	ranked_button.text      = SettingsManager.t("NET_STEAM_RANKED")
	cancel_ranked_button.text = SettingsManager.t("NET_RANKED_CANCEL")
	invite_button.text      = SettingsManager.t("NET_STEAM_INVITE")
	back_button.text        = SettingsManager.t("NET_BACK")

# ─── Actions UI ───────────────────────────────────────────────────────────────

func _on_steam_host_pressed() -> void:
	_quick_matching = false
	var err := _net.host_game_with(TransportFactory.Backend.STEAM)
	if err == OK:
		_set_loading(true)
		_set_status("NET_STEAM_HOSTING")
	else:
		_set_status("NET_STEAM_UNAVAILABLE")

func _on_steam_quick_pressed() -> void:
	_quick_matching = true
	var err := _net.join_game_with(TransportFactory.Backend.STEAM)
	if err == OK:
		_set_loading(true)
		_set_status("NET_STEAM_SEARCHING")
	else:
		_quick_matching = false
		_set_status("NET_STEAM_UNAVAILABLE")

# L'overlay Steam d'invitation exige un lobby déjà créé (voir
# SteamTransport.invite_friends) : si aucun n'est en cours, on héberge d'abord
# et on ouvre l'overlay dès que le lobby est prêt, plutôt que de laisser le
# joueur presser « Héberger » lui-même avant de pouvoir inviter.
func _on_steam_invite_pressed() -> void:
	if _lobby_hosted:
		_net.invite_friends()
		return
	_quick_matching = false
	_net.session_ready.connect(_on_invite_lobby_ready, CONNECT_ONE_SHOT)
	var err := _net.host_game_with(TransportFactory.Backend.STEAM)
	if err == OK:
		_set_loading(true)
		_set_status("NET_STEAM_HOSTING")
	else:
		if _net.session_ready.is_connected(_on_invite_lobby_ready):
			_net.session_ready.disconnect(_on_invite_lobby_ready)
		_set_status("NET_STEAM_UNAVAILABLE")

func _on_invite_lobby_ready(_session_id: int) -> void:
	_net.invite_friends()

func _on_session_ready(_session_id: int) -> void:
	_lobby_hosted = _net.is_host

func _on_back_pressed() -> void:
	# Coupe une éventuelle connexion en cours avant de revenir au menu.
	_cancel_ranked_search(false)
	_lobby_hosted = false
	_set_loading(false)
	_net.close()
	AudioManager.play(AudioManager.CLOSE_MENU)
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

# ─── Matchmaking classé ───────────────────────────────────────────────────────

func _on_ranked_pressed() -> void:
	if not BackendClient.is_authenticated():
		_set_status("NET_RANKED_UNAVAILABLE")
		return
	_set_actions_enabled(false)
	cancel_ranked_button.visible = true
	_set_loading(true)
	_set_status("NET_RANKED_QUEUEING")
	BackendClient.queue_join(func(success: bool, data: Dictionary) -> void:
		if not success or str(data.get("ticket_id", "")) == "":
			_set_status("NET_RANKED_UNAVAILABLE")
			_reset_ranked_ui()
			return
		_ranked_ticket_id = str(data.get("ticket_id", ""))
		_ranked_elapsed = 0.0
		_ranked_poll_timer = Timer.new()
		_ranked_poll_timer.wait_time = RANKED_POLL_INTERVAL
		_ranked_poll_timer.timeout.connect(_poll_ranked_queue)
		add_child(_ranked_poll_timer)
		_ranked_poll_timer.start()
	)

func _on_cancel_ranked_pressed() -> void:
	_cancel_ranked_search(true)

# manual : true si annulé par le joueur (statut dédié), false si on quitte
# l'écran (aucun message utile, on part de toute façon).
func _cancel_ranked_search(manual: bool) -> void:
	if _ranked_ticket_id == "":
		return
	BackendClient.queue_cancel(_ranked_ticket_id)
	if manual:
		_set_status("NET_RANKED_CANCELLED")
	_reset_ranked_ui()

func _reset_ranked_ui() -> void:
	if _ranked_poll_timer != null:
		_ranked_poll_timer.stop()
		_ranked_poll_timer.queue_free()
		_ranked_poll_timer = null
	_ranked_ticket_id = ""
	_ranked_role = ""
	cancel_ranked_button.visible = false
	_set_actions_enabled(true)
	_set_loading(false)

func _poll_ranked_queue() -> void:
	_ranked_elapsed += RANKED_POLL_INTERVAL
	if _ranked_elapsed >= RANKED_QUEUE_TIMEOUT:
		_set_status("NET_RANKED_TIMEOUT")
		_cancel_ranked_search(false)
		return
	var ticket_id := _ranked_ticket_id
	BackendClient.queue_status(ticket_id, func(success: bool, data: Dictionary) -> void:
		# La recherche a pu être annulée pendant l'aller-retour réseau.
		if ticket_id != _ranked_ticket_id or not success:
			return
		match str(data.get("status", "waiting")):
			"matched":
				_on_ranked_matched(data)
			"cancelled", "expired":
				_set_status("NET_RANKED_TIMEOUT")
				_reset_ranked_ui()
			_:
				pass  # "waiting" : rien à faire, on repollera au prochain tick
	)

func _on_ranked_matched(data: Dictionary) -> void:
	_ranked_role = str(data.get("role", ""))
	if _ranked_role == "host":
		if _ranked_poll_timer != null:
			_ranked_poll_timer.stop()
		_quick_matching = false
		_net.session_ready.connect(_on_ranked_lobby_ready, CONNECT_ONE_SHOT)
		var err := _net.host_game_with(TransportFactory.Backend.STEAM)
		if err == OK:
			_set_status("NET_RANKED_MATCHED")
		else:
			if _net.session_ready.is_connected(_on_ranked_lobby_ready):
				_net.session_ready.disconnect(_on_ranked_lobby_ready)
			_set_status("NET_STEAM_UNAVAILABLE")
			_cancel_ranked_search(false)
		return
	# Invité : le lobby n'est disponible qu'une fois l'hôte l'ayant rapporté
	# (queue_report_lobby) — on continue de repoller jusqu'à ce qu'il apparaisse.
	var lobby_id := int(data.get("steam_lobby_id", 0))
	if lobby_id == 0:
		return
	if _ranked_poll_timer != null:
		_ranked_poll_timer.stop()
	_quick_matching = false
	_ranked_ticket_id = ""  # déjà apparié, plus de sens à repoller/annuler ce ticket
	_set_status("NET_RANKED_MATCHED")
	var err := _net.join_game_with(TransportFactory.Backend.STEAM, {"lobby_id": lobby_id})
	if err != OK:
		_set_status("NET_STEAM_UNAVAILABLE")
		_reset_ranked_ui()

# Hôte classé uniquement : le lobby vient d'être créé, on transmet son id au
# backend pour que l'invité puisse le rejoindre directement (voir
# _on_ranked_matched, branche invité).
func _on_ranked_lobby_ready(session_id: int) -> void:
	if _ranked_ticket_id == "":
		return
	BackendClient.queue_report_lobby(_ranked_ticket_id, session_id)
	_ranked_ticket_id = ""  # le rôle d'hôte n'a plus besoin de repoller/annuler

# ─── Connexion → handshake → bataille ─────────────────────────────────────────

func _on_peer_connected() -> void:
	_quick_matching = false
	cancel_ranked_button.visible = false
	print("[NetLobby] _on_peer_connected  self=%s  handshake_deja_present=%s" % [self, _handshake != null])
	_set_loading(true)
	_set_status("NET_LOADING_PREPARING")
	_set_actions_enabled(false)
	_handshake = NetHandshake.new(_net, _local_deck_paths(), _net.is_host)
	add_child(_handshake)
	_handshake.completed.connect(_on_handshake_ready)
	_handshake.progress.connect(func(text: String) -> void: print("[NetLobby] " + text))
	_handshake.start()

# Boutons de lancement de partie désactivés dès qu'une connexion pair-à-pair
# est en cours (handshake/synchronisation) : les relancer casserait l'état de
# _net. Le bouton Retour reste actif pour permettre d'annuler.
func _set_actions_enabled(enabled: bool) -> void:
	host_button.disabled = not enabled
	quick_match_button.disabled = not enabled
	ranked_button.disabled = not enabled
	invite_button.disabled = not enabled

func _on_peer_disconnected(reason: String) -> void:
	match reason:
		"steam_same_account":
			_quick_matching = false
			_reset_ranked_ui()
			_set_loading(false)
			_set_status("NET_STEAM_SAME_ACCOUNT")
		"steam_no_lobby_found":
			if _quick_matching:
				_set_status("NET_STEAM_NO_LOBBY_HOSTING")
				_start_quick_match_host()
			else:
				_reset_ranked_ui()
				_set_loading(false)
				_set_status("NET_STEAM_NO_LOBBY")
		_:
			_quick_matching = false
			_reset_ranked_ui()
			_set_loading(false)
			print("[NetLobby] Pair déconnecté (%s)" % [reason])
			_set_status("NET_STEAM_DISCONNECTED")

# Partie rapide sans adversaire trouvé : on héberge à la place plutôt que de
# laisser le joueur relancer manuellement (voir _on_steam_quick_pressed).
func _start_quick_match_host() -> void:
	_quick_matching = false
	var err := _net.host_game_with(TransportFactory.Backend.STEAM)
	if err == OK:
		_set_loading(true)
		_set_status("NET_STEAM_HOSTING")
	else:
		_set_loading(false)
		_set_status("NET_STEAM_UNAVAILABLE")

# Invitation Steam acceptée (overlay ami / lien « Rejoindre la partie ») alors
# que le joueur est déjà sur cet écran : on rejoint directement ce lobby.
func _on_steam_join_requested(lobby_id: int) -> void:
	_quick_matching = false
	_set_status("NET_STEAM_INVITE_RECEIVED")
	var err := _net.join_game_with(TransportFactory.Backend.STEAM, {"lobby_id": lobby_id})
	if err == OK:
		_set_loading(true)
		_set_status("NET_STEAM_SEARCHING")
	else:
		_set_loading(false)
		_set_status("NET_STEAM_UNAVAILABLE")

# Deck local mélangé, sous forme de resource_path (identifiant partagé).
func _local_deck_paths() -> Array:
	var active := DeckManager.get_active_deck()
	if active == null:
		return []
	var paths: Array = active.card_paths.duplicate()
	paths.shuffle()
	return paths

func _on_handshake_ready(setup: Dictionary) -> void:
	print("[NetLobby] _on_handshake_ready  self=%s  in_tree=%s" % [self, is_inside_tree()])
	_set_status("NET_WAITING_OPPONENT")
	NetContext.active = true
	NetContext.net = _net
	NetContext.is_host = _net.is_host
	NetContext.setup = setup
	# Sans cette étape, chaque client basculerait sur Battle.tscn dès que SON
	# handshake local est fini, indépendamment du pair — un joueur pouvait
	# démarrer son mulligan pendant que l'autre était encore au lobby. On
	# n'entre en bataille qu'une fois les deux prêts (voir NetBattleSync).
	_battle_sync = NetBattleSync.new(_net)
	add_child(_battle_sync)
	_battle_sync.completed.connect(_on_battle_sync_ready)
	_battle_sync.progress.connect(func(text: String) -> void: print("[NetLobby] " + text))
	_battle_sync.start()

func _on_battle_sync_ready() -> void:
	print("[NetLobby] Adversaire prêt — lancement de la bataille réseau…")
	# Le NetworkManager doit survivre au changement de scène : on le reparente
	# sous la racine de l'arbre avant de charger Battle.
	_net.get_parent().remove_child(_net)
	get_tree().root.add_child(_net)
	get_tree().change_scene_to_file(BATTLE_SCENE)
