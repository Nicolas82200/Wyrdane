extends Control
class_name Card

signal card_clicked(card: CardData, row: String, insert_index: int)
signal drag_started
signal drag_ended

const DRAG_THRESHOLD := 350.0
const HAND_RETURN_DISTANCE := 50.0

const BORDER_TEXTURES := {
	Race.Type.UNDEAD: preload("res://assets/borders/undead-border-card.png"),
}

const RARITY_COLORS := {
	"Common":    Color("80808096"),
	"Rare":      Color("3498db96"),
	"Epic":      Color("9b59b696"),
	"Legendary": Color("f39c1296")
}

const RACE_COLORS := {
	Race.Type.UNDEAD: Color("#342e1aa5"),
	Race.Type.HUMAN:  Color("#5a4a3596"),
	Race.Type.ELF:    Color("#2f5d5096"),
	Race.Type.DWARF:  Color("#5a3a2296"),
	Race.Type.DEMON:  Color("#5a1f1f96"),
}

const BORDER_RACE_COLORS := {
	Race.Type.UNDEAD: Color("342e1ae1"),
	Race.Type.HUMAN:  Color("5a4a35e1"),
	Race.Type.ELF:    Color("2f5d50e1"),
	Race.Type.DWARF:  Color("5a3a22e1"),
	Race.Type.DEMON:  Color("5a1f1fe1"),
}

@onready var art: TextureRect    = $Art
@onready var name_label: Label   = $NameLabel
@onready var cost_label: Label   = $CostLabel
@onready var attack_label: Label = $AttackLabel
@onready var health_label: Label = $HealthLabel
@onready var desc_label: Label   = $DescLabel
@onready var race_label: Label   = $RaceLabel
@onready var border: TextureRect = $BorderFrame
@onready var text_background: Control = $TextBackground
@onready var rarity_panel: Control    = $RarityPanel
@onready var border_color: Panel      = $BorderFrameColor

var data: CardData
var drag_enabled := true

var dragging := false
var original_position: Vector2
var original_scale: Vector2
var drag_start_mouse: Vector2

var _rarity_style      := StyleBoxFlat.new()
var _race_bg_style     := StyleBoxFlat.new()
var _race_border_style := StyleBoxFlat.new()


func _ready() -> void:
	_init_rarity_style()
	_init_race_border_style()
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_PASS

func set_data(new_data: CardData) -> void:
	data = new_data
	update_display()

func update_display() -> void:
	name_label.text   = data.card_name
	cost_label.text   = str(data.cost)
	attack_label.text = str(data.attack)
	health_label.text = str(data.health)
	var is_minion = data.card_type == "Minion"
	attack_label.visible = is_minion
	health_label.visible = is_minion
	desc_label.text = data.description
	if data.card_type == "Minion":
		race_label.text = Race.get_race_name(data.race)
	else:
		race_label.text = _get_card_type_label(data.card_type)
	if data.texture:
		art.texture = data.texture
	if BORDER_TEXTURES.has(data.race):
		border.texture = BORDER_TEXTURES[data.race]
	else:
		push_warning("Pas de bordure pour la race: %s" % Race.get_race_name(data.race))
	_apply_race_style()
	_apply_rarity_style()

func _get_card_type_label(card_type: String) -> String:
	match card_type:
		"Instant":     return "Sort"
		"Ritual":      return "Rituel"
		"Enchantment": return "Enchantement"
		_:             return card_type

func _init_rarity_style() -> void:
	_rarity_style.border_width_left          = 2
	_rarity_style.border_width_right         = 2
	_rarity_style.border_width_top           = 2
	_rarity_style.border_width_bottom        = 2
	_rarity_style.corner_radius_top_left     = 12
	_rarity_style.corner_radius_top_right    = 12
	_rarity_style.corner_radius_bottom_left  = 12
	_rarity_style.corner_radius_bottom_right = 12
	rarity_panel.add_theme_stylebox_override("panel", _rarity_style)

func _init_race_border_style() -> void:
	_race_border_style.bg_color            = Color.TRANSPARENT
	_race_border_style.border_width_left   = 8
	_race_border_style.border_width_right  = 8
	_race_border_style.border_width_top    = 15
	_race_border_style.border_width_bottom = 0
	_race_border_style.border_blend        = true
	border_color.add_theme_stylebox_override("panel", _race_border_style)
	text_background.add_theme_stylebox_override("panel", _race_bg_style)

func _apply_rarity_style() -> void:
	_rarity_style.border_color = RARITY_COLORS.get(data.rarity, Color.WHITE)
	rarity_panel.queue_redraw()

func _apply_race_style() -> void:
	_race_bg_style.bg_color         = RACE_COLORS.get(data.race, Color.WHITE)
	_race_border_style.border_color = BORDER_RACE_COLORS.get(data.race, Color.WHITE)
	text_background.queue_redraw()
	border_color.queue_redraw()

# ─── Drag & Drop ──────────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if not drag_enabled:
		return
	if event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed:
		original_position  = position
		original_scale     = scale
		drag_start_mouse   = get_global_mouse_position()
		dragging           = true
		z_index            = 100
		scale              = original_scale * 1.05
		_set_children_mouse_filter(Control.MOUSE_FILTER_IGNORE)
		# Reparent to Battle to avoid clipping from Hand
		var parent_node = get_parent()
		if parent_node:
			var battle: Node = get_tree().current_scene
			if battle:
				reparent(battle)
				# Adjust position to account for parent change
				global_position = get_global_mouse_position() - size * scale * 0.5
		drag_started.emit()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if dragging:
		# Center the card under the mouse while dragging for predictable placement
		global_position = get_global_mouse_position() - size * scale * 0.5
		var battle: Node = get_tree().current_scene
		if battle and battle.has_method("update_player_drop_highlight"):
			battle.call("update_player_drop_highlight", data, get_viewport().get_mouse_position(), true)

func _input(event: InputEvent) -> void:
	if not dragging:
		return
	if event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and not event.pressed:
		_on_drag_released()
		get_viewport().set_input_as_handled()

func _on_drag_released() -> void:
	dragging = false
	visible  = true
	scale    = original_scale
	_set_children_mouse_filter(Control.MOUSE_FILTER_PASS)

	var mouse_pos := get_viewport().get_mouse_position()
	var drag_distance := mouse_pos.distance_to(drag_start_mouse)

	var battle: Node = get_tree().current_scene

	# Missclic : souris pas assez éloignée du point de départ
	if drag_distance < DRAG_THRESHOLD:
		# clear highlights then restore position and reparent
		if battle and battle.has_method("clear_player_drop_highlight"):
			battle.call("clear_player_drop_highlight")
		_return_to_hand()
		drag_ended.emit()
		return

	if battle == null:
		_return_to_hand()
		drag_ended.emit()
		return

	var board: Control = battle.get_node_or_null("Board") as Control
	if board != null and board.get_global_rect().has_point(mouse_pos):
		var row: String = "Front"
		var insert_index: int = -1
		if battle.has_method("get_player_drop_row_at"):
			row = str(battle.call("get_player_drop_row_at", mouse_pos, data))
		if row.is_empty():
			_return_to_hand()
		else:
			if battle.has_method("get_player_drop_index_at"):
				# Read the insert index while the placeholder still exists
				insert_index = int(battle.call("get_player_drop_index_at", mouse_pos, row))
			# Now it's safe to clear the visuals and emit the event
			if battle.has_method("clear_player_drop_highlight"):
				battle.call("clear_player_drop_highlight")
			card_clicked.emit(data, row, insert_index)
			# Reparent back to hand container immediately after playing
			var hand: Control = battle.get_node_or_null("Hand")
			var container: Control = hand.get_node_or_null("CardsContainer") if hand else null
			if container and get_parent() != container:
				reparent(container)
				position = original_position
			drag_ended.emit()
			return
	
	# Check distance to hand before returning
	var hand_node = get_parent().get_parent() if get_parent().name != "CardsContainer" else get_parent()
	if hand_node == null:
		hand_node = battle.get_node_or_null("Hand")
	
	if hand_node != null:
		var dist_to_hand := mouse_pos.distance_to(hand_node.global_position + hand_node.size * 0.5)
		if dist_to_hand < HAND_RETURN_DISTANCE:
			# Too close to hand, return it
			_return_to_hand()
			drag_ended.emit()
			return
	
	# Fell outside the board and too far from hand, return it
	if battle and battle.has_method("clear_player_drop_highlight"):
		battle.call("clear_player_drop_highlight")
	_return_to_hand()
	drag_ended.emit()

func _return_to_hand() -> void:
	# Reparent back to hand
	var battle: Node = get_tree().current_scene
	if battle:
		var hand: Control = battle.get_node_or_null("Hand")
		var container: Control = hand.get_node_or_null("CardsContainer") if hand else null
		if container:
			reparent(container)
	position = original_position
	var hand_node = get_parent().get_parent()
	if hand_node and hand_node.has_method("_update_hand_layout"):
		hand_node._update_hand_layout()

# ─── Utilitaires ──────────────────────────────────────────────────────────────

func _set_children_mouse_filter(filter: int) -> void:
	for child in get_children():
		if child is Control:
			child.mouse_filter = filter

func is_dragging() -> bool:
	return dragging

func set_non_interactive() -> void:
	drag_enabled = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

const CARD_BACK_TEX = preload("res://assets/card_back/card-back.png")

func show_back(show_card_back: bool) -> void:
	if show_card_back:
		art.texture      = CARD_BACK_TEX
		name_label.hide()
		cost_label.hide()
		attack_label.hide()
		health_label.hide()
		desc_label.hide()
		race_label.hide()
		border.hide()
		rarity_panel.hide()
		border_color.hide()
		text_background.hide()
	else:
		if data:
			update_display()
		name_label.show()
		cost_label.show()
		attack_label.show()
		health_label.show()
		desc_label.show()
		race_label.show()
		border.show()
		rarity_panel.show()
		border_color.show()
		text_background.show()
