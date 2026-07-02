extends RefCounted
class_name CardPopupSystem

const CARD_SCENE = preload("res://scenes/card/Card.tscn")
const DISPLAY_DURATION = 2.0
const LEFT_MARGIN = 24.0

var battle
var _popup_layer: CanvasLayer
var _persistent_card: Card = null
var _popup_queue: Array = []
var _popup_active: bool = false

func init(_battle) -> void:
	battle = _battle
	_popup_layer = CanvasLayer.new()
	_popup_layer.layer = 10
	battle.add_child(_popup_layer)

# Emplacement commun de toutes les popups : à gauche de l'écran, centré verticalement
func _get_left_slot_position(card_size: Vector2) -> Vector2:
	var viewport_size: Vector2 = battle.get_viewport().get_visible_rect().size
	return Vector2(LEFT_MARGIN, (viewport_size.y - card_size.y) / 2.0)

# ── Popup temporaire (effets de combat) ───────────────────────────────────────
func get_targeting_popup_tip() -> Vector2:
	if _persistent_card == null or not is_instance_valid(_persistent_card):
		return Vector2.ZERO
	# Convertit depuis l'espace CanvasLayer vers l'espace viewport
	var screen_pos: Vector2 = _persistent_card.get_screen_position()
	return Vector2(
		screen_pos.x + _persistent_card.size.x,
		screen_pos.y + _persistent_card.size.y / 2.0
	)

func show_card_popup(card_data: CardData, source_minion: Minion = null) -> void:
	if card_data == null:
		return
	# Capture la position de la source maintenant : le serviteur peut avoir
	# quitté le plateau au moment où la popup sort de la file d'attente
	var origin := Vector2.ZERO
	var has_origin := false
	if source_minion != null:
		var visual: BoardMinion = battle.board_visual_system.get_visual(source_minion)
		if visual != null and is_instance_valid(visual):
			origin = visual.get_screen_position() + visual.size / 2.0
			has_origin = true
	_popup_queue.append({"card_data": card_data, "origin": origin, "has_origin": has_origin})
	if not _popup_active:
		_process_popup_queue()

func _process_popup_queue() -> void:
	_popup_active = true
	while not _popup_queue.is_empty():
		var entry: Dictionary = _popup_queue.pop_front()
		await _display_popup(entry["card_data"], entry["origin"], entry["has_origin"])
	_popup_active = false

func _display_popup(card_data: CardData, origin: Vector2, has_origin: bool) -> void:
	var card: Card = CARD_SCENE.instantiate()
	_popup_layer.add_child(card)
	card.set_non_interactive()
	card.set_data(card_data)

	await card.get_tree().process_frame
	card.pivot_offset = card.size / 2.0
	var target_pos: Vector2 = _get_left_slot_position(card.size)
	card.modulate.a = 0.0

	if has_origin:
		# Arrive depuis l'emplacement de la carte sur le plateau
		card.position = origin - card.size / 2.0
		card.scale = Vector2(0.3, 0.3)
		var t_in = card.create_tween().set_parallel(true)
		t_in.tween_property(card, "position", target_pos, 0.4)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t_in.tween_property(card, "scale", Vector2(1.0, 1.0), 0.4)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t_in.tween_property(card, "modulate:a", 1.0, 0.15)
		await t_in.finished
	else:
		# Pas de source sur le plateau : apparition sur place
		card.position = target_pos
		card.scale = Vector2(0.5, 0.5)
		var t_in = card.create_tween().set_parallel(true)
		t_in.tween_property(card, "scale", Vector2(1.1, 1.1), 0.2)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		t_in.tween_property(card, "modulate:a", 1.0, 0.15)
		await t_in.finished
		var settle = card.create_tween()
		settle.tween_property(card, "scale", Vector2(1.0, 1.0), 0.08)
		await settle.finished

	await battle.get_tree().create_timer(DISPLAY_DURATION).timeout

	var t_out = card.create_tween().set_parallel(true)
	t_out.tween_property(card, "scale", Vector2(0.8, 0.8), 0.15)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t_out.tween_property(card, "modulate:a", 0.0, 0.15)
	await t_out.finished
	card.queue_free()

# ── Popup persistante (pendant le ciblage) ────────────────────────────────────

func show_targeting_popup(card_data: CardData) -> void:
	hide_targeting_popup()
	if card_data == null:
		return

	var card: Card = CARD_SCENE.instantiate()
	_popup_layer.add_child(card)
	card.set_non_interactive()
	card.set_data(card_data)

	await card.get_tree().process_frame

	card.position = _get_left_slot_position(card.size)
	card.pivot_offset = card.size / 2.0
	card.position.x = -card.size.x
	card.modulate.a = 0.0
	_persistent_card = card

	var t = card.create_tween().set_parallel(true)
	t.tween_property(card, "position:x", LEFT_MARGIN, 0.25)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(card, "modulate:a", 1.0, 0.2)
	await t.finished

func hide_targeting_popup() -> void:
	if _persistent_card == null or not is_instance_valid(_persistent_card):
		_persistent_card = null
		return
	var card := _persistent_card
	_persistent_card = null
	var t = card.create_tween().set_parallel(true)
	t.tween_property(card, "position:x", -card.size.x, 0.2)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(card, "modulate:a", 0.0, 0.15)
	await t.finished
	card.queue_free()
