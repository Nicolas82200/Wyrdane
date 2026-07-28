# MainMenu.gd
extends Control

const BATTLE_SCENE := "res://scenes/battle/Battle.tscn"
const NET_LOBBY_SCENE := "res://scenes/net/NetLobby.tscn"
const NEWS_DIR := "res://resources/news/"
const DISCORD_URL := "https://discord.gg/qdBEjrsdEw"

@onready var play_button:     Button = $NavPanel/NavMargin/VBoxContainer/PlayButton
@onready var multiplayer_button: Button = $NavPanel/NavMargin/VBoxContainer/MultiplayerButton
@onready var settings_button: Button = $NavPanel/NavMargin/VBoxContainer/SettingsButton
@onready var credits_button:  Button = $NavPanel/NavMargin/VBoxContainer/CreditsButton
@onready var quit_button:     Button = $NavPanel/NavMargin/VBoxContainer/QuitButton
@onready var credits_panel:   Panel  = $CreditsPanel
@onready var close_credits:   Button = $CreditsPanel/CloseCreditsButton
@onready var legal_button:    Button = $CreditsPanel/LegalButton
@onready var legal_panel:     Panel  = $LegalPanel
@onready var close_legal:     Button = $LegalPanel/CloseLegalButton
@onready var legal_title_label: Label = $LegalPanel/LegalTitleLabel
@onready var legal_label:     Label  = $LegalPanel/LegalScroll/LegalLabel
@onready var decks_button:    Button = $NavPanel/NavMargin/VBoxContainer/DecksButton
@onready var packs_button:    Button = $NavPanel/NavMargin/VBoxContainer/PacksButton
@onready var pack_shop:       Control = $PackShop
@onready var replay_tutorial_button: Button = $NavPanel/NavMargin/VBoxContainer/ReplayTutorialButton
@onready var deck_list:       Control = $DeckList
@onready var subtitle_label:  Label  = $SubtitleLabel
@onready var credits_label:   Label  = $CreditsPanel/CreditsLabel
@onready var steam_profile:   Control = $PlayerStatusPanel/PlayerMargin/PlayerVBox/SteamProfile
@onready var steam_avatar:    TextureRect = $PlayerStatusPanel/PlayerMargin/PlayerVBox/SteamProfile/Avatar
@onready var steam_name_label: Label = $PlayerStatusPanel/PlayerMargin/PlayerVBox/SteamProfile/NameLabel
@onready var currency_label: Label = $PlayerStatusPanel/PlayerMargin/PlayerVBox/CurrencyLabel
@onready var match_stats_label: Label = $PlayerStatusPanel/PlayerMargin/PlayerVBox/MatchStatsLabel
@onready var profile_button: Button = $PlayerStatusPanel/ProfileButton
@onready var profile_panel: Control = $ProfilePanel
@onready var news_title_label: Label = $NewsPanel/NewsMargin/NewsVBox/NewsTitleLabel
@onready var news_list_vbox: VBoxContainer = $NewsPanel/NewsMargin/NewsVBox/NewsScroll/NewsListVBox
@onready var discord_button: TextureButton = $FooterPanel/FooterMargin/FooterRow/DiscordButton
@onready var offline_banner: PanelContainer = $OfflineBanner
@onready var offline_banner_label: Label = $OfflineBanner/OfflineBannerMargin/OfflineBannerRow/OfflineBannerLabel
@onready var offline_banner_close: Button = $OfflineBanner/OfflineBannerMargin/OfflineBannerRow/OfflineBannerCloseButton
# Non typé : typer en AudioSettingsMenu cassait _ready() si le type ne matchait pas
@onready var settings_menu = $SettingsMenu

var _news_entries: Array[NewsEntry] = []

func _ready() -> void:
	AudioManager.play_menu_music()
	SettingsManager.language_changed.connect(func(_l): _retranslate())
	_retranslate()
	_apply_tutorial_lock()
	play_button.pressed.connect(_on_play)
	multiplayer_button.pressed.connect(_on_multiplayer)
	credits_button.pressed.connect(_on_credits)
	quit_button.pressed.connect(_on_quit)
	decks_button.pressed.connect(_on_decks_button_pressed)
	packs_button.pressed.connect(_on_packs_button_pressed)
	replay_tutorial_button.pressed.connect(_on_replay_tutorial_pressed)
	discord_button.pressed.connect(_on_discord_pressed)
	profile_button.set_meta("no_click_sound", true)
	profile_button.pressed.connect(profile_panel.open)
	# Le son de fermeture remplace le clic générique
	close_credits.set_meta("no_click_sound", true)
	close_credits.pressed.connect(func():
		AudioManager.play(AudioManager.CLOSE_MENU)
		credits_panel.hide()
	)
	legal_button.pressed.connect(_on_legal_pressed)
	close_legal.set_meta("no_click_sound", true)
	close_legal.pressed.connect(func():
		AudioManager.play(AudioManager.CLOSE_MENU)
		legal_panel.hide()
	)
	legal_panel.hide()
	# settings_menu peut légitimement être absent
	if settings_menu:
		settings_button.pressed.connect(settings_menu.open)
	else:
		push_error("SettingsMenu introuvable !")
	credits_panel.hide()
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
		match_stats_label.text = SettingsManager.t("MENU_MATCH_STATS") % [wins, losses]
	)
	match_stats_label.text = SettingsManager.t("MENU_MATCH_STATS") % [SettingsManager.match_wins, SettingsManager.match_losses]
	_load_news()
	_start_backend_sync()
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

# Fondu d'apparition pour les panneaux plein écran (Decks/Packs), qui portent
# déjà leur propre voile d'assombrissement en fond — un simple fondu du
# contrôle entier évite tout artefact de bord lié à un scale.
func _fade_in_overlay(panel: Control) -> void:
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# Pop d'apparition (fondu + léger zoom depuis 92%) pour les petits panneaux
# centrés sans voile de fond (Crédits/Mentions légales).
func _pop_in_panel(panel: Control) -> void:
	panel.pivot_offset = panel.size / 2.0
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.92, 0.92)
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.16)
	tween.parallel().tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
	multiplayer_button.disabled = locked
	decks_button.disabled = locked
	packs_button.disabled = locked
	multiplayer_button.tooltip_text = SettingsManager.t("MENU_LOCKED_TUTORIAL") if locked else ""
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

func _on_decks_button_pressed() -> void:
	if not CardLibrary.is_loaded:
		push_warning("CardLibrary pas encore chargé !")
		return
	AudioManager.play(AudioManager.OPEN_MENU)
	deck_list.visible = true
	_fade_in_overlay(deck_list)
	if deck_list.has_method("_refresh"):
		deck_list._refresh()

func _on_packs_button_pressed() -> void:
	AudioManager.play(AudioManager.OPEN_MENU)
	pack_shop.visible = true
	_fade_in_overlay(pack_shop)
	if pack_shop.has_method("refresh"):
		pack_shop.refresh()

func _on_play() -> void:
	TutorialContext.active = not SettingsManager.tutorial_completed
	get_tree().change_scene_to_file(BATTLE_SCENE)

# Bouton temporaire de debug/test : force le rejeu du tutoriel obligatoire
# sans avoir à éditer le fichier de config à la main (voir
# SettingsManager.reset_tutorial_completed). À retirer une fois le tutoriel
# validé.
func _on_replay_tutorial_pressed() -> void:
	SettingsManager.reset_tutorial_completed()
	_apply_tutorial_lock()
	TutorialContext.active = true
	get_tree().change_scene_to_file(BATTLE_SCENE)

func _on_multiplayer() -> void:
	if DeckManager.get_active_deck() == null:
		push_warning("Aucun deck actif : crée/sélectionne un deck avant de jouer en ligne.")
		return
	AudioManager.play(AudioManager.OPEN_MENU)
	get_tree().change_scene_to_file(NET_LOBBY_SCENE)

# Charge toutes les ressources NewsEntry (res://resources/news/*.tres), triées
# par date décroissante (format YYYY-MM-DD, comparable directement en string),
# puis peuple le panneau. Aucune dépendance backend : contenu embarqué au build,
# comme les cartes.
func _load_news() -> void:
	_news_entries.clear()
	var dir := DirAccess.open(NEWS_DIR)
	if dir == null:
		push_warning("Dossier d'actualités introuvable : %s" % NEWS_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var entry := load(NEWS_DIR + file_name) as NewsEntry
			if entry:
				_news_entries.append(entry)
		file_name = dir.get_next()
	dir.list_dir_end()
	_news_entries.sort_custom(func(a: NewsEntry, b: NewsEntry): return a.date > b.date)
	_populate_news()

func _populate_news() -> void:
	for child in news_list_vbox.get_children():
		child.queue_free()
	for entry in _news_entries:
		var item := VBoxContainer.new()
		item.add_theme_constant_override("separation", 4)

		var date_label := Label.new()
		date_label.text = entry.date
		date_label.add_theme_font_size_override("font_size", 13)
		date_label.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 0.55))
		item.add_child(date_label)

		var title_label := Label.new()
		title_label.text = entry.display_title()
		title_label.add_theme_font_size_override("font_size", 18)
		title_label.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		item.add_child(title_label)

		var body_label := Label.new()
		body_label.text = entry.display_body()
		body_label.add_theme_font_size_override("font_size", 15)
		body_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72, 0.9))
		body_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		item.add_child(body_label)

		news_list_vbox.add_child(item)

func _on_discord_pressed() -> void:
	OS.shell_open(DISCORD_URL)

func _on_credits() -> void:
	credits_panel.visible = not credits_panel.visible
	AudioManager.play(AudioManager.OPEN_MENU if credits_panel.visible else AudioManager.CLOSE_MENU)
	if credits_panel.visible:
		_pop_in_panel(credits_panel)

func _on_legal_pressed() -> void:
	credits_panel.hide()
	legal_panel.visible = true
	AudioManager.play(AudioManager.OPEN_MENU)
	_pop_in_panel(legal_panel)

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
	replay_tutorial_button.text = SettingsManager.t("MENU_REPLAY_TUTORIAL_DEBUG")
	multiplayer_button.text = SettingsManager.t("MENU_MULTIPLAYER")
	settings_button.text = SettingsManager.t("MENU_SETTINGS")
	credits_button.text = SettingsManager.t("MENU_CREDITS")
	quit_button.text    = SettingsManager.t("MENU_QUIT")
	credits_label.text  = SettingsManager.t("MENU_CREDITS_BODY")
	close_credits.text  = SettingsManager.t("MENU_CLOSE")
	legal_button.text   = SettingsManager.t("MENU_LEGAL")
	legal_title_label.text = SettingsManager.t("MENU_LEGAL")
	legal_label.text    = SettingsManager.t("MENU_LEGAL_BODY")
	close_legal.text    = SettingsManager.t("MENU_CLOSE")
	news_title_label.text = SettingsManager.t("MENU_NEWS_TITLE")
	_populate_news()
	discord_button.tooltip_text = SettingsManager.t("MENU_DISCORD_TOOLTIP")
	offline_banner_label.text = SettingsManager.t("MENU_OFFLINE_BANNER")
	match_stats_label.text = SettingsManager.t("MENU_MATCH_STATS") % [SettingsManager.match_wins, SettingsManager.match_losses]
