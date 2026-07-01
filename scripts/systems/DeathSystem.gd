extends RefCounted
class_name DeathSystem

var battle
var processing_deaths := false

func init(_battle) -> void:
	battle = _battle

func process_deaths() -> void:
	if processing_deaths:
		return
	processing_deaths = true
	var dead_player: Array[Minion] = battle.player_minions.filter(func(m: Minion): return m.is_dead())
	var dead_enemy:  Array[Minion] = battle.enemy_minions.filter(func(m: Minion): return m.is_dead())
	var dead_all:    Array[Minion] = []
	dead_all.append_array(dead_player)
	dead_all.append_array(dead_enemy)
	if dead_all.is_empty():
		processing_deaths = false
		return
	await _animate_deaths(dead_all)
	battle.player_minions = battle.player_minions.filter(func(m: Minion): return not m.is_dead())
	battle.enemy_minions  = battle.enemy_minions.filter(func(m: Minion): return not m.is_dead())
	_send_to_graveyards(dead_player, dead_enemy)
	await _trigger_deathrattle(dead_player)
	await _trigger_deathrattle(dead_enemy)
	await _trigger_death_reactions(dead_player, true)
	await _trigger_death_reactions(dead_enemy, false)
	await _trigger_sacrifice(dead_player, true)
	await _trigger_sacrifice(dead_enemy, false)
	processing_deaths = false
	battle.aura_system.recompute_all()
	battle.board_visual_system.refresh_board()
	await process_deaths()

func _animate_deaths(dead_minions: Array[Minion]) -> void:
	for minion in dead_minions:
		var visual = battle.board_visual_system.get_visual(minion)
		if visual:
			battle.animation_system.play_death(visual)
	if not dead_minions.is_empty():
		await battle.get_tree().create_timer(0.35).timeout
	for minion in dead_minions:
		var visual = battle.board_visual_system.get_visual(minion)
		if visual and is_instance_valid(visual):
			visual.queue_free()
		battle.board_visual_system.remove_visual(minion)

func _send_to_graveyards(dead_player: Array[Minion], dead_enemy: Array[Minion]) -> void:
	for minion in dead_player:
		battle.player_graveyard.add_minion(minion.card_data)
	for minion in dead_enemy:
		battle.enemy_graveyard.add_minion(minion.card_data)

func _trigger_deathrattle(dead_minions: Array[Minion]) -> void:
	for minion in dead_minions:
		await battle.effect_manager.trigger_effects(battle, minion, "DEATHRATTLE")

func _trigger_death_reactions(dead_minions: Array[Minion], dead_were_player: bool) -> void:
	if dead_minions.is_empty():
		return
	var same_camp: Array[Minion]  = battle.player_minions if dead_were_player else battle.enemy_minions
	var other_camp: Array[Minion] = battle.enemy_minions if dead_were_player else battle.player_minions

	# Deuil (OnGrief) : un ALLIÉ vient de mourir → survivants du même camp réagissent
	for minion in same_camp:
		await battle.effect_manager.trigger_effects(battle, minion, "OnGrief")

	# Mort-rage (Serviteur) + Carnage (Rituel/Enchantement) : un ENNEMI vient de mourir
	for minion in other_camp:
		await battle.effect_manager.trigger_effects(battle, minion, "OnDeathRage")
		await battle.effect_manager.trigger_effects(battle, minion, "OnCarnage")

	await battle.trigger_system.fire("OnGrief", null, dead_were_player)
	await battle.trigger_system.fire("OnCarnage", null, not dead_were_player)

func _trigger_sacrifice(dead_minions: Array[Minion], dead_were_player: bool) -> void:
	var sacrificed_ones: Array[Minion] = dead_minions.filter(func(m: Minion): return m.sacrificed)
	if sacrificed_ones.is_empty():
		return
	var survivors: Array[Minion] = battle.player_minions if dead_were_player else battle.enemy_minions
	for survivor in survivors:
		await battle.effect_manager.trigger_effects(battle, survivor, "OnSacrifice")
