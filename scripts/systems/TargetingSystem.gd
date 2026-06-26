extends Node
class_name TargetingSystem

signal targeting_cancelled
signal target_selected(target)

var battle
var _active: bool = false
var _pending_card: CardData = null
var _pending_row: String = "Front"
var _pending_insert_index: int = -1
var _highlighted: Array[Control] = []
var _arrow: ArrowOverlay = null
var _origin_node: Control = null  # nœud de départ de la flèche (la carte jouée)

const HIGHLIGHT_COLOR      := Color(1.0, 0.85, 0.1, 0.55)
const HIGHLIGHT_ENEMY_COLOR := Color(1.0, 0.3, 0.3, 0.55)
const HIGHLIGHT_ALLY_COLOR  := Color(0.3, 0.8, 1.0, 0.55)

func init(_battle) -> void:
	battle = _battle
	_arrow = ArrowOverlay.new()
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 10
	battle.add_child(canvas_layer)
	canvas_layer.add_child(_arrow)
func is_targeting() -> bool:
	return _active

func begin_targeting(card_data: CardData, row: String, insert_index: int, origin: Control = null) -> void:
	print("begin_targeting — row: %s, index: %d" % [row, insert_index])
	_pending_card         = card_data
	_pending_row          = row
	_pending_insert_index = insert_index
	_origin_node          = origin
	_active               = true
	_show_valid_targets(card_data)
	_arrow.show_arrow(Vector2.ZERO, Vector2.ZERO)  # ← initialise visible dès le début
	battle.set_process(true)

func update_arrow() -> void:
	if not _active or _arrow == null:
		return
	# Départ = bord droit de la popup de ciblage
	var from: Vector2 = battle.card_popup_system.get_targeting_popup_tip()
	if from == Vector2.ZERO:
		# Fallback si pas de popup
		if _origin_node and is_instance_valid(_origin_node):
			from = _origin_node.global_position + _origin_node.size * 0.5
		else:
			from = battle.get_viewport().get_mouse_position() - Vector2(0, 80)
	var to: Vector2 = battle.get_viewport().get_mouse_position()
	_arrow.show_arrow(from, to)

# ─── Clicks ───────────────────────────────────────────────────────────────────

func on_enemy_minion_clicked(minion: Minion, visual: BoardMinion) -> void:
	if not _active:
		return
	if not _is_valid_target_minion(minion, _pending_card):
		return
	# Flèche pointe vers le centre du visual au moment du clic
	var to: Vector2 = visual.global_position + visual.size * 0.5
	_snap_arrow_to(to)
	_finish(minion)

func on_ally_minion_clicked(minion: Minion, visual: BoardMinion) -> void:
	if not _active:
		return
	if not _is_valid_target_minion(minion, _pending_card):
		return
	var to: Vector2 = visual.global_position + visual.size * 0.5
	_snap_arrow_to(to)
	_finish(minion)

func on_enemy_hero_clicked() -> void:
	if not _active:
		return
	var target_str := _pending_card.effects[0].target if _pending_card and _pending_card.effects.size() > 0 else ""
	if target_str not in ["EnemyHero", "AnyMinion"]:
		return
	var hero_panel: Control = battle.get_node("EnemyHeroPanel")
	if hero_panel:
		_snap_arrow_to(hero_panel.global_position + hero_panel.size * 0.5)
	_finish(battle.enemy_hero)

# ─── Interne ──────────────────────────────────────────────────────────────────

func _snap_arrow_to(to: Vector2) -> void:
	if _origin_node and is_instance_valid(_origin_node):
		_arrow.show_arrow(
			_origin_node.global_position + _origin_node.size * 0.5,
			to
		)

func _finish(target) -> void:
	print("_finish — row: %s, index: %d" % [_pending_row, _pending_insert_index])
	_active = false
	_clear_highlights()
	_arrow.hide_arrow()
	battle.set_process(false)
	# ← Cache la popup de ciblage
	battle.card_popup_system.hide_targeting_popup()
	var card   := _pending_card
	var row    := _pending_row
	var index  := _pending_insert_index
	_pending_card = null
	_origin_node  = null
	battle.card_system.resolve_with_target(card, row, index, target)
	target_selected.emit(target)

func cancel() -> void:
	if not _active:
		return
	_active = false
	_pending_card = null
	_origin_node  = null
	_clear_highlights()
	_arrow.hide_arrow()
	battle.set_process(false)
	# ← Cache la popup si annulation
	battle.card_popup_system.hide_targeting_popup()
	targeting_cancelled.emit()

func _show_valid_targets(card_data: CardData) -> void:
	_clear_highlights()
	if card_data == null or card_data.effects.is_empty():
		return
	var target_str: String = card_data.effects[0].target
	match target_str:
		"EnemyMinion":
			_highlight_side(battle.enemy_minions, HIGHLIGHT_ENEMY_COLOR)
		"AllyMinion":
			_highlight_side(battle.player_minions, HIGHLIGHT_ALLY_COLOR)
		"AnyMinion":
			_highlight_side(battle.enemy_minions, HIGHLIGHT_ENEMY_COLOR)
			_highlight_side(battle.player_minions, HIGHLIGHT_ALLY_COLOR)
		"EnemyHero":
			_highlight_hero(false)
		"OwnerHero":
			_highlight_hero(true)

func _highlight_side(minions: Array[Minion], color: Color) -> void:
	var has_taunt := minions.any(func(m: Minion) -> bool:
		return m.has_keyword(Keyword.Type.TAUNT)
	)
	for minion in minions:
		if has_taunt and not minion.has_keyword(Keyword.Type.TAUNT):
			continue
		_highlight_minion(minion, color)

func _highlight_minion(minion: Minion, color: Color) -> void:
	var visual: BoardMinion = battle.board_visual_system.find_visual(minion) as BoardMinion
	if visual == null or not is_instance_valid(visual):
		return
	visual.set_targetable(true, color)
	_highlighted.append(visual)

func _highlight_hero(is_player: bool) -> void:
	var panel: Control = battle.get_node("PlayerHeroPanel") if is_player else battle.get_node("EnemyHeroPanel")
	if panel == null:
		return
	panel.modulate = HIGHLIGHT_ENEMY_COLOR
	_highlighted.append(panel)

func _clear_highlights() -> void:
	for node in _highlighted:
		if not is_instance_valid(node):
			continue
		if node is BoardMinion:
			(node as BoardMinion).set_targetable(false, Color.WHITE)
		else:
			node.modulate = Color.WHITE
	_highlighted.clear()

func _is_valid_target_minion(minion: Minion, card_data: CardData) -> bool:
	if card_data == null or card_data.effects.is_empty():
		return false
	var t := card_data.effects[0].target
	match t:
		"EnemyMinion":
			if not minion.owner_is_player:
				return _check_taunt(minion, battle.enemy_minions)
			return false
		"AllyMinion":
			if minion.owner_is_player:
				return _check_taunt(minion, battle.player_minions)
			return false
		"AnyMinion":
			var enemies :Array[Minion]= battle.enemy_minions
			var allies  :Array[Minion]= battle.player_minions
			if not minion.owner_is_player:
				return _check_taunt(minion, enemies)
			else:
				return _check_taunt(minion, allies)
		_:
			return false

func _check_taunt(minion: Minion, side: Array[Minion]) -> bool:
	# S'il existe un Rempart dans ce camp, seuls les Remparts sont valides
	var has_taunt := side.any(func(m: Minion) -> bool:
		return m.has_keyword(Keyword.Type.TAUNT)
	)
	if has_taunt:
		return minion.has_keyword(Keyword.Type.TAUNT)
	return true
