extends Node
class_name TurnSystem

var battle

func init(_battle) -> void:
	battle = _battle

func end_turn() -> void:
	var acted := false
	# Fin de tour — serviteurs joueur
	acted = await _trigger_minions_paced(battle.player_minions, "OnTurnEnd", acted)
	# Fin de tour — enchantements joueur
	acted = await battle.trigger_system.fire("OnTurnEnd", null, true, {}, true, acted)
	battle.trigger_system.tick_enchantment_durations(true)

	# Fin de tour — serviteurs ennemis
	acted = await _trigger_minions_paced(battle.enemy_minions, "OnTurnEnd", acted)
	acted = await battle.trigger_system.fire("OnTurnEnd", null, false, {}, true, acted)
	battle.trigger_system.tick_enchantment_durations(false)

	await _apply_infection_damage()
	await battle.ai_system.take_turn()
	if battle.game_over:
		return
	await _begin_player_turn()

func _begin_player_turn() -> void:
	battle.aura_system.recompute_all()
	for minion in battle.player_minions.duplicate():
		minion.refresh_attacks()
	var acted := false
	acted = await _trigger_minions_paced(battle.player_minions + battle.enemy_minions, "OnTurnStart", acted)
	acted = await battle.trigger_system.fire("OnTurnStart", null, true, {}, true, acted)
	acted = await battle.trigger_system.fire("OnTurnStart", null, false, {}, true, acted)
	acted = await _trigger_minions_paced(battle.player_minions, "OnAwaken", acted)
	acted = await battle.trigger_system.fire("OnAwaken", null, true, {}, true, acted)
	acted = await _trigger_minions_paced(battle.enemy_minions, "OnDecline", acted)
	battle.turn_choice_panel.show_choice()

# Déclenche un trigger sur chaque serviteur de la liste, avec une pause AVANT
# chaque déclenchement sauf le premier de la file. Retourne l'état "acted"
# pour chaîner le pacing sur la suite de la phase.
func _trigger_minions_paced(minions: Array, trigger_name: String, already_acted: bool) -> bool:
	var acted := already_acted
	for minion in minions.duplicate():
		if not battle.effect_manager.has_trigger(minion, trigger_name):
			continue
		if acted:
			await battle.pace_actions()
		await battle.effect_manager.trigger_effects(battle, minion, trigger_name)
		acted = true
	return acted

func _apply_infection_damage() -> void:
	var any_infected := false
	for minion in (battle.player_minions + battle.enemy_minions).duplicate():
		if minion.infected:
			any_infected = true
			var dealt: int = minion.take_damage(1)
			if dealt > 0 and not minion.is_dead():
				await battle.effect_manager.trigger_effects(battle, minion, "OnDamaged")
	await battle.death_system.process_deaths()
	battle.board_visual_system.refresh_board()
	if any_infected:
		await battle.pace_actions()

func choose_draw() -> void:
	draw_card()
	_finish_turn_start()

func choose_mana() -> void:
	battle.max_mana += 1
	_finish_turn_start()

func _finish_turn_start() -> void:
	battle.mana = battle.max_mana
	battle.update_mana_ui()
	battle.board_visual_system.refresh_board()

func draw_card() -> void:
	if battle.deck.is_empty():
		return
	battle.hand_cards.append(battle.deck.pop_back())
	var deck_pos: Vector2 = battle.deck_button.global_position + battle.deck_button.size / 2.0
	AudioManager.play(AudioManager.DRAW)
	battle.hand.set_hand(battle.hand_cards, true, deck_pos)
	battle.deck_system.update_deck_ui()
