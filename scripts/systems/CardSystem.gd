extends Node
class_name CardSystem

var battle

func init(_battle) -> void:
	battle = _battle

func handle_card_played(card_data: CardData, row: String, insert_index: int) -> void:
	if card_data.card_type == "Resource":
		if not battle.can_afford_card(card_data):
			return
		battle.play_resource_card(card_data, true)
		_remove_from_hand(card_data)
		await battle.get_tree().process_frame
		battle.hand._update_hand_layout(true)
		# Popup d'effet (glisse depuis la gauche, lisible) qui se désintègre
		# ensuite vers le pool de mana de sa race — sans await, pour ne pas
		# bloquer la suite du tour sur cette animation cosmétique.
		battle.card_popup_system.show_resource_popup(card_data)
		if battle.net_emitter != null:
			battle.net_emitter.play_card(card_data, "Resource", -1)
		if battle.tutorial_manager:
			await battle.tutorial_manager.notify_card_played(card_data)
		return
	if card_data.card_type == "Minion" and not battle.can_play_card_on_row(card_data, row):
		return
	if card_data.card_type == "Minion" and not battle.can_summon_to_row(true, row):
		push_warning("Rangée %s pleine." % row)
		return
	if not conditions_met(card_data):
		push_warning("Conditions non remplies pour jouer %s." % card_data.card_name)
		battle.hand.set_hand(battle.hand_cards)
		return

	# PACTE : demande au joueur s'il paie le coût en PV pour activer l'effet
	# d'Arrivée de la carte. Sans PACTE (value 0), pact_paid reste true — n'a
	# alors aucune incidence sur la suite du flux (carte non concernée).
	var pact_value: int = card_data.get_demon_keyword_value(KeywordDemon.Type.PACTE)
	var pact_paid: bool = true
	if card_data.card_type == "Minion" and pact_value > 0:
		pact_paid = await battle.pact_choice_system.ask(card_data, pact_value)

	if card_data.requires_target:
		if not pact_paid:
			# Pacte refusé : l'effet (donc le besoin de cible) disparaît, la
			# carte se pose comme un vanille, sans passer par le ciblage.
			await play_card(card_data, row, insert_index, false)
			return
		# Serviteur à effet ciblé sans cible valide : on le pose quand même,
		# l'effet d'Invocation est simplement perdu (le sort, lui, est bloqué
		# en amont par conditions_met)
		if card_data.card_type == "Minion" \
				and not battle.targeting_system.has_any_valid_target(card_data):
			await play_card(card_data, row, insert_index, pact_paid)
			return
		battle.pending_card         = card_data
		battle.pending_row          = row
		battle.pending_insert_index = insert_index
		battle.waiting_for_target   = true
		await battle.card_popup_system.show_targeting_popup(card_data)
		battle.targeting_system.begin_targeting(card_data, row, insert_index, null, pact_paid)
		return
	await play_card(card_data, row, insert_index, pact_paid)

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
			"SacrificeAlly":
				# Impossible de payer le coût de sacrifice sans assez d'alliés.
				if battle.player_minions.size() < effect.count:
					return false
	return true

func play_card(card_data: CardData, row := "Front", insert_index := -1, pact_paid := false) -> void:
	# Les sorts éphémères montrent leur popup d'effet dans _resolve (glisse depuis
	# la gauche, puis l'effet). Inutile de doubler avec un reveal de ciblage ici.
	if card_data.card_type != "Instant":
		await battle.card_popup_system.show_targeting_popup(card_data)
		await battle.get_tree().create_timer(0.4).timeout
		battle.card_popup_system.hide_targeting_popup()
	battle.cost_system.pay(card_data, true)
	battle.update_mana_ui()
	await battle.cost_system.on_card_played(card_data, true)
	_remove_from_hand(card_data)
	await battle.get_tree().process_frame
	battle.hand._update_hand_layout(true)
	await _resolve(card_data, row, insert_index, pact_paid)
	if battle.tutorial_manager:
		await battle.tutorial_manager.notify_card_played(card_data)

func resolve_with_target(card_data: CardData, row: String, insert_index: int, target, pact_paid := true) -> void:
	battle.cost_system.pay(card_data, true)
	battle.update_mana_ui()
	await battle.cost_system.on_card_played(card_data, true)
	_remove_from_hand(card_data)
	await battle.get_tree().process_frame
	battle.hand._update_hand_layout(true)

	# Capture les ids de tous les serviteurs créés par l'action, pour les rejouer.
	if battle.net_emitter != null:
		battle.net_registry.begin_capture()

	var summoned: Minion = null
	if card_data.card_type == "Minion":
		summoned = await battle.board_system.summon_minion_return(card_data, true, row, insert_index, false, pact_paid)
		# pact_paid par défaut à true : seules les cartes PACTE ciblées passent
		# explicitement false (Pacte refusé, voir handle_card_played) — dans ce
		# cas l'effet ci-dessous, qui EST l'effet du Pacte, ne doit pas s'exécuter.
		if pact_paid:
			for effect in card_data.effects:
				if target is Minion:
					await battle.effect_manager.execute_effect(battle, summoned, effect, target)
				elif target is CardData:
					await battle.effect_manager.execute_enchantment_targeted_effect(battle, summoned, effect, target)
				else:
					await battle.effect_manager.execute_effect(battle, summoned, effect)
	else:
		# Annulation de sort (Rituel de l'Éclipse Rouge) : un rituel adverse peut
		# contrer un sort ciblant un de ses serviteurs. Le sort est alors défaussé
		# sans effet (mana déjà payé).
		if target is Minion and await battle.trigger_system.try_cancel_spell(true, target):
			battle.player_graveyard.add_spell(card_data)
			battle.board_visual_system.refresh_board()
			if battle.net_emitter != null:
				var cancelled_ids: Array = battle.net_registry.end_capture()
				battle.net_emitter.play_card(card_data, row, insert_index, cancelled_ids, target)
			battle.reset_targeting_state()
			return
		battle.combat_log.card_played(card_data, true)
		# Popup de la carte (glisse depuis la gauche) affichée et lisible AVANT
		# que l'effet ne se joue — uniquement en résolution immédiate (Éphémère,
		# Rituel sans durée) ; un Enchantement/Rituel à durée rejoint sa zone
		# sans reveal, donc pas de popup pour lui.
		var shows_popup: bool = card_data.card_type != "Enchantment" \
			and not (card_data.card_type == "Ritual" and card_data.ritual_duration != 0)
		if shows_popup:
			await battle.card_popup_system.show_card_popup(card_data)
		# Sortilège — enchantements adverses réagissent
		await battle.trigger_system.fire("OnSpell", null, false)
		for ally in battle.player_minions.duplicate():
			await battle.effect_manager.trigger_effects(battle, ally, "OnSpell")
		if card_data.card_type == "Enchantment":
			# Reste en jeu dans sa zone jusqu'à destruction — effets via TriggerSystem/AuraSystem
			battle.trigger_system.register_enchantment(card_data, true, -1)
			battle.enchantment_system.add_enchantment(card_data, true)
			battle.aura_system.recompute_all()
			await battle.death_system.process_deaths()
		elif card_data.card_type == "Ritual" and card_data.ritual_duration != 0:
			# Rituel à durée : reste dans sa zone, effets via triggers ; chaque
			# déclenchement effectif consomme une charge (voir _consume_ritual_charge)
			AudioManager.play_spell_cast(card_data)
			battle.vfx_manager.spawn_for_spell(battle, card_data, true, target if target is Minion else null)
			battle.trigger_system.register_enchantment(card_data, true, card_data.ritual_duration)
			battle.enchantment_system.add_ritual(card_data, true, card_data.ritual_duration)
			battle.aura_system.recompute_all()
			await battle.death_system.process_deaths()
		else:
			# Son/VFX joués juste avant la résolution effective de l'effet (et
			# non avant), pour rester synchronisés avec ce qui se passe réellement.
			AudioManager.play_spell_cast(card_data)
			battle.vfx_manager.spawn_for_spell(battle, card_data, true, target if target is Minion else null)
			battle.player_graveyard.add_spell(card_data)
			for effect in card_data.effects:
				if target is Minion:
					await battle.effect_manager.execute_effect(battle, null, effect, target)
				elif target is CardData:
					await battle.effect_manager.execute_enchantment_targeted_effect(battle, null, effect, target)
				else:
					await battle.effect_manager.execute_effect(battle, null, effect)
		battle.board_visual_system.refresh_board()

	# Émission réseau : le joueur local a joué cette carte sur une cible.
	# NOTE: NetCommand ne sait sérialiser qu'un net_id de Minion ; une cible
	# CardData (enchantement/rituel) n'est donc PAS encore synchronisée au
	# pair distant (nécessiterait un id stable façon NetRegistry pour les
	# enchantements). À faire avant d'utiliser ce ciblage en multijoueur.
	if battle.net_emitter != null:
		var ids: Array = battle.net_registry.end_capture()
		battle.net_emitter.play_card(card_data, row, insert_index,
			ids, target if target is Minion else null, pact_paid)

	battle.reset_targeting_state()
	if battle.tutorial_manager:
		await battle.tutorial_manager.notify_card_played(card_data)

func _resolve(card_data: CardData, row: String, insert_index: int, pact_paid := false) -> void:
	if battle.net_emitter != null:
		battle.net_registry.begin_capture()
	if card_data.card_type == "Minion":
		await battle.board_system.summon_minion_return(card_data, true, row, insert_index, false, pact_paid)
	else:
		battle.combat_log.card_played(card_data, true)
		var shows_popup: bool = card_data.card_type != "Enchantment" \
			and not (card_data.card_type == "Ritual" and card_data.ritual_duration != 0)
		if shows_popup:
			await battle.card_popup_system.show_card_popup(card_data)
		# Sortilège — enchantements adverses réagissent
		await battle.trigger_system.fire("OnSpell", null, false)
		for ally in battle.player_minions.duplicate():
			await battle.effect_manager.trigger_effects(battle, ally, "OnSpell")
		if card_data.card_type == "Enchantment":
			# Reste en jeu dans sa zone jusqu'à destruction — effets via TriggerSystem/AuraSystem
			battle.trigger_system.register_enchantment(card_data, true, -1)
			battle.enchantment_system.add_enchantment(card_data, true)
			battle.aura_system.recompute_all()
			await battle.death_system.process_deaths()
		elif card_data.card_type == "Ritual" and card_data.ritual_duration != 0:
			# Rituel à durée : reste dans sa zone, effets via triggers ; chaque
			# déclenchement effectif consomme une charge (voir _consume_ritual_charge)
			AudioManager.play_spell_cast(card_data)
			battle.vfx_manager.spawn_for_spell(battle, card_data, true, null)
			battle.trigger_system.register_enchantment(card_data, true, card_data.ritual_duration)
			battle.enchantment_system.add_ritual(card_data, true, card_data.ritual_duration)
			battle.aura_system.recompute_all()
			await battle.death_system.process_deaths()
		else:
			# Son/VFX joués juste avant la résolution effective de l'effet (et
			# non avant), pour rester synchronisés avec ce qui se passe réellement.
			AudioManager.play_spell_cast(card_data)
			battle.vfx_manager.spawn_for_spell(battle, card_data, true, null)
			battle.player_graveyard.add_spell(card_data)
			for effect in card_data.effects:
				await battle.effect_manager.execute_effect(battle, null, effect)
		battle.board_visual_system.refresh_board()

	# Émission réseau : le joueur local a joué cette carte (sans cible).
	if battle.net_emitter != null:
		var ids: Array = battle.net_registry.end_capture()
		battle.net_emitter.play_card(card_data, row, insert_index, ids, null, pact_paid)

func _remove_from_hand(card_data: CardData) -> void:
	var idx: int = battle.hand_cards.find(card_data)
	if idx != -1:
		battle.hand_cards.remove_at(idx)
