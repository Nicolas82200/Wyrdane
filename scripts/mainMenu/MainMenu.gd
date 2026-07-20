# MainMenu.gd
extends Control

const BATTLE_SCENE := "res://scenes/battle/Battle.tscn"
const NET_LOBBY_SCENE := "res://scenes/net/NetLobby.tscn"

@onready var play_button:     Button = $NavPanel/NavMargin/VBoxContainer/PlayButton
@onready var multiplayer_button: Button = $NavPanel/NavMargin/VBoxContainer/MultiplayerButton
@onready var settings_button: Button = $NavPanel/NavMargin/VBoxContainer/SettingsButton
@onready var credits_button:  Button = $NavPanel/NavMargin/VBoxContainer/CreditsButton
@onready var quit_button:     Button = $NavPanel/NavMargin/VBoxContainer/QuitButton
@onready var credits_panel:   Panel  = $CreditsPanel
@onready var close_credits:   Button = $CreditsPanel/CloseCreditsButton
@onready var decks_button:    Button = $NavPanel/NavMargin/VBoxContainer/DecksButton
@onready var packs_button:    Button = $NavPanel/NavMargin/VBoxContainer/PacksButton
@onready var pack_shop:       Control = $PackShop
@onready var replay_tutorial_button: Button = $NavPanel/NavMargin/VBoxContainer/ReplayTutorialButton
@onready var deck_list:       Control = $DeckList
@onready var subtitle_label:  Label  = $SubtitleLabel
@onready var credits_label:   Label  = $CreditsPanel/CreditsLabel
@onready var steam_profile:   Control = $SteamProfile
@onready var steam_avatar:    TextureRect = $SteamProfile/Avatar
@onready var steam_name_label: Label = $SteamProfile/NameLabel
@onready var currency_label: Label = $CurrencyLabel
# Non typé : typer en AudioSettingsMenu cassait _ready() si le type ne matchait pas
@onready var settings_menu = $SettingsMenu

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
	# Le son de fermeture remplace le clic générique
	close_credits.set_meta("no_click_sound", true)
	close_credits.pressed.connect(func():
		AudioManager.play(AudioManager.CLOSE_MENU)
		credits_panel.hide()
	)
	# settings_menu peut légitimement être absent
	if settings_menu:
		settings_button.pressed.connect(settings_menu.open)
	else:
		push_error("SettingsMenu introuvable !")
	credits_panel.hide()
	_update_steam_profile()
	CurrencyManager.balance_changed.connect(func(new_balance: int):
		currency_label.text = SettingsManager.t("MENU_CURRENCY") % new_balance
	)
	currency_label.text = SettingsManager.t("MENU_CURRENCY") % CurrencyManager.balance
	_start_backend_sync()

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
# de mode hors-ligne (voir DeckManager).
func _start_backend_sync() -> void:
	if not SteamService.ensure_init():
		return
	BackendClient.login_succeeded.connect(func(_user):
		CardLibrary.sync_backend_catalog(func(success: bool):
			if success:
				DeckManager.sync_from_backend()
				CollectionManager.sync_from_backend()
				CurrencyManager.sync_from_backend()
		)
	, CONNECT_ONE_SHOT)
	BackendClient.login_failed.connect(func(reason: String):
		push_warning("Connexion backend échouée : %s" % reason)
	, CONNECT_ONE_SHOT)
	BackendClient.login_with_steam()

func _on_decks_button_pressed() -> void:
	if not CardLibrary.is_loaded:
		push_warning("CardLibrary pas encore chargé !")
		return
	AudioManager.play(AudioManager.OPEN_MENU)
	deck_list.visible = true
	if deck_list.has_method("_refresh"):
		deck_list._refresh()

func _on_packs_button_pressed() -> void:
	AudioManager.play(AudioManager.OPEN_MENU)
	pack_shop.visible = true
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

func _on_credits() -> void:
	credits_panel.visible = not credits_panel.visible
	AudioManager.play(AudioManager.OPEN_MENU if credits_panel.visible else AudioManager.CLOSE_MENU)

func _on_quit() -> void:
	get_tree().quit()

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
