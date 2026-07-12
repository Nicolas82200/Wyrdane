extends Button
class_name EndTurnButton

## Bouton "Fin du tour" stylisé (dark fantasy, bordure dorée)

const FONT_BOLD := preload("res://assets/fonts/MedievalSharp-Bold.ttf")

var _hover_tween: Tween
var _hint_glow: Panel = null
var _hint_tween: Tween

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_style()
	_create_hint_glow()
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

# Halo doré pulsant derrière le bouton : invite à finir le tour quand le
# joueur n'a plus aucune action possible (même langage visuel que le glow
# des serviteurs prêts à attaquer).
func _create_hint_glow() -> void:
	_hint_glow = Panel.new()
	_hint_glow.name = "ReadyHintGlow"
	_hint_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_glow.show_behind_parent = true
	var style := StyleBoxFlat.new()
	style.bg_color                   = Color(0, 0, 0, 0)
	style.border_width_left          = 3
	style.border_width_right         = 3
	style.border_width_top           = 3
	style.border_width_bottom        = 3
	style.border_color               = Color("f0c040")
	style.corner_radius_top_left     = 10
	style.corner_radius_top_right    = 10
	style.corner_radius_bottom_left  = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color               = Color("f0c04088")
	style.shadow_size                = 8
	_hint_glow.add_theme_stylebox_override("panel", style)
	_hint_glow.visible = false
	add_child(_hint_glow)

func set_ready_hint(on: bool) -> void:
	if _hint_glow == null or _hint_glow.visible == on:
		return
	_hint_glow.visible = on
	if _hint_tween:
		_hint_tween.kill()
		_hint_tween = null
	if not on:
		return
	_hint_glow.position = Vector2(-4, -4)
	_hint_glow.size = size + Vector2(8, 8)
	_hint_glow.modulate.a = 0.35
	_hint_tween = create_tween().set_loops()
	_hint_tween.tween_property(_hint_glow, "modulate:a", 0.9, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hint_tween.tween_property(_hint_glow, "modulate:a", 0.35, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_hover(hovered: bool) -> void:
	if disabled:
		return
	pivot_offset = size / 2.0
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween()
	var target := Vector2(1.05, 1.05) if hovered else Vector2.ONE
	_hover_tween.tween_property(self, "scale", target, 0.1)
