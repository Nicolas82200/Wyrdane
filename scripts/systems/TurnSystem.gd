extends Node
class_name TurnSystem

var battle

func init(_battle) -> void:
	battle = _battle

func end_turn() -> void:
	for minion in battle.player_minions:
		battle.trigger_effects(minion, "OnTurnEnd")
	if battle.has_method("enchantment_system"):
		battle.enchantment_system.trigger_on_turn_end(true)
	await _apply_infection_damage()
	_begin_player_turn()

func _begin_player_turn() -> void:
	for minion in battle.player_minions:
		minion.refresh_attacks()
	for minion in battle.player_minions:
		battle.trigger_effects(minion, "OnTurnStart")
		battle.trigger_effects(minion, "OnAwaken")
	for minion in battle.enemy_minions:
		battle.trigger_effects(minion, "OnDecline")
	if battle.get("enchantment_system") != null:
		battle.enchantment_system.trigger_on_turn_start(true)
	battle.turn_choice_panel.show_choice()

func _apply_infection_damage() -> void:
	for minion in battle.player_minions + battle.enemy_minions:
		if minion.infected:
			minion.take_damage(1)
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
