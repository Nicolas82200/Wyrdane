extends Node

class_name CombatSystem

var battle

func init(_battle):
	battle = _battle


func resolve_combat(attacker, defender) -> void:
	var attacker_visual = battle._find_board_minion_visual(attacker)
	var defender_visual = battle._find_board_minion_visual(defender)

	if attacker_visual and defender_visual:
		await battle._animate_attack_lunge(attacker_visual, defender_visual)

	_execute_damage(attacker, defender)

	await battle.get_tree().create_timer(0.2).timeout
	await battle.remove_dead_minions()
	battle.update_hero_ui()
	battle.check_game_end()


func _execute_damage(attacker, defender) -> void:
	battle.trigger_effects(attacker, "OnAttack")

	var a_dmg = attacker.attack
	var d_dmg = defender.attack

	defender.take_damage(a_dmg)
	attacker.take_damage(d_dmg)

	if attacker.has_keyword(Keyword.Type.DEADLY_POISON):
		defender.health = 0

	if defender.has_keyword(Keyword.Type.DEADLY_POISON):
		attacker.health = 0

	battle.trigger_effects(defender, "OnDamaged")

	if attacker.has_keyword(Keyword.Type.LIFESTEAL):
		battle.get_owner_hero(attacker).heal(a_dmg)

	attacker.attacks_remaining -= 1

	battle.refresh_board()


func perform_hero_attack(attacker: Minion) -> void:
	var visual = battle._find_board_minion_visual(attacker)

	if visual:
		var hero_panel = battle.get_node("EnemyHeroPanel")
		await battle._animate_attack_lunge(visual, hero_panel)

	battle.damage_hero(battle.enemy_hero, attacker.attack)

	if attacker.has_keyword(Keyword.Type.LIFESTEAL):
		battle.get_owner_hero(attacker).heal(attacker.attack)

	attacker.attacks_remaining -= 1
