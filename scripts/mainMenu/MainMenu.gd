extends Control
class_name MainMenu

const BATTLE_SCENE := "res://scenes/battle/Battle.tscn"

@onready var play_button: Button    = $VBoxContainer/PlayButton
@onready var future_button: Button  = $VBoxContainer/FutureButton
@onready var audio_button: Button   = $VBoxContainer/AudioSettingsButton
@onready var credits_button: Button = $VBoxContainer/CreditsButton
@onready var quit_button: Button    = $VBoxContainer/QuitButton
@onready var credits_panel: Panel   = $CreditsPanel
@onready var close_credits: Button  = $CreditsPanel/CloseCreditsButton
@onready var settings_menu          = get_node_or_null("AudioSettingsMenu") as AudioSettingsMenu

func _ready() -> void:
	AudioManager.play_battle_music()
	_style_all_buttons()

	play_button.pressed.connect(_on_play)
	future_button.pressed.connect(_on_future)
	credits_button.pressed.connect(_on_credits)
	quit_button.pressed.connect(_on_quit)
	close_credits.pressed.connect(func(): credits_panel.hide())

	if settings_menu:
		audio_button.pressed.connect(settings_menu.open)
	else:
		push_error("AudioSettingsMenu introuvable !")

	credits_panel.hide()

func _on_play() -> void:
	get_tree().change_scene_to_file(BATTLE_SCENE)

func _on_future() -> void:
	pass # À implémenter plus tard

func _on_credits() -> void:
	credits_panel.visible = not credits_panel.visible

func _on_quit() -> void:
	get_tree().quit()

# ─── Style ────────────────────────────────────────────────────────────────────

func _style_all_buttons() -> void:
	for btn in $VBoxContainer.get_children():
		if btn is Button:
			_style_button(btn)

func _style_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color                  = Color("1a1a2eaa")
	normal.border_width_left         = 2
	normal.border_width_right        = 2
	normal.border_width_top          = 2
	normal.border_width_bottom       = 2
	normal.border_color              = Color("8b6914")
	normal.corner_radius_top_left    = 6
	normal.corner_radius_top_right   = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right= 6
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color     = Color("2a2a4ecc")
	hover.border_color = Color("c9a227")
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color     = Color("0d0d1eee")
	pressed.border_color = Color("f0c040")
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", Color("e8d5a3"))
	btn.add_theme_color_override("font_hover_color", Color("fff5d6"))
	btn.add_theme_font_size_override("font_size", 20)
