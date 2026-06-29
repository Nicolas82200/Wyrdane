# CombatSystem.gd
extends Node
class_name CombatSystem

var battle

func init(_battle) -> void:
	battle = _battle

func resolve_combat(attacker: Minion, defender: Minion) -> void:
	var attacker_visual: BoardMinion = battle.board_visual_system.find_visual(attacker)
	var defender_visual: BoardMinion = battle.board_visual_system.find_visual(defender)
	if attacker_visual and defender_visual:
		await battle.animation_system.play_attack_lunge(attacker_visual, defender_visual)
	await _execute_damage(attacker, defender)
	await battle.get_tree().create_timer(0.05).timeout
	await battle.death_system.process_deaths()
	battle.hero_system.update_ui()
	battle.check_game_end()

func _execute_damage(attacker: Minion, defender: Minion) -> void:
	# Triggers avant combat
	await battle.effect_manager.trigger_effects(battle, attacker, "OnAttack")
	await battle.effect_manager.trigger_effects(battle, attacker, "OnRally")

	var a_dmg: int = attacker.attack
	var d_dmg: int = defender.attack

	defender.take_damage(a_dmg)
	attacker.take_damage(d_dmg)
	AudioManager.play(AudioManager.HIT)

	# VENIN MORTEL
	if attacker.has_keyword(Keyword.Type.DEADLY_POISON):
		defender.health = 0
	if defender.has_keyword(Keyword.Type.DEADLY_POISON):
		attacker.health = 0

	# OnDamaged sur les deux si ils ont pris des dégâts et survivent
	if d_dmg > 0 and not attacker.is_dead():
		await battle.effect_manager.trigger_effects(battle, attacker, "OnDamaged")
	if a_dmg > 0 and not defender.is_dead():
		await battle.effect_manager.trigger_effects(battle, defender, "OnDamaged")

	# MOISSON
	if attacker.has_keyword(Keyword.Type.LIFESTEAL):
		battle.hero_system.get_owner_hero(attacker).heal(a_dmg)

	# OnExecution + RAVAGE
	if defender.is_dead():
		await battle.effect_manager.trigger_effects(battle, attacker, "OnExecution")
		if attacker.has_keyword(Keyword.Type.RAVAGE):
			var excess: int = a_dmg - defender.max_health
			if excess > 0:
				battle.hero_system.damage(battle.hero_system.get_enemy_hero(attacker), excess)
				await battle.effect_manager.trigger_effects(battle, attacker, "OnCarnage")

	attacker.consume_attack()
	battle.board_visual_system.refresh_board()

func perform_hero_attack(attacker: Minion) -> void:
	var visual: BoardMinion = battle.board_visual_system.find_visual(attacker)
	if visual:
		var hero_panel: Control = battle.get_node("EnemyHeroPanel")
		await battle.animation_system.play_attack_lunge(visual, hero_panel)
	AudioManager.play(AudioManager.HIT)
	await battle.effect_manager.trigger_effects(battle, attacker, "OnAttack")
	await battle.effect_manager.trigger_effects(battle, attacker, "OnRally")
	battle.hero_system.damage(battle.enemy_hero, attacker.attack)
	if attacker.has_keyword(Keyword.Type.LIFESTEAL):
		battle.hero_system.get_owner_hero(attacker).heal(attacker.attack)
	attacker.consume_attack()
