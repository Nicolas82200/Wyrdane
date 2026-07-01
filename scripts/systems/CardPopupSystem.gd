extends RefCounted
class_name CardPopupSystem

const CARD_SCENE = preload("res://scenes/card/Card.tscn")
const DISPLAY_DURATION = 3

var battle
var _popup_layer: CanvasLayer
var _persistent_card: Card = null

func init(_battle) -> void:
	battle = _battle
	_popup_layer = CanvasLayer.new()
	_popup_layer.layer = 10
	battle.add_child(_popup_layer)

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

func show_card_popup(card_data: CardData) -> void:
	if card_data == null:
		return
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_layer.add_child(dim)

	var card: Card = CARD_SCENE.instantiate()
	_popup_layer.add_child(card)
	card.set_non_interactive()
	card.set_data(card_data)

	await card.get_tree().process_frame
	card.pivot_offset = card.size / 2.0
	card.position = (battle.get_viewport().get_visible_rect().size - card.size) / 2.0

	card.scale = Vector2(0.5, 0.5)
	card.modulate.a = 0.0
	dim.modulate.a = 0.0
	var t_in = card.create_tween().set_parallel(true)
	t_in.tween_property(card, "scale", Vector2(1.1, 1.1), 0.2)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t_in.tween_property(card, "modulate:a", 1.0, 0.15)
	t_in.tween_property(dim, "modulate:a", 1.0, 0.15)
	await t_in.finished
	var settle = card.create_tween()
	settle.tween_property(card, "scale", Vector2(1.0, 1.0), 0.08)
	await settle.finished

	await battle.get_tree().create_timer(DISPLAY_DURATION).timeout

	var t_out = card.create_tween().set_parallel(true)
	t_out.tween_property(card, "scale", Vector2(0.8, 0.8), 0.15)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t_out.tween_property(card, "modulate:a", 0.0, 0.15)
	t_out.tween_property(dim, "modulate:a", 0.0, 0.15)
	await t_out.finished
	card.queue_free()
	dim.queue_free()

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

	var viewport_size: Vector2 = battle.get_viewport().get_visible_rect().size
	card.position = Vector2(24.0, (viewport_size.y - card.size.y) / 2.0)
	card.pivot_offset = card.size / 2.0
	card.position.x = -card.size.x
	card.modulate.a = 0.0
	_persistent_card = card

	var t = card.create_tween().set_parallel(true)
	t.tween_property(card, "position:x", 24.0, 0.25)\
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
