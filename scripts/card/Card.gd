extends Control
class_name Card

signal card_clicked(card)

var data: CardData

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

var _rarity_style     := StyleBoxFlat.new()
var _race_bg_style    := StyleBoxFlat.new()
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
	attack_label.text = str(data.attack)  # ← vérifie que cette ligne existe
	health_label.text = str(data.health)  # ← et celle-là
	var is_minion = data.card_type == "Minion"
	attack_label.visible = is_minion
	health_label.visible = is_minion
	attack_label.visible = is_minion
	health_label.visible = is_minion
	desc_label.text   = data.description
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
	print(data.card_name, " race = ", data.race)
	_apply_race_style()
	_apply_rarity_style()

func _get_card_type_label(card_type: String) -> String:
	match card_type:
		"Instant":      return "Sort"
		"Ritual":       return "Rituel"
		"Enchantment":  return "Enchantement"
		_:              return card_type

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

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
		and event.pressed \
		and event.button_index == MOUSE_BUTTON_LEFT:
		card_clicked.emit(data)
