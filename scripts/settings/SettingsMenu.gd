extends Control


@onready var panel           = $Panel
@onready var audio_menu      = $AudioSettingsMenu
@onready var graphism_menu   = $GraphismSettingsMenu
@onready var control_menu    = $ControlSettingsMenu
@onready var audio_button    = $Panel/VBox/ButtonsMargin/ButtonsVBox/AudioButton
@onready var graphism_button = $Panel/VBox/ButtonsMargin/ButtonsVBox/GraphismButton
@onready var control_button  = $Panel/VBox/ButtonsMargin/ButtonsVBox/ControlButton
@onready var close_button    = $Panel/VBox/CloseMargin/CloseButton

func _ready() -> void:
	_style_all_buttons()
	audio_button.pressed.connect(_on_audio)
	graphism_button.pressed.connect(_on_graphism)
	control_button.pressed.connect(_on_control)
	close_button.pressed.connect(close)

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
	panel.show()
	show()

func close() -> void:
	hide()

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

func _style_all_buttons() -> void:
	for btn in [audio_button, graphism_button, control_button, close_button]:
		_style_button(btn)

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
