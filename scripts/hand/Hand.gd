extends Control
signal card_played(card_data)

@onready var container = $CardsContainer
@onready var preview   = $CardPreview  # un Card instancié en dehors du container

const CARD_SCENE    = preload("res://scenes/card/Card.tscn")
const NORMAL_SCALE  := Vector2(0.55, 0.55)
const SPACING       := 80.0
const ARC_STRENGTH  := 40.0
const MAX_ROTATION  := 12.0

var _base_positions: Dictionary = {}

func _ready() -> void:
	preview.hide()

func set_hand(cards: Array[CardData]) -> void:
	for c in container.get_children():
		c.queue_free()
	_base_positions.clear()
	await get_tree().process_frame
	for card_data in cards:
		var card: Card = CARD_SCENE.instantiate()
		container.add_child(card)
		card.set_data(card_data)
		card.scale = NORMAL_SCALE
		card.card_clicked.connect(_on_card_clicked)
		card.mouse_entered.connect(_on_card_hover.bind(card))
		card.mouse_exited.connect(_on_card_unhover)
		for child in card.get_children():
			if child is Control:
				child.mouse_filter = Control.MOUSE_FILTER_PASS
	await get_tree().process_frame
	for card in container.get_children():
		card.pivot_offset = Vector2(card.size.x / 2.0, card.size.y * 2.0)
	_update_hand_layout()

func _on_card_clicked(card_data: CardData) -> void:
	card_played.emit(card_data)

func _on_card_hover(card: Card) -> void:
	preview.set_data(card.data)
	preview.scale    = Vector2(1.0, 1.0)
	preview.z_index  = 100
	# Position au-dessus de la carte hovérée
	var pos := card.global_position
	preview.global_position = Vector2(
		pos.x - preview.size.x * 0.2,
		pos.y - preview.size.y * 1
	)
	preview.show()

func _on_card_unhover() -> void:
	preview.hide()

func _update_hand_layout() -> void:
	var cards      := container.get_children()
	var count      := cards.size()
	if count == 0:
		return
	var viewport   := get_viewport_rect().size
	var center_x   := viewport.x * 0.5
	var base_y     := viewport.y * 0.4
	var card_width := 200.0 * NORMAL_SCALE.x
	var start_x    := center_x - (float(count - 1) * SPACING) / 2.0 - card_width / 2.0
	for i in range(count):
		var offset      := float(i) - float(count - 1) / 2.0
		var norm: float  = offset / max(float(count - 1) / 2.0, 1.0)
		var pos := Vector2(
			start_x + i * SPACING,
			base_y + (norm * norm) * ARC_STRENGTH
		)
		cards[i].scale            = NORMAL_SCALE
		cards[i].rotation_degrees = norm * MAX_ROTATION
		cards[i].position         = pos
		cards[i].z_index          = i
		_base_positions[cards[i]] = pos
