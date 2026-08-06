extends RefCounted
class_name CardPopupSystem

const CARD_SCENE = preload("res://scenes/card/Card.tscn")
# Temps de lecture, popup en place, AVANT que l'effet ne se joue
const READ_HOLD = 0.4
# Temps où la popup reste affichée pendant/après la résolution de l'effet
const DISPLAY_DURATION = 0.6
# Temps où la popup d'une carte-ressource reste affichée avant de se désintégrer
# vers le pool de mana (voir show_resource_popup / _absorb_resource_popup)
const RESOURCE_HOLD = 0.5
const LEFT_MARGIN = 24.0
# File d'attente façon MTG Arena : une seule popup « se joue » à la fois à
# l'emplacement principal ; les suivantes patientent empilées au-dessus,
# réduites et assombries. Un nouvel effet déclenché passe DEVANT la file :
# le plus récent se joue en premier.
const MAX_STACKED = 4
const STACK_PEEK = 84.0
const STACK_SCALE = 0.85
const STACK_DIM = 0.6

var battle
var _popup_layer: CanvasLayer
var _persistent_card: Card = null
# Popups en attente, index 0 = la prochaine à se jouer (la plus récente)
var _pending: Array = []
var _popup_active: bool = false
# Popup en cours de résolution à l'emplacement principal
var _active_card: Card = null
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

# Awaitable : rend la main dès que la popup de CETTE carte se joue à
# l'emplacement principal, pour que l'appelant déclenche son effet au même
# moment. En attendant son tour, la popup patiente dans la pile visible.
func show_card_popup(card_data: CardData, source_minion: Minion = null) -> void:
	if card_data == null:
		return
	# Capture la position de la source maintenant : le serviteur peut avoir
	# quitté le plateau au moment où la popup se joue
	var origin := Vector2.ZERO
	var has_origin := false
	if source_minion != null:
		var visual: BoardMinion = battle.board_visual_system.get_visual(source_minion)
		if visual != null and is_instance_valid(visual):
			origin = visual.get_screen_position() + visual.size / 2.0
			has_origin = true

	var card: Card = CARD_SCENE.instantiate()
	_popup_layer.add_child(card)
	card.set_non_interactive()
	card.set_data(card_data)
	await card.get_tree().process_frame
	card.pivot_offset = card.size / 2.0
	# La popup active reste dessinée au-dessus des nouvelles arrivantes
	if _active_card != null and is_instance_valid(_active_card):
		_popup_layer.move_child(card, _active_card.get_index())

	# Position de départ : depuis la carte source sur le plateau, sinon
	# depuis le bord gauche de l'écran (sorts)
	card.modulate.a = 0.0
	if has_origin:
		card.position = origin - card.size / 2.0
		card.scale = Vector2(0.3, 0.3)
	else:
		card.position = _waiting_slot_position(0, card.size)
		card.position.x = -card.size.x
		card.scale = Vector2(STACK_SCALE, STACK_SCALE)

	var entry := {"card": card, "shown": false}
	# Un nouvel effet déclenché passe DEVANT la file : il se jouera en premier
	_pending.push_front(entry)
	_reflow_pending()
	if not _popup_active:
		_process_popup_queue()
	while not entry["shown"]:
		await battle.get_tree().process_frame

# Popup d'une carte-ressource jouée : même emplacement/mise en scène que
# show_card_popup (glisse depuis la gauche, temps de lecture des effets), mais
# se termine par une désintégration vers le pool de mana de sa race au lieu
# d'un fondu — voir _absorb_resource_popup.
func show_resource_popup(card_data: CardData) -> void:
	if card_data == null:
		return
	var card: Card = CARD_SCENE.instantiate()
	_popup_layer.add_child(card)
	card.set_non_interactive()
	card.set_data(card_data)
	await card.get_tree().process_frame
	card.pivot_offset = card.size / 2.0
	if _active_card != null and is_instance_valid(_active_card):
		_popup_layer.move_child(card, _active_card.get_index())

	card.modulate.a = 0.0
	card.position = _waiting_slot_position(0, card.size)
	card.position.x = -card.size.x
	card.scale = Vector2(STACK_SCALE, STACK_SCALE)

	var entry := {"card": card, "shown": false, "kind": "resource", "card_data": card_data}
	_pending.push_front(entry)
	_reflow_pending()
	if not _popup_active:
		_process_popup_queue()
	while not entry["shown"]:
		await battle.get_tree().process_frame

# Joue les popups une par une ; les arrivées pendant la résolution sont
# insérées en tête de _pending et seront donc jouées avant les plus anciennes
func _process_popup_queue() -> void:
	_popup_active = true
	while not _pending.is_empty():
		var entry: Dictionary = _pending.pop_front()
		await _play_popup(entry)
	_popup_active = false

# Emplacement d'attente : empilé au-dessus de l'emplacement principal, le
# bandeau de nom de chaque popup restant visible
func _waiting_slot_position(index: int, card_size: Vector2) -> Vector2:
	var pos := _get_left_slot_position(card_size)
	pos.y -= STACK_PEEK * (1 + mini(index, MAX_STACKED - 1))
	return pos

func _kill_popup_tween(card: Card) -> void:
	if card.has_meta("popup_tween"):
		var prev: Tween = card.get_meta("popup_tween")
		if prev != null and prev.is_valid():
			prev.kill()

# Replace chaque popup en attente sur son emplacement dans la pile
func _reflow_pending() -> void:
	for i in _pending.size():
		var card: Card = _pending[i]["card"]
		if not is_instance_valid(card):
			continue
		_kill_popup_tween(card)
		var t = card.create_tween().set_parallel(true)
		card.set_meta("popup_tween", t)
		t.tween_property(card, "position", _waiting_slot_position(i, card.size), 0.25)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.tween_property(card, "scale", Vector2(STACK_SCALE, STACK_SCALE), 0.25)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.tween_property(card, "modulate:a", STACK_DIM, 0.25)

# Joue une popup : descend à l'emplacement principal, temps de lecture,
# libère l'effet, reste affichée, puis s'efface pendant que la suivante arrive
func _play_popup(entry: Dictionary) -> void:
	var card: Card = entry["card"]
	if not is_instance_valid(card):
		entry["shown"] = true
		return
	var is_resource: bool = entry.get("kind", "") == "resource"
	_active_card = card
	if not is_resource:
		# Cette carte devient l'origine des courbes d'effet tracées vers les cibles
		_effect_card = card
	# Dessinée au-dessus des popups en attente
	_popup_layer.move_child(card, _popup_layer.get_child_count() - 1)
	_kill_popup_tween(card)
	var t_in = card.create_tween().set_parallel(true)
	card.set_meta("popup_tween", t_in)
	t_in.tween_property(card, "position", _get_left_slot_position(card.size), 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t_in.tween_property(card, "scale", Vector2(1.0, 1.0), 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t_in.tween_property(card, "modulate:a", 1.0, 0.15)
	await t_in.finished

	# La popup est en place : temps de lecture AVANT de libérer l'effet, pour que
	# le joueur voie la description de l'effet avant qu'il ne se joue.
	await battle.get_tree().create_timer(READ_HOLD).timeout
	entry["shown"] = true

	if is_resource:
		await battle.get_tree().create_timer(RESOURCE_HOLD).timeout
		_active_card = null
		_absorb_resource_popup(card, entry["card_data"])
		return

	await battle.get_tree().create_timer(DISPLAY_DURATION).timeout

	if _effect_card == card:
		_effect_card = null
		clear_effect_arrows()
	_active_card = null
	# Sans await : la popup suivante se joue pendant le fondu de celle-ci
	_fade_out_popup(card)

# Remplace le fondu habituel par la dissolution de AnimationSystem, depuis la
# position de la popup — la même animation que Card.gd utilisait auparavant
# depuis la main, désormais déclenchée depuis l'emplacement de la popup. Le
# pool de mana du joueur "respire" (pulse_max) au même instant, pour que le
# gain de mana soit visuellement associé à la disparition de la carte.
func _absorb_resource_popup(card: Card, card_data: CardData) -> void:
	var color: Color = Color.WHITE
	if battle.get("mana_display"):
		color = ManaDisplay.RACE_MANA_COLORS.get(card_data.race, Color.WHITE)
		battle.mana_display.pulse_max()
	if battle.get("animation_system"):
		battle.animation_system.play_resource_absorb(card, color)
	else:
		card.queue_free()

func _fade_out_popup(card: Card) -> void:
	_kill_popup_tween(card)
	var t_out = card.create_tween().set_parallel(true)
	t_out.tween_property(card, "scale", card.scale * 0.8, 0.15)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t_out.tween_property(card, "modulate:a", 0.0, 0.15)
	await t_out.finished
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
# lance un projectile de sort le long de la même courbe (AnimationSystem),
# puis rend la main à l'appelant qui applique alors l'effet.
# skip_missile : true quand VFXManager a déjà joué un vrai projectile pour ce
# sort (résolution immédiate d'un Éphémère/Rituel joué, voir CardSystem.gd) —
# évite d'afficher les deux projectiles en double sur la même carte.
func show_effect_arrows(target_positions: Array, hold: float = 0.35, skip_missile: bool = false) -> void:
	var from: Vector2 = get_effect_popup_tip()
	if from == Vector2.ZERO or target_positions.is_empty():
		return
	var pts: Array[Vector2] = []
	for p in target_positions:
		pts.append(p)
	_effect_arrow.show_arrows(from, pts)
	if not skip_missile and battle.get("animation_system") and _effect_card != null \
			and is_instance_valid(_effect_card) and _effect_card.data != null:
		var color: Color = ManaDisplay.RACE_MANA_COLORS.get(_effect_card.data.race, Color.WHITE)
		battle.animation_system.play_spell_missile(from, pts, color)
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
