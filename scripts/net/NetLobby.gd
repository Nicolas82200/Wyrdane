extends Control

# Point d'entrée du multijoueur, entièrement backend Steam (lobby + P2P
# Steamworks — voir SteamTransport/SteamService). Sans l'extension GodotSteam
# installée ou sans client Steam lancé, les boutons restent affichés mais
# échouent proprement avec un message (voir NET_STEAM_UNAVAILABLE) plutôt que
# de disparaître : mieux vaut un échec explicite qu'un écran vide.
#
# Trois modes, aucun choix héberger/rejoindre laissé au joueur :
# « Normal » est un vrai matchmaking : cherche un lobby Steam existant et, si
# aucun n'est trouvé, héberge automatiquement à la place (voir
# _on_normal_pressed/_start_quick_match_host).
# « Classé » passe par la file d'attente backend (voir section Matchmaking
# classé plus bas) : héberge ou rejoint selon le rôle renvoyé par le serveur.
# « Contre un ami » héberge un lobby et ouvre l'overlay Steam d'invitation dès
# qu'il est prêt (voir _on_steam_invite_pressed). Dès l'arrivée sur cet écran,
# on écoute aussi les demandes de rejoindre reçues via une invitation Steam
# acceptée (overlay ami, lien « Rejoindre la partie ») : le jeu doit déjà
# tourner et être sur cet écran — le cas « jeu pas encore lancé »
# (+connect_lobby en ligne de commande) n'est pas géré ici.
#
# Pendant la recherche : bandeau haut-droite (voir _show_search_banner).
# Une fois l'adversaire trouvé : écran de chargement plein écran avec astuces
# jusqu'à ce que la bataille démarre (voir _show_match_found_overlay).
#
# UI reprise du même habillage que MainMenu (fond vidéo, vignette, panneau
# doré) : voir scenes/net/NetLobby.tscn.

const BATTLE_SCENE := "res://scenes/battle/Battle.tscn"
const MAIN_MENU_SCENE := "res://scenes/mainMenu/MainMenu.tscn"

@onready var normal_button:      Button = $NavPanel/NavMargin/VBoxContainer/NormalButton
@onready var ranked_button:      Button = $NavPanel/NavMargin/VBoxContainer/RankedButton
@onready var invite_button:      Button = $NavPanel/NavMargin/VBoxContainer/InviteButton
@onready var cancel_search_button: Button = $NavPanel/NavMargin/VBoxContainer/CancelSearchButton
@onready var back_button:        Button = $NavPanel/NavMargin/VBoxContainer/BackButton
@onready var title_label:        Label  = $TitleLabel
@onready var subtitle_label:     Label  = $SubtitleLabel
@onready var status_title_label: Label  = $StatusPanel/StatusMargin/StatusVBox/StatusTitleLabel
@onready var spinner_icon:       TextureRect = $StatusPanel/StatusMargin/StatusVBox/LoadingCenter/LoadingVBox/SpinnerIcon
@onready var phase_label:        Label  = $StatusPanel/StatusMargin/StatusVBox/LoadingCenter/LoadingVBox/PhaseLabel

@onready var search_banner:        Control     = $SearchBanner
@onready var search_banner_spinner: TextureRect = $SearchBanner/SearchBannerMargin/SearchBannerSpinner
@onready var search_banner_label:   Label       = $SearchBanner/SearchBannerMargin/SearchBannerLabel

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
var _status_key := "NET_LOADING_IDLE"  # clé de traduction affichée par phase_label
var _loading := false  # affiche le spinner tant qu'une connexion est en cours
var _search_mode := ""  # "" | "normal" | "ranked" | "invite" — pilote le bouton Annuler
var _tip_timer: Timer
var _tip_index := 0

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
	normal_button.pressed.connect(_on_normal_pressed)
	ranked_button.pressed.connect(_on_ranked_pressed)
	cancel_search_button.pressed.connect(_on_cancel_search_pressed)
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
		var spin := delta * TAU * SPINNER_TURNS_PER_SECOND
		spinner_icon.rotation += spin
		search_banner_spinner.rotation += spin
		overlay_spinner.rotation += spin

# Remplace le texte de statut affiché (une seule phase à la fois, jamais un
# journal qui s'accumule — voir _net.status en debug console pour le détail).
func _set_status(key: String) -> void:
	_status_key = key
	phase_label.text = SettingsManager.t(key)
	if match_found_overlay.visible:
		overlay_phase_label.text = SettingsManager.t(key)

func _set_loading(active: bool) -> void:
	_loading = active
	spinner_icon.visible = active
	if not active:
		spinner_icon.rotation = 0.0

# Bandeau haut-droite affiché tant qu'on cherche un adversaire (avant que le
# pair ne soit connecté) — remplace l'ancien choix manuel héberger/rejoindre.
func _show_search_banner(active: bool) -> void:
	search_banner.visible = active
	cancel_search_button.visible = active
	if active:
		search_banner_spinner.rotation = 0.0

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
	title_label.text        = SettingsManager.t("MENU_MULTIPLAYER")
	subtitle_label.text     = SettingsManager.t("NET_LOBBY_SUBTITLE")
	status_title_label.text = SettingsManager.t("NET_STATUS_TITLE")
	phase_label.text        = SettingsManager.t(_status_key)
	normal_button.text      = SettingsManager.t("NET_MODE_NORMAL")
	ranked_button.text      = SettingsManager.t("NET_STEAM_RANKED")
	invite_button.text      = SettingsManager.t("NET_MODE_FRIEND")
	cancel_search_button.text = SettingsManager.t("NET_SEARCH_CANCEL")
	back_button.text        = SettingsManager.t("NET_BACK")
	search_banner_label.text = SettingsManager.t("NET_SEARCH_BANNER")

# ─── Actions UI ───────────────────────────────────────────────────────────────

# « Normal » : matchmaking automatique, sans choix héberger/rejoindre — cherche
# un lobby existant et, si aucun n'est trouvé, héberge à la place (voir
# _on_peer_disconnected/_start_quick_match_host).
func _on_normal_pressed() -> void:
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
		_set_status("NET_STEAM_UNAVAILABLE")

func _on_invite_lobby_ready(_session_id: int) -> void:
	_net.invite_friends()

func _on_session_ready(_session_id: int) -> void:
	_lobby_hosted = _net.is_host

func _on_back_pressed() -> void:
	# Coupe une éventuelle connexion en cours avant de revenir au menu.
	_cancel_ranked_search(false)
	_lobby_hosted = false
	_search_mode = ""
	_set_loading(false)
	_show_search_banner(false)
	_show_match_found_overlay(false)
	_net.close()
	AudioManager.play(AudioManager.CLOSE_MENU)
	SceneTransition.change_scene(MAIN_MENU_SCENE)

# ─── Matchmaking classé ───────────────────────────────────────────────────────

func _on_ranked_pressed() -> void:
	if not BackendClient.is_authenticated():
		_set_status("NET_RANKED_UNAVAILABLE")
		return
	_search_mode = "ranked"
	_set_actions_enabled(false)
	_show_search_banner(true)
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

# Annulation générique de la recherche en cours, quel que soit le mode
# (Normal/Classé/Ami) — voir _search_mode.
func _on_cancel_search_pressed() -> void:
	match _search_mode:
		"ranked":
			_cancel_ranked_search(true)
		"normal", "invite":
			_quick_matching = false
			_search_mode = ""
			_net.close()
			_show_search_banner(false)
			_set_loading(false)
			_set_actions_enabled(true)
			_set_status("NET_LOADING_IDLE")

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
	_search_mode = ""
	_show_search_banner(false)
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

# Annule et libère tout handshake/synchronisation de bataille d'une tentative
# de connexion précédente et abandonnée (pair déconnecté avant la fin, ou
# retour au lobby) — sans ça, l'ancienne instance reste enfant de NetLobby,
# toujours abonnée à _net.command_received, et peut réagir à un paquet reçu
# lors d'une tentative suivante (double changement de scène, ou setup — seed
# RNG, parité d'ids — périmé écrasant le bon).
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
	print("[NetLobby] _on_peer_connected  self=%s  handshake_deja_present=%s" % [self, _handshake != null])
	_cleanup_connection_flow()
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
	normal_button.disabled = not enabled
	ranked_button.disabled = not enabled
	invite_button.disabled = not enabled

func _on_peer_disconnected(reason: String) -> void:
	# Coupure pendant un handshake/synchronisation en cours : évite de laisser
	# une instance abandonnée abonnée à _net.command_received (voir
	# _cleanup_connection_flow) avant une éventuelle tentative suivante.
	_cleanup_connection_flow()
	_show_match_found_overlay(false)
	match reason:
		"steam_same_account":
			_quick_matching = false
			_search_mode = ""
			_reset_ranked_ui()
			_set_loading(false)
			_show_search_banner(false)
			_set_status("NET_STEAM_SAME_ACCOUNT")
		"steam_no_lobby_found":
			if _quick_matching:
				_set_status("NET_STEAM_NO_LOBBY_HOSTING")
				_start_quick_match_host()
			else:
				_search_mode = ""
				_reset_ranked_ui()
				_set_loading(false)
				_show_search_banner(false)
				_set_status("NET_STEAM_NO_LOBBY")
		_:
			_quick_matching = false
			_search_mode = ""
			_reset_ranked_ui()
			_set_loading(false)
			_show_search_banner(false)
			print("[NetLobby] Pair déconnecté (%s)" % [reason])
			_set_status("NET_STEAM_DISCONNECTED")

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
		_set_loading(false)
		_show_search_banner(false)
		_set_status("NET_STEAM_UNAVAILABLE")

# Invitation Steam acceptée (overlay ami / lien « Rejoindre la partie ») alors
# que le joueur est déjà sur cet écran : on rejoint directement ce lobby.
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
		_set_loading(false)
		_show_search_banner(false)
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
	_battle_sync.progress.connect(func(text: String) -> void: print("[NetLobby] " + text))
	_battle_sync.start()

func _on_battle_sync_ready() -> void:
	print("[NetLobby] Adversaire prêt — lancement de la bataille réseau…")
	await _show_vs_screen()
	# Le NetworkManager doit survivre au changement de scène : on le reparente
	# sous la racine de l'arbre avant de charger Battle.
	_net.get_parent().remove_child(_net)
	get_tree().root.add_child(_net)
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
