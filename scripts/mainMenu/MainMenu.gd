# MainMenu.gd
extends Control

const BATTLE_SCENE := "res://scenes/battle/Battle.tscn"

@onready var play_button:     Button = $NavPanel/NavMargin/VBoxContainer/PlayButton
@onready var future_button:   Button = $NavPanel/NavMargin/VBoxContainer/FutureButton
@onready var settings_button: Button = $NavPanel/NavMargin/VBoxContainer/SettingsButton
@onready var credits_button:  Button = $NavPanel/NavMargin/VBoxContainer/CreditsButton
@onready var quit_button:     Button = $NavPanel/NavMargin/VBoxContainer/QuitButton
@onready var credits_panel:   Panel  = $CreditsPanel
@onready var close_credits:   Button = $CreditsPanel/CloseCreditsButton
@onready var decks_button:    Button = $NavPanel/NavMargin/VBoxContainer/DecksButton
@onready var deck_list:       Control = $DeckList
# [FIX] Non typé — typer en AudioSettingsMenu cassait _ready() si le type ne matchait pas
@onready var settings_menu = $SettingsMenu

func _ready() -> void:
	AudioManager.play_battle_music()
	play_button.pressed.connect(_on_play)
	future_button.pressed.connect(_on_future)
	credits_button.pressed.connect(_on_credits)
	quit_button.pressed.connect(_on_quit)
	decks_button.pressed.connect(_on_decks_button_pressed)
	close_credits.pressed.connect(func(): credits_panel.hide())
	# [FIX] Null-check restauré — settings_menu peut légitimement être absent
	if settings_menu:
		settings_button.pressed.connect(settings_menu.open)
	else:
		push_error("SettingsMenu introuvable !")
	credits_panel.hide()

func _on_decks_button_pressed() -> void:
	if not CardLibrary.is_loaded:
		push_warning("CardLibrary pas encore chargé !")
		return
	deck_list.visible = true
	if deck_list.has_method("_refresh"):
		deck_list._refresh()

func _on_play() -> void:
	get_tree().change_scene_to_file(BATTLE_SCENE)

func _on_future() -> void:
	pass

func _on_credits() -> void:
	credits_panel.visible = not credits_panel.visible

func _on_quit() -> void:
	get_tree().quit()
