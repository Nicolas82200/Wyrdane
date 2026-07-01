extends Node
class_name TurnSystem

var battle

func init(_battle) -> void:
	battle = _battle

func end_turn() -> void:
	# Fin de tour — serviteurs joueur
	for minion in battle.player_minions.duplicate():
		await battle.effect_manager.trigger_effects(battle, minion, "OnTurnEnd")
	# Fin de tour — enchantements joueur
	await battle.trigger_system.fire("OnTurnEnd", null, true)
	battle.trigger_system.tick_enchantment_durations(true)

	# Fin de tour — serviteurs ennemis
	for minion in battle.enemy_minions.duplicate():
		await battle.effect_manager.trigger_effects(battle, minion, "OnTurnEnd")
	await battle.trigger_system.fire("OnTurnEnd", null, false)
	battle.trigger_system.tick_enchantment_durations(false)

	await _apply_infection_damage()
	await _begin_player_turn()

func _begin_player_turn() -> void:
	battle.aura_system.recompute_all()
	for minion in battle.player_minions.duplicate():
		minion.refresh_attacks()
	for minion in (battle.player_minions + battle.enemy_minions).duplicate():
		await battle.effect_manager.trigger_effects(battle, minion, "OnTurnStart")
	await battle.trigger_system.fire("OnTurnStart", null, true)
	await battle.trigger_system.fire("OnTurnStart", null, false)
	for minion in battle.player_minions.duplicate():
		await battle.effect_manager.trigger_effects(battle, minion, "OnAwaken")
	await battle.trigger_system.fire("OnAwaken", null, true)
	for minion in battle.enemy_minions.duplicate():
		await battle.effect_manager.trigger_effects(battle, minion, "OnDecline")
	battle.turn_choice_panel.show_choice()

func _apply_infection_damage() -> void:
	for minion in (battle.player_minions + battle.enemy_minions).duplicate():
		if minion.infected:
			var dealt: int = minion.take_damage(1)
			if dealt > 0 and not minion.is_dead():
				await battle.effect_manager.trigger_effects(battle, minion, "OnDamaged")
	await battle.death_system.process_deaths()
	battle.board_visual_system.refresh_board()

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
