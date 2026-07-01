# Card.gd
extends Control
class_name Card

signal card_clicked(card: CardData, row: String, insert_index: int)
signal drag_started
signal drag_ended

const DRAG_THRESHOLD      := 350.0
const HAND_RETURN_DISTANCE := 50.0
const BOARD_MINION_SCENE  = preload("res://scenes/minion/BoardMinion.tscn")
const BOARD_MINION_SIZE   := Vector2(100, 150)
const CARD_BACK_TEX       = preload("res://assets/card_back/card-back.png")

const BORDER_TEXTURES := {
	Race.Type.UNDEAD: preload("res://assets/borders/undead-border-card.png"),
	Race.Type.HUMAN:  preload("res://assets/borders/human-border-card.png")
}

const RARITY_COLORS := {
	"Common":    Color("808080"),
	"Rare":      Color("3498db"),
	"Epic":      Color("9b59b6"),
	"Legendary": Color("f39c12")
}

const RACE_COLORS := {
	Race.Type.UNDEAD: Color("#342e1aa5"),
	Race.Type.HUMAN:  Color("#5a4a3596"),
	Race.Type.ELF:    Color("#2f5d5096"),
	Race.Type.DWARF:  Color("#5a3a2296"),
	Race.Type.DEMON:  Color("#5a1f1f96"),
}

@onready var art: TextureRect          = $Art
@onready var name_label: Label         = $NameLabel
@onready var cost_label: Label         = $CostLabel
@onready var attack_label: Label       = $AttackLabel
@onready var health_label: Label       = $HealthLabel
@onready var desc_label: RichTextLabel = $DescLabel
@onready var border: TextureRect       = $BorderFrame
@onready var text_background: Control  = $TextBackground
@onready var rarity_gem: TextureRect   = $RarityGem

var data: CardData
var drag_enabled := true

# [FIX] Référence injectée à la main — plus de get_parent().get_parent() fragile
var hand_ref: Control = null

# Drag state
var dragging          := false
var original_position : Vector2
var original_scale    : Vector2
var drag_start_mouse  : Vector2
var last_drag_mouse   : Vector2
var drag_rotation     := 0.0
var _drag_board_minion: Control = null
var _drag_released    := false

# [FIX] Référence cachée en début de drag — plus de get_tree().current_scene dans _process
var _battle: Node = null

var can_drag_check: Callable = Callable()
var create_drag_preview: Callable = Callable()

var _race_bg_style := StyleBoxFlat.new()

func _ready() -> void:
	text_background.add_theme_stylebox_override("panel", _race_bg_style)
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_PASS

# ─── Données ──────────────────────────────────────────────────────────────────

func set_data(new_data: CardData) -> void:
	if new_data == null:
		push_warning("Card.set_data: card_data est null, carte ignorée")
		return
	data = new_data
	update_display()
func update_display() -> void:
	name_label.text   = data.card_name
	cost_label.text   = str(data.cost)
	attack_label.text = str(data.attack)
	health_label.text = str(data.health)

	var is_minion := data.card_type == "Minion"
	attack_label.visible = is_minion
	health_label.visible = is_minion

	if not data.flavour_text.is_empty() and data.description.is_empty():
		desc_label.text = "[center][font_size=10][i]" + data.flavour_text + "[/i][/font_size][/center]"
	elif not data.flavour_text.is_empty():
		desc_label.text = data.description + "\n\n[font_size=10][i]" + data.flavour_text + "[/i][/font_size]"
	else:
		desc_label.text = data.description

	if data.texture:
		art.texture = data.texture

	if BORDER_TEXTURES.has(data.race):
		border.texture = BORDER_TEXTURES[data.race]
	else:
		push_warning("Pas de bordure pour la race: %s" % Race.get_race_name(data.race))

	_apply_race_style()
	_apply_rarity_style()

func _apply_rarity_style() -> void:
	var color : Color = RARITY_COLORS.get(data.rarity, Color.WHITE)
	color.a = 1.0
	rarity_gem.modulate = color

func _apply_race_style() -> void:
	_race_bg_style.bg_color = RACE_COLORS.get(data.race, Color.WHITE)
	text_background.queue_redraw()

# ─── Drag & Drop ──────────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if not drag_enabled:
		return
	if not (event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed):
		return

	var can_drag: bool = not can_drag_check.is_valid() or can_drag_check.call(data)
	if not can_drag:
		get_viewport().set_input_as_handled()
		return

	var battle: Node = get_tree().current_scene

	if data.card_type == "Minion":
		if battle and battle.has_method("get_allowed_rows_for_card"):
			var allowed_rows = battle.call("get_allowed_rows_for_card", data)
			var can_place := false
			for r in allowed_rows:
				if battle.call("can_summon_to_row", true, r):
					can_place = true
					break
			if not can_place:
				get_viewport().set_input_as_handled()
				return

	original_position = position
	original_scale    = scale
	drag_start_mouse  = get_global_mouse_position()
	last_drag_mouse   = drag_start_mouse
	drag_rotation     = 0.0
	dragging          = true
	_drag_released    = false
	z_index           = 100
	visible           = false

	# [FIX] On cache la référence battle UNE fois au début du drag
	_battle = battle

	if create_drag_preview.is_valid():
		_drag_board_minion = create_drag_preview.call(data)

	_set_children_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	drag_started.emit()
	get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not dragging:
		return

	var current_mouse := get_global_mouse_position()
	var delta_x := current_mouse.x - last_drag_mouse.x
	drag_rotation = clamp(drag_rotation + delta_x * 0.4, -20.0, 20.0)
	drag_rotation = lerpf(drag_rotation, 0.0, 0.1)
	last_drag_mouse = current_mouse

	if _drag_board_minion:
		_drag_board_minion.global_position = current_mouse - Vector2(50, 75)
		_drag_board_minion.rotation_degrees = drag_rotation

	# [FIX] Utilise _battle mis en cache — plus d'appel à get_tree().current_scene chaque frame
	if _battle and _battle.get("drop_system"):
		_battle.drop_system.update_player_drop_highlight(data, get_viewport().get_mouse_position(), true)

func _input(event: InputEvent) -> void:
	if not dragging:
		return
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		_on_drag_released()
		get_viewport().set_input_as_handled()

func _on_drag_released() -> void:
	# [FIX] Guard retiré — set_input_as_handled() dans _input suffit à éviter le double appel
	dragging      = false
	drag_rotation = 0.0

	if _drag_board_minion:
		_drag_board_minion.queue_free()
		_drag_board_minion = null

	var mouse_pos := get_viewport().get_mouse_position()

	var drop_row := ""
	if _battle and _battle.get("drop_system"):
		drop_row = _battle.drop_system.get_player_drop_row_at(mouse_pos, data)

	if not drop_row.is_empty():
		var insert_index := -1
		if _battle and _battle.get("drop_system"):
			insert_index = _battle.drop_system.get_player_drop_index_at(mouse_pos, drop_row)
			_battle.drop_system.clear_player_drop_highlight()
		_battle = null
		card_clicked.emit(data, drop_row, insert_index)
		drag_ended.emit()
		queue_free()
		return

	if _battle and _battle.get("drop_system"):
		_battle.drop_system.clear_player_drop_highlight()
	_battle = null
	_restore_in_hand()
	drag_ended.emit()

# [FIX] _restore_in_hand utilise hand_ref injecté — plus de navigation par get_parent().get_parent()
func _restore_in_hand() -> void:
	visible = true
	rotation_degrees = 0.0
	_set_children_mouse_filter(Control.MOUSE_FILTER_PASS)
	if hand_ref and hand_ref.has_method("_update_hand_layout"):
		hand_ref._update_hand_layout()

# [FIX] _update_hand_layout et _return_to_hand fusionnés dans _restore_in_hand
# Les deux faisaient la même chose avec une navigation fragile — supprimés

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

func show_back(show_card_back: bool) -> void:
	if show_card_back:
		art.texture = CARD_BACK_TEX
		name_label.hide()
		cost_label.hide()
		attack_label.hide()
		health_label.hide()
		desc_label.hide()
		border.hide()
		rarity_gem.hide()
		text_background.hide()
	else:
		if data:
			update_display()
		name_label.show()
		cost_label.show()
		attack_label.show()
		health_label.show()
		desc_label.show()
		border.show()
		rarity_gem.show()
		text_background.show()
