extends CanvasLayer

# Autoload : orchestre tout le multijoueur (choix du mode, recherche,
# connexion, handshake) sans jamais quitter la scène courante. Remplace
# l'ancien écran plein écran NetLobby.tscn : ce CanvasLayer vit à la racine
# de l'arbre (comme tout autoload) et survit donc à n'importe quel
# `change_scene_to_file` — le joueur peut ouvrir le Deck Builder, la
# boutique, etc. pendant qu'une recherche est en cours.
#
# Entrée : le choix du mode (Normal/Classé) vit directement dans MainMenu
# (cartes sous la liste de decks, voir MainMenu._on_match_normal_pressed & co)
# — MainMenu appelle start_normal()/start_ranked() une fois le deck choisi.
# Inviter un ami précis (voir invite_friend(), appelé depuis
# FriendsPanel._show_context_menu via MainMenu._start_friend_invite_flow) suit
# le même principe mais saute l'écran de mode. Dès l'appel, le bandeau de
# recherche (haut-droite, ancré à cet autoload donc visible partout) prend le
# relais. Le bandeau sert aussi de zone de statut/erreur (voir _flash_banner)
# tant qu'il n'y a plus de StatusPanel toujours visible comme sur l'ancien
# écran NetLobby.
#
# Le bandeau affiche aussi le mode en recherche, le temps écoulé et une
# estimation d'attente moyenne (voir _update_search_meta/_refresh_banner_text).
#
# Une fois l'adversaire trouvé : le bandeau clignote quelques secondes
# ("Chargement de la partie", voir _flash_match_ready_banner) — le temps que
# le joueur, même ailleurs dans le menu, voie qu'une partie va démarrer —
# avant l'écran de chargement plein écran, puis la présentation face-à-face,
# puis la bascule sur Battle.tscn.

const BATTLE_SCENE := "res://scenes/battle/Battle.tscn"

@onready var search_banner:            Control     = $SearchBanner
@onready var search_banner_spinner:    RingSpinner = $SearchBanner/SearchBannerMargin/SearchBannerSpinner
@onready var search_banner_mode_label: Label       = $SearchBanner/SearchBannerMargin/SearchBannerTextBox/SearchBannerModeLabel
@onready var search_banner_label:      Label       = $SearchBanner/SearchBannerMargin/SearchBannerTextBox/SearchBannerLabel
@onready var search_banner_avg_label:  Label       = $SearchBanner/SearchBannerMargin/SearchBannerTextBox/SearchBannerAvgLabel
@onready var search_banner_cancel:     Button      = $SearchBanner/SearchBannerMargin/SearchBannerCancel

@onready var match_found_overlay: Control     = $MatchFoundOverlay
@onready var overlay_spinner:     RingSpinner = $MatchFoundOverlay/OverlayCenter/OverlayVBox/OverlaySpinner
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

# Popup de choix de deck affiché à la réception d'une invitation, quelle que
# soit sa source : une invitation d'ami Wyrdane (voir _poll_incoming_invites,
# flux normal depuis le retrait de l'ancien overlay Steam natif) ou, en repli,
# une invitation Steam classique (overlay ami / lien « Rejoindre la partie »,
# voir _on_steam_join_requested — reste possible si un ami rejoint via son
# propre client Steam plutôt que la popup en jeu). Contrairement au flux
# normal/classé, où le deck est choisi dans MainMenu AVANT de lancer la
# recherche, celui qui reçoit une invitation peut accepter depuis n'importe où
# (y compris juste après le lancement du jeu) sans jamais être passé par
# DeckSelectView — ce popup est donc le seul moment où on lui laisse choisir
# son deck avant de rejoindre le lobby de l'hôte.
@onready var invite_deck_overlay:    Control         = $InviteDeckChoiceOverlay
@onready var invite_title_label:     Label           = $InviteDeckChoiceOverlay/InvitePanel/InviteMargin/InviteVBox/InviteHeaderRow/InviteTitleLabel
@onready var invite_decline_button:  Button          = $InviteDeckChoiceOverlay/InvitePanel/InviteMargin/InviteVBox/InviteHeaderRow/InviteDeclineButton
@onready var invite_from_label:      Label           = $InviteDeckChoiceOverlay/InvitePanel/InviteMargin/InviteVBox/InviteFromLabel
@onready var invite_decks_container: VBoxContainer   = $InviteDeckChoiceOverlay/InvitePanel/InviteMargin/InviteVBox/InviteDeckScroll/InviteDecksContainer
@onready var invite_join_button:     Button          = $InviteDeckChoiceOverlay/InvitePanel/InviteMargin/InviteVBox/InviteJoinButton

# Durée d'affichage d'un message de fin de recherche (erreur/annulation) dans
# le bandeau avant qu'il ne se referme tout seul (voir _flash_banner).
const BANNER_MESSAGE_DURATION := 4.0

# Nom affiché + estimation d'attente par mode (voir _update_search_meta).
# Purement indicatif (pas de stat serveur réelle) : pas d'entrée pour "invite"
# — l'attente dépend entièrement de l'ami invité, une moyenne n'aurait pas de
# sens dans ce cas, seul le temps écoulé est affiché.
const MODE_DISPLAY_KEYS := {
	"normal": "NET_MODE_NORMAL",
	"ranked": "NET_STEAM_RANKED",
	"invite": "NET_MODE_FRIEND",
}
const AVERAGE_WAIT_SECONDS := {
	"normal": 20,
	"ranked": 60,
}

# Le bandeau clignote et décompte (5/4/3/2/1) le temps que les deux clients
# confirment la connexion P2P, avant de basculer sur l'écran de chargement
# plein écran (voir _on_peer_connected/_run_match_ready_countdown) — pour que
# le joueur, même s'il navigue ailleurs dans le menu, voie clairement qu'une
# partie va démarrer.
const MATCH_READY_COUNTDOWN_START := 5
# Demi-période choisie pour qu'un cycle complet (0.5 x2) dure exactement 1s,
# soit la même cadence que le décompte du texte (voir _run_match_ready_countdown)
# — le texte change à chaque clignotement, pas de façon désynchronisée.
const MATCH_READY_BLINK_HALF_PERIOD := 0.5

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
var _status_key := ""  # clé de traduction affichée par le bandeau
var _status_format_arg = null  # argument % substitué dans _status_key, voir _set_status
var _loading := false  # affiche le spinner tant qu'une connexion est en cours
var _search_mode := ""  # "" | "normal" | "ranked" | "invite" — pilote le bouton Annuler
var _tip_timer: Timer
var _tip_index := 0
var _banner_hide_timer: Timer
var _search_elapsed := 0.0  # secondes depuis le début de la recherche active
var _last_shown_elapsed := -1  # évite de retoucher le Label plus d'une fois par seconde
var _connect_token := 0  # incrémenté à chaque (dé)connexion : annule un flash "adversaire trouvé" périmé
var _banner_flash_tween: Tween

# ─── Popup de choix de deck sur invitation ─────────────────────────────────────
var _pending_invite_lobby_id := 0  # 0 = aucune invitation en attente de choix de deck
var _pending_invite_friend_name := ""  # "" si nom non résolu (voir _retranslate, réappliqué si la langue change pendant que le popup est ouvert)
var _pending_invite_deck_index := -1
# id de l'invitation backend en attente de réponse (voir _poll_incoming_invites/
# BackendClient.accept_game_invite) — 0 si le popup n'a rien à répondre côté
# serveur (ne devrait plus arriver depuis le retrait du flux Steam natif, mais
# _show_invite_deck_popup reste générique).
var _pending_backend_invite_id := 0

# ─── Invitation de partie entre amis (remplace l'ancien overlay Steam natif,
# voir FriendsPanel.gd/BackendClient.send_game_invite) ─────────────────────────
const INCOMING_INVITE_POLL_INTERVAL := 4.0  # même cadence que ChatPanel._poll
const OUTGOING_INVITE_POLL_INTERVAL := 2.0
# Légèrement au-dessus d'INVITE_EXPIRY_SECONDS côté backend (45s) : le serveur
# expire déjà l'invitation de son côté, cette marge évite juste une course où
# le client abandonnerait une fraction de seconde avant lui.
const OUTGOING_INVITE_TIMEOUT := 50.0
var _incoming_invite_poll_timer: Timer
var _outgoing_invite_poll_timer: Timer
var _pending_outgoing_invite_id := 0  # 0 = aucune invitation envoyée en attente de réponse
var _pending_outgoing_recipient_name := ""
var _outgoing_invite_elapsed := 0.0

# ─── Matchmaking classé ───────────────────────────────────────────────────────
# Contrat backend : docs/backend-contracts/ranked-matchmaking-and-retention.md
const RANKED_POLL_INTERVAL := 2.0
const RANKED_QUEUE_TIMEOUT := 180.0  # abandon après 3 min sans adversaire
# "Normal" tente désormais lui aussi l'appariement par MMR (caché, voir
# start_normal) sur cette même file backend — mais avec un délai d'abandon
# bien plus court : contrairement au Classé, il existe un repli (recherche de
# lobby Steam directe, ancien comportement) si personne n'est trouvé à temps,
# pas de raison de faire attendre le joueur aussi longtemps qu'en Classé.
const NORMAL_QUEUE_TIMEOUT := 20.0
# queue_report_lobby (voir _on_queue_lobby_ready) était appelée sans callback :
# un échec réseau ponctuel restait totalement silencieux, l'invité restant
# bloqué à repoller un lobby qui n'arrivait jamais jusqu'au timeout de 3 min
# (bug rapporté : partie classée qui ne se lance jamais). Réessai avec un
# court délai avant d'abandonner et de prévenir explicitement l'hôte.
const RANKED_REPORT_LOBBY_MAX_ATTEMPTS := 3
const RANKED_REPORT_LOBBY_RETRY_DELAY := 1.5

# Temps d'attente max d'un pair réel une fois hôte désigné par la file
# backend et le lobby Steam créé/rapporté (voir _on_queue_matched, branche
# hôte). Sans ce filet, un hôte dont l'invité n'arrive jamais (join Steam
# refusé de son côté, voir _queue_matched_join_pending) restait bloqué "en
# attente d'un adversaire" indéfiniment, sans le savoir — rien côté Steam ne
# prévient l'hôte d'une entrée en lobby refusée chez le pair (lobby_chat_update
# ne se déclenche que si quelqu'un entre RÉELLEMENT dans le lobby). Plutôt que
# de rester bloqué, l'hôte referme et relance une recherche automatiquement.
#
# 60s et non 30 : l'invité doit avoir le temps de voir le lobby apparaître à son
# prochain poll (RANKED_POLL_INTERVAL), de le rejoindre côté Steam, PUIS
# d'établir la connexion P2P. À 30s, un aller-retour un peu lent suffisait à ce
# que l'hôte referme son lobby (voir NetworkManager._setup_transport : toute
# nouvelle tentative quitte le lobby en cours) pendant que l'invité était encore
# en train de le rejoindre — l'invité recevait alors "lobby inexistant" (code 2)
# et les deux repartaient en boucle, chacun détruisant le lobby que l'autre
# venait de trouver.
const HOST_PEER_WAIT_TIMEOUT := 60.0

# Nombre maximum de relances automatiques consécutives après un join refusé
# (voir _on_peer_disconnected, "steam_lobby_join_failed"). Sans plafond, deux
# joueurs pouvaient se relancer indéfiniment l'un après l'autre — chaque
# relance détruisant le lobby en cours (voir HOST_PEER_WAIT_TIMEOUT) et donc
# provoquant l'échec suivant : une boucle qui ne convergeait jamais et
# empêchait complètement de jouer ensemble. Au-delà, on s'arrête et on le dit
# au joueur plutôt que de boucler en silence.
const MAX_AUTO_JOIN_RETRIES := 2

# Mode de la file backend en cours ("ranked"|"normal"|"") — distinct de
# _search_mode (qui reste "normal" même une fois basculé sur le repli Steam
# direct, voir _start_direct_quick_match) : sert uniquement à savoir si le
# match en cours de connexion vient réellement d'un appariement CLASSÉ (voir
# _on_handshake_ready, setup["is_ranked"]) — _queue_role, lui, est désormais
# partagé par les deux modes depuis que Normal passe aussi par cette file.
var _queue_mode: String = ""
var _queue_ticket_id: String = ""
var _queue_role: String = ""  # "host" | "guest", connu une fois apparié
var _queue_elapsed := 0.0
var _queue_poll_timer: Timer
# Preuve d'appariement backend (voir TODO.md P9) : matchId serveur + jeton
# signé, reçus dans la réponse "matched" du poll de file d'attente, identiques
# des deux côtés (voir matchmakingModel.pairTickets côté wyrdane-backend).
var _queue_match_id: String = ""
var _queue_match_session_token: String = ""
# true entre le clic Annuler et la réponse de queue_join quand ce dernier
# n'est pas encore revenu (voir _cancel_queue_search/start_ranked) : le
# ticket sera annulé dès qu'il arrive au lieu d'être laissé actif en tâche de
# fond pendant que l'UI se croit déjà revenue au repos.
var _queue_cancel_pending := false
# true entre l'envoi du join() vers le lobby rapporté par l'hôte (voir
# _on_queue_matched, branche invité) et sa confirmation/son échec — distingue
# un "steam_lobby_join_failed" venant de ce flux (retenté automatiquement,
# voir _on_peer_disconnected) d'un échec de join sur une invitation Steam
# classique (lobby_id choisi par le joueur, jamais retenté automatiquement).
var _queue_matched_join_pending := false
# Filet de sécurité côté hôte : voir HOST_PEER_WAIT_TIMEOUT.
var _host_peer_wait_timer: Timer
# Relances automatiques consécutives déjà consommées (voir
# MAX_AUTO_JOIN_RETRIES) — remis à zéro dès qu'une connexion aboutit ou qu'une
# nouvelle recherche est lancée à la main par le joueur.
var _auto_join_retries := 0

func _ready() -> void:
	_net = NetworkManager.new()
	add_child(_net)
	_net.peer_connected.connect(_on_peer_connected)
	_net.peer_identified.connect(_on_peer_identified)
	_net.peer_disconnected.connect(_on_peer_disconnected)
	# Détail technique (ids de lobby, codes de connexion P2P...) utile en debug
	# mais pas au joueur : direction console uniquement (voir _flash_banner/
	# _set_status pour le texte réellement affiché, un message à la fois).
	_net.status.connect(func(text: String) -> void: print("[MatchmakingOverlay] " + text))
	search_banner_cancel.pressed.connect(_on_banner_cancel_pressed)
	invite_decline_button.pressed.connect(_on_invite_decline_pressed)
	invite_join_button.pressed.connect(_on_invite_join_pressed)
	SettingsManager.language_changed.connect(func(_l): _retranslate())
	_retranslate()
	if SteamService.is_available():
		SteamService.watch_join_requests(_on_steam_join_requested)
	_incoming_invite_poll_timer = Timer.new()
	_incoming_invite_poll_timer.wait_time = INCOMING_INVITE_POLL_INTERVAL
	_incoming_invite_poll_timer.timeout.connect(_poll_incoming_invites)
	add_child(_incoming_invite_poll_timer)
	_incoming_invite_poll_timer.start()

func _process(delta: float) -> void:
	# Pompe les callbacks Steam en continu (même hors recherche active), pour
	# capter une invitation reçue à tout moment (voir SteamService.
	# watch_join_requests). Sans effet si Steam pas initialisé.
	if SteamService.is_available():
		SteamService.run_callbacks()
	# Temps écoulé affiché sous le statut principal tant qu'une recherche est
	# active (voir _refresh_banner_text) — retouché au plus une fois par
	# seconde, pas besoin de plus pour un compteur en mm:ss.
	if _loading and _search_mode != "":
		_search_elapsed += delta
		var whole := int(_search_elapsed)
		if whole != _last_shown_elapsed:
			_last_shown_elapsed = whole
			_refresh_banner_text()

# ─── Statut / bandeau ──────────────────────────────────────────────────────────

# Change de mode de recherche (voir _search_mode) en centralisant les effets
# de bord : réinitialise le compteur de temps écoulé seulement sur une
# véritable transition repos → recherche (jamais sur un changement interne,
# ex. bascule join→host de "Normal" quand aucun lobby n'est trouvé — voir
# _start_quick_match_host, qui réaffecte "normal" alors qu'une recherche est
# déjà en cours), et tient les libellés mode/moyenne à jour dans le bandeau.
func _set_search_mode(mode: String) -> void:
	if mode != "" and _search_mode == "":
		_search_elapsed = 0.0
		_last_shown_elapsed = -1
	_search_mode = mode
	_update_search_meta()

func _update_search_meta() -> void:
	if _search_mode == "":
		search_banner_mode_label.visible = false
		search_banner_avg_label.visible = false
		return
	search_banner_mode_label.visible = true
	search_banner_mode_label.text = SettingsManager.t(MODE_DISPLAY_KEYS.get(_search_mode, ""))
	if AVERAGE_WAIT_SECONDS.has(_search_mode):
		search_banner_avg_label.visible = true
		search_banner_avg_label.text = SettingsManager.t("NET_AVERAGE_WAIT") % _format_mmss(AVERAGE_WAIT_SECONDS[_search_mode])
	else:
		search_banner_avg_label.visible = false

func _format_mmss(total_seconds: int) -> String:
	return "%d:%02d" % [total_seconds / 60, total_seconds % 60]

# Texte traduit du statut courant — %s/%d substitué depuis _status_format_arg
# si présent (ex. nom de l'ami, voir _on_peer_identified), sinon texte fixe.
func _format_status_text() -> String:
	if _status_key == "":
		return ""
	var text := SettingsManager.t(_status_key)
	return (text % _status_format_arg) if _status_format_arg != null else text

# Recompose le texte principal du bandeau : statut traduit + temps écoulé tant
# qu'une recherche est active (voir _process).
func _refresh_banner_text() -> void:
	var text := _format_status_text()
	if _loading and _search_mode != "":
		text += "  " + _format_mmss(int(_search_elapsed))
	search_banner_label.text = text

# format_arg substitué dans le texte traduit (ex. nom de l'ami qui se prépare,
# voir _on_peer_identified) — null pour un statut sans partie dynamique.
func _set_status(key: String, format_arg = null) -> void:
	_status_key = key
	_status_format_arg = format_arg
	_refresh_banner_text()
	if match_found_overlay.visible:
		overlay_phase_label.text = _format_status_text()

func _set_loading(active: bool) -> void:
	_loading = active
	search_banner_spinner.visible = active

# Bandeau haut-droite affiché tant qu'on cherche un adversaire.
func _show_search_banner(active: bool) -> void:
	if _banner_hide_timer != null:
		_banner_hide_timer.stop()
	search_banner.visible = active
	search_banner_cancel.visible = active

# Affiche un message de fin de recherche (erreur, annulation, timeout...) dans
# le bandeau puis le referme tout seul après BANNER_MESSAGE_DURATION — sans
# StatusPanel toujours visible comme sur l'ancien écran, une erreur silencieuse
# passerait sinon inaperçue pendant que le joueur navigue ailleurs. Une
# recherche est par définition terminée dès qu'un message est flashé : efface
# aussi le mode/la moyenne affichés (voir _set_search_mode).
func _flash_banner(key: String) -> void:
	_set_loading(false)
	_set_search_mode("")
	_set_status(key)
	search_banner.visible = true
	search_banner_cancel.visible = false
	if _banner_hide_timer == null:
		_banner_hide_timer = Timer.new()
		_banner_hide_timer.one_shot = true
		_banner_hide_timer.timeout.connect(func(): search_banner.visible = false)
		add_child(_banner_hide_timer)
	_banner_hide_timer.start(BANNER_MESSAGE_DURATION)

# Bandeau clignotant affiché dès que le pair est connecté, avant l'écran de
# chargement plein écran (voir _on_peer_connected/_run_match_ready_countdown)
# — la recherche est finie mais le joueur (peut-être ailleurs dans le menu)
# doit voir que la partie va démarrer, pas juste basculer brutalement sur
# l'overlay plein écran. Décompte le texte lui-même de
# MATCH_READY_COUNTDOWN_START à 1 (une seconde par palier) : titre fixe
# ("Partie trouvée" ou, en mode invitation, "<ami> est prêt") sur la première
# ligne, "Début dans N" sur la seconde. `token` est celui de _connect_token au
# moment de l'appel (voir _on_peer_connected) : une coupure en cours de route
# invalide le décompte sans avoir à l'annuler explicitement.
func _run_match_ready_countdown(token: int, peer_name: String) -> void:
	if _banner_hide_timer != null:
		_banner_hide_timer.stop()
	search_banner.visible = true
	search_banner_cancel.visible = false
	var title := SettingsManager.t("NET_INVITE_PEER_READY_FORMAT") % peer_name if peer_name != "" \
		else SettingsManager.t("NET_MATCH_FOUND_BANNER")
	_banner_flash_tween = create_tween()
	_banner_flash_tween.set_loops()
	_banner_flash_tween.tween_property(search_banner, "modulate:a", 0.35, MATCH_READY_BLINK_HALF_PERIOD)
	_banner_flash_tween.tween_property(search_banner, "modulate:a", 1.0, MATCH_READY_BLINK_HALF_PERIOD)
	for count in range(MATCH_READY_COUNTDOWN_START, 0, -1):
		if token != _connect_token:
			return
		search_banner_label.text = title + "\n" + (SettingsManager.t("NET_MATCH_STARTING_IN_FORMAT") % count)
		await get_tree().create_timer(1.0).timeout
	_stop_match_ready_flash()

func _stop_match_ready_flash() -> void:
	if _banner_flash_tween != null and is_instance_valid(_banner_flash_tween):
		_banner_flash_tween.kill()
	_banner_flash_tween = null
	search_banner.modulate.a = 1.0

# Écran de chargement plein écran affiché une fois l'adversaire trouvé, le
# temps du handshake/synchronisation (voir _on_peer_connected/_on_handshake_ready).
func _show_match_found_overlay(active: bool) -> void:
	match_found_overlay.visible = active
	if active:
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
	search_banner_cancel.tooltip_text = SettingsManager.t("NET_SEARCH_CANCEL")
	_refresh_banner_text()
	_update_search_meta()
	invite_title_label.text = SettingsManager.t("NET_INVITE_TITLE")
	invite_decline_button.text = SettingsManager.t("NET_INVITE_DECLINE")
	invite_join_button.text = SettingsManager.t("NET_INVITE_JOIN")
	_refresh_invite_from_label()

# ─── Actions UI ───────────────────────────────────────────────────────────────
# Appelées directement par MainMenu une fois le deck choisi (voir
# MainMenu._on_match_normal_pressed & co) — pas de popup intermédiaire.
# Ignorées si une recherche/connexion est déjà en cours : le bandeau + son
# bouton Annuler donnent déjà tout le contrôle nécessaire.

# « Normal » : matchmaking automatique, sans choix héberger/rejoindre. Tente
# d'abord un appariement par MMR CACHÉ via la file backend (même mécanisme que
# le Classé, voir _queue_join_and_poll) — façon MMR caché League of Legends :
# apparie des adversaires de niveau similaire sans jamais afficher ce MMR ni
# lui faire gagner/perdre de points de classement (voir
# BackendClient.report_ranked_match, mode="normal"). Si le backend est
# indisponible, si la requête échoue, ou si personne n'est trouvé sous
# NORMAL_QUEUE_TIMEOUT, repli silencieux sur l'ancien comportement (recherche
# d'un lobby Steam existant puis hébergement, voir _start_direct_quick_match)
# — jamais d'erreur affichée pour ce repli, un joueur ne doit pas voir Normal
# devenir indisponible juste parce que l'appariement par niveau l'est.
func start_normal() -> void:
	if _search_mode != "" or _loading:
		return
	_queue_mode = ""  # jamais un résidu d'une précédente recherche classée
	if not BackendClient.is_authenticated():
		_start_direct_quick_match()
		return
	_queue_cancel_pending = false
	_set_search_mode("normal")
	_show_search_banner(true)
	_set_loading(true)
	_set_status("NET_RANKED_QUEUEING")
	_queue_join_and_poll("normal")

# Ancien comportement de start_normal() avant l'ajout du MMR caché ci-dessus :
# recherche directe d'un lobby Steam public existant, hébergement en secours
# si aucun n'est trouvé (voir _on_peer_disconnected/_start_quick_match_host).
# Sert désormais de repli quand la file backend est indisponible/infructueuse.
func _start_direct_quick_match() -> void:
	if _search_mode != "" and _search_mode != "normal":
		return
	_quick_matching = true
	_set_search_mode("normal")
	var err := _net.join_game_with(TransportFactory.Backend.STEAM)
	if err == OK:
		_set_loading(true)
		_show_search_banner(true)
		_set_status("NET_STEAM_SEARCHING")
	else:
		_quick_matching = false
		_set_search_mode("")
		_flash_banner("NET_STEAM_UNAVAILABLE")

# Invite un ami Wyrdane précis à jouer (remplace l'ancien overlay Steam natif,
# voir FriendsPanel._show_context_menu) : on héberge d'abord un lobby Steam
# comme avant, mais l'invitation elle-même transite par le backend au lieu de
# activateGameOverlayInviteDialog — l'ami la découvre par polling
# (_poll_incoming_invites côté lui) et reçoit une popup en jeu avec choix de
# deck, qu'il soit ou non en train de regarder Steam à ce moment-là.
func invite_friend(recipient_id: int, recipient_name: String) -> void:
	if _search_mode != "" or _loading:
		return
	if not BackendClient.is_authenticated():
		_flash_banner("NET_STEAM_UNAVAILABLE")
		return
	# Une invitation est un choix explicite de jouer avec QUELQU'UN de précis :
	# rien du matchmaking automatique ne doit pouvoir la saboter derrière. Un
	# ticket de file encore vivant (recherche annulée dont la réponse backend
	# n'était pas encore revenue, poll en cours...) pouvait se réveiller plus
	# tard et rappeler host_game_with/join_game_with — ce qui quitte le lobby
	# d'invitation en cours (voir NetworkManager._setup_transport) et faisait
	# échouer l'entrée de l'ami avec "lobby inexistant" (code 2).
	_abandon_queue_for_invite()
	_pending_outgoing_recipient_name = recipient_name
	_quick_matching = false
	_set_search_mode("invite")
	_net.session_ready.connect(_on_friend_invite_lobby_ready.bind(recipient_id, recipient_name), CONNECT_ONE_SHOT)
	var err := _net.host_game_with(TransportFactory.Backend.STEAM)
	if err == OK:
		_set_loading(true)
		_show_search_banner(true)
		_set_status("NET_STEAM_HOSTING")
	else:
		_set_search_mode("")
		if _net.session_ready.is_connected(_on_friend_invite_lobby_ready):
			_net.session_ready.disconnect(_on_friend_invite_lobby_ready)
		_flash_banner("NET_STEAM_UNAVAILABLE")

func _on_friend_invite_lobby_ready(session_id: int, recipient_id: int, recipient_name: String) -> void:
	BackendClient.send_game_invite(recipient_id, session_id, func(success: bool, data: Dictionary) -> void:
		if _search_mode != "invite":
			return  # annulé pendant l'aller-retour réseau, voir _on_banner_cancel_pressed
		if not success:
			_net.close()
			_reset_friend_invite_state()
			if str(data.get("message", "")) == "recipient_unavailable":
				_flash_banner("NET_FRIEND_INVITE_UNAVAILABLE")
			else:
				_flash_banner("NET_FRIEND_INVITE_FAILED")
			return
		_pending_outgoing_invite_id = int(data.get("id", 0))
		_set_status("NET_FRIEND_INVITE_WAITING_FORMAT", recipient_name)
		_outgoing_invite_elapsed = 0.0
		_outgoing_invite_poll_timer = Timer.new()
		_outgoing_invite_poll_timer.wait_time = OUTGOING_INVITE_POLL_INTERVAL
		_outgoing_invite_poll_timer.timeout.connect(_poll_outgoing_invite)
		add_child(_outgoing_invite_poll_timer)
		_outgoing_invite_poll_timer.start()
	)

# Pollé pendant l'attente de réponse de l'ami invité. Une acceptation ne fait
# rien de spécial ici : l'ami va rejoindre le lobby Steam de son côté, ce qui
# déclenche _on_peer_connected comme n'importe quelle autre connexion — seul
# le refus/l'expiration/l'annulation doivent interrompre l'attente ici.
func _poll_outgoing_invite() -> void:
	_outgoing_invite_elapsed += OUTGOING_INVITE_POLL_INTERVAL
	if _outgoing_invite_elapsed >= OUTGOING_INVITE_TIMEOUT:
		_net.close()
		_reset_friend_invite_state()
		_flash_banner("NET_FRIEND_INVITE_TIMEOUT")
		return
	var invite_id := _pending_outgoing_invite_id
	BackendClient.get_invite_status(invite_id, func(success: bool, status: String) -> void:
		if invite_id != _pending_outgoing_invite_id or not success:
			return
		match status:
			"declined":
				_net.close()
				_reset_friend_invite_state()
				_flash_banner("NET_FRIEND_INVITE_DECLINED")
			"expired", "cancelled":
				_net.close()
				_reset_friend_invite_state()
				_flash_banner("NET_FRIEND_INVITE_TIMEOUT")
			"accepted":
				# L'ami a accepté : il est en train de rejoindre le lobby Steam,
				# _on_peer_connected prendra le relais. On coupe le poll ici sans
				# rien fermer ni toucher au bandeau (la connexion P2P peut encore
				# demander quelques secondes) — surtout ne pas laisser le délai
				# d'abandon courir, il appellerait _net.close() sur une partie en
				# train de démarrer.
				_stop_outgoing_invite_poll()
				_pending_outgoing_invite_id = 0
			_:
				pass  # "pending" : on repollera au prochain tick
	)

func _stop_outgoing_invite_poll() -> void:
	if _outgoing_invite_poll_timer != null:
		_outgoing_invite_poll_timer.stop()
		_outgoing_invite_poll_timer.queue_free()
		_outgoing_invite_poll_timer = null

func _reset_friend_invite_state() -> void:
	_stop_outgoing_invite_poll()
	_pending_outgoing_invite_id = 0
	_pending_outgoing_recipient_name = ""
	_set_search_mode("")
	_set_loading(false)
	_show_search_banner(false)
	_set_status("")

# ─── Popup d'invitation reçue (voir InviteDeckChoiceOverlay dans la scène) ────

# Pollé en continu tant qu'aucune recherche/connexion n'est en cours et que le
# joueur n'est pas déjà en bataille (voir PresenceService.in_battle) — une
# invitation reçue pendant une partie en cours ne doit jamais interrompre le
# joueur avec une popup.
func _poll_incoming_invites() -> void:
	if not BackendClient.is_authenticated():
		return
	if PresenceService.in_battle:
		return
	if _pending_invite_lobby_id != 0 or _search_mode != "" or _loading:
		return
	BackendClient.get_incoming_invites(func(success: bool, invites: Array) -> void:
		if not success or invites.is_empty():
			return
		if _pending_invite_lobby_id != 0 or _search_mode != "" or _loading:
			return  # état changé pendant l'aller-retour réseau
		var row: Dictionary = invites[0]
		_pending_backend_invite_id = int(row.get("id", 0))
		_pending_invite_lobby_id = int(row.get("steam_lobby_id", 0))
		_pending_invite_friend_name = str(row.get("sender_username", ""))
		_show_invite_deck_popup()
	)

# ─── Matchmaking classé ───────────────────────────────────────────────────────

func start_ranked() -> void:
	if _search_mode != "" or _loading:
		return
	if not BackendClient.is_authenticated():
		_flash_banner("NET_RANKED_UNAVAILABLE")
		return
	_queue_mode = ""  # posé à "ranked" une fois le ticket obtenu, voir _queue_join_and_poll
	_queue_cancel_pending = false
	_set_search_mode("ranked")
	_show_search_banner(true)
	_set_loading(true)
	_set_status("NET_RANKED_QUEUEING")
	_queue_join_and_poll("ranked")

# Rejoint la file backend pour `mode` ("ranked" ou "normal", voir start_ranked/
# start_normal — mêmes hypothèses des deux côtés : _search_mode déjà posé au
# mode courant, bandeau déjà affiché). Partagé entre les deux : appariement
# par MMR public (Classé) ou MMR caché (Normal), identique côté serveur, voir
# matchmakingModel.joinQueue côté wyrdane-backend.
func _queue_join_and_poll(mode: String) -> void:
	BackendClient.queue_join(mode, func(success: bool, data: Dictionary) -> void:
		# Annulé pendant l'aller-retour réseau (voir _cancel_queue_search) :
		# l'UI est déjà revenue au repos, il ne reste qu'à ne pas laisser le
		# ticket vivre côté backend si jamais il a été créé entre-temps.
		if _queue_cancel_pending:
			_queue_cancel_pending = false
			if success and str(data.get("ticket_id", "")) != "":
				BackendClient.queue_cancel(str(data.get("ticket_id", "")))
			return
		if not success or str(data.get("ticket_id", "")) == "":
			if mode == "normal":
				# Repli silencieux (voir start_normal) : le backend n'a pas pu
				# être joint, mais Normal doit rester jouable sans lui.
				_reset_queue_ui()
				_start_direct_quick_match()
			else:
				_flash_banner("NET_RANKED_UNAVAILABLE")
				_reset_queue_ui()
			return
		_queue_ticket_id = str(data.get("ticket_id", ""))
		_queue_mode = mode
		_queue_elapsed = 0.0
		_queue_poll_timer = Timer.new()
		_queue_poll_timer.wait_time = RANKED_POLL_INTERVAL
		_queue_poll_timer.timeout.connect(_poll_queue)
		add_child(_queue_poll_timer)
		_queue_poll_timer.start()
	)

# Annulation générique de la recherche en cours, quel que soit le mode
# (Normal/Classé/Ami) — bouton "✕" du bandeau (voir _search_mode). "normal" et
# "ranked" partagent le même chemin depuis que Normal tente aussi la file
# backend (MMR caché, voir start_normal) : _cancel_queue_search annule le
# ticket s'il y en a un, _net.close() est de toute façon nécessaire dans les
# deux cas pour couper une éventuelle session Steam déjà ouverte (Normal a pu
# retomber sur _start_direct_quick_match avant que le joueur n'annule).
func _on_banner_cancel_pressed() -> void:
	match _search_mode:
		"ranked", "normal":
			# manual: false — on ferme le bandeau immédiatement (voir plus bas)
			# plutôt que de laisser traîner le message "Recherche annulée"
			# pendant BANNER_MESSAGE_DURATION : le joueur vient de cliquer sur
			# Annuler, inutile de le lui confirmer par un texte qui reste seul
			# affiché (mode/minuteur déjà masqués à cet instant) — ça se voyait
			# comme un bandeau vide pendant quelques secondes.
			_cancel_queue_search(false)
			_quick_matching = false
			_queue_matched_join_pending = false
			_auto_join_retries = 0  # annulation joueur : la prochaine recherche repart à neuf
			_stop_host_peer_wait_timer()
			_net.close()
			_show_search_banner(false)
			_set_status("")
		"invite":
			_quick_matching = false
			# L'ami invité doit être prévenu tout de suite plutôt que de laisser
			# son popup/poll croire l'invitation encore valide jusqu'à son
			# expiration (45s côté backend) — voir BackendClient.cancel_game_invite.
			if _pending_outgoing_invite_id != 0:
				BackendClient.cancel_game_invite(_pending_outgoing_invite_id)
			_net.close()
			_reset_friend_invite_state()
		_:
			# Pas de recherche active : le bandeau n'affiche qu'un message
			# (erreur/annulation) déjà en train de s'auto-fermer — on le
			# ferme juste immédiatement.
			_show_search_banner(false)

# manual : true si annulé par le joueur (statut dédié), false si on abandonne
# silencieusement (ex: coupure réseau déjà annoncée par ailleurs). Le message
# de confirmation ("Recherche annulée") n'a de sens qu'en Classé — Normal n'a
# jamais eu de confirmation de ce type (voir l'ancien comportement direct).
func _cancel_queue_search(manual: bool) -> void:
	var was_ranked := _search_mode == "ranked"
	if _queue_ticket_id == "":
		# queue_join n'a pas encore répondu (voir start_ranked/start_normal) :
		# impossible d'annuler un ticket qui n'existe pas encore côté backend,
		# mais il faut quand même libérer l'UI tout de suite — sinon
		# _search_mode/_loading restent bloqués pour le reste de la session,
		# empêchant toute recherche future (Normal/Classé/Ami).
		# _queue_cancel_pending fera annuler le ticket dès qu'il arrivera.
		if _search_mode == "ranked" or _search_mode == "normal":
			_queue_cancel_pending = true
			_reset_queue_ui()
			if manual and was_ranked:
				_flash_banner("NET_RANKED_CANCELLED")
		return
	BackendClient.queue_cancel(_queue_ticket_id)
	_reset_queue_ui()
	if manual and was_ranked:
		_flash_banner("NET_RANKED_CANCELLED")

func _reset_queue_ui() -> void:
	if _queue_poll_timer != null:
		_queue_poll_timer.stop()
		_queue_poll_timer.queue_free()
		_queue_poll_timer = null
	_queue_ticket_id = ""
	_queue_role = ""
	_queue_match_id = ""
	_queue_match_session_token = ""
	_set_search_mode("")
	_set_loading(false)

# Coupe tout ce qui, dans le matchmaking automatique, pourrait se réveiller plus
# tard et détruire le lobby d'une invitation en cours (voir invite_friend /
# _on_invite_join_pressed). Volontairement distinct de _reset_queue_ui : ne
# touche NI à _search_mode NI au spinner (l'appelant est en train de passer en
# mode "invite", pas de revenir au repos) et ne ferme jamais _net — le lobby
# éventuellement déjà hébergé est justement celui qu'il faut préserver.
func _abandon_queue_for_invite() -> void:
	if _queue_ticket_id != "":
		BackendClient.queue_cancel(_queue_ticket_id)
		_queue_ticket_id = ""
	else:
		# queue_join peut être en vol sans ticket connu de ce côté : son callback
		# annulera le ticket dès son arrivée (voir _queue_join_and_poll). Un
		# drapeau laissé à true sans ticket à venir est inoffensif — start_normal
		# et start_ranked le remettent tous les deux à false.
		_queue_cancel_pending = true
	if _queue_poll_timer != null:
		_queue_poll_timer.stop()
		_queue_poll_timer.queue_free()
		_queue_poll_timer = null
	_stop_host_peer_wait_timer()
	_queue_mode = ""
	_queue_role = ""
	_queue_match_id = ""
	_queue_match_session_token = ""
	_queue_matched_join_pending = false
	_quick_matching = false
	_auto_join_retries = 0

func _poll_queue() -> void:
	# Une invitation a pris la main depuis (voir _abandon_queue_for_invite) : ce
	# tick est un résidu et ne doit surtout pas relancer quoi que ce soit, sous
	# peine de détruire le lobby de l'invitation en cours.
	if _search_mode == "invite":
		return
	_queue_elapsed += RANKED_POLL_INTERVAL
	var is_normal := _search_mode == "normal"
	var timeout := NORMAL_QUEUE_TIMEOUT if is_normal else RANKED_QUEUE_TIMEOUT
	# Déjà apparié (_queue_role rempli) mais le lobby de l'hôte n'est pas encore
	# publié : le délai COURT de la file ne s'applique plus. L'appliquer ici
	# lâchait un adversaire qui était justement en train de créer son lobby — les
	# deux repartaient alors chacun de leur côté sans jamais retomber en phase.
	# On ne poll pas indéfiniment pour autant : on accorde à l'hôte le même temps
	# que son propre filet de sécurité (voir HOST_PEER_WAIT_TIMEOUT), jamais
	# moins que le délai nominal du mode.
	if _queue_role != "":
		timeout = maxf(timeout, HOST_PEER_WAIT_TIMEOUT)
	if _queue_elapsed >= timeout:
		if _queue_ticket_id != "":
			BackendClient.queue_cancel(_queue_ticket_id)
		_reset_queue_ui()
		if is_normal:
			# Repli silencieux (voir start_normal) plutôt qu'un abandon avec
			# message d'erreur : Normal reste jouable même sans appariement
			# par niveau.
			_start_direct_quick_match()
		else:
			_flash_banner("NET_RANKED_TIMEOUT")
		return
	var ticket_id := _queue_ticket_id
	BackendClient.queue_status(ticket_id, func(success: bool, data: Dictionary) -> void:
		# La recherche a pu être annulée pendant l'aller-retour réseau.
		if ticket_id != _queue_ticket_id or not success:
			return
		match str(data.get("status", "waiting")):
			"matched":
				_on_queue_matched(data)
			"cancelled", "expired":
				_reset_queue_ui()
				if is_normal:
					_start_direct_quick_match()
				else:
					_flash_banner("NET_RANKED_TIMEOUT")
			_:
				pass  # "waiting" : rien à faire, on repollera au prochain tick
	)

func _on_queue_matched(data: Dictionary) -> void:
	# Réponse de file arrivée après qu'une invitation a pris la main : l'ignorer,
	# sinon le host_game_with/join_game_with ci-dessous quitterait le lobby de
	# l'invitation (voir _abandon_queue_for_invite).
	if _search_mode == "invite":
		return
	_queue_role = str(data.get("role", ""))
	_queue_match_id = str(data.get("match_id", ""))
	_queue_match_session_token = str(data.get("match_session_token", ""))
	if _queue_role == "host":
		if _queue_poll_timer != null:
			_queue_poll_timer.stop()
			_queue_poll_timer.queue_free()
			_queue_poll_timer = null
		_quick_matching = false
		_net.session_ready.connect(_on_queue_lobby_ready, CONNECT_ONE_SHOT)
		var err := _net.host_game_with(TransportFactory.Backend.STEAM)
		if err == OK:
			_set_status("NET_RANKED_MATCHED")
			_start_host_peer_wait_timer()
		else:
			if _net.session_ready.is_connected(_on_queue_lobby_ready):
				_net.session_ready.disconnect(_on_queue_lobby_ready)
			_cancel_queue_search(false)
			_flash_banner("NET_STEAM_UNAVAILABLE")
		return
	# Invité : le lobby n'est disponible qu'une fois l'hôte l'ayant rapporté
	# (queue_report_lobby) — on continue de repoller jusqu'à ce qu'il apparaisse.
	var lobby_id := int(data.get("steam_lobby_id", 0))
	if lobby_id == 0:
		return
	if _queue_poll_timer != null:
		_queue_poll_timer.stop()
		_queue_poll_timer.queue_free()
		_queue_poll_timer = null
	_quick_matching = false
	_queue_ticket_id = ""  # déjà apparié, plus de sens à repoller/annuler ce ticket
	_set_status("NET_RANKED_MATCHED")
	_queue_matched_join_pending = true
	var err := _net.join_game_with(TransportFactory.Backend.STEAM, {"lobby_id": lobby_id})
	if err != OK:
		_queue_matched_join_pending = false
		_reset_queue_ui()
		_flash_banner("NET_STEAM_UNAVAILABLE")

# Hôte classé uniquement : le lobby vient d'être créé, on transmet son id au
# backend pour que l'invité puisse le rejoindre directement (voir
# _on_queue_matched, branche invité).
func _on_queue_lobby_ready(session_id: int) -> void:
	if _queue_ticket_id == "":
		return
	var ticket_id := _queue_ticket_id
	_queue_ticket_id = ""  # le rôle d'hôte n'a plus besoin de repoller/annuler
	_report_queue_lobby(ticket_id, session_id, 1)

func _report_queue_lobby(ticket_id: String, session_id: int, attempt: int) -> void:
	BackendClient.queue_report_lobby(ticket_id, session_id, func(code: int, _parsed: Variant) -> void:
		if code == 200 or code ==204:
			return
		push_warning("[Ranked] queue_report_lobby a échoué (code %d, tentative %d/%d, ticket %s)" \
			% [code, attempt, RANKED_REPORT_LOBBY_MAX_ATTEMPTS, ticket_id])
		if attempt < RANKED_REPORT_LOBBY_MAX_ATTEMPTS:
			await get_tree().create_timer(RANKED_REPORT_LOBBY_RETRY_DELAY).timeout
			_report_queue_lobby(ticket_id, session_id, attempt + 1)
		else:
			# L'invité ne recevra jamais ce lobby : inutile de laisser l'hôte
			# héberger dans le vide jusqu'à ce que l'invité expire de son côté
			# (jusqu'à 3 min) — on referme et on prévient tout de suite.
			_net.close()
			_reset_queue_ui()
			_flash_banner("NET_RANKED_LOBBY_REPORT_FAILED")
	)

func _start_host_peer_wait_timer() -> void:
	_stop_host_peer_wait_timer()
	_host_peer_wait_timer = Timer.new()
	_host_peer_wait_timer.one_shot = true
	_host_peer_wait_timer.timeout.connect(_on_host_peer_wait_timeout)
	add_child(_host_peer_wait_timer)
	_host_peer_wait_timer.start(HOST_PEER_WAIT_TIMEOUT)

func _stop_host_peer_wait_timer() -> void:
	if _host_peer_wait_timer != null:
		_host_peer_wait_timer.stop()
		_host_peer_wait_timer.queue_free()
		_host_peer_wait_timer = null

# Aucun pair réel n'est arrivé dans le lobby avant HOST_PEER_WAIT_TIMEOUT (voir
# la constante) : plutôt que de laisser l'hôte planté indéfiniment, on ferme
# ce lobby et on relance une recherche dans le même mode ("normal"/"ranked",
# voir _queue_mode). L'invité qui a échoué de son côté (voir
# _queue_matched_join_pending) a de toute façon déjà relancé la sienne — les
# deux se re-matcheront naturellement au prochain appariement compatible.
func _on_host_peer_wait_timeout() -> void:
	_stop_host_peer_wait_timer()
	# Une invitation est passée devant : son lobby doit survivre (un ami peut
	# accepter longtemps après l'envoi), on ne referme surtout rien ici.
	if _search_mode == "invite":
		return
	# Plafond atteint : on arrête de relancer dans le vide et on le dit, plutôt
	# que d'entretenir la boucle où chacun détruit le lobby de l'autre (voir
	# MAX_AUTO_JOIN_RETRIES).
	if _auto_join_retries >= MAX_AUTO_JOIN_RETRIES:
		_auto_join_retries = 0
		_net.close()
		_reset_queue_ui()
		_show_search_banner(false)
		_flash_banner("NET_STEAM_JOIN_RETRY_FAILED")
		return
	_auto_join_retries += 1
	var mode_to_retry := _queue_mode
	_net.close()
	_reset_queue_ui()
	if mode_to_retry == "ranked":
		start_ranked()
	else:
		start_normal()

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

# Le pair distant est identifié (nom Steam connu) avant même que la connexion
# P2P soit établie (voir NetTransport.peer_identified) — en mode invitation
# uniquement, où le nom de l'ami a un sens : pour Normal/Classé l'adversaire
# est un inconnu apparié au hasard, afficher son nom n'apporterait rien.
func _on_peer_identified() -> void:
	if _search_mode != "invite":
		return
	var peer_name := _net.remote_display_name()
	if peer_name != "":
		_set_status("NET_INVITE_PEER_PREPARING_FORMAT", peer_name)
	else:
		_set_status("NET_INVITE_PEER_PREPARING_UNKNOWN")

func _on_peer_connected() -> void:
	_stop_host_peer_wait_timer()
	_queue_matched_join_pending = false
	_auto_join_retries = 0  # série de relances close : la connexion a abouti
	# L'invitation a rempli son rôle (l'ami est là) : couper son poll MAINTENANT.
	# Sans ça, son délai d'abandon (OUTGOING_INVITE_TIMEOUT) finissait par
	# expirer en pleine partie et appelait _net.close() — ce qui quitte le lobby
	# et coupe la connexion d'un match déjà lancé (voir
	# NetworkManager._setup_transport).
	_stop_outgoing_invite_poll()
	_pending_outgoing_invite_id = 0
	_pending_outgoing_recipient_name = ""
	# Le nom (mode invitation) doit être capturé AVANT de réinitialiser
	# _search_mode ci-dessous : _run_match_ready_countdown en a besoin pour
	# afficher "<ami> est prêt" plutôt que le générique "Partie trouvée".
	var ready_peer_name := _net.remote_display_name() if _search_mode == "invite" else ""
	_quick_matching = false
	_set_search_mode("")
	# La recherche est finie mais la partie ne démarre pas tout de suite : le
	# bandeau clignote et décompte (5/4/3/2/1) quelques secondes avant de
	# basculer sur l'écran de chargement plein écran, pour que le joueur —
	# peut-être ailleurs dans le menu — voie qu'une partie va commencer plutôt
	# que de se faire happer sans prévenir (voir _run_match_ready_countdown).
	_connect_token += 1
	var token := _connect_token
	await _run_match_ready_countdown(token, ready_peer_name)
	if token != _connect_token:
		return  # déconnecté entre-temps : cette tentative est périmée
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
	_stop_host_peer_wait_timer()
	# Invalide un éventuel flash "adversaire trouvé" encore en attente (voir
	# _on_peer_connected) : une coupure pendant ces 5 secondes ne doit pas
	# quand même enchaîner sur l'écran de chargement plein écran.
	_connect_token += 1
	_stop_match_ready_flash()
	# Coupure pendant un handshake/synchronisation en cours : évite de laisser
	# une instance abandonnée abonnée à _net.command_received (voir
	# _cleanup_connection_flow) avant une éventuelle tentative suivante.
	_cleanup_connection_flow()
	_show_match_found_overlay(false)
	match reason:
		"steam_same_account":
			_quick_matching = false
			_reset_queue_ui()
			_show_search_banner(false)
			_flash_banner("NET_STEAM_SAME_ACCOUNT")
		"steam_no_lobby_found":
			if _quick_matching:
				_set_status("NET_STEAM_NO_LOBBY_HOSTING")
				_start_quick_match_host()
			else:
				_set_search_mode("")
				_reset_queue_ui()
				_show_search_banner(false)
				_flash_banner("NET_STEAM_NO_LOBBY")
		"steam_lobby_join_failed":
			# Le lobby rapporté par l'hôte (voir _on_queue_matched, branche
			# invité) n'existe déjà plus côté Steam au moment du join — le plus
			# souvent un hôte qui a relancé sa propre recherche entre-temps
			# (voir HOST_PEER_WAIT_TIMEOUT) plutôt qu'une vraie coupure. Retenté
			# automatiquement dans le même mode au lieu de planter le joueur sur
			# un message "adversaire déconnecté" qui l'obligerait à recliquer
			# lui-même — mais UNIQUEMENT pour ce flux (jamais pour l'échec d'un
			# join sur une invitation Steam explicite, voir
			# _queue_matched_join_pending).
			if _queue_matched_join_pending:
				_queue_matched_join_pending = false
				# Plafonné : sans ça, les deux joueurs se relançaient sans fin,
				# chaque relance quittant le lobby en cours (voir
				# NetworkManager._setup_transport) et causant l'échec suivant —
				# ils ne se rejoignaient jamais (voir MAX_AUTO_JOIN_RETRIES).
				if _auto_join_retries >= MAX_AUTO_JOIN_RETRIES:
					_auto_join_retries = 0
					_reset_queue_ui()
					_show_search_banner(false)
					_flash_banner("NET_STEAM_JOIN_RETRY_FAILED")
					return
				_auto_join_retries += 1
				var mode_to_retry := _queue_mode
				_reset_queue_ui()
				if mode_to_retry == "ranked":
					start_ranked()
				else:
					start_normal()
			else:
				# Échec d'entrée sur une invitation explicite : "connexion
				# interrompue" est trompeur (rien n'a jamais été connecté) et ne
				# dit pas au joueur quoi faire. Le lobby de l'ami n'existe plus —
				# il faut lui redemander une invitation.
				var was_invite := _search_mode == "invite"
				_quick_matching = false
				_set_search_mode("")
				_reset_queue_ui()
				_show_search_banner(false)
				_flash_banner("NET_STEAM_INVITE_LOBBY_GONE" if was_invite else "NET_STEAM_DISCONNECTED")
		_:
			_quick_matching = false
			_queue_matched_join_pending = false
			_set_search_mode("")
			_reset_queue_ui()
			_show_search_banner(false)
			print("[MatchmakingOverlay] Pair déconnecté (%s)" % [reason])
			_flash_banner("NET_STEAM_DISCONNECTED")

# Partie rapide sans adversaire trouvé : on héberge à la place plutôt que de
# laisser le joueur relancer manuellement (voir start_normal).
func _start_quick_match_host() -> void:
	_quick_matching = false
	_set_search_mode("normal")
	var err := _net.host_game_with(TransportFactory.Backend.STEAM)
	if err == OK:
		_set_loading(true)
		_show_search_banner(true)
		_set_status("NET_STEAM_HOSTING")
	else:
		_set_search_mode("")
		_show_search_banner(false)
		_flash_banner("NET_STEAM_UNAVAILABLE")

# Invitation Steam acceptée (overlay ami / lien « Rejoindre la partie ») —
# peu importe l'écran sur lequel le joueur se trouve, y compris s'il n'est
# jamais passé par DeckSelectView (invitation acceptée juste après le
# lancement du jeu). On ne rejoint PAS le lobby tout de suite : le popup de
# choix de deck (_show_invite_deck_popup) est le seul moment où ce joueur
# choisit son deck pour ce match, _on_invite_join_pressed rejoint ensuite
# réellement le lobby une fois un deck confirmé.
func _on_steam_join_requested(lobby_id: int, friend_id: int = 0) -> void:
	_pending_invite_lobby_id = lobby_id
	_pending_invite_friend_name = SteamService.friend_persona_name(friend_id)
	_pending_backend_invite_id = 0  # invitation Steam native, pas d'id backend à répondre
	_show_invite_deck_popup()

func _show_invite_deck_popup() -> void:
	_pending_invite_deck_index = -1
	invite_join_button.disabled = true
	_refresh_invite_from_label()
	_refresh_invite_deck_list()
	invite_deck_overlay.visible = true

func _refresh_invite_from_label() -> void:
	if _pending_invite_friend_name != "":
		invite_from_label.text = SettingsManager.t("NET_INVITE_FROM_FORMAT") % _pending_invite_friend_name
	else:
		invite_from_label.text = SettingsManager.t("NET_INVITE_FROM_UNKNOWN")

# Liste simplifiée (choix uniquement) des decks du joueur — même principe que
# MainMenu._refresh_play_deck_list/_make_play_deck_row, dupliqué en plus
# léger ici (pas de bandeau de race, pas d'édition) : ce popup n'a besoin que
# de choisir un deck jouable, pas de le prévisualiser en détail.
func _refresh_invite_deck_list() -> void:
	for child in invite_decks_container.get_children():
		child.queue_free()
	if DeckManager.decks.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = SettingsManager.t("decklist.empty")
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		empty_lbl.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 0.5))
		empty_lbl.add_theme_font_size_override("font_size", Typography.BODY)
		invite_decks_container.add_child(empty_lbl)
		return
	for i in range(DeckManager.decks.size()):
		invite_decks_container.add_child(_make_invite_deck_row(DeckManager.decks[i], i))

func _make_invite_deck_row(deck: DeckData, index: int) -> Control:
	var is_selected := index == _pending_invite_deck_index

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.10, 0.08, 1)
	bg.border_color = Color(0.78, 0.58, 0.10, 0.9) if is_selected else Color(0.30, 0.24, 0.10, 0.5)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(5)
	bg.content_margin_left   = 12
	bg.content_margin_right  = 10
	bg.content_margin_top    = 8
	bg.content_margin_bottom = 8

	var bg_hover := bg.duplicate() as StyleBoxFlat
	bg_hover.bg_color     = Color(0.18, 0.15, 0.10, 1)
	bg_hover.border_color = Color(0.78, 0.58, 0.10, 1)

	var bg_disabled := bg.duplicate() as StyleBoxFlat
	bg_disabled.bg_color = Color(0.08, 0.07, 0.055, 0.7)

	var button := Button.new()
	button.flat = true
	button.custom_minimum_size = Vector2(0, 44)
	button.add_theme_stylebox_override("normal", bg)
	button.add_theme_stylebox_override("hover", bg_hover)
	button.add_theme_stylebox_override("pressed", bg_hover)
	button.add_theme_stylebox_override("disabled", bg_disabled)
	button.pressed.connect(_on_invite_deck_selected.bind(index))
	var warnings := DeckManager.playability_warnings(deck)
	if not warnings.is_empty():
		button.tooltip_text = "\n".join(warnings)
		button.disabled = true

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(row)

	var select_indicator := Label.new()
	select_indicator.text = "●" if is_selected else "○"
	select_indicator.custom_minimum_size = Vector2(24, 0)
	select_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	select_indicator.add_theme_font_size_override("font_size", Typography.SECTION)
	select_indicator.add_theme_color_override("font_color",
		Color(0.94, 0.75, 0.25, 1) if is_selected else Color(0.91, 0.835, 0.639, 0.35))
	row.add_child(select_indicator)

	var name_lbl := Label.new()
	name_lbl.text = SettingsManager.t(deck.name)
	name_lbl.clip_text = true
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", Typography.BODY)
	name_lbl.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	row.add_child(name_lbl)

	var count_lbl := Label.new()
	count_lbl.text = "%d/%d" % [deck.size(), DeckManager.MIN_TOTAL_CARDS]
	count_lbl.custom_minimum_size = Vector2(44, 0)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.add_theme_font_size_override("font_size", Typography.MICRO)
	count_lbl.add_theme_color_override("font_color",
		Color(0.5, 0.9, 0.5, 1) if deck.size() >= DeckManager.MIN_TOTAL_CARDS else Color(1, 0.4, 0.4, 1))
	row.add_child(count_lbl)

	return button

func _on_invite_deck_selected(index: int) -> void:
	_pending_invite_deck_index = index
	invite_join_button.disabled = false
	_refresh_invite_deck_list()

# Refuse l'invitation : ferme simplement le popup sans jamais rejoindre le
# lobby de l'hôte (celui-ci reste en attente, voir NET_STEAM_HOSTING côté hôte).
# Prévient le backend si l'invitation vient d'un ami Wyrdane (voir
# _poll_incoming_invites) pour que l'expéditeur soit notifié tout de suite
# plutôt que d'attendre son propre timeout.
func _on_invite_decline_pressed() -> void:
	if _pending_backend_invite_id != 0:
		BackendClient.decline_game_invite(_pending_backend_invite_id)
	invite_deck_overlay.visible = false
	_pending_invite_lobby_id = 0
	_pending_invite_deck_index = -1
	_pending_backend_invite_id = 0

func _on_invite_join_pressed() -> void:
	if _pending_invite_deck_index < 0:
		return
	DeckManager.set_active_deck(_pending_invite_deck_index)
	var lobby_id := _pending_invite_lobby_id
	var backend_invite_id := _pending_backend_invite_id
	invite_deck_overlay.visible = false
	_pending_invite_lobby_id = 0
	_pending_invite_deck_index = -1
	_pending_backend_invite_id = 0
	if backend_invite_id != 0:
		BackendClient.accept_game_invite(backend_invite_id, func(_success: bool, _lobby_id: int) -> void: pass)
	_quick_matching = false
	# Même précaution que côté hôte (voir invite_friend) : couper tout résidu de
	# matchmaking automatique AVANT de rejoindre, sinon un poll/appariement
	# encore en vol pouvait rappeler host_game_with/join_game_with et défaire la
	# connexion à l'ami à peine établie.
	_abandon_queue_for_invite()
	_set_search_mode("invite")
	_set_status("NET_STEAM_INVITE_RECEIVED")
	var err := _net.join_game_with(TransportFactory.Backend.STEAM, {"lobby_id": lobby_id})
	if err == OK:
		_set_loading(true)
		_show_search_banner(true)
		_set_status("NET_STEAM_SEARCHING")
	else:
		_set_search_mode("")
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
	# Ce flag pilote le mode envoyé à report_ranked_match (voir BackendClient/
	# rankedController côté wyrdane-backend) : seul un vrai appariement CLASSÉ
	# fait gagner/perdre des points de MMR public — Normal, même apparié via la
	# même file d'attente backend (MMR caché, voir start_normal), ne doit
	# jamais être compté comme classé ici. _queue_role, lui, est désormais
	# partagé par les deux modes (host/guest s'applique aussi bien à un
	# appariement Normal) — c'est _queue_mode qui distingue les deux, posé à
	# "ranked"/"normal" par _queue_join_and_poll une fois le ticket obtenu,
	# jamais à autre chose sur un repli direct (Steam sans backend).
	setup["is_ranked"] = _queue_mode == "ranked"
	# Pour un match apparié via la file backend (classé OU Normal caché), le
	# matchId qui fait foi côté rapport de fin de partie devient celui émis par
	# le backend à l'appariement (preuve qu'un vrai appariement a eu lieu, voir
	# TODO.md P9) plutôt que celui dérivé localement par NetHandshake
	# (client_match_id, toujours présent — sert de repli pour un Normal en
	# repli direct/une invitation d'ami, qui n'ont pas d'appariement backend).
	# _queue_match_id n'est non-vide qu'après un appariement via la file.
	if _queue_match_id != "":
		setup["client_match_id"] = _queue_match_id
	setup["match_session_token"] = _queue_match_session_token
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
	# La connexion/le handshake sont terminés ici (bataille sur le point de
	# démarrer) : sans ce reset, _loading reste bloqué à true pour le reste de
	# la session (cet autoload survit à tout change_scene_to_file) et
	# start_normal/start_ranked/invite_friend refusent silencieusement de
	# relancer une recherche après cette partie (concède ou fin normale).
	_set_loading(false)
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
