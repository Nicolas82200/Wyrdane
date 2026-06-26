extends Control
class_name Hand

signal card_played(card_data: CardData, row: String, insert_index: int)
signal drag_started
signal drag_ended

@onready var container = $CardsContainer
@onready var preview   = $CardPreview

const CARD_SCENE   = preload("res://scenes/card/Card.tscn")
const NORMAL_SCALE := Vector2(0.75, 0.75)
const SPACING      := 100.0
const COMPACT_SPACING := 20.0
const ARC_STRENGTH := 20.0

var _base_positions: Dictionary = {}
var _is_compact: bool = false
var can_play_check: Callable = Callable()
var create_drag_preview: Callable = Callable()

func _ready() -> void:
	preview.hide()

func set_hand(cards: Array[CardData], animate_last: bool = false, deck_origin: Vector2 = Vector2.ZERO) -> void:
	if not animate_last:
		# Cas normal : recrée tout sans animation
		for c in container.get_children():
			c.queue_free()
		_base_positions.clear()

		await get_tree().process_frame

		for card_data in cards:
			var card: Card = CARD_SCENE.instantiate()
			container.add_child(card)
			card.set_data(card_data)
			card.scale = NORMAL_SCALE
			_connect_card(card)

		await get_tree().process_frame

		for card in container.get_children():
			card.pivot_offset = Vector2(card.size.x / 2.0, card.size.y)
			card.visible = true

		_update_hand_layout(false)
		return

	# Cas pioche : ajoute seulement la nouvelle carte, garde les autres intactes
	var new_card_data :CardData= cards.back()
	var new_card: Card = CARD_SCENE.instantiate()
	new_card.visible = false
	container.add_child(new_card)
	new_card.set_data(new_card_data)
	new_card.scale = NORMAL_SCALE
	_connect_card(new_card)

	await get_tree().process_frame
	new_card.pivot_offset = Vector2(new_card.size.x / 2.0, new_card.size.y)

	# Recalcule les positions et anime les cartes existantes
	_update_hand_layout(false)

	# Anime les cartes existantes vers leur nouvelle position en douceur
	var children := container.get_children()
	for i in range(children.size() - 1):  # toutes sauf la dernière
		var card = children[i]
		var tween_existing := create_tween()
		tween_existing.set_parallel(true)
		tween_existing.tween_property(card, "position", _base_positions[card], 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween_existing.tween_property(card, "scale",    card.scale,            0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Animation fantôme pour la carte piochée
	var final_pos   = new_card.global_position
	var final_scale = new_card.scale

	var ghost: Card = CARD_SCENE.instantiate()
	get_tree().current_scene.add_child(ghost)
	ghost.set_data(new_card_data)
	ghost.drag_enabled = false
	ghost.show_back(true)
	ghost.scale    = final_scale
	ghost.modulate = Color.WHITE
	ghost.z_index  = 100
	ghost.visible  = false

	await get_tree().process_frame

	ghost.global_position = deck_origin - Vector2(
		ghost.size.x * final_scale.x / 2.0,
		ghost.size.y * final_scale.y / 2.0
	)
	ghost.visible = true

	var mid_pos := Vector2(
		(deck_origin.x + final_pos.x) / 2.0,
		(deck_origin.y + final_pos.y) / 2.0 - 100
	)

	var tween := create_tween()
	tween.set_parallel(false)
	tween.tween_property(ghost, "global_position", mid_pos,       0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost, "scale:x",         0.0,           0.1).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(func(): ghost.show_back(false))
	tween.tween_property(ghost, "scale:x",         final_scale.x, 0.1).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(ghost, "global_position", final_pos,     0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		new_card.visible = true
		ghost.queue_free()
	)
		

func _on_card_clicked(card_data: CardData, row: String = "Front", insert_index: int = -1) -> void:
	card_played.emit(card_data, row, insert_index)

func _on_card_hover(card: Card) -> void:
	var battle = get_tree().current_scene
	if battle and battle.has_method("is_dragging_card") and battle.call("is_dragging_card"):
		return
	for c in container.get_children():
		if c is Card and c.dragging:
			return
	if card.dragging:
		return
	preview.set_data(card.data)
	preview.scale   = Vector2(1.1, 1.1)
	preview.z_index = 100
	var pos := card.global_position
	preview.global_position = Vector2(
		pos.x - preview.size.x * 0.25,
		pos.y - preview.size.y * 1.0
	)
	preview.show()
	card.drag_started.connect(func(): preview.hide())

func _on_card_unhover() -> void:
	preview.hide()

func set_compact(compact: bool) -> void:
	if _is_compact == compact:
		return
	_is_compact = compact
	
	# Animate the compacting/expanding transition smoothly
	var cards := container.get_children()
	var count := cards.size()
	if count == 0:
		return
	
	var viewport           := get_viewport_rect().size
	var max_width          := viewport.x * 0.3
	var reduction_per_card := 0.04
	var hand_bottom        := size.y - 30.0
	var scale_factor       := 1.0 - (count - 1) * reduction_per_card
	scale_factor = clamp(scale_factor, 0.55, 1.2)

	var target_spacing := COMPACT_SPACING if compact else SPACING
	if count > 1:
		target_spacing = min(target_spacing, max_width / float(count - 1)) if not compact else COMPACT_SPACING
	target_spacing = max(target_spacing, SPACING * 0.3) if not compact else COMPACT_SPACING
	
	# Animate each card to its new position
	for i in range(count):
		var card   = cards[i]
		var offset := float(i) - float(count - 1) / 2.0
		var norm: float = offset / max(float(count - 1) / 2.0, 1.0)
		var pos := Vector2(
			80.0 + i * target_spacing,
			hand_bottom - card.size.y + (norm * norm) * ARC_STRENGTH
		)
		_base_positions[card] = pos
		
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(card, "position", pos, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func is_compact() -> bool:
	return _is_compact

func _update_hand_layout(animated: bool = false) -> void:
	var cards := container.get_children()
	var count := cards.size()
	if count == 0:
		return

	var viewport           := get_viewport_rect().size
	var max_width          := viewport.x * 0.3
	var reduction_per_card := 0.04
	# Relatif à Hand, pas au viewport entier
	var hand_bottom        := size.y - 30.0
	var scale_factor       := 1.0 - (count - 1) * reduction_per_card
	scale_factor = clamp(scale_factor, 0.55, 1.2)
	var hand_scale := Vector2(scale_factor, scale_factor)

	var spacing := SPACING if not _is_compact else COMPACT_SPACING
	if count > 1:
		spacing = min(spacing, max_width / float(count - 1)) if not _is_compact else COMPACT_SPACING
	spacing = max(spacing, SPACING * 0.3) if not _is_compact else COMPACT_SPACING

	# Compute horizontal start so the hand is centered according to spacing and card width
	var left_margin := 80.0
	var start_x := left_margin
	if count > 0:
		start_x = left_margin

	for i in range(count):
		var card   = cards[i]
		var offset := float(i) - float(count - 1) / 2.0
		var norm: float = offset / max(float(count - 1) / 2.0, 1.0)
		var pos := Vector2(
			start_x + i * spacing,
			hand_bottom - card.size.y + (norm * norm) * ARC_STRENGTH
		)
		_base_positions[card] = pos
		card.z_index  = i
		card.scale    = hand_scale
		card.position = pos

		if animated:
			var tween := create_tween()
			tween.set_parallel(true)
			tween.tween_property(card, "position", pos,        0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(card, "scale",    hand_scale, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			var tween := create_tween()
			tween.set_parallel(true)

			tween.tween_property(
	card,
	"position",
	pos,
	0.25
)

			tween.tween_property(
	card,
	"scale",
	hand_scale,
	0.25
)
			card.position = pos
			
func _connect_card(card: Card) -> void:
	card.card_clicked.connect(_on_card_clicked)
	card.drag_started.connect(func(): drag_started.emit())
	card.drag_ended.connect(func(): drag_ended.emit())
	card.mouse_entered.connect(_on_card_hover.bind(card))
	card.mouse_exited.connect(_on_card_unhover)
	for child in card.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_PASS
	if can_play_check.is_valid():
		card.can_drag_check = can_play_check
	if create_drag_preview.is_valid():
		card.create_drag_preview = create_drag_preview
