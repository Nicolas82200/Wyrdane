extends Button
class_name LockAttacksButton

## Bouton "Verrouiller les attaques" — même styling dark fantasy que
## EndTurnButton (voir ce fichier), dupliqué ici pour rester un composant
## indépendant (sémantique différente : verrouille les paires déclarées par
## SelectionSystem au lieu de terminer le tour).

const FONT_BOLD := preload("res://assets/fonts/MedievalSharp-Bold.ttf")

var _hover_tween: Tween

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_style()
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))

func _apply_style() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color                   = Color("1c2a3acc")
	normal.border_width_left          = 2
	normal.border_width_right         = 2
	normal.border_width_top           = 2
	normal.border_width_bottom        = 2
	normal.border_color               = Color("6b8b14")
	normal.corner_radius_top_left     = 8
	normal.corner_radius_top_right    = 8
	normal.corner_radius_bottom_left  = 8
	normal.corner_radius_bottom_right = 8
	normal.shadow_color               = Color(0, 0, 0, 0.4)
	normal.shadow_size                = 4
	add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color     = Color("263a54dd")
	hover.border_color = Color("a2c927")
	add_theme_stylebox_override("hover", hover)

	var pressed_style := normal.duplicate() as StyleBoxFlat
	pressed_style.bg_color     = Color("101c24ee")
	pressed_style.border_color = Color("c0f040")
	add_theme_stylebox_override("pressed", pressed_style)

	var disabled_style := normal.duplicate() as StyleBoxFlat
	disabled_style.bg_color     = Color("26262688")
	disabled_style.border_color = Color("55555588")
	add_theme_stylebox_override("disabled", disabled_style)

	add_theme_font_override("font", FONT_BOLD)
	add_theme_font_size_override("font_size", 18)
	add_theme_color_override("font_color",          Color("d5e8a3"))
	add_theme_color_override("font_hover_color",    Color("f5ffd6"))
	add_theme_color_override("font_pressed_color",  Color("c0f040"))
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
