extends Node
class_name TurnSystem

var battle

func init(_battle):
	battle = _battle

func start_new_turn() -> void:
	for minion in battle.player_minions:
		minion.refresh_attacks()
		battle.trigger_effects(minion, "ONTURNSTART")
	battle.turn_choice_panel.show_choice()

func end_turn() -> void:
	for minion in battle.player_minions:
		battle.trigger_effects(minion, "ONTURNEND")
	start_new_turn()

func choose_draw() -> void:
	draw_card()
	_finish_turn_start()

func choose_mana() -> void:
	battle.max_mana += 1
	_finish_turn_start()

func _finish_turn_start() -> void:
	battle.mana = battle.max_mana
	battle.update_mana_ui()
	battle.refresh_board()

func draw_card() -> void:
	if battle.deck.is_empty():
		return
	battle.hand_cards.append(battle.deck.pop_back())
	var deck_pos: Vector2 = battle.deck_button.global_position + battle.deck_button.size / 2.0
	AudioManager.play(AudioManager.DRAW)
	battle.hand.set_hand(battle.hand_cards, true, deck_pos)
	battle.update_deck_ui()
