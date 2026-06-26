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
	_execute_damage(attacker, defender)
	await battle.get_tree().create_timer(0.05).timeout
	await battle.death_system.process_deaths()
	battle.hero_system.update_ui()
	battle.check_game_end()

func _execute_damage(attacker: Minion, defender: Minion) -> void:
	battle.trigger_effects(attacker, "OnAttack")
	battle.trigger_effects(attacker, "OnRally")  # Ralliement = quand ce serviteur attaque
	var a_dmg: int = attacker.attack
	var d_dmg: int = defender.attack
	defender.take_damage(a_dmg)
	attacker.take_damage(d_dmg)
	AudioManager.play(AudioManager.HIT)
	if attacker.has_keyword(Keyword.Type.DEADLY_POISON):
		defender.health = 0
	if defender.has_keyword(Keyword.Type.DEADLY_POISON):
		attacker.health = 0
	battle.trigger_effects(defender, "OnDamaged")
	if attacker.has_keyword(Keyword.Type.LIFESTEAL):
		battle.hero_system.get_owner_hero(attacker).heal(a_dmg)
	# Vérifie si l'attaquant a tué le défenseur
	if defender.is_dead():
		battle.trigger_effects(attacker, "OnExecution")
		# Vérifie Carnage (dégâts excédentaires vers le héros)
		if attacker.has_keyword(Keyword.Type.RAVAGE):
			var excess: int = a_dmg - (d_dmg + defender.health)
			if excess > 0:
				battle.hero_system.damage(battle.hero_system.get_enemy_hero(attacker), excess)
				battle.trigger_effects(attacker, "OnCarnage")
	attacker.consume_attack()
	battle.board_visual_system.refresh_board()

func perform_hero_attack(attacker: Minion) -> void:
	var visual: BoardMinion = battle.board_visual_system.find_visual(attacker)
	if visual:
		var hero_panel: Control = battle.get_node("EnemyHeroPanel")
		await battle.animation_system.play_attack_lunge(visual, hero_panel)
	AudioManager.play(AudioManager.HIT)
	battle.trigger_effects(attacker, "OnAttack")
	battle.trigger_effects(attacker, "OnRally")
	battle.hero_system.damage(battle.enemy_hero, attacker.attack)
	if attacker.has_keyword(Keyword.Type.LIFESTEAL):
		battle.hero_system.get_owner_hero(attacker).heal(attacker.attack)
	attacker.consume_attack()
