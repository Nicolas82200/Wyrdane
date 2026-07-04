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
	# Les sorts éphémères montrent leur popup d'effet dans _resolve (glisse depuis
	# la gauche, puis l'effet). Inutile de doubler avec un reveal de ciblage ici.
	if card_data.card_type != "Instant":
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

	var summoned: Minion = null
	if card_data.card_type == "Minion":
		summoned = await battle.board_system.summon_minion_return(card_data, true, row, insert_index)
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
		elif card_data.card_type == "Ritual" and card_data.ritual_duration != 0:
			# Rituel à durée : reste dans sa zone, effets via triggers ; chaque
			# déclenchement effectif consomme une charge (voir _consume_ritual_charge)
			battle.trigger_system.register_enchantment(card_data, true, card_data.ritual_duration)
			battle.enchantment_system.add_ritual(card_data, true, card_data.ritual_duration)
			battle.aura_system.recompute_all()
		else:
			battle.player_graveyard.add_spell(card_data)
			# Popup de la carte (glisse depuis la gauche) affichée et lisible AVANT
			# que l'effet ne se joue
			await battle.card_popup_system.show_card_popup(card_data)
			for effect in card_data.effects:
				if target is Minion:
					await battle.effect_manager.execute_effect(battle, null, effect, target)
				else:
					await battle.effect_manager.execute_effect(battle, null, effect)
		battle.board_visual_system.refresh_board()

	# Émission réseau : le joueur local a joué cette carte sur une cible.
	if battle.net_emitter != null:
		battle.net_emitter.play_card(card_data, row, insert_index,
			summoned, target if target is Minion else null)

	battle.reset_targeting_state()

func _resolve(card_data: CardData, row: String, insert_index: int) -> void:
	var summoned: Minion = null
	if card_data.card_type == "Minion":
		summoned = await battle.board_system.summon_minion_return(card_data, true, row, insert_index)
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
		elif card_data.card_type == "Ritual" and card_data.ritual_duration != 0:
			# Rituel à durée : reste dans sa zone, effets via triggers ; chaque
			# déclenchement effectif consomme une charge (voir _consume_ritual_charge)
			battle.trigger_system.register_enchantment(card_data, true, card_data.ritual_duration)
			battle.enchantment_system.add_ritual(card_data, true, card_data.ritual_duration)
			battle.aura_system.recompute_all()
		else:
			battle.player_graveyard.add_spell(card_data)
			# Popup de la carte (glisse depuis la gauche) affichée et lisible AVANT
			# que l'effet ne se joue
			await battle.card_popup_system.show_card_popup(card_data)
			for effect in card_data.effects:
				await battle.effect_manager.execute_effect(battle, null, effect)
		battle.board_visual_system.refresh_board()

	# Émission réseau : le joueur local a joué cette carte (sans cible).
	if battle.net_emitter != null:
		battle.net_emitter.play_card(card_data, row, insert_index, summoned, null)

func _remove_from_hand(card_data: CardData) -> void:
	var idx: int = battle.hand_cards.find(card_data)
	if idx != -1:
		battle.hand_cards.remove_at(idx)
