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
	await battle.effect_manager.trigger_effects(battle, attacker, "OnAttack")
	await battle.effect_manager.trigger_effects(battle, attacker, "OnRally")
	# Résonance — enchantements réagissent quand un allié de la même race attaque
	await battle.trigger_system.fire("OnResonance", attacker, attacker.owner_is_player)

	var a_dmg: int = attacker.attack
	var d_dmg: int = defender.attack
	var dealt_to_defender: int = defender.take_damage(a_dmg)
	var dealt_to_attacker: int = attacker.take_damage(d_dmg)
	AudioManager.play(AudioManager.HIT)

	if attacker.has_keyword(Keyword.Type.DEADLY_POISON):
		defender.health = 0
	if defender.has_keyword(Keyword.Type.DEADLY_POISON):
		attacker.health = 0

	if dealt_to_attacker > 0 and not attacker.is_dead():
		await battle.effect_manager.trigger_effects(battle, attacker, "OnDamaged")
	if dealt_to_defender > 0 and not defender.is_dead():
		await battle.effect_manager.trigger_effects(battle, defender, "OnDamaged")
		if defender.has_human_keyword(KeywordHuman.Type.CONTRE_ATTAQUE):
			var counter: int = attacker.take_damage(defender.attack)
			if counter > 0 and not attacker.is_dead():
				await battle.effect_manager.trigger_effects(battle, attacker, "OnDamaged")
	
	if attacker.has_keyword(Keyword.Type.LIFESTEAL):
		battle.hero_system.get_owner_hero(attacker).heal(dealt_to_defender)

	if defender.is_dead():
		await battle.effect_manager.trigger_effects(battle, attacker, "OnExecution")
		if attacker.has_keyword(Keyword.Type.RAVAGE):
			var excess: int = a_dmg - defender.max_health
			if excess > 0:
				battle.hero_system.damage(battle.hero_system.get_enemy_hero(attacker), excess)
			
	attacker.consume_attack()
	battle.board_visual_system.refresh_board()

func perform_hero_attack(attacker: Minion) -> void:
	var panel_name: String = "EnemyHeroPanel" if attacker.owner_is_player else "PlayerHeroPanel"
	var visual: BoardMinion = battle.board_visual_system.find_visual(attacker)
	if visual:
		var hero_panel: Control = battle.get_node(panel_name)
		await battle.animation_system.play_attack_lunge(visual, hero_panel)
	AudioManager.play(AudioManager.HIT)
	await battle.effect_manager.trigger_effects(battle, attacker, "OnAttack")
	await battle.effect_manager.trigger_effects(battle, attacker, "OnRally")
	await battle.trigger_system.fire("OnRally", attacker, attacker.owner_is_player)
	battle.hero_system.damage(battle.hero_system.get_enemy_hero(attacker), attacker.attack)
	if attacker.has_keyword(Keyword.Type.LIFESTEAL):
		battle.hero_system.get_owner_hero(attacker).heal(attacker.attack)
	attacker.consume_attack()
