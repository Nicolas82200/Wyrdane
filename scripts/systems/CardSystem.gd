extends Node
class_name CardSystem

var battle

func init(_battle) -> void:
	battle = _battle

func play_card(card_data: CardData, row := "Front", insert_index := -1) -> void:
	var needs_target := _card_needs_target(card_data)

	if needs_target:
		pass
	else:
		await battle.card_popup_system.show_targeting_popup(card_data)
		await battle.get_tree().create_timer(0.4).timeout
		battle.card_popup_system.hide_targeting_popup()

	battle._pay_mana(card_data.cost)
	_remove_from_hand(card_data)
	await battle.get_tree().process_frame
	battle.hand._update_hand_layout(true)

	if not needs_target:
		await _resolve(card_data, row, insert_index)

func _card_needs_target(card_data: CardData) -> bool:
	if card_data == null or card_data.effects.is_empty():
		return false
	var t := card_data.effects[0].target
	return t in ["EnemyMinion", "AllyMinion", "AnyMinion", "EnemyHero", "OwnerHero"]

func resolve_with_target(card_data: CardData, row: String, insert_index: int, target) -> void:
	battle._pay_mana(card_data.cost)
	_remove_from_hand(card_data)
	await battle.get_tree().process_frame
	battle.hand._update_hand_layout(true)

	if card_data.card_type == "Minion":
		print("summon_minion — row: %s, index: %d" % [row, insert_index])
		await battle.board_system.summon_minion(card_data, true, row, insert_index)
		var source: Minion = null
		if not battle.player_minions.is_empty():
			for m in battle.player_minions:
				if m.card_data == card_data:
					source = m
					break
		for effect in card_data.effects:
			if target is Minion:
				await battle.effect_manager.execute_effect(battle, source, effect, target)
			else:
				await battle.effect_manager.execute_effect(battle, source, effect)
	else:
		battle.player_graveyard.add_spell(card_data)
		_trigger_on_spell()
		for effect in card_data.effects:
			if target is Minion:
				await battle.effect_manager.execute_effect(battle, null, effect, target)
			else:
				await battle.effect_manager.execute_effect(battle, null, effect)
		battle.board_visual_system.refresh_board()

	battle.waiting_for_target   = false
	battle.pending_card         = null
	battle.pending_row          = "Front"
	battle.pending_insert_index = -1

func _remove_from_hand(card_data: CardData) -> void:
	var idx: int = battle.hand_cards.find(card_data)
	if idx != -1:
		battle.hand_cards.remove_at(idx)

func _resolve(card_data: CardData, row: String, insert_index: int) -> void:
	if card_data.card_type == "Minion":
		await battle.board_system.summon_minion(card_data, true, row, insert_index)
	else:
		battle.board_visual_system.refresh_board()
		battle.player_graveyard.add_spell(card_data)
		_trigger_on_spell()
		for effect in card_data.effects:
			await battle.effect_manager.execute_effect(battle, null, effect)
		battle.board_visual_system.refresh_board()

func _trigger_on_spell() -> void:
	for minion in battle.player_minions:
		battle.trigger_effects(minion, "OnSpell")
