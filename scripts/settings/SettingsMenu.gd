extends Control

# Émis quand le joueur confirme le bouton Concéder (visible uniquement en jeu).
signal concede_requested

# Affiche le bouton Concéder rouge. Activé depuis la bataille pour permettre de
# concéder la partie ; laissé à false dans le menu principal. Le bouton Fermer,
# lui, est masqué en partie : on ferme le menu via la croix en haut à droite.
@export var show_quit: bool = false

@onready var panel                 = $Panel
@onready var audio_menu            = $AudioSettingsMenu
@onready var graphism_menu         = $GraphismSettingsMenu
@onready var control_menu          = $ControlSettingsMenu
@onready var audio_button          = $Panel/VBox/ButtonsMargin/ButtonsVBox/AudioButton
@onready var graphism_button       = $Panel/VBox/ButtonsMargin/ButtonsVBox/GraphismButton
@onready var control_button        = $Panel/VBox/ButtonsMargin/ButtonsVBox/ControlButton
@onready var close_button          = $Panel/VBox/CloseMargin/CloseVBox/CloseButton
@onready var concede_button        = $Panel/VBox/CloseMargin/CloseVBox/ConcedeButton
@onready var close_x_button        = $Panel/VBox/TitleMargin/TitleRow/CloseXButton
@onready var title_label           = $Panel/VBox/TitleMargin/TitleRow/Title
@onready var confirm_panel         = $ConfirmPanel
@onready var confirm_message       = $ConfirmPanel/ConfirmMargin/ConfirmVBox/ConfirmMessage
@onready var confirm_cancel_button = $ConfirmPanel/ConfirmMargin/ConfirmVBox/ConfirmButtonsRow/ConfirmCancelButton
@onready var confirm_yes_button    = $ConfirmPanel/ConfirmMargin/ConfirmVBox/ConfirmButtonsRow/ConfirmYesButton

func _ready() -> void:
	_style_all_buttons()
	_style_danger_button(concede_button)
	_style_danger_button(confirm_yes_button)
	_style_close_x_button()
	audio_button.pressed.connect(_on_audio)
	graphism_button.pressed.connect(_on_graphism)
	control_button.pressed.connect(_on_control)

	SettingsManager.language_changed.connect(func(_l): _retranslate())
	_retranslate()
	# Le son de fermeture est joué dans close(), pas le clic générique
	close_button.set_meta("no_click_sound", true)
	close_button.pressed.connect(close)
	close_x_button.set_meta("no_click_sound", true)
	close_x_button.pressed.connect(close)

	# En partie : pas de bouton Fermer (la croix suffit), et Concéder remplace Quitter.
	close_button.visible = not show_quit
	concede_button.visible = show_quit
	concede_button.pressed.connect(_on_concede_pressed)
	confirm_cancel_button.pressed.connect(_on_confirm_cancel)
	confirm_yes_button.pressed.connect(_on_confirm_yes)

	if audio_menu.has_signal("back_requested"):
		audio_menu.back_requested.connect(_on_sub_back)
	else:
		push_error("AudioSettingsMenu: signal back_requested manquant !")

	if graphism_menu.has_signal("back_requested"):
		graphism_menu.back_requested.connect(_on_sub_back)
	else:
		push_error("GraphismSettingsMenu: signal back_requested manquant !")

	if control_menu.has_signal("back_requested"):
		control_menu.back_requested.connect(_on_sub_back)
	else:
		push_error("ControlSettingsMenu: signal back_requested manquant !")

	audio_menu.hide()
	graphism_menu.hide()
	control_menu.hide()

func open() -> void:
	AudioManager.play(AudioManager.OPEN_MENU)
	confirm_panel.hide()
	panel.show()
	show()
	panel.pivot_offset = panel.size / 2.0
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.94, 0.94)
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.15)
	tween.parallel().tween_property(panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func close() -> void:
	AudioManager.play(AudioManager.CLOSE_MENU)
	hide()

func _on_concede_pressed() -> void:
	panel.hide()
	confirm_panel.show()

func _on_confirm_cancel() -> void:
	confirm_panel.hide()
	panel.show()

func _on_confirm_yes() -> void:
	confirm_panel.hide()
	concede_requested.emit()

func _on_audio() -> void:
	audio_menu.open()      
	panel.hide()

func _on_graphism() -> void:
	graphism_menu.show()
	panel.hide()

func _on_control() -> void:
	control_menu.show()
	panel.hide()

func _on_sub_back() -> void:
	audio_menu.hide()
	graphism_menu.hide()
	control_menu.hide()
	panel.show()

# Met à jour les libellés du menu racine dans la langue courante.
func _retranslate() -> void:
	title_label.text           = SettingsManager.t("settings.title")
	audio_button.text          = SettingsManager.t("settings.audio")
	graphism_button.text       = SettingsManager.t("settings.graphics")
	control_button.text        = SettingsManager.t("settings.controls")
	close_button.text          = SettingsManager.t("settings.close")
	concede_button.text        = SettingsManager.t("settings.concede")
	confirm_message.text       = SettingsManager.t("settings.concede_confirm_message")
	confirm_cancel_button.text = SettingsManager.t("settings.concede_confirm_cancel")
	confirm_yes_button.text    = SettingsManager.t("settings.concede_confirm_yes")

func _style_all_buttons() -> void:
	for btn in [audio_button, graphism_button, control_button, close_button, confirm_cancel_button]:
		_style_button(btn)

# Boutons dangereux (Concéder, confirmation) : même forme que les autres mais habillage rouge sang.
func _style_danger_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color                   = Color("3a0d0daa")
	normal.border_width_left          = 2
	normal.border_width_right         = 2
	normal.border_width_top           = 2
	normal.border_width_bottom        = 2
	normal.border_color               = Color("8b1a1a")
	normal.corner_radius_top_left     = 6
	normal.corner_radius_top_right    = 6
	normal.corner_radius_bottom_left  = 6
	normal.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color     = Color("5a1414cc")
	hover.border_color = Color("c92727")
	btn.add_theme_stylebox_override("hover", hover)
	var pressed_style := normal.duplicate() as StyleBoxFlat
	pressed_style.bg_color     = Color("2a0808ee")
	pressed_style.border_color = Color("f04040")
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_color_override("font_color",       Color("f0b0b0"))
	btn.add_theme_color_override("font_hover_color", Color("fff0f0"))
	btn.add_theme_font_size_override("font_size", 20)

# Petite croix discrète en haut à droite de la popup.
func _style_close_x_button() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color                   = Color(0, 0, 0, 0)
	normal.corner_radius_top_left     = 6
	normal.corner_radius_top_right    = 6
	normal.corner_radius_bottom_left  = 6
	normal.corner_radius_bottom_right = 6
	close_x_button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("8b1a1a55")
	close_x_button.add_theme_stylebox_override("hover", hover)
	var pressed_style := normal.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color("8b1a1a88")
	close_x_button.add_theme_stylebox_override("pressed", pressed_style)
	close_x_button.add_theme_color_override("font_color",       Color("e8d5a3"))
	close_x_button.add_theme_color_override("font_hover_color", Color("fff0f0"))
	close_x_button.add_theme_font_size_override("font_size", 18)

func _style_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color                   = Color("1a1a2eaa")
	normal.border_width_left          = 2
	normal.border_width_right         = 2
	normal.border_width_top           = 2
	normal.border_width_bottom        = 2
	normal.border_color               = Color("8b6914")
	normal.corner_radius_top_left     = 6
	normal.corner_radius_top_right    = 6
	normal.corner_radius_bottom_left  = 6
	normal.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color     = Color("2a2a4ecc")
	hover.border_color = Color("c9a227")
	btn.add_theme_stylebox_override("hover", hover)
	var pressed_style := normal.duplicate() as StyleBoxFlat
	pressed_style.bg_color     = Color("0d0d1eee")
	pressed_style.border_color = Color("f0c040")
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_color_override("font_color",       Color("e8d5a3"))
	btn.add_theme_color_override("font_hover_color", Color("fff5d6"))
	btn.add_theme_font_size_override("font_size", 20)
