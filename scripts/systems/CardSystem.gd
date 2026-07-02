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
	if not conditions_met(card_data):
		push_warning("Conditions non remplies pour jouer %s." % card_data.card_name)
		battle.hand.set_hand(battle.hand_cards)
		return
	if card_data.requires_target:
		# Serviteur à effet ciblé sans cible valide : on le pose quand même,
		# l'effet d'Invocation est simplement perdu (le sort, lui, est bloqué
		# en amont par conditions_met)
		if card_data.card_type == "Minion" \
				and not battle.targeting_system.has_any_valid_target(card_data):
			await play_card(card_data, row, insert_index)
			return
		battle.pending_card         = card_data
		battle.pending_row          = row
		battle.pending_insert_index = insert_index
		battle.waiting_for_target   = true
		await battle.card_popup_system.show_targeting_popup(card_data)
		battle.targeting_system.begin_targeting(card_data, row, insert_index)
		return
	await play_card(card_data, row, insert_index)

# Un sort dont les conditions ne sont pas remplies (aucune cible valide,
# cimetière vide...) ne doit pas pouvoir être lancé.
func conditions_met(card_data: CardData) -> bool:
	if card_data == null:
		return false
	if card_data.card_type == "Minion":
		return true
	if card_data.requires_target \
			and not battle.targeting_system.has_any_valid_target(card_data):
		return false
	for effect in card_data.effects:
		match effect.effect_id:
			"Resurrect", "ResurrectLast", "ReturnFromGrave":
				if battle.player_graveyard.get_minions().is_empty():
					return false
	return true

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
		battle.player_graveyard.add_spell(card_data)
		# Sortilège — enchantements adverses réagissent
		await battle.trigger_system.fire("OnSpell", null, false)
		for ally in battle.player_minions.duplicate():
			await battle.effect_manager.trigger_effects(battle, ally, "OnSpell")
		for effect in card_data.effects:
			if target is Minion:
				await battle.effect_manager.execute_effect(battle, null, effect, target)
			else:
				await battle.effect_manager.execute_effect(battle, null, effect)
		# Enregistre l'enchantement si c'est un enchantement
		if card_data.card_type == "Enchantment":
			var duration: int = card_data.get("duration") if card_data.get("duration") != null else -1
			battle.trigger_system.register_enchantment(card_data, true, duration)
			battle.aura_system.recompute_all()
			battle.enchantment_system.add_enchantment(card_data, true)
		battle.board_visual_system.refresh_board()

	battle.reset_targeting_state()

func _resolve(card_data: CardData, row: String, insert_index: int) -> void:
	if card_data.card_type == "Minion":
		await battle.board_system.summon_minion(card_data, true, row, insert_index)
	else:
		battle.player_graveyard.add_spell(card_data)
		# Sortilège — enchantements adverses réagissent
		await battle.trigger_system.fire("OnSpell", null, false)
		for ally in battle.player_minions.duplicate():
			await battle.effect_manager.trigger_effects(battle, ally, "OnSpell")
		for effect in card_data.effects:
			await battle.effect_manager.execute_effect(battle, null, effect)
		# Enregistre l'enchantement si c'est un enchantement
		if card_data.card_type == "Enchantment":
			var duration: int = card_data.get("duration") if card_data.get("duration") != null else -1
			battle.trigger_system.register_enchantment(card_data, true, duration)
			battle.aura_system.recompute_all()
			battle.enchantment_system.add_enchantment(card_data, true)
		battle.board_visual_system.refresh_board()

func _remove_from_hand(card_data: CardData) -> void:
	var idx: int = battle.hand_cards.find(card_data)
	if idx != -1:
		battle.hand_cards.remove_at(idx)
