extends Node
class_name CardSystem

var battle: Node

func init(_battle: Node) -> void:
	battle = _battle

func handle_card_played(card_data: CardData, row: String, insert_index: int) -> void:
	if card_data.card_type == "Minion" and not battle.can_play_card_on_row(card_data, row):
		return
	if card_data.card_type == "Minion" and not battle.can_summon_to_row(true, row):
		push_warning("Rangée %s pleine." % row)
		return
	if card_data.requires_target:
		battle.pending_card         = card_data
		battle.pending_row          = row
		battle.pending_insert_index = insert_index
		battle.waiting_for_target   = true
		await battle.card_popup_system.show_targeting_popup(card_data)
		battle.targeting_system.begin_targeting(card_data, row, insert_index)
		return
	await play_card(card_data, row, insert_index)

func play_card(card_data: CardData, row := "Front", insert_index := -1) -> void:
	await battle.card_popup_system.show_targeting_popup(card_data)
	await battle.get_tree().create_timer(0.4).timeout
	battle.card_popup_system.hide_targeting_popup()
	battle._pay_mana(card_data.cost)
	_remove_from_hand(card_data)
	await battle.get_tree().process_frame
	battle.hand._update_hand_layout(true)
	await _resolve(card_data, row, insert_index)

func resolve_with_target(card_data: CardData, row: String, insert_index: int, target) -> void:
	battle._pay_mana(card_data.cost)
	_remove_from_hand(card_data)
	await battle.get_tree().process_frame
	battle.hand._update_hand_layout(true)

	if card_data.card_type == "Minion":
		var summoned: Minion = await battle.board_system.summon_minion_return(card_data, true, row, insert_index)
		for effect in card_data.effects:
			if target is Minion:
				await battle.effect_manager.execute_effect(battle, summoned, effect, target)
			else:
				await battle.effect_manager.execute_effect(battle, summoned, effect)
	else:
		# Sortilège — enchantements adverses réagissent
		await battle.trigger_system.fire("OnSpell", null, false)
		for ally in battle.player_minions.duplicate():
			await battle.effect_manager.trigger_effects(battle, ally, "OnSpell")
		if card_data.card_type == "Enchantment":
			# Reste en jeu dans sa zone jusqu'à destruction — effets via TriggerSystem/AuraSystem
			battle.trigger_system.register_enchantment(card_data, true, -1)
			battle.enchantment_system.add_enchantment(card_data, true)
			battle.aura_system.recompute_all()
		else:
			battle.player_graveyard.add_spell(card_data)
			for effect in card_data.effects:
				if target is Minion:
					await battle.effect_manager.execute_effect(battle, null, effect, target)
				else:
					await battle.effect_manager.execute_effect(battle, null, effect)
		battle.board_visual_system.refresh_board()

	battle.reset_targeting_state()

func _resolve(card_data: CardData, row: String, insert_index: int) -> void:
	if card_data.card_type == "Minion":
		await battle.board_system.summon_minion(card_data, true, row, insert_index)
	else:
		# Sortilège — enchantements adverses réagissent
		await battle.trigger_system.fire("OnSpell", null, false)
		for ally in battle.player_minions.duplicate():
			await battle.effect_manager.trigger_effects(battle, ally, "OnSpell")
		if card_data.card_type == "Enchantment":
			# Reste en jeu dans sa zone jusqu'à destruction — effets via TriggerSystem/AuraSystem
			battle.trigger_system.register_enchantment(card_data, true, -1)
			battle.enchantment_system.add_enchantment(card_data, true)
			battle.aura_system.recompute_all()
		else:
			battle.player_graveyard.add_spell(card_data)
			for effect in card_data.effects:
				await battle.effect_manager.execute_effect(battle, null, effect)
		battle.board_visual_system.refresh_board()

func _remove_from_hand(card_data: CardData) -> void:
	var idx: int = battle.hand_cards.find(card_data)
	if idx != -1:
		battle.hand_cards.remove_at(idx)
