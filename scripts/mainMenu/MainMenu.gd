# MainMenu.gd
extends Control

const BATTLE_SCENE := "res://scenes/battle/Battle.tscn"
const NET_LOBBY_SCENE := "res://scenes/net/NetLobby.tscn"
const ARENA_SCENE := "res://scenes/arena/ArenaBattle.tscn"
const NEWS_DIR := "res://resources/news/"
const NEWS_FEED_URL := "https://wyrdane.com/feed.json"
const DISCORD_URL := "https://discord.gg/qdBEjrsdEw"
const WEBSITE_URL := "https://wyrdane.com"
const WEBSITE_NEWS_PATH := "/news"
const WEBSITE_DEVLOG_PATH := "/dev-log"
const DECK_BUILDER_SCENE := "res://scenes/deck/DeckBuilder.tscn"

enum PlayMode { SOLO, MULTI }
enum NavView { MAIN, MODE_SELECT, DECK_SELECT }
enum InfoView { NEWS, DECK_COMPOSITION, PROFILE, CREDITS, SETTINGS, DECKS_MANAGE, SHOP, REPORT, QUESTS }

# Couleur d'accent affichée en bandeau à gauche de chaque ligne de deck, selon
# la race dominante du deck — même repère visuel que DeckList._dominant_race_color.
const RACE_ACCENTS := {
	Race.Type.UNDEAD: Color(0.35, 0.62, 0.32, 1),
	Race.Type.HUMAN:  Color(0.85, 0.68, 0.30, 1),
	Race.Type.DEMON:  Color(0.78, 0.22, 0.25, 1),
	Race.Type.ELF:    Color(0.30, 0.65, 0.55, 1),
	Race.Type.DWARF:  Color(0.62, 0.42, 0.24, 1),
}
const NEUTRAL_ACCENT := Color(0.4, 0.35, 0.25, 1)

# Aperçu de carte dans la vue "Composition du deck" (voir DeckCompositionPanel
# pour la courbe de mana/répartition affichée à côté).
# Taille agrandie de x1.2 par rapport à la taille "carte de base" (180x270).
const DECK_COMP_PREVIEW_SIZE := Vector2(216, 324)
# Taille native de Card.tscn (voir DeckBuilder.CARD_BASE_SIZE) : la carte de
# preview garde cette taille réelle et n'est réduite que visuellement via
# `scale`, car plusieurs de ses enfants (labels, icônes) sont positionnés en
# offsets fixes calibrés pour cette taille — redimensionner `size` directement
# désaligne le contenu par rapport à la bordure.
const CARD_BASE_SIZE := Vector2(250, 375)
const DECK_COMP_PREVIEW_SCALE := DECK_COMP_PREVIEW_SIZE / CARD_BASE_SIZE

@onready var play_button:     Button = $NavPanel/NavMargin/NavStack/MainNavView/PlayButton
@onready var settings_button: Button = $NavPanel/NavMargin/NavStack/MainNavView/SettingsButton
@onready var report_button:  Button = $NavPanel/NavMargin/NavStack/MainNavView/ReportButton
@onready var credits_button:  Button = $NavPanel/NavMargin/NavStack/MainNavView/CreditsButton
@onready var quit_button:     Button = $NavPanel/NavMargin/NavStack/MainNavView/QuitButton
@onready var subtitle_label:  Label  = $SubtitleLabel

@onready var main_nav_view:   VBoxContainer = $NavPanel/NavMargin/NavStack/MainNavView
@onready var mode_select_view: VBoxContainer = $NavPanel/NavMargin/NavStack/ModeSelectView
@onready var mode_title_label: Label = $NavPanel/NavMargin/NavStack/ModeSelectView/ModeTitleLabel
@onready var solo_mode_button: Button = $NavPanel/NavMargin/NavStack/ModeSelectView/SoloModeButton
@onready var multi_mode_button: Button = $NavPanel/NavMargin/NavStack/ModeSelectView/MultiModeButton
@onready var arena_mode_button: Button = $NavPanel/NavMargin/NavStack/ModeSelectView/ArenaModeButton
@onready var mode_back_button: Button = $NavPanel/NavMargin/NavStack/ModeSelectView/ModeBackButton
@onready var deck_select_view: VBoxContainer = $NavPanel/NavMargin/NavStack/DeckSelectView
@onready var play_back_button: Button = $NavPanel/NavMargin/NavStack/DeckSelectView/DeckSelectHeader/PlayBackButton
@onready var deck_select_title_label: Label = $NavPanel/NavMargin/NavStack/DeckSelectView/DeckSelectHeader/DeckSelectTitleLabel
@onready var play_decks_container: VBoxContainer = $NavPanel/NavMargin/NavStack/DeckSelectView/PlayDeckScroll/PlayDecksContainer
@onready var launch_button: Button = $NavPanel/NavMargin/NavStack/DeckSelectView/LaunchButton

@onready var steam_profile:   Control = $PlayerStatusPanel/PlayerMargin/PlayerVBox/SteamProfile
@onready var steam_avatar:    TextureRect = $PlayerStatusPanel/PlayerMargin/PlayerVBox/SteamProfile/Avatar
@onready var steam_name_label: Label = $PlayerStatusPanel/PlayerMargin/PlayerVBox/SteamProfile/NameLabel
@onready var currency_label: Label = $PlayerStatusPanel/PlayerMargin/PlayerVBox/CurrencyLabel
@onready var rank_badge_label: Label = $PlayerStatusPanel/PlayerMargin/PlayerVBox/RankBadgeLabel
@onready var profile_button: Button = $PlayerStatusPanel/ProfileButton

@onready var discord_button: TextureButton = $FooterPanel/FooterMargin/FooterRow/DiscordButton
@onready var website_button: Button = $FooterPanel/FooterMargin/FooterRow/WebsiteButton
@onready var offline_banner: PanelContainer = $OfflineBanner
@onready var offline_banner_label: Label = $OfflineBanner/OfflineBannerMargin/OfflineBannerRow/OfflineBannerLabel
@onready var offline_banner_close: Button = $OfflineBanner/OfflineBannerMargin/OfflineBannerRow/OfflineBannerCloseButton

@onready var decks_button:    Button = $BottomCenterPanel/BottomCenterMargin/BottomCenterRow/DecksButton
@onready var packs_button:    Button = $BottomCenterPanel/BottomCenterMargin/BottomCenterRow/PacksButton
@onready var quests_button:   Button = $BottomCenterPanel/BottomCenterMargin/BottomCenterRow/QuestsButton
@onready var pack_shop:       Control = $PackShop

@onready var news_view:       VBoxContainer = $InfoPanel/InfoMargin/ViewsRoot/NewsView
@onready var news_title_label: Label = $InfoPanel/InfoMargin/ViewsRoot/NewsView/NewsTitleLabel
@onready var news_list_vbox: VBoxContainer = $InfoPanel/InfoMargin/ViewsRoot/NewsView/NewsScroll/NewsListVBox

@onready var deck_composition_view: VBoxContainer = $InfoPanel/InfoMargin/ViewsRoot/DeckCompositionView
@onready var deck_comp_title_label: Label = $InfoPanel/InfoMargin/ViewsRoot/DeckCompositionView/DeckCompTitleLabel
@onready var deck_comp_list_vbox: VBoxContainer = $InfoPanel/InfoMargin/ViewsRoot/DeckCompositionView/DeckCompBody/DeckCompLeftCol/DeckCompScroll/DeckCompListVBox
@onready var deck_comp_preview_card: Card = $InfoPanel/InfoMargin/ViewsRoot/DeckCompositionView/DeckCompBody/DeckCompRightCol/DeckCompPreviewBox/DeckCompPreviewHolder/DeckCompPreviewCard
@onready var deck_comp_preview_hint: Label = $InfoPanel/InfoMargin/ViewsRoot/DeckCompositionView/DeckCompBody/DeckCompRightCol/DeckCompPreviewBox/DeckCompPreviewHint
@onready var deck_comp_stats_panel: VBoxContainer = $InfoPanel/InfoMargin/ViewsRoot/DeckCompositionView/DeckCompBody/DeckCompLeftCol/DeckCompStatsScroll/DeckCompStatsPanel
@onready var edit_deck_button: Button = $InfoPanel/InfoMargin/ViewsRoot/DeckCompositionView/EditDeckButton

@onready var profile_view:    VBoxContainer = $InfoPanel/InfoMargin/ViewsRoot/ProfileView
@onready var profile_title_label: Label = $InfoPanel/InfoMargin/ViewsRoot/ProfileView/ProfileTitleLabel
@onready var profile_avatar:  TextureRect = $InfoPanel/InfoMargin/ViewsRoot/ProfileView/ProfileHeaderRow/ProfileAvatar
@onready var profile_name_label: Label = $InfoPanel/InfoMargin/ViewsRoot/ProfileView/ProfileHeaderRow/ProfileNameLabel
@onready var profile_match_stats_label: Label = $InfoPanel/InfoMargin/ViewsRoot/ProfileView/ProfileMatchStatsLabel
@onready var profile_member_since_label: Label = $InfoPanel/InfoMargin/ViewsRoot/ProfileView/ProfileMemberSinceLabel
@onready var profile_collection_label: Label = $InfoPanel/InfoMargin/ViewsRoot/ProfileView/ProfileCollectionLabel
@onready var profile_solo_stats_label: Label = $InfoPanel/InfoMargin/ViewsRoot/ProfileView/ProfileSoloStatsLabel
@onready var profile_ranked_stats_label: Label = $InfoPanel/InfoMargin/ViewsRoot/ProfileView/ProfileRankedStatsLabel
@onready var profile_rank_badge_label: Label = $InfoPanel/InfoMargin/ViewsRoot/ProfileView/ProfileRankBadgeLabel

@onready var credits_view:    VBoxContainer = $InfoPanel/InfoMargin/ViewsRoot/CreditsView
@onready var credits_main_sub: VBoxContainer = $InfoPanel/InfoMargin/ViewsRoot/CreditsView/CreditsStack/CreditsMainSub
@onready var credits_label:   Label  = $InfoPanel/InfoMargin/ViewsRoot/CreditsView/CreditsStack/CreditsMainSub/CreditsLabel
@onready var legal_button:    Button = $InfoPanel/InfoMargin/ViewsRoot/CreditsView/CreditsStack/CreditsMainSub/LegalButton
@onready var credits_legal_sub: VBoxContainer = $InfoPanel/InfoMargin/ViewsRoot/CreditsView/CreditsStack/CreditsLegalSub
@onready var close_legal:     Button = $InfoPanel/InfoMargin/ViewsRoot/CreditsView/CreditsStack/CreditsLegalSub/CloseLegalButton
@onready var legal_label:     Label  = $InfoPanel/InfoMargin/ViewsRoot/CreditsView/CreditsStack/CreditsLegalSub/LegalScroll/LegalLabel

@onready var report_view:     VBoxContainer = $InfoPanel/InfoMargin/ViewsRoot/ReportView
@onready var report_title_label: Label = $InfoPanel/InfoMargin/ViewsRoot/ReportView/ReportTitleLabel
@onready var report_category_label: Label = $InfoPanel/InfoMargin/ViewsRoot/ReportView/ReportCategoryLabel
@onready var report_category_select: OptionButton = $InfoPanel/InfoMargin/ViewsRoot/ReportView/ReportCategorySelect
@onready var report_desc_label: Label = $InfoPanel/InfoMargin/ViewsRoot/ReportView/ReportDescLabel
@onready var report_text_edit: TextEdit = $InfoPanel/InfoMargin/ViewsRoot/ReportView/ReportTextEdit
@onready var report_status_label: Label = $InfoPanel/InfoMargin/ViewsRoot/ReportView/ReportStatusLabel
@onready var report_submit_button: Button = $InfoPanel/InfoMargin/ViewsRoot/ReportView/ReportSubmitButton

# Non typé : typer en AudioSettingsMenu cassait _ready() si le type ne matchait pas
@onready var settings_menu = $InfoPanel/InfoMargin/ViewsRoot/SettingsMenu
@onready var deck_list:       DeckList = $InfoPanel/InfoMargin/ViewsRoot/DeckList

@onready var shop_view:       VBoxContainer = $InfoPanel/InfoMargin/ViewsRoot/ShopView
@onready var shop_title_label: Label = $InfoPanel/InfoMargin/ViewsRoot/ShopView/ShopTitleLabel
@onready var shop_desc_label: Label = $InfoPanel/InfoMargin/ViewsRoot/ShopView/ShopDescLabel
@onready var shop_open_button: Button = $InfoPanel/InfoMargin/ViewsRoot/ShopView/ShopOpenButton

@onready var quests_view:       VBoxContainer = $InfoPanel/InfoMargin/ViewsRoot/QuestsView
@onready var quests_title_label: Label = $InfoPanel/InfoMargin/ViewsRoot/QuestsView/QuestsTitleLabel
@onready var quests_status_label: Label = $InfoPanel/InfoMargin/ViewsRoot/QuestsView/QuestsStatusLabel
@onready var quests_list_vbox: VBoxContainer = $InfoPanel/InfoMargin/ViewsRoot/QuestsView/QuestsScroll/QuestsListVBox

@onready var login_reward_popup: Control = $LoginRewardPopup
@onready var login_reward_title_label: Label = $LoginRewardPopup/LoginRewardPanel/LoginRewardMargin/LoginRewardVBox/LoginRewardTitleLabel
@onready var login_reward_streak_label: Label = $LoginRewardPopup/LoginRewardPanel/LoginRewardMargin/LoginRewardVBox/LoginRewardStreakLabel
@onready var login_reward_amount_label: Label = $LoginRewardPopup/LoginRewardPanel/LoginRewardMargin/LoginRewardVBox/LoginRewardAmountLabel
@onready var login_reward_claim_button: Button = $LoginRewardPopup/LoginRewardPanel/LoginRewardMargin/LoginRewardVBox/LoginRewardClaimButton

var _local_news_entries: Array[NewsEntry] = []
var _remote_news_entries: Array = []
var _use_remote_news := false

var _current_info_view: InfoView = InfoView.NEWS
var _play_mode: int = PlayMode.SOLO
var _play_selected_deck_index: int = -1
var _composition_deck_index: int = -1

func _ready() -> void:
	AudioManager.play_menu_music()
	SettingsManager.language_changed.connect(func(_l): _retranslate())
	_retranslate()
	_apply_tutorial_lock()
	play_button.pressed.connect(_on_play)
	credits_button.pressed.connect(_on_credits)
	report_button.pressed.connect(_on_report_pressed)
	report_submit_button.pressed.connect(_on_report_submit_pressed)
	quit_button.pressed.connect(_on_quit)
	decks_button.pressed.connect(_on_decks_button_pressed)
	packs_button.pressed.connect(_on_packs_button_pressed)
	quests_button.pressed.connect(func(): _show_info_view(InfoView.QUESTS))
	login_reward_claim_button.pressed.connect(ProfilePanel.on_claim_login_reward_pressed.bind(self))
	discord_button.pressed.connect(_on_discord_pressed)
	website_button.pressed.connect(_on_website_pressed)
	profile_button.set_meta("no_click_sound", true)
	profile_button.pressed.connect(_on_profile_button_pressed)
	settings_button.pressed.connect(func(): _show_info_view(InfoView.SETTINGS))

	deck_comp_preview_card.set_non_interactive()
	# La carte reste à sa taille NATIVE (des enfants comme les labels sont
	# positionnés en offsets fixes calibrés pour elle — la redimensionner
	# directement désaligne le contenu par rapport à la bordure) et n'est
	# réduite que visuellement via `scale`. Elle est placée dans un Control
	# simple (DeckCompPreviewHolder), pas directement dans le CenterContainer :
	# un Container réinitialise `scale`/`rotation` de ses enfants directs à
	# chaque tri de layout (ex. au show()/hide()), ce qui annulerait le scale.
	# Le holder, lui, garde un gabarit figé (216x324) pour que le
	# CenterContainer autour ne recalcule jamais sa mise en page au survol.
	deck_comp_preview_card.custom_minimum_size = CARD_BASE_SIZE
	deck_comp_preview_card.scale = DECK_COMP_PREVIEW_SCALE
	deck_comp_preview_card.hide()

	solo_mode_button.pressed.connect(_on_solo_mode_selected)
	multi_mode_button.pressed.connect(_on_multi_mode_selected)
	arena_mode_button.pressed.connect(_on_arena_mode_selected)
	mode_back_button.pressed.connect(_on_mode_back_pressed)
	play_back_button.pressed.connect(_on_play_back_pressed)
	launch_button.pressed.connect(_on_launch_pressed)
	edit_deck_button.pressed.connect(DeckCompositionPanel.edit_deck.bind(self))
	shop_open_button.pressed.connect(_on_shop_open_pressed)
	_show_nav_view(NavView.MAIN)

	legal_button.pressed.connect(_on_legal_pressed)
	close_legal.set_meta("no_click_sound", true)
	close_legal.pressed.connect(func():
		AudioManager.play(AudioManager.CLOSE_MENU)
		credits_legal_sub.hide()
		credits_main_sub.show()
	)
	credits_legal_sub.hide()
	credits_main_sub.show()
	# Le bouton "Retour" interne à DeckList (voir DeckList._on_back) ne fait
	# que se cacher lui-même : on ramène en plus la fenêtre actualités sur
	# les actus, pour ne pas la laisser vide.
	deck_list.back_button.pressed.connect(func(): _show_info_view(InfoView.NEWS))
	# settings_menu peut légitimement être absent
	if not settings_menu:
		push_error("SettingsMenu introuvable !")
	else:
		# Même logique : les boutons Fermer/croix de SettingsMenu (voir
		# SettingsMenu.close) ne font que se cacher eux-mêmes.
		settings_menu.close_button.pressed.connect(func(): _show_info_view(InfoView.NEWS))
		settings_menu.close_x_button.pressed.connect(func(): _show_info_view(InfoView.NEWS))
	offline_banner.hide()
	offline_banner_close.set_meta("no_click_sound", true)
	offline_banner_close.pressed.connect(offline_banner.hide)
	BackendClient.login_failed.connect(func(reason: String):
		push_warning("Connexion backend échouée : %s" % reason)
		_show_offline_banner()
	)
	DeckManager.sync_failed.connect(func(reason: String):
		push_warning("Sync decks échouée : %s" % reason)
		_show_offline_banner()
	)
	_update_steam_profile()
	CurrencyManager.balance_changed.connect(func(new_balance: int):
		currency_label.text = SettingsManager.t("MENU_CURRENCY") % new_balance
	)
	currency_label.text = SettingsManager.t("MENU_CURRENCY") % CurrencyManager.balance
	SettingsManager.match_stats_changed.connect(func(wins: int, losses: int):
		profile_match_stats_label.text = SettingsManager.t("MENU_MATCH_STATS") % [wins, losses]
	)
	NewsPanel.load_news(self)
	_start_backend_sync()
	_show_info_view(InfoView.NEWS)
	_play_intro_animation()
	_wire_nav_hover_pop()

# Apparition en cascade des boutons de navigation (la barre de l'écran de
# chargement disparaît elle-même en fondu — voir
# LoadingScreen._fade_out_loading_ui). Rejoué aussi au retour d'une partie :
# transition douce dans tous les cas.
func _play_intro_animation() -> void:
	var nav_buttons := play_button.get_parent().get_children()
	for i in nav_buttons.size():
		var button := nav_buttons[i] as Control
		if button == null:
			continue
		button.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_interval(0.15 + i * 0.07)
		tween.tween_property(button, "modulate:a", 1.0, 0.3)

# Léger "pop" d'échelle au survol des boutons de nav, en plus du changement de
# couleur déjà géré par le thème/StyleBox — renforce le retour visuel sans
# toucher au style existant.
func _wire_nav_hover_pop() -> void:
	for child in play_button.get_parent().get_children():
		var button := child as BaseButton
		if button == null:
			continue
		button.mouse_entered.connect(func():
			if button.disabled:
				return
			button.pivot_offset = button.size / 2.0
			var tween := create_tween()
			tween.tween_property(button, "scale", Vector2(1.035, 1.035), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		)
		button.mouse_exited.connect(func():
			var tween := create_tween()
			tween.tween_property(button, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		)

# Fondu d'apparition pour les panneaux plein écran (Packs), qui portent déjà
# leur propre voile d'assombrissement en fond — un simple fondu du contrôle
# entier évite tout artefact de bord lié à un scale.
func _fade_in_overlay(panel: Control) -> void:
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# Affiche l'avatar + pseudo Steam du joueur local en bas à gauche du menu.
# Masqué entièrement si Steam est indisponible (même logique que le reste du
# jeu : pas de dépendance dure à GodotSteam).
func _update_steam_profile() -> void:
	if not SteamService.ensure_init():
		steam_profile.visible = false
		return

	var persona := SteamService.local_persona_name()
	if persona == "":
		steam_profile.visible = false
		return

	steam_name_label.text = persona
	var avatar := SteamService.local_avatar_texture()
	if avatar:
		steam_avatar.texture = avatar
	steam_profile.visible = true

# Tant que le tutoriel obligatoire n'est pas terminé (nouveau joueur) :
# multijoueur et deckbuilder restent verrouillés, un deck lui est fourni
# automatiquement à la place (voir Battle._start_tutorial).
func _apply_tutorial_lock() -> void:
	var locked: bool = not SettingsManager.tutorial_completed
	multi_mode_button.disabled = locked
	decks_button.disabled = locked
	packs_button.disabled = locked
	multi_mode_button.tooltip_text = SettingsManager.t("MENU_LOCKED_TUTORIAL") if locked else ""
	decks_button.tooltip_text = SettingsManager.t("MENU_LOCKED_TUTORIAL") if locked else ""
	packs_button.tooltip_text = SettingsManager.t("MENU_LOCKED_TUTORIAL") if locked else ""

# Enchaîne auth Steam -> mapping id carte backend -> chargement des decks
# en tâche de fond, sans bloquer l'affichage du menu. Si une étape échoue
# (Steam ou backend indisponible), les decks restent simplement vides — pas
# de mode hors-ligne (voir DeckManager). Le premier login + sync a normalement
# déjà eu lieu pendant l'écran de chargement (LoadingScreen._sync_backend) :
# ici on ne relance que les syncs (rafraîchit gold/collection/decks au retour
# d'une partie ou du tutoriel), le login n'est refait que s'il avait échoué.
func _start_backend_sync() -> void:
	if not SteamService.ensure_init():
		return
	if BackendClient.is_authenticated():
		_launch_backend_syncs()
		return
	BackendClient.login_succeeded.connect(func(_user):
		_launch_backend_syncs()
	, CONNECT_ONE_SHOT)
	BackendClient.login_failed.connect(func(reason: String):
		push_warning("Connexion backend échouée : %s" % reason)
	, CONNECT_ONE_SHOT)
	BackendClient.login_with_steam()

func _launch_backend_syncs() -> void:
	CardLibrary.sync_backend_catalog(func(success: bool):
		if success:
			DeckManager.sync_from_backend()
			CollectionManager.sync_from_backend()
			CurrencyManager.sync_from_backend()
	)
	ProfilePanel.fetch_rank_badge(self)
	ProfilePanel.fetch_login_reward_status(self)

# --- Fenêtre "Actualités" multi-vues -----------------------------------
# Le panneau de droite affiche une seule vue à la fois (Actualités par
# défaut, composition de deck pendant le flux Jouer, Profil/Crédits/
# Paramètres/Mes Decks/Boutique selon le bouton cliqué).

func _show_info_view(view: InfoView) -> void:
	_current_info_view = view
	news_view.visible = view == InfoView.NEWS
	deck_composition_view.visible = view == InfoView.DECK_COMPOSITION
	credits_view.visible = view == InfoView.CREDITS
	shop_view.visible = view == InfoView.SHOP
	profile_view.visible = view == InfoView.PROFILE
	settings_menu.visible = view == InfoView.SETTINGS
	deck_list.visible = view == InfoView.DECKS_MANAGE
	report_view.visible = view == InfoView.REPORT
	quests_view.visible = view == InfoView.QUESTS
	if view == InfoView.PROFILE:
		ProfilePanel.open(self)
	elif view == InfoView.SETTINGS:
		settings_menu.open()
	elif view == InfoView.DECKS_MANAGE:
		deck_list._refresh()
	elif view == InfoView.REPORT:
		_open_report_view()
	elif view == InfoView.QUESTS:
		QuestsPanel.open(self)

# --- Profil (vue "actualités", plus de popup séparée) --------------------

func _on_profile_button_pressed() -> void:
	_show_info_view(InfoView.PROFILE)

func _on_credits() -> void:
	credits_main_sub.show()
	credits_legal_sub.hide()
	_show_info_view(InfoView.CREDITS)

func _on_report_pressed() -> void:
	_show_info_view(InfoView.REPORT)

func _open_report_view() -> void:
	report_status_label.text = ""
	report_text_edit.text = ""

func _populate_report_categories() -> void:
	var previous := report_category_select.selected
	report_category_select.clear()
	report_category_select.add_item(SettingsManager.t("REPORT_CATEGORY_BUG"))
	report_category_select.set_item_metadata(0, ReportDialog.TYPE_BUG)
	if previous >= 0 and previous < report_category_select.item_count:
		report_category_select.selected = previous

func _on_report_submit_pressed() -> void:
	var description := report_text_edit.text.strip_edges()
	if description.is_empty():
		report_status_label.text = SettingsManager.t("REPORT_EMPTY_ERROR")
		return
	var type_id: String = report_category_select.get_item_metadata(report_category_select.selected)
	report_status_label.text = ""
	report_submit_button.disabled = true
	BackendClient.report_issue(type_id, description, 0, "", func(code: int, _parsed):
		report_submit_button.disabled = false
		if code == 200:
			report_status_label.text = SettingsManager.t("REPORT_SUCCESS_TEXT")
			report_text_edit.text = ""
		else:
			report_status_label.text = SettingsManager.t("REPORT_ERROR_TEXT")
	)

# --- Quêtes quotidiennes --------------------------------------------------
func _on_legal_pressed() -> void:
	credits_main_sub.hide()
	credits_legal_sub.show()
	AudioManager.play(AudioManager.OPEN_MENU)

func _on_decks_button_pressed() -> void:
	if not CardLibrary.is_loaded:
		push_warning("CardLibrary pas encore chargé !")
		return
	AudioManager.play(AudioManager.OPEN_MENU)
	_show_info_view(InfoView.DECKS_MANAGE)

# Ouvre le shop plein écran existant (animations d'ouverture de pack, non
# adaptées à l'espace réduit de la fenêtre actualités — voir PackShop.gd).
# La vue "Boutique" de la fenêtre actualités sert de point d'entrée en
# attendant une vraie boutique multi-articles (prévue plus tard).
func _on_shop_open_pressed() -> void:
	AudioManager.play(AudioManager.OPEN_MENU)
	pack_shop.visible = true
	_fade_in_overlay(pack_shop)
	if pack_shop.has_method("refresh"):
		pack_shop.refresh()

func _on_packs_button_pressed() -> void:
	_show_info_view(InfoView.SHOP)

# --- Flux "Jouer" : mode puis deck, directement dans le panneau de nav ----
# Le panneau de gauche (Jouer/Paramètres/Crédits/...) bascule son contenu au
# lieu d'ouvrir une fenêtre à part : MAIN (boutons habituels) -> MODE_SELECT
# (Solo/Multijoueur) -> DECK_SELECT (liste des decks + Lancer la partie).

func _show_nav_view(view: NavView) -> void:
	main_nav_view.visible = view == NavView.MAIN
	mode_select_view.visible = view == NavView.MODE_SELECT
	deck_select_view.visible = view == NavView.DECK_SELECT

func _on_play() -> void:
	if not SettingsManager.tutorial_completed:
		TutorialContext.active = true
		get_tree().change_scene_to_file(BATTLE_SCENE)
		return
	AudioManager.play(AudioManager.OPEN_MENU)
	_show_nav_view(NavView.MODE_SELECT)
	_show_info_view(InfoView.NEWS)

func _on_mode_back_pressed() -> void:
	_show_nav_view(NavView.MAIN)

func _on_solo_mode_selected() -> void:
	_play_mode = PlayMode.SOLO
	_show_deck_select()

func _on_multi_mode_selected() -> void:
	_play_mode = PlayMode.MULTI
	_show_deck_select()

# L'Arena n'utilise pas le deck du joueur (pool de cartes partagé, voir
# scripts/arena/) : contrairement à Solo/Multi, saute directement le choix
# de deck et lance la scène dédiée.
func _on_arena_mode_selected() -> void:
	AudioManager.play(AudioManager.OPEN_MENU)
	get_tree().change_scene_to_file(ARENA_SCENE)

func _show_deck_select() -> void:
	_show_nav_view(NavView.DECK_SELECT)
	_play_selected_deck_index = -1
	launch_button.disabled = true
	_refresh_play_deck_list()
	_show_info_view(InfoView.NEWS)

func _on_play_back_pressed() -> void:
	_show_nav_view(NavView.MODE_SELECT)

func _refresh_play_deck_list() -> void:
	for child in play_decks_container.get_children():
		child.queue_free()
	if DeckManager.decks.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = SettingsManager.t("decklist.empty")
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		empty_lbl.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 0.5))
		empty_lbl.add_theme_font_size_override("font_size", 16)
		play_decks_container.add_child(empty_lbl)
		return
	for i in range(DeckManager.decks.size()):
		play_decks_container.add_child(_make_play_deck_row(DeckManager.decks[i], i))

## Couleur de la race la plus représentée dans le deck (même logique que
## DeckList._dominant_race_color).
func _dominant_race_color(deck: DeckData) -> Color:
	var counts: Dictionary = {}
	for card in deck.get_cards():
		counts[card.race] = counts.get(card.race, 0) + 1
	var best_race := -1
	var best_count := 0
	for race in counts:
		if counts[race] > best_count:
			best_race = race
			best_count = counts[race]
	return RACE_ACCENTS.get(best_race, NEUTRAL_ACCENT)

## Ligne simplifiée (choix uniquement, pas d'édition) pour le flux Jouer.
func _make_play_deck_row(deck: DeckData, index: int) -> Control:
	var is_selected := index == _play_selected_deck_index

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

	var button := Button.new()
	button.flat = true
	button.custom_minimum_size = Vector2(0, 52)
	button.add_theme_stylebox_override("normal", bg)
	button.add_theme_stylebox_override("hover", bg_hover)
	button.add_theme_stylebox_override("pressed", bg_hover)
	button.pressed.connect(_on_play_deck_selected.bind(index))

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(row)

	var race_strip := ColorRect.new()
	race_strip.color = _dominant_race_color(deck)
	race_strip.custom_minimum_size = Vector2(5, 0)
	row.add_child(race_strip)

	var select_indicator := Label.new()
	select_indicator.text = "●" if is_selected else "○"
	select_indicator.custom_minimum_size = Vector2(28, 0)
	select_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	select_indicator.add_theme_font_size_override("font_size", 18)
	select_indicator.add_theme_color_override("font_color",
		Color(0.94, 0.75, 0.25, 1) if is_selected else Color(0.91, 0.835, 0.639, 0.35))
	row.add_child(select_indicator)

	var name_lbl := Label.new()
	name_lbl.text = SettingsManager.t(deck.name)
	name_lbl.clip_text = true
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	row.add_child(name_lbl)

	var count_lbl := Label.new()
	count_lbl.text = "%d/40" % deck.size()
	count_lbl.custom_minimum_size = Vector2(44, 0)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.add_theme_font_size_override("font_size", 12)
	count_lbl.add_theme_color_override("font_color",
		Color(0.5, 0.9, 0.5, 1) if deck.size() >= 40 else Color(1, 0.4, 0.4, 1))
	row.add_child(count_lbl)

	return button

func _on_play_deck_selected(index: int) -> void:
	_play_selected_deck_index = index
	launch_button.disabled = false
	_refresh_play_deck_list()
	DeckCompositionPanel.show(self, index)

func _on_launch_pressed() -> void:
	if _play_selected_deck_index < 0:
		return
	DeckManager.set_active_deck(_play_selected_deck_index)
	_show_nav_view(NavView.MAIN)
	if _play_mode == PlayMode.SOLO:
		TutorialContext.active = false
		get_tree().change_scene_to_file(BATTLE_SCENE)
	else:
		AudioManager.play(AudioManager.OPEN_MENU)
		get_tree().change_scene_to_file(NET_LOBBY_SCENE)

func _on_discord_pressed() -> void:
	OS.shell_open(DISCORD_URL)

func _on_website_pressed() -> void:
	OS.shell_open(WEBSITE_URL)

func _on_quit() -> void:
	get_tree().quit()

# Rend visible la bannière "mode hors ligne" (backend/Steam injoignable) :
# non bloquante, dismissible, tant que la connexion n'a pas été rétablie
# (voir CollectionManager/CurrencyManager : la progression n'est simplement
# pas sauvegardée, aucune donnée n'est perdue localement).
func _show_offline_banner() -> void:
	offline_banner.visible = true

# Met à jour tous les libellés du menu dans la langue courante.
func _retranslate() -> void:
	subtitle_label.text = SettingsManager.t("MENU_SUBTITLE")
	play_button.text    = SettingsManager.t("MENU_PLAY")
	decks_button.text   = SettingsManager.t("MENU_DECKS")
	packs_button.text   = SettingsManager.t("MENU_PACKS")
	currency_label.text = SettingsManager.t("MENU_CURRENCY") % CurrencyManager.balance
	settings_button.text = SettingsManager.t("MENU_SETTINGS")
	credits_button.text = SettingsManager.t("MENU_CREDITS")
	report_button.text  = SettingsManager.t("MENU_REPORT")
	quit_button.text    = SettingsManager.t("MENU_QUIT")
	credits_label.text  = SettingsManager.t("MENU_CREDITS_BODY")
	legal_button.text   = SettingsManager.t("MENU_LEGAL")
	legal_label.text    = SettingsManager.t("MENU_LEGAL_BODY")
	close_legal.text    = SettingsManager.t("ui.back")
	news_title_label.text = SettingsManager.t("MENU_NEWS_TITLE")
	report_title_label.text = SettingsManager.t("REPORT_TITLE")
	report_category_label.text = SettingsManager.t("REPORT_CATEGORY_LABEL")
	_populate_report_categories()
	report_desc_label.text = SettingsManager.t("REPORT_DESCRIPTION_LABEL")
	report_text_edit.placeholder_text = SettingsManager.t("REPORT_DESCRIPTION_PLACEHOLDER")
	report_submit_button.text = SettingsManager.t("REPORT_SUBMIT")
	NewsPanel._populate_news(self)
	discord_button.tooltip_text = SettingsManager.t("MENU_DISCORD_TOOLTIP")
	website_button.tooltip_text = SettingsManager.t("MENU_WEBSITE_TOOLTIP")
	offline_banner_label.text = SettingsManager.t("MENU_OFFLINE_BANNER")

	mode_title_label.text = SettingsManager.t("MENU_PLAY_CHOOSE_MODE")
	solo_mode_button.text = SettingsManager.t("MENU_PLAY_SOLO")
	multi_mode_button.text = SettingsManager.t("MENU_PLAY_MULTI")
	arena_mode_button.text = SettingsManager.t("MENU_ARENA")
	mode_back_button.text = SettingsManager.t("ui.back")
	play_back_button.text = SettingsManager.t("ui.back")
	deck_select_title_label.text = SettingsManager.t("MENU_PLAY_CHOOSE_DECK")
	launch_button.text = SettingsManager.t("MENU_PLAY_LAUNCH")
	edit_deck_button.text = SettingsManager.t("MENU_EDIT_DECK_LINK")
	deck_comp_preview_hint.text = SettingsManager.t("MENU_DECK_COMPOSITION_EMPTY")
	shop_title_label.text = SettingsManager.t("MENU_SHOP_TITLE")
	shop_desc_label.text = SettingsManager.t("MENU_SHOP_PLACEHOLDER")
	shop_open_button.text = SettingsManager.t("MENU_SHOP_OPEN_BUTTON")
	profile_title_label.text = SettingsManager.t("PROFILE_TITLE")
	quests_button.text = SettingsManager.t("MENU_QUESTS")
	quests_title_label.text = SettingsManager.t("QUESTS_TITLE")
	if quests_view.visible:
		QuestsPanel.open(self)
	if deck_composition_view.visible and _composition_deck_index >= 0 and _composition_deck_index < DeckManager.decks.size():
		DeckCompositionPanel.show(self, _composition_deck_index)
	if profile_view.visible:
		ProfilePanel.open(self)
