extends CanvasLayer

# Autoload : orchestre tout le multijoueur (choix du mode, recherche,
# connexion, handshake) sans jamais quitter la scène courante. Remplace
# l'ancien écran plein écran NetLobby.tscn : ce CanvasLayer vit à la racine
# de l'arbre (comme tout autoload) et survit donc à n'importe quel
# `change_scene_to_file` — le joueur peut ouvrir le Deck Builder, la
# boutique, etc. pendant qu'une recherche est en cours.
#
# Entrée : MainMenu appelle open_mode_picker() une fois le deck choisi (voir
# MainMenu._on_launch_pressed). Le popup affiche Normal/Classé/Contre un ami ;
# dès qu'un mode est choisi, le popup se ferme et le bandeau de recherche
# (haut-droite, ancré à cet autoload donc visible partout) prend le relais.
# Le bandeau sert aussi de zone de statut/erreur (voir _flash_banner) tant
# qu'il n'y a plus de StatusPanel toujours visible comme sur l'ancien écran.
#
# Une fois l'adversaire trouvé : écran de chargement plein écran, puis
# présentation face-à-face, puis bascule sur Battle.tscn — identique à
# l'ancien NetLobby, logique inchangée.

const BATTLE_SCENE := "res://scenes/battle/Battle.tscn"

@onready var mode_picker:        Control = $ModePickerLayer
@onready var normal_button:      Button  = $ModePickerLayer/PickerCenter/PickerPanel/PickerMargin/PickerVBox/NormalButton
@onready var ranked_button:      Button  = $ModePickerLayer/PickerCenter/PickerPanel/PickerMargin/PickerVBox/RankedButton
@onready var invite_button:      Button  = $ModePickerLayer/PickerCenter/PickerPanel/PickerMargin/PickerVBox/InviteButton
@onready var picker_close_button: Button = $ModePickerLayer/PickerCenter/PickerPanel/PickerMargin/PickerVBox/PickerCloseButton
@onready var picker_title_label: Label   = $ModePickerLayer/PickerCenter/PickerPanel/PickerMargin/PickerVBox/PickerTitleLabel

@onready var search_banner:         Control     = $SearchBanner
@onready var search_banner_spinner: TextureRect = $SearchBanner/SearchBannerMargin/SearchBannerSpinner
@onready var search_banner_label:   Label       = $SearchBanner/SearchBannerMargin/SearchBannerLabel
@onready var search_banner_cancel:  Button      = $SearchBanner/SearchBannerMargin/SearchBannerCancel

@onready var match_found_overlay: Control     = $MatchFoundOverlay
@onready var overlay_spinner:     TextureRect = $MatchFoundOverlay/OverlayCenter/OverlayVBox/OverlaySpinner
@onready var overlay_phase_label: Label       = $MatchFoundOverlay/OverlayCenter/OverlayVBox/OverlayPhaseLabel
@onready var overlay_tip_label:   Label       = $MatchFoundOverlay/OverlayCenter/OverlayVBox/OverlayTipLabel

# Présentation face-à-face affichée juste avant le lancement de Battle.tscn
# (voir _on_battle_sync_ready/_show_vs_screen) : nom + race(s) de chaque camp.
@onready var vs_overlay:            Control = $VsOverlay
@onready var vs_local_name_label:   Label   = %LocalNameLabel
@onready var vs_local_race_label:   Label   = %LocalRaceLabel
@onready var vs_remote_name_label:  Label   = %RemoteNameLabel
@onready var vs_remote_race_label:  Label   = %RemoteRaceLabel
const VS_SCREEN_DURATION := 2.2

const SPINNER_TURNS_PER_SECOND := 0.5
# Durée d'affichage d'un message de fin de recherche (erreur/annulation) dans
# le bandeau avant qu'il ne se referme tout seul (voir _flash_banner).
const BANNER_MESSAGE_DURATION := 4.0

# Astuces affichées en boucle sur l'écran de chargement une fois l'adversaire
# trouvé (voir _start_tip_cycle) — clés dans translations/game.csv.
const TIP_KEYS := [
	"NET_TIP_1", "NET_TIP_2", "NET_TIP_3", "NET_TIP_4", "NET_TIP_5", "NET_TIP_6",
]
const TIP_INTERVAL := 6.0

var _net: NetworkManager
var _handshake: NetHandshake
var _battle_sync: NetBattleSync
var _quick_matching := false  # bascule join→host en cours ; voir _on_peer_disconnected
var _lobby_hosted := false  # lobby Steam actif côté hôte ; condition réelle d'invite_friends()
var _status_key := ""  # clé de traduction affichée par le bandeau
var _loading := false  # affiche le spinner tant qu'une connexion est en cours
var _search_mode := ""  # "" | "normal" | "ranked" | "invite" — pilote le bouton Annuler
var _tip_timer: Timer
var _tip_index := 0
var _banner_hide_timer: Timer

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
	# mais pas au joueur : direction console uniquement (voir _flash_banner/
	# _set_status pour le texte réellement affiché, un message à la fois).
	_net.status.connect(func(text: String) -> void: print("[MatchmakingOverlay] " + text))
	normal_button.pressed.connect(_on_normal_pressed)
	ranked_button.pressed.connect(_on_ranked_pressed)
	invite_button.pressed.connect(_on_steam_invite_pressed)
	picker_close_button.pressed.connect(_on_picker_close_pressed)
	search_banner_cancel.pressed.connect(_on_banner_cancel_pressed)
	_net.session_ready.connect(_on_session_ready)
	SettingsManager.language_changed.connect(func(_l): _retranslate())
	_retranslate()
	if SteamService.is_available():
		SteamService.watch_join_requests(_on_steam_join_requested)

func _process(delta: float) -> void:
	# Pompe les callbacks Steam en continu (même hors recherche active), pour
	# capter une invitation reçue à tout moment (voir SteamService.
	# watch_join_requests). Sans effet si Steam pas initialisé.
	if SteamService.is_available():
		SteamService.run_callbacks()
	if _loading:
		var spin := delta * TAU * SPINNER_TURNS_PER_SECOND
		search_banner_spinner.rotation += spin
		overlay_spinner.rotation += spin

# ─── Panneau de choix du mode ──────────────────────────────────────────────────

# Appelé par MainMenu une fois le deck choisi (voir MainMenu._on_launch_pressed).
# Ignoré si une recherche/connexion est déjà en cours : le bandeau + son bouton
# Annuler donnent déjà tout le contrôle nécessaire, pas besoin de rouvrir le
# choix de mode par-dessus une recherche en cours.
func open_mode_picker() -> void:
	if _search_mode != "" or _loading:
		return
	mode_picker.visible = true

func _on_picker_close_pressed() -> void:
	mode_picker.visible = false

# ─── Statut / bandeau ──────────────────────────────────────────────────────────

func _set_status(key: String) -> void:
	_status_key = key
	search_banner_label.text = SettingsManager.t(key)
	if match_found_overlay.visible:
		overlay_phase_label.text = SettingsManager.t(key)

func _set_loading(active: bool) -> void:
	_loading = active
	search_banner_spinner.visible = active
	if not active:
		search_banner_spinner.rotation = 0.0

# Bandeau haut-droite affiché tant qu'on cherche un adversaire.
func _show_search_banner(active: bool) -> void:
	if _banner_hide_timer != null:
		_banner_hide_timer.stop()
	search_banner.visible = active
	if active:
		search_banner_spinner.rotation = 0.0

# Affiche un message de fin de recherche (erreur, annulation, timeout...) dans
# le bandeau puis le referme tout seul après BANNER_MESSAGE_DURATION — sans
# StatusPanel toujours visible comme sur l'ancien écran, une erreur silencieuse
# passerait sinon inaperçue pendant que le joueur navigue ailleurs.
func _flash_banner(key: String) -> void:
	_set_loading(false)
	_set_status(key)
	search_banner.visible = true
	if _banner_hide_timer == null:
		_banner_hide_timer = Timer.new()
		_banner_hide_timer.one_shot = true
		_banner_hide_timer.timeout.connect(func(): search_banner.visible = false)
		add_child(_banner_hide_timer)
	_banner_hide_timer.start(BANNER_MESSAGE_DURATION)

# Écran de chargement plein écran affiché une fois l'adversaire trouvé, le
# temps du handshake/synchronisation (voir _on_peer_connected/_on_handshake_ready).
func _show_match_found_overlay(active: bool) -> void:
	match_found_overlay.visible = active
	if active:
		overlay_spinner.rotation = 0.0
		overlay_phase_label.text = SettingsManager.t("NET_MATCH_FOUND_TITLE")
		_start_tip_cycle()
	else:
		_stop_tip_cycle()

func _start_tip_cycle() -> void:
	_tip_index = randi() % TIP_KEYS.size()
	_apply_tip()
	if _tip_timer == null:
		_tip_timer = Timer.new()
		_tip_timer.wait_time = TIP_INTERVAL
		_tip_timer.timeout.connect(_on_tip_timeout)
		add_child(_tip_timer)
	_tip_timer.start()

func _stop_tip_cycle() -> void:
	if _tip_timer != null:
		_tip_timer.stop()

func _on_tip_timeout() -> void:
	_tip_index = (_tip_index + 1) % TIP_KEYS.size()
	_apply_tip()

func _apply_tip() -> void:
	overlay_tip_label.text = SettingsManager.t(TIP_KEYS[_tip_index])

func _retranslate() -> void:
	picker_title_label.text   = SettingsManager.t("MENU_MULTIPLAYER")
	normal_button.text        = SettingsManager.t("NET_MODE_NORMAL")
	ranked_button.text        = SettingsManager.t("NET_STEAM_RANKED")
	invite_button.text        = SettingsManager.t("NET_MODE_FRIEND")
	picker_close_button.text  = SettingsManager.t("NET_BACK")
	search_banner_cancel.tooltip_text = SettingsManager.t("NET_SEARCH_CANCEL")
	if _status_key != "":
		search_banner_label.text = SettingsManager.t(_status_key)

# ─── Actions UI ───────────────────────────────────────────────────────────────

# « Normal » : matchmaking automatique, sans choix héberger/rejoindre — cherche
# un lobby existant et, si aucun n'est trouvé, héberge à la place (voir
# _on_peer_disconnected/_start_quick_match_host).
func _on_normal_pressed() -> void:
	mode_picker.visible = false
	_quick_matching = true
	_search_mode = "normal"
	var err := _net.join_game_with(TransportFactory.Backend.STEAM)
	if err == OK:
		_set_loading(true)
		_show_search_banner(true)
		_set_status("NET_STEAM_SEARCHING")
	else:
		_quick_matching = false
		_search_mode = ""
		_flash_banner("NET_STEAM_UNAVAILABLE")

# L'overlay Steam d'invitation exige un lobby déjà créé (voir
# SteamTransport.invite_friends) : si aucun n'est en cours, on héberge d'abord
# et on ouvre l'overlay dès que le lobby est prêt, plutôt que de laisser le
# joueur presser « Héberger » lui-même avant de pouvoir inviter.
func _on_steam_invite_pressed() -> void:
	mode_picker.visible = false
	if _lobby_hosted:
		_net.invite_friends()
		return
	_quick_matching = false
	_search_mode = "invite"
	_net.session_ready.connect(_on_invite_lobby_ready, CONNECT_ONE_SHOT)
	var err := _net.host_game_with(TransportFactory.Backend.STEAM)
	if err == OK:
		_set_loading(true)
		_show_search_banner(true)
		_set_status("NET_STEAM_HOSTING")
	else:
		_search_mode = ""
		if _net.session_ready.is_connected(_on_invite_lobby_ready):
			_net.session_ready.disconnect(_on_invite_lobby_ready)
		_flash_banner("NET_STEAM_UNAVAILABLE")

func _on_invite_lobby_ready(_session_id: int) -> void:
	_net.invite_friends()

func _on_session_ready(_session_id: int) -> void:
	_lobby_hosted = _net.is_host

# ─── Matchmaking classé ───────────────────────────────────────────────────────

func _on_ranked_pressed() -> void:
	if not BackendClient.is_authenticated():
		_flash_banner("NET_RANKED_UNAVAILABLE")
		return
	mode_picker.visible = false
	_search_mode = "ranked"
	_show_search_banner(true)
	_set_loading(true)
	_set_status("NET_RANKED_QUEUEING")
	BackendClient.queue_join(func(success: bool, data: Dictionary) -> void:
		if not success or str(data.get("ticket_id", "")) == "":
			_flash_banner("NET_RANKED_UNAVAILABLE")
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

# Annulation générique de la recherche en cours, quel que soit le mode
# (Normal/Classé/Ami) — bouton "✕" du bandeau (voir _search_mode).
func _on_banner_cancel_pressed() -> void:
	match _search_mode:
		"ranked":
			_cancel_ranked_search(true)
		"normal", "invite":
			_quick_matching = false
			_search_mode = ""
			_net.close()
			_show_search_banner(false)
			_set_loading(false)
			_set_status("")
		_:
			# Pas de recherche active : le bandeau n'affiche qu'un message
			# (erreur/annulation) déjà en train de s'auto-fermer — on le
			# ferme juste immédiatement.
			_show_search_banner(false)

# manual : true si annulé par le joueur (statut dédié), false si on abandonne
# silencieusement (ex: coupure réseau déjà annoncée par ailleurs).
func _cancel_ranked_search(manual: bool) -> void:
	if _ranked_ticket_id == "":
		return
	BackendClient.queue_cancel(_ranked_ticket_id)
	_reset_ranked_ui()
	if manual:
		_flash_banner("NET_RANKED_CANCELLED")

func _reset_ranked_ui() -> void:
	if _ranked_poll_timer != null:
		_ranked_poll_timer.stop()
		_ranked_poll_timer.queue_free()
		_ranked_poll_timer = null
	_ranked_ticket_id = ""
	_ranked_role = ""
	_search_mode = ""
	_set_loading(false)

func _poll_ranked_queue() -> void:
	_ranked_elapsed += RANKED_POLL_INTERVAL
	if _ranked_elapsed >= RANKED_QUEUE_TIMEOUT:
		_cancel_ranked_search(false)
		_flash_banner("NET_RANKED_TIMEOUT")
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
				_reset_ranked_ui()
				_flash_banner("NET_RANKED_TIMEOUT")
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
			_cancel_ranked_search(false)
			_flash_banner("NET_STEAM_UNAVAILABLE")
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
		_reset_ranked_ui()
		_flash_banner("NET_STEAM_UNAVAILABLE")

# Hôte classé uniquement : le lobby vient d'être créé, on transmet son id au
# backend pour que l'invité puisse le rejoindre directement (voir
# _on_ranked_matched, branche invité).
func _on_ranked_lobby_ready(session_id: int) -> void:
	if _ranked_ticket_id == "":
		return
	BackendClient.queue_report_lobby(_ranked_ticket_id, session_id)
	_ranked_ticket_id = ""  # le rôle d'hôte n'a plus besoin de repoller/annuler

# ─── Connexion → handshake → bataille ─────────────────────────────────────────

# Annule et libère tout handshake/synchronisation de bataille d'une tentative
# de connexion précédente et abandonnée (pair déconnecté avant la fin) — sans
# ça, l'ancienne instance reste abonnée à _net.command_received et peut réagir
# à un paquet reçu lors d'une tentative suivante (setup — seed RNG, parité
# d'ids — périmé écrasant le bon).
func _cleanup_connection_flow() -> void:
	if _handshake != null and is_instance_valid(_handshake):
		_handshake.cancel()
		_handshake.queue_free()
	_handshake = null
	if _battle_sync != null and is_instance_valid(_battle_sync):
		_battle_sync.cancel()
		_battle_sync.queue_free()
	_battle_sync = null

func _on_peer_connected() -> void:
	_quick_matching = false
	_search_mode = ""
	_show_search_banner(false)
	_show_match_found_overlay(true)
	_cleanup_connection_flow()
	_set_loading(true)
	_set_status("NET_LOADING_PREPARING")
	_handshake = NetHandshake.new(_net, _local_deck_paths(), _net.is_host)
	add_child(_handshake)
	_handshake.completed.connect(_on_handshake_ready)
	_handshake.progress.connect(func(text: String) -> void: print("[MatchmakingOverlay] " + text))
	_handshake.start()

func _on_peer_disconnected(reason: String) -> void:
	# Coupure pendant un handshake/synchronisation en cours : évite de laisser
	# une instance abandonnée abonnée à _net.command_received (voir
	# _cleanup_connection_flow) avant une éventuelle tentative suivante.
	_cleanup_connection_flow()
	_show_match_found_overlay(false)
	match reason:
		"steam_same_account":
			_quick_matching = false
			_reset_ranked_ui()
			_show_search_banner(false)
			_flash_banner("NET_STEAM_SAME_ACCOUNT")
		"steam_no_lobby_found":
			if _quick_matching:
				_set_status("NET_STEAM_NO_LOBBY_HOSTING")
				_start_quick_match_host()
			else:
				_search_mode = ""
				_reset_ranked_ui()
				_show_search_banner(false)
				_flash_banner("NET_STEAM_NO_LOBBY")
		_:
			_quick_matching = false
			_search_mode = ""
			_reset_ranked_ui()
			_show_search_banner(false)
			print("[MatchmakingOverlay] Pair déconnecté (%s)" % [reason])
			_flash_banner("NET_STEAM_DISCONNECTED")

# Partie rapide sans adversaire trouvé : on héberge à la place plutôt que de
# laisser le joueur relancer manuellement (voir _on_normal_pressed).
func _start_quick_match_host() -> void:
	_quick_matching = false
	_search_mode = "normal"
	var err := _net.host_game_with(TransportFactory.Backend.STEAM)
	if err == OK:
		_set_loading(true)
		_show_search_banner(true)
		_set_status("NET_STEAM_HOSTING")
	else:
		_search_mode = ""
		_show_search_banner(false)
		_flash_banner("NET_STEAM_UNAVAILABLE")

# Invitation Steam acceptée (overlay ami / lien « Rejoindre la partie ») alors
# qu'aucune connexion n'est en cours : on rejoint directement ce lobby, peu
# importe l'écran sur lequel le joueur se trouve.
func _on_steam_join_requested(lobby_id: int) -> void:
	_quick_matching = false
	_search_mode = "normal"
	_set_status("NET_STEAM_INVITE_RECEIVED")
	var err := _net.join_game_with(TransportFactory.Backend.STEAM, {"lobby_id": lobby_id})
	if err == OK:
		_set_loading(true)
		_show_search_banner(true)
		_set_status("NET_STEAM_SEARCHING")
	else:
		_search_mode = ""
		_show_search_banner(false)
		_flash_banner("NET_STEAM_UNAVAILABLE")

# Deck local mélangé, sous forme de resource_path (identifiant partagé).
func _local_deck_paths() -> Array:
	var active := DeckManager.get_active_deck()
	if active == null:
		return []
	var paths: Array = active.card_paths.duplicate()
	paths.shuffle()
	return paths

func _on_handshake_ready(setup: Dictionary) -> void:
	_set_status("NET_WAITING_OPPONENT")
	NetContext.active = true
	NetContext.net = _net
	NetContext.is_host = _net.is_host
	# Le backend ne distingue pas ranked/partie rapide (voir CLAUDE.md § Ranked) :
	# ce flag n'existe que côté client, propagé jusqu'à Battle pour le succès
	# Steam "Premier sang" (voir AchievementManager). _ranked_role n'est non-vide
	# qu'après un appariement classé réussi (_on_ranked_matched), et n'est remis
	# à "" que par _reset_ranked_ui() (annulation/timeout), jamais sur ce chemin.
	setup["is_ranked"] = _ranked_role != ""
	NetContext.setup = setup
	# Sans cette étape, chaque client basculerait sur Battle.tscn dès que SON
	# handshake local est fini, indépendamment du pair — un joueur pouvait
	# démarrer son mulligan pendant que l'autre était encore au lobby. On
	# n'entre en bataille qu'une fois les deux prêts (voir NetBattleSync).
	_battle_sync = NetBattleSync.new(_net)
	add_child(_battle_sync)
	_battle_sync.completed.connect(_on_battle_sync_ready)
	_battle_sync.progress.connect(func(text: String) -> void: print("[MatchmakingOverlay] " + text))
	_battle_sync.start()

func _on_battle_sync_ready() -> void:
	await _show_vs_screen()
	# _net vit déjà sous cet autoload (racine de l'arbre, jamais affecté par un
	# change_scene_to_file) : pas besoin de le reparenter avant de charger
	# Battle, contrairement à l'ancien NetLobby (Control d'une scène remplacée).
	SceneTransition.change_scene(BATTLE_SCENE)

# Présentation face-à-face brève avant la bataille (voir CLAUDE.md, doc UX
# "Présentation avant la partie") : remplace l'écran de chargement, affiche
# nom + race(s) de chaque camp pendant VS_SCREEN_DURATION secondes.
func _show_vs_screen() -> void:
	match_found_overlay.hide()
	var local_name := SteamService.local_persona_name()
	vs_local_name_label.text = local_name if local_name != "" else SettingsManager.t("NET_VS_YOU")
	var remote_name := _net.remote_display_name()
	vs_remote_name_label.text = remote_name if remote_name != "" else SettingsManager.t("NET_VS_OPPONENT")
	var local_deck: Array = DeckManager.get_active_deck().card_paths if DeckManager.get_active_deck() else []
	vs_local_race_label.text = Race.deck_race_label(local_deck)
	vs_remote_race_label.text = Race.deck_race_label(NetContext.setup.get("opponent_deck", []))
	vs_overlay.show()
	await get_tree().create_timer(VS_SCREEN_DURATION).timeout
	vs_overlay.hide()
