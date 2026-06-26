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
	var dead_player: Array[Minion] = battle.player_minions.filter(
		func(minion: Minion): return minion.is_dead()
	)
	var dead_enemy: Array[Minion] = battle.enemy_minions.filter(
		func(minion: Minion): return minion.is_dead()
	)
	var dead_all: Array[Minion] = []
	dead_all.append_array(dead_player)
	dead_all.append_array(dead_enemy)
	if dead_all.is_empty():
		processing_deaths = false
		return
	await _animate_deaths(dead_all)
	# Retire des tableaux avant les triggers pour éviter qu'ils se re-ciblent
	battle.player_minions = battle.player_minions.filter(
		func(minion: Minion): return not minion.is_dead()
	)
	battle.enemy_minions = battle.enemy_minions.filter(
		func(minion: Minion): return not minion.is_dead()
	)
	_send_to_graveyards(dead_player, dead_enemy)
	# OnGrief : déclenché sur tous les alliés survivants pour chaque mort
	_trigger_grief(dead_player, true)
	_trigger_grief(dead_enemy, false)
	# OnDeathRage : déclenché sur les alliés Mort-Vivants survivants
	_trigger_death_rage(dead_player, true)
	_trigger_death_rage(dead_enemy, false)
	processing_deaths = false
	battle.board_visual_system.refresh_board()
	# Récursion : de nouveaux morts peuvent être apparus via les triggers
	await process_deaths()

func _animate_deaths(dead_minions: Array[Minion]) -> void:
	var tweens: Array[Tween] = []
	for minion in dead_minions:
		var visual = battle.board_visual_system.get_visual(minion)
		if visual:
			var t = battle.animation_system.play_death(visual)
			tweens.append(t)
	if tweens.size() > 0:
		await battle.get_tree().create_timer(0.35).timeout
	for minion in dead_minions:
		var visual = battle.board_visual_system.get_visual(minion)
		if visual and is_instance_valid(visual):
			visual.queue_free()
		battle.board_visual_system.remove_visual(minion)

func _send_to_graveyards(dead_player: Array[Minion], dead_enemy: Array[Minion]) -> void:
	for minion in dead_player:
		battle.player_graveyard.add_minion(minion.card_data)
		battle.effect_manager.trigger_effects(battle, minion, "DEATHRATTLE")
	for minion in dead_enemy:
		battle.enemy_graveyard.add_minion(minion.card_data)
		battle.effect_manager.trigger_effects(battle, minion, "DEATHRATTLE")

func _trigger_grief(dead_minions: Array[Minion], dead_were_player: bool) -> void:
	if dead_minions.is_empty():
		return
	var survivors: Array[Minion] = battle.player_minions if dead_were_player else battle.enemy_minions
	for survivor in survivors:
		battle.effect_manager.trigger_effects(battle, survivor, "OnGrief")

func _trigger_death_rage(dead_minions: Array[Minion], dead_were_player: bool) -> void:
	if dead_minions.is_empty():
		return
	var has_undead_death := false
	for minion in dead_minions:
		if minion.card_data.race == Race.Type.UNDEAD:
			has_undead_death = true
			break
	if not has_undead_death:
		return
	var survivors: Array[Minion] = battle.player_minions if dead_were_player else battle.enemy_minions
	for survivor in survivors:
		battle.effect_manager.trigger_effects(survivor, "OnDeathRage")

func trigger_effects(minion: Minion, trigger_name: String) -> void:
	if minion == null:
		return
	var trigger_found := false
	for trigger in minion.card_data.trigger_types:
		if trigger.type == trigger_name:
			trigger_found = true
			break
	if not trigger_found:
		return
	for effect in minion.card_data.effects:
		battle.effect_manager.execute_effect(battle, minion, effect)
