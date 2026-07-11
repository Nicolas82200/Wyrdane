# Hand.gd
extends Control
class_name Hand

signal card_played(card_data: CardData, row: String, insert_index: int)
signal drag_started
signal drag_ended
signal mulligan_card_clicked(index: int, card_data: CardData)

@onready var container = $CardsContainer
@onready var preview   = $CardPreview

const CARD_SCENE      := preload("res://scenes/card/Card.tscn")
const NORMAL_SCALE    := Vector2(0.75, 0.75)
const SPACING         := 100.0
const COMPACT_SPACING := 20.0
const ARC_STRENGTH    := 20.0

var _base_positions:    Dictionary     = {}
var _is_compact:        bool           = false
var can_play_check:     Callable       = Callable()
var create_drag_preview: Callable      = Callable()
# Coût effectif d'une carte (remises de mana comprises), injecté par Battle.
# Non défini hors bataille : le coût de base est alors affiché.
var display_cost:       Callable       = Callable()
var _keyword_tooltips:  Array[Control] = []
var _tooltip_layer:     CanvasLayer    = null
var _hovering:          bool           = false
# Phase de mulligan : un clic sur une carte la remplace directement (pas de
# drag). Appliqué à chaque carte connectée, y compris celles créées après coup.
var _mulligan_mode:     bool           = false

# Référence Battle mise en cache
var _battle: Node = null

func _ready() -> void:
	preview.hide()
	_battle = get_tree().current_scene

# ─── Main ─────────────────────────────────────────────────────────────────────

func set_hand(cards: Array[CardData], animate_last: bool = false, deck_origin: Vector2 = Vector2.ZERO) -> void:
	if not animate_last:
		await _set_hand_instant(cards)
	else:
		await _set_hand_animated(cards, deck_origin)

func _set_hand_instant(cards: Array[CardData]) -> void:
	for c in container.get_children():
		c.queue_free()
	_base_positions.clear()
	await get_tree().process_frame

	for card_data in cards:
		if card_data == null:
			push_warning("Hand: carte nulle ignorée")
			continue
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

func _set_hand_animated(cards: Array[CardData], deck_origin: Vector2) -> void:
	var new_card_data: CardData = cards.back()
	var new_card: Card = CARD_SCENE.instantiate()
	new_card.visible = false
	container.add_child(new_card)
	new_card.set_data(new_card_data)
	new_card.scale = NORMAL_SCALE
	_connect_card(new_card)
	await get_tree().process_frame
	new_card.pivot_offset = Vector2(new_card.size.x / 2.0, new_card.size.y)
	_update_hand_layout(false)

	var children := container.get_children()
	for i in range(children.size() - 1):
		var card = children[i]
		var tween_existing := create_tween()
		tween_existing.set_parallel(true)
		tween_existing.tween_property(card, "position", _base_positions[card], 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween_existing.tween_property(card, "scale",    card.scale,            0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var final_pos   := new_card.global_position
	var final_scale := new_card.scale
	var ghost: Card = CARD_SCENE.instantiate()
	_battle.add_child(ghost)
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

# ─── Carte cliquée ────────────────────────────────────────────────────────────

func _on_card_clicked(card_data: CardData, row: String = "Front", insert_index: int = -1) -> void:
	card_played.emit(card_data, row, insert_index)

# ─── Mulligan ─────────────────────────────────────────────────────────────────

func set_mulligan_mode(active: bool) -> void:
	_mulligan_mode = active
	for card in container.get_children():
		if card is Card:
			card.mulligan_mode = active

# L'index dans container (== index dans battle.hand_cards, même ordre) identifie
# la carte sans ambiguïté : deux exemplaires d'une même carte partagent la même
# ressource CardData, donc comparer par égalité de données désignerait toujours
# le premier exemplaire au lieu de celui réellement cliqué.
func _on_mulligan_card_clicked(card: Card) -> void:
	var index: int = container.get_children().find(card)
	if index != -1:
		mulligan_card_clicked.emit(index, card.data)

# Remplace en place la carte à cet index, avec un effet de retournement (comme
# la pioche animée), sans reconstruire toute la main.
func flip_replace_at(index: int, new_data: CardData) -> void:
	var children := container.get_children()
	if index < 0 or index >= children.size():
		return
	var card: Card = children[index]
	var target_scale_x: float = card.scale.x
	var tween := create_tween()
	tween.tween_property(card, "scale:x", 0.0, 0.12).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(func():
		card.set_data(new_data)
		if display_cost.is_valid():
			card.set_display_cost(display_cost.call(new_data))
	)
	tween.tween_property(card, "scale:x", target_scale_x, 0.12).set_trans(Tween.TRANS_LINEAR)

# ─── Hover ────────────────────────────────────────────────────────────────────

func _on_card_hover(card: Card) -> void:
	_hovering = true
	if _battle and _battle.has_method("is_dragging_card") and _battle.call("is_dragging_card"):
		return
	for c in container.get_children():
		if c is Card and c.dragging:
			return
	if card.dragging:
		return
	preview.set_data(card.data)
	if display_cost.is_valid():
		preview.set_display_cost(display_cost.call(card.data))
	preview.scale   = Vector2(1.1, 1.1)
	preview.z_index = 100
	var pos := card.global_position
	preview.global_position = Vector2(
		pos.x - preview.size.x * 0.25,
		pos.y - preview.size.y * 1.0
	)
	preview.show()
	card.drag_started.connect(func(): preview.hide())
	await get_tree().process_frame
	await get_tree().process_frame
	if not _hovering or not is_instance_valid(card) or card.dragging:
		return
	var tooltip_x: float = preview.global_position.x + preview.size.x * 1.1 + 15
	var tooltip_y: float = preview.global_position.y
	await _show_keyword_tooltips(card.data, tooltip_x, tooltip_y)

func _on_card_unhover() -> void:
	_hovering = false
	preview.hide()
	_hide_keyword_tooltips()

# ─── Tooltips — délégués à TooltipData ───────────────────────────────────────

func _show_keyword_tooltips(card_data: CardData, base_x: float, base_y: float) -> void:
	_hide_keyword_tooltips()
	if card_data == null:
		return
	_tooltip_layer = CanvasLayer.new()
	_tooltip_layer.layer = 20
	_battle.add_child(_tooltip_layer)
	var panels: Array[Control] = TooltipData.build_panels_for_card(card_data, _tooltip_layer)
	await get_tree().process_frame
	for panel in panels:
		if not is_instance_valid(panel):
			continue
		panel.global_position = Vector2(base_x, base_y)
		base_y += panel.size.y + 6
		_keyword_tooltips.append(panel)

func _hide_keyword_tooltips() -> void:
	for tooltip in _keyword_tooltips:
		if is_instance_valid(tooltip):
			tooltip.queue_free()
	_keyword_tooltips.clear()
	if _tooltip_layer and is_instance_valid(_tooltip_layer):
		_tooltip_layer.queue_free()
		_tooltip_layer = null

# ─── Layout ───────────────────────────────────────────────────────────────────

func _compute_layout(cards: Array) -> Dictionary:
	var count := cards.size()
	var viewport           := get_viewport_rect().size
	var max_width          := viewport.x * 0.3
	var reduction_per_card := 0.04
	var scale_factor       :float= clamp(1.0 - (count - 1) * reduction_per_card, 0.55, 1.2)
	var spacing: float     = SPACING if not _is_compact else COMPACT_SPACING
	if count > 1 and not _is_compact:
		spacing = max(min(spacing, max_width / float(count - 1)), SPACING * 0.3)
	return {
		"scale":       Vector2(scale_factor, scale_factor),
		"spacing":     spacing,
		"hand_bottom": size.y - 30.0,
	}

func set_compact(compact: bool) -> void:
	if _is_compact == compact:
		return
	_is_compact = compact
	var cards := container.get_children()
	if cards.is_empty():
		return
	var layout := _compute_layout(cards)
	for i in range(cards.size()):
		var card   = cards[i]
		var norm   := _card_norm(i, cards.size())
		var pos    := _card_position(i, layout, card, norm)
		_base_positions[card] = pos
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(card, "position", pos, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _update_hand_layout(animated: bool = false) -> void:
	var cards := container.get_children()
	if cards.is_empty():
		return
	var layout := _compute_layout(cards)
	for i in range(cards.size()):
		var card = cards[i]
		var norm := _card_norm(i, cards.size())
		var pos  := _card_position(i, layout, card, norm)
		_base_positions[card] = pos
		card.z_index = i
		card.scale   = layout["scale"]
		if animated:
			var tween := create_tween()
			tween.set_parallel(true)
			tween.tween_property(card, "position", pos,             0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(card, "scale",    layout["scale"], 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			card.position = pos

func _card_norm(index: int, count: int) -> float:
	var offset := float(index) - float(count - 1) / 2.0
	return offset / max(float(count - 1) / 2.0, 1.0)

func _card_position(index: int, layout: Dictionary, card: Control, norm: float) -> Vector2:
	return Vector2(
		80.0 + index * layout["spacing"],
		layout["hand_bottom"] - card.size.y + (norm * norm) * ARC_STRENGTH
	)

# ─── Connexions ───────────────────────────────────────────────────────────────

func _relay_drag_started() -> void:
	drag_started.emit()

func _relay_drag_ended() -> void:
	drag_ended.emit()

func _connect_card(card: Card) -> void:
	card.hand_ref = self

	if not card.card_clicked.is_connected(_on_card_clicked):
		card.card_clicked.connect(_on_card_clicked)
	if not card.drag_started.is_connected(_relay_drag_started):
		card.drag_started.connect(_relay_drag_started)
	if not card.drag_ended.is_connected(_relay_drag_ended):
		card.drag_ended.connect(_relay_drag_ended)
	if not card.mouse_entered.is_connected(_on_card_hover):
		card.mouse_entered.connect(_on_card_hover.bind(card))
	if not card.mouse_exited.is_connected(_on_card_unhover):
		card.mouse_exited.connect(_on_card_unhover)
	if not card.mulligan_clicked.is_connected(_on_mulligan_card_clicked):
		card.mulligan_clicked.connect(_on_mulligan_card_clicked.bind(card))
	card.mulligan_mode = _mulligan_mode
	for child in card.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_PASS
	if can_play_check.is_valid():
		card.can_drag_check = can_play_check
	if create_drag_preview.is_valid():
		card.create_drag_preview = create_drag_preview
	if display_cost.is_valid():
		card.set_display_cost(display_cost.call(card.data))

# Réaffiche le coût effectif de chaque carte en main (appelé quand une remise
# de mana apparaît ou expire).
func refresh_costs() -> void:
	if not display_cost.is_valid():
		return
	for card in container.get_children():
		if card is Card and card.data != null and not card.is_queued_for_deletion():
			card.set_display_cost(display_cost.call(card.data))
