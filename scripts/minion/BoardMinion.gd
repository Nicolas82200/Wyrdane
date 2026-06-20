extends Control
class_name BoardMinion

signal minion_clicked(minion, board_minion)

# Pas de type statique "Minion" ici — évite l'erreur d'ordre de chargement des scripts.
var minion = null
var is_selected := false

@onready var art              = $Art
@onready var attack_label     = $AttackLabel
@onready var health_label     = $HealthLabel
@onready var border_highlight: Panel = $BorderHighlight
@onready var protection_icon  = $ProtectionIcon
@onready var border_color: Panel = get_node_or_null("BorderColor")

var _highlight_style: StyleBoxFlat
var _race_style: StyleBoxFlat
const CARD_SCENE = preload("res://scenes/card/Card.tscn")
var _hover_preview: Card = null
const BORDER_RACE_COLORS := {
	Race.Type.UNDEAD: Color("342e1ae1"),
	Race.Type.HUMAN:  Color("5a4a35e1"),
	Race.Type.ELF:    Color("2f5d50e1"),
	Race.Type.DWARF:  Color("5a3a22e1"),
	Race.Type.DEMON:  Color("5a1f1fe1"),
}

func _ready() -> void:
	_highlight_style = StyleBoxFlat.new()
	_highlight_style.bg_color            = Color.TRANSPARENT
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
	mouse_filter = Control.MOUSE_FILTER_STOP
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func set_minion(new_minion) -> void:
	minion = new_minion
	update_display()
	scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func update_display() -> void:
	if minion == null:
		return
	attack_label.text = str(minion.attack)
	health_label.text = str(max(minion.health, 0))
	modulate = Color.WHITE if minion.can_attack() else Color(0.7, 0.7, 0.7)
	if minion.card_data.texture:
		art.texture = minion.card_data.texture
	protection_icon.visible = minion.has_keyword(Keyword.Type.PROTECTION)
	_race_style.border_color = BORDER_RACE_COLORS.get(minion.card_data.race, Color.WHITE)
	if border_color:
		border_color.queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		minion_clicked.emit(minion, self)

func set_selected(value: bool, multi: bool = false) -> void:
	is_selected = value
	border_highlight.visible = value
	if value and multi:
		_highlight_style.border_color = Color(1.0, 0.45, 0.05)  # orange
	else:
		_highlight_style.border_color = Color(1.0, 0.9, 0.3)    # jaune
	border_highlight.queue_redraw()

func _on_mouse_entered() -> void:
	var battle = get_tree().current_scene
	if battle and battle.has_method("is_dragging_card") and battle.call("is_dragging_card"):
		return
	if _hover_preview != null:
		return
	_hover_preview = CARD_SCENE.instantiate()
	_hover_preview.drag_enabled = false
	_hover_preview.z_index = 1000
	get_tree().current_scene.add_child(_hover_preview)
	_hover_preview.set_data(minion.card_data)
	_hover_preview.scale = Vector2(0.9, 0.9)
	await get_tree().process_frame
	if not is_instance_valid(_hover_preview):
		return
	_hover_preview.global_position = global_position + Vector2(
	size.x + 15,
	(size.y - _hover_preview.size.y * 0.9) / 2.0
)

func _on_mouse_exited() -> void:
	if _hover_preview:
		_hover_preview.queue_free()
		_hover_preview = null
