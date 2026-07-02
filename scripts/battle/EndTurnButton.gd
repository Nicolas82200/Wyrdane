extends Button
class_name EndTurnButton

## Bouton "Fin du tour" stylisé (dark fantasy, bordure dorée)

const FONT_BOLD := preload("res://assets/fonts/MedievalSharp-Bold.ttf")

var _hover_tween: Tween

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_style()
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))

func _apply_style() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color                   = Color("3a1c1ccc")
	normal.border_width_left          = 2
	normal.border_width_right         = 2
	normal.border_width_top           = 2
	normal.border_width_bottom        = 2
	normal.border_color               = Color("8b6914")
	normal.corner_radius_top_left     = 8
	normal.corner_radius_top_right    = 8
	normal.corner_radius_bottom_left  = 8
	normal.corner_radius_bottom_right = 8
	normal.shadow_color               = Color(0, 0, 0, 0.4)
	normal.shadow_size                = 4
	add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color     = Color("542626dd")
	hover.border_color = Color("c9a227")
	add_theme_stylebox_override("hover", hover)

	var pressed_style := normal.duplicate() as StyleBoxFlat
	pressed_style.bg_color     = Color("241010ee")
	pressed_style.border_color = Color("f0c040")
	add_theme_stylebox_override("pressed", pressed_style)

	var disabled_style := normal.duplicate() as StyleBoxFlat
	disabled_style.bg_color     = Color("26262688")
	disabled_style.border_color = Color("55555588")
	add_theme_stylebox_override("disabled", disabled_style)

	add_theme_font_override("font", FONT_BOLD)
	add_theme_font_size_override("font_size", 20)
	add_theme_color_override("font_color",          Color("e8d5a3"))
	add_theme_color_override("font_hover_color",    Color("fff5d6"))
	add_theme_color_override("font_pressed_color",  Color("f0c040"))
	add_theme_color_override("font_disabled_color", Color("777777"))

func _on_hover(hovered: bool) -> void:
	if disabled:
		return
	pivot_offset = size / 2.0
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween()
	var target := Vector2(1.05, 1.05) if hovered else Vector2.ONE
	_hover_tween.tween_property(self, "scale", target, 0.1)
