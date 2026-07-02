extends PanelContainer
class_name ManaDisplay

## Affichage du mana utilisable : rangée de cristaux + compteur "X / Y"

const FONT_BOLD := preload("res://assets/fonts/MedievalSharp-Bold.ttf")

# Au-delà de cette limite, seuls les cristaux affichés se remplissent,
# le compteur texte reste la source exacte
const MAX_CRYSTALS: int = 10

const COLOR_CRYSTAL_FULL  := Color("5ec8ff")
const COLOR_CRYSTAL_EMPTY := Color("2a3f5c")
const COLOR_TEXT          := Color("cfe6ff")

var _crystals: Array[Label] = []
var _amount_label: Label
var _last_mana: int = -1
var _pulse_tween: Tween

func _ready() -> void:
	_build_style()
	_build_content()

func _build_style() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color                   = Color("101a2bcc")
	bg.border_width_left          = 2
	bg.border_width_right         = 2
	bg.border_width_top           = 2
	bg.border_width_bottom        = 2
	bg.border_color               = Color("3f6fa8")
	bg.corner_radius_top_left     = 8
	bg.corner_radius_top_right    = 8
	bg.corner_radius_bottom_left  = 8
	bg.corner_radius_bottom_right = 8
	bg.content_margin_left        = 10.0
	bg.content_margin_right       = 10.0
	bg.content_margin_top         = 4.0
	bg.content_margin_bottom      = 4.0
	bg.shadow_color               = Color(0, 0, 0, 0.4)
	bg.shadow_size                = 4
	add_theme_stylebox_override("panel", bg)

func _build_content() -> void:
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	add_child(vbox)

	var crystals_row := HBoxContainer.new()
	crystals_row.alignment = BoxContainer.ALIGNMENT_CENTER
	crystals_row.add_theme_constant_override("separation", 2)
	vbox.add_child(crystals_row)

	for i in range(MAX_CRYSTALS):
		var crystal := Label.new()
		crystal.text = "◆"
		crystal.visible = false
		crystal.add_theme_font_size_override("font_size", 13)
		crystal.add_theme_color_override("font_color", COLOR_CRYSTAL_EMPTY)
		crystal.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		crystal.add_theme_constant_override("shadow_offset_x", 1)
		crystal.add_theme_constant_override("shadow_offset_y", 1)
		crystals_row.add_child(crystal)
		_crystals.append(crystal)

	_amount_label = Label.new()
	_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_amount_label.add_theme_font_override("font", FONT_BOLD)
	_amount_label.add_theme_font_size_override("font_size", 18)
	_amount_label.add_theme_color_override("font_color", COLOR_TEXT)
	_amount_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_amount_label.add_theme_constant_override("shadow_offset_x", 1)
	_amount_label.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(_amount_label)

func set_mana(current: int, maximum: int) -> void:
	_amount_label.text = "%d / %d" % [current, maximum]
	tooltip_text = "Mana : %d disponible sur %d" % [current, maximum]

	var shown: int = mini(maximum, MAX_CRYSTALS)
	for i in range(MAX_CRYSTALS):
		var crystal := _crystals[i]
		crystal.visible = i < shown
		var filled: bool = i < mini(current, shown)
		crystal.add_theme_color_override(
			"font_color",
			COLOR_CRYSTAL_FULL if filled else COLOR_CRYSTAL_EMPTY
		)

	if current > _last_mana and _last_mana >= 0:
		_pulse()
	_last_mana = current

func _pulse() -> void:
	pivot_offset = size / 2.0
	if _pulse_tween:
		_pulse_tween.kill()
	scale = Vector2.ONE
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.08)
	_pulse_tween.tween_property(self, "scale", Vector2.ONE, 0.15)
