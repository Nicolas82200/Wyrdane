extends Control
class_name BoardMinion

var minion: Minion
var is_selected := false

signal minion_clicked(minion, board_minion)

@onready var art             = $Art
@onready var attack_label    = $AttackLabel
@onready var health_label    = $HealthLabel
@onready var border_highlight: Panel = $BorderHighlight
@onready var protection_icon = $ProtectionIcon
@onready var border_color: Panel = get_node_or_null("BorderColor")

var _highlight_style: StyleBoxFlat
var _race_style: StyleBoxFlat

const BORDER_RACE_COLORS := {
	Race.Type.UNDEAD: Color("342e1ae1"),
	Race.Type.HUMAN:  Color("5a4a35e1"),
	Race.Type.ELF:    Color("2f5d50e1"),
	Race.Type.DWARF:  Color("5a3a22e1"),
	Race.Type.DEMON:  Color("5a1f1fe1"),
}

func _ready():
	_highlight_style = StyleBoxFlat.new()
	_highlight_style.bg_color          = Color.TRANSPARENT
	_highlight_style.border_width_left   = 2
	_highlight_style.border_width_right  = 2
	_highlight_style.border_width_top    = 2
	_highlight_style.border_width_bottom = 2
	_highlight_style.border_color        = Color(1.0, 0.9, 0.3)
	border_highlight.add_theme_stylebox_override("panel", _highlight_style)
	border_highlight.visible = false

	_race_style = StyleBoxFlat.new()
	_race_style.bg_color            = Color.TRANSPARENT
	_race_style.border_width_left   = 8
	_race_style.border_width_right  = 8
	_race_style.border_width_top    = 15
	_race_style.border_width_bottom = 0
	_race_style.border_blend        = true
	if border_color:
		border_color.add_theme_stylebox_override("panel", _race_style)

func set_minion(new_minion: Minion) -> void:
	minion = new_minion
	update_display()
	# Animation d'apparition
	scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func update_display():
	if minion == null:
		return
	attack_label.text = str(minion.attack)
	health_label.text = str(max(minion.health, 0))

	if minion.can_attack():
		modulate = Color.WHITE
	else:
		modulate = Color(0.7, 0.7, 0.7)

	if minion.card_data.texture:
		art.texture = minion.card_data.texture

	protection_icon.visible = minion.has_keyword(Keyword.Type.PROTECTION)

	var race = minion.card_data.race
	_race_style.border_color = BORDER_RACE_COLORS.get(race, Color.WHITE)

func _gui_input(event):
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		minion_clicked.emit(minion, self)

func set_selected(value: bool) -> void:
	is_selected = value
	border_highlight.visible = value
