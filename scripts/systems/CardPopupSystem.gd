extends RefCounted
class_name CardPopupSystem

const CARD_SCENE = preload("res://scenes/card/Card.tscn")
# Temps de lecture, popup en place, AVANT que l'effet ne se joue
const READ_HOLD = 0.5
# Temps où la popup reste affichée pendant/après la résolution de l'effet
const DISPLAY_DURATION = 1.0
const LEFT_MARGIN = 24.0

var battle
var _popup_layer: CanvasLayer
var _persistent_card: Card = null
var _popup_queue: Array = []
var _popup_active: bool = false
# Carte de la popup d'effet actuellement affichée (origine de la courbe d'effet)
var _effect_card: Card = null
var _effect_arrow: ArrowOverlay = null

func init(_battle) -> void:
	battle = _battle
	_popup_layer = CanvasLayer.new()
	_popup_layer.layer = 10
	battle.add_child(_popup_layer)
	_effect_arrow = ArrowOverlay.new()
	_popup_layer.add_child(_effect_arrow)

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

# Awaitable : rend la main dès que la popup de CETTE carte est arrivée à
# l'emplacement d'affichage, pour que l'appelant déclenche son effet au même
# moment. La popup reste ensuite affichée puis disparaît en arrière-plan.
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
	var entry := {"card_data": card_data, "origin": origin, "has_origin": has_origin, "shown": false}
	_popup_queue.append(entry)
	if not _popup_active:
		_process_popup_queue()
	while not entry["shown"]:
		await battle.get_tree().process_frame

func _process_popup_queue() -> void:
	_popup_active = true
	while not _popup_queue.is_empty():
		var entry: Dictionary = _popup_queue.pop_front()
		await _display_popup(entry)
	_popup_active = false

func _display_popup(entry: Dictionary) -> void:
	var card_data: CardData = entry["card_data"]
	var origin: Vector2 = entry["origin"]
	var has_origin: bool = entry["has_origin"]
	var card: Card = CARD_SCENE.instantiate()
	_popup_layer.add_child(card)
	card.set_non_interactive()
	card.set_data(card_data)
	# Cette carte devient l'origine des courbes d'effet tracées vers les cibles
	_effect_card = card

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
		# Pas de source sur le plateau (sorts) : glisse depuis le bord gauche
		card.scale = Vector2(1.0, 1.0)
		card.position = target_pos
		card.position.x = -card.size.x
		var t_in = card.create_tween().set_parallel(true)
		t_in.tween_property(card, "position:x", LEFT_MARGIN, 0.3)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t_in.tween_property(card, "modulate:a", 1.0, 0.2)
		await t_in.finished

	# La popup est en place : temps de lecture AVANT de libérer l'effet, pour que
	# le joueur voie la description de l'effet avant qu'il ne se joue.
	await battle.get_tree().create_timer(READ_HOLD).timeout
	entry["shown"] = true

	await battle.get_tree().create_timer(DISPLAY_DURATION).timeout

	var t_out = card.create_tween().set_parallel(true)
	t_out.tween_property(card, "scale", Vector2(0.8, 0.8), 0.15)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t_out.tween_property(card, "modulate:a", 0.0, 0.15)
	await t_out.finished
	if _effect_card == card:
		_effect_card = null
		clear_effect_arrows()
	card.queue_free()

# ── Courbe d'effet : de la popup vers les cibles ──────────────────────────────

# Position du bout de la courbe côté popup (bord droit de la carte d'effet)
func get_effect_popup_tip() -> Vector2:
	if _effect_card == null or not is_instance_valid(_effect_card):
		return Vector2.ZERO
	var screen_pos: Vector2 = _effect_card.get_screen_position()
	return Vector2(
		screen_pos.x + _effect_card.size.x,
		screen_pos.y + _effect_card.size.y / 2.0
	)

# Trace une courbe depuis la popup d'effet vers chaque position de cible, la
# laisse visible un court instant (pour que le joueur voie qui est touché),
# puis rend la main à l'appelant qui applique alors l'effet.
func show_effect_arrows(target_positions: Array, hold: float = 0.35) -> void:
	var from: Vector2 = get_effect_popup_tip()
	if from == Vector2.ZERO or target_positions.is_empty():
		return
	var pts: Array[Vector2] = []
	for p in target_positions:
		pts.append(p)
	_effect_arrow.show_arrows(from, pts)
	await battle.get_tree().create_timer(hold).timeout

func clear_effect_arrows() -> void:
	if _effect_arrow != null and is_instance_valid(_effect_arrow):
		_effect_arrow.hide_arrow()

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
