extends Node
class_name CardSystem

var battle

func init(_battle):
	battle = _battle


func play_card(card_data, row := "Front", insert_index := -1) -> void:
	battle._pay_mana(card_data.cost)
	_remove_from_hand(card_data)

	await battle.get_tree().process_frame
	battle.hand._update_hand_layout(true)

	_resolve(card_data, row, insert_index)


func _remove_from_hand(card_data):
	var idx = battle.hand_cards.find(card_data)
	if idx != -1:
		battle.hand_cards.remove_at(idx)


func _resolve(card_data, row, insert_index):
	if card_data.card_type == "Minion":
		battle.board_system.summon_minion(card_data, true, row, insert_index)
	else:
		battle.player_graveyard.add_spell(card_data)
		for effect in card_data.effects:
			battle.effect_manager.execute_effect(battle, null, effect)
			battle.refresh_board()
