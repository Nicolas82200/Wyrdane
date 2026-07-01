extends Node
class_name SelectionSystem

var battle

var selected_attacker: Minion          = null
var selected_board_minion: BoardMinion = null
var selected_attackers: Array[Minion]  = []
var selected_board_minions: Array[BoardMinion] = []
var is_multi_selecting: bool           = false

func init(_battle) -> void:
	battle = _battle

# ─── Sélection joueur ─────────────────────────────────────────────────────────

func on_player_minion_clicked(minion: Minion, board_minion: BoardMinion) -> void:
	if battle.game_over or not minion.can_attack():
		return

	var ctrl_held := Input.is_key_pressed(KEY_CTRL)

	if ctrl_held:
		if not is_multi_selecting and selected_attacker != null and selected_board_minion != null:
			selected_attackers.append(selected_attacker)
			selected_board_minions.append(selected_board_minion)
			selected_attacker     = null
			selected_board_minion = null

		is_multi_selecting = true
		if minion in selected_attackers:
			var idx := selected_attackers.find(minion)
			selected_attackers.remove_at(idx)
			selected_board_minions.remove_at(idx)
			board_minion.set_selected(false)
		else:
			selected_attackers.append(minion)
			selected_board_minions.append(board_minion)
			board_minion.set_selected(true)

		if selected_attackers.is_empty():
			is_multi_selecting = false
	else:
		clear_multi_selection()
		is_multi_selecting = false
		if selected_board_minion:
			selected_board_minion.set_selected(false)
		selected_attacker     = minion
		selected_board_minion = board_minion
		board_minion.set_selected(true, true)

# ─── Attaque ennemie ──────────────────────────────────────────────────────────

func on_enemy_minion_clicked(target: Minion, _board_minion: BoardMinion) -> void:
	if battle.game_over:
		return

	if is_multi_selecting and not selected_attackers.is_empty():
		if not battle._can_attack_minion_target(selected_attackers[0], target):
			return
		await _resolve_multi_attack(target)
		return

	if selected_attacker == null or not battle._can_attack_minion_target(selected_attacker, target):
		return
	await battle.combat_system.resolve_combat(selected_attacker, target)
	clear_selection()

func on_enemy_hero_clicked() -> void:
	if battle.game_over:
		return

	if is_multi_selecting and not selected_attackers.is_empty():
		await _resolve_multi_attack_hero()
		return

	if selected_attacker == null or not battle._can_attack_hero(selected_attacker):
		return
	await battle.combat_system.perform_hero_attack(selected_attacker)
	clear_selection()
	battle.check_game_end()
	battle.board_visual_system.refresh_board()

# ─── Multi-attaque ────────────────────────────────────────────────────────────

func _resolve_multi_attack(target: Minion) -> void:
	var attackers := _sort_attackers_left_to_right(selected_attackers)
	clear_multi_selection()
	for attacker in attackers:
		if target.is_dead():
			break
		if attacker == null or attacker.is_dead() or not attacker.can_attack():
			continue
		if not battle._can_attack_minion_target(attacker, target):
			continue
		await battle.combat_system.resolve_combat(attacker, target)
		await battle.get_tree().create_timer(0.4).timeout

func _resolve_multi_attack_hero() -> void:
	var attackers := _sort_attackers_left_to_right(selected_attackers)
	clear_multi_selection()
	for attacker in attackers:
		if attacker == null or attacker.is_dead() or not attacker.can_attack():
			continue
		if not battle._can_attack_hero(attacker):
			continue
		await battle.combat_system.perform_hero_attack(attacker)
		await battle.get_tree().create_timer(0.2).timeout
	battle.check_game_end()
	battle.board_visual_system.refresh_board()

func _sort_attackers_left_to_right(attackers: Array[Minion]) -> Array[Minion]:
	var sorted: Array[Minion] = attackers.duplicate()
	sorted.sort_custom(func(a, b): return battle.player_minions.find(a) < battle.player_minions.find(b))
	return sorted

# ─── Clear ────────────────────────────────────────────────────────────────────

func clear_selection() -> void:
	if selected_board_minion:
		selected_board_minion.set_selected(false)
	selected_board_minion = null
	selected_attacker     = null
	clear_multi_selection()

func clear_multi_selection() -> void:
	for bm in selected_board_minions:
		if is_instance_valid(bm):
			bm.set_selected(false)
	selected_attackers.clear()
	selected_board_minions.clear()
	is_multi_selecting = false
