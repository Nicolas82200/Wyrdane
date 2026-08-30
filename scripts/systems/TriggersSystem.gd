extends Node
class_name TriggerSystem

# ─── Contexte d'un événement ──────────────────────────────────────────────────
class TriggerContext:
	var trigger_name: String
	var source_minion: Minion
	var is_player_event: bool
	var extra: Dictionary

	func _init(t: String, m: Minion, player: bool, data: Dictionary = {}) -> void:
		trigger_name    = t
		source_minion   = m
		is_player_event = player
		extra           = data

var battle

var _enchantments: Dictionary = {
	true:  [],
	false: []
}

func init(_battle) -> void:
	battle = _battle

# ─── Enregistrement ───────────────────────────────────────────────────────────

func register_enchantment(card_data: CardData, is_player: bool, duration: int = -1) -> void:
	_enchantments[is_player].append({
		"card_data":  card_data,
		"turns_left": duration,
		"triggered_this_turn": false
	})
	# Une aura de réduction de coût (Présence) doit se refléter immédiatement
	# sur les cartes en main, pas seulement au prochain tour (CostSystem.get_cost
	# la recalcule déjà correctement, mais rien ne rafraîchissait l'affichage
	# avant le prochain appel naturel à refresh_costs()).
	if battle.hand != null:
		battle.hand.refresh_costs()

# Réinitialise les enchantements/rituels "une fois par tour" du camp dont le
# tour commence (appelé depuis TurnSystem.run_turn_start_triggers).
func reset_once_per_turn(is_player: bool) -> void:
	for entry in _enchantments[is_player]:
		entry["triggered_this_turn"] = false

func unregister_enchantment(card_data: CardData, is_player: bool) -> void:
	_enchantments[is_player] = _enchantments[is_player].filter(
		func(e): return e["card_data"] != card_data
	)
	if battle.hand != null:
		battle.hand.refresh_costs()

func get_active_enchantments(is_player: bool) -> Array:
	return _enchantments[is_player]

# ─── Fire ─────────────────────────────────────────────────────────────────────

# paced : espace chaque enchantement déclenché d'une pause (phases de tour) ;
# à laisser false pour les triggers résolus au milieu d'une action (combat).
# already_acted : true si une action vient déjà d'avoir lieu dans la même file —
# la pause est insérée AVANT chaque déclenchement suivant, jamais avant le premier.
# Retourne l'état "au moins une action a eu lieu" pour chaîner le pacing.
func fire(trigger_name: String, source: Minion = null, is_player: bool = true, extra: Dictionary = {}, paced: bool = false, already_acted: bool = false) -> bool:
	var ctx := TriggerContext.new(trigger_name, source, is_player, extra)
	return await _fire_on_enchantments(ctx, paced, already_acted)

# ─── Enchantements ────────────────────────────────────────────────────────────

func _fire_on_enchantments(ctx: TriggerContext, paced: bool = false, already_acted: bool = false) -> bool:
	var acted := already_acted
	for is_player in [true, false]:
		var to_process: Array = _enchantments[is_player].duplicate()
		for entry in to_process:
			var card_data: CardData = entry["card_data"]
			if not _enchantment_reacts(card_data, ctx, is_player):
				continue
			if card_data.trigger_once_per_turn and entry["triggered_this_turn"]:
				continue
			# Les rituels d'annulation de sort ne réagissent PAS au fire OnSpell
			# générique : ils sont résolus en amont par try_cancel_spell (sinon ils
			# consommeraient une charge sur chaque sort, ciblé ou non).
			if ctx.trigger_name == "OnSpell" and _is_spell_cancel_card(card_data):
				continue
			# Condition non remplie (ex: pas assez d'alliés, mauvaise race du mort) :
			# le rituel ne réagit pas et ne consomme donc pas de charge.
			var proxy := _make_proxy(card_data, is_player)
			if not battle.effect_manager.any_condition_met(battle, proxy, card_data, ctx.source_minion):
				continue
			if paced and acted:
				await battle.pace_actions()
			# PACTE sur Rituel/Enchantement : contrairement à un serviteur (choix
			# unique à la pose), le paiement est redemandé à CHAQUE déclenchement
			# effectif du trigger ; l'effet de base reste gratuit, seul le bonus
			# (ou son remplacement) est gated (voir PactChoiceSystem.resolve_trigger).
			await _execute_enchantment_effects_with_proxy(proxy, card_data, is_player, ctx)
			acted = true
			if card_data.trigger_once_per_turn:
				entry["triggered_this_turn"] = true
			_consume_ritual_charge(entry, is_player)
	return acted

# ─── Rituels de Sacrifice ─────────────────────────────────────────────────────

# Activation volontaire d'un rituel de Sacrifice : tue les victimes (marquées
# `sacrificed`), exécute les effets du rituel puis consomme une charge.
# Appelé par SacrificeSystem (joueur local) et par NetworkOpponent (rejeu).
func activate_sacrifice_ritual(card_data: CardData, is_player: bool, victims: Array) -> void:
	var entry: Dictionary = _find_entry(card_data, is_player)
	if entry.is_empty():
		return
	for victim in victims:
		if victim == null or victim.is_dead():
			continue
		victim.sacrificed = true
		victim.health = 0
	await battle.death_system.process_deaths()
	var proxy := _make_proxy(card_data, is_player)

	# PACTE : les effets de base s'exécutent toujours ; le bonus (le cas échéant)
	# est proposé en plus, même logique que _fire_on_enchantments.
	var base_effects: Array[CardEffect] = []
	var bonus_effects: Array[CardEffect] = []
	for effect in card_data.effects:
		if effect.pact_bonus:
			bonus_effects.append(effect)
		else:
			base_effects.append(effect)

	var pact_paid: bool = false
	if not bonus_effects.is_empty():
		var pact_value: int = card_data.get_demon_keyword_value(KeywordDemon.Type.PACTE)
		if pact_value > 0:
			pact_paid = await battle.pact_choice_system.resolve_trigger(card_data, is_player)
			# Garde-fou : resolve_trigger() attend potentiellement plusieurs
			# secondes le clic Oui/Non du joueur (PactChoiceSystem.ask) ; si la
			# scène de bataille a été détruite entre-temps, `battle` devient une
			# instance libérée — sans ce garde-fou, tout le reste plantait
			# dessus (même classe de bug que sur Hand.gd/EffectManager.gd).
			if not is_instance_valid(battle):
				return
			if pact_paid:
				await battle.hero_system.self_damage(is_player, pact_value)

	var replaces_base: bool = pact_paid and bonus_effects.any(func(e: CardEffect) -> bool: return e.pact_replaces_base)
	if not replaces_base:
		for effect in base_effects:
			await battle.effect_manager.execute_effect(battle, proxy, effect)
	if pact_paid:
		for effect in bonus_effects:
			await battle.effect_manager.execute_effect(battle, proxy, effect)
	_consume_ritual_charge(entry, is_player)
	battle.board_visual_system.refresh_board()

func _find_entry(card_data: CardData, is_player: bool) -> Dictionary:
	for entry in _enchantments[is_player]:
		if entry["card_data"] == card_data:
			return entry
	return {}

# Un rituel à durée limitée ne perd une charge que lorsque son effet se
# déclenche réellement (et non passivement à chaque tour). Quand le compteur
# atteint 0, le rituel est détruit et envoyé au cimetière.
# Les enchantements permanents (turns_left == -1) ne sont jamais décrémentés.
func _consume_ritual_charge(entry: Dictionary, is_player: bool) -> void:
	if entry["turns_left"] == -1:
		return
	entry["turns_left"] -= 1
	if entry["turns_left"] <= 0:
		battle.enchantment_system.destroy_enchantment(entry["card_data"], is_player)
	else:
		battle.enchantment_system.update_turns_left(entry["card_data"], is_player, entry["turns_left"])

func _enchantment_reacts(card_data: CardData, ctx: TriggerContext, enchantment_owner_is_player: bool) -> bool:
	for trigger in card_data.trigger_types:
		# trigger.type est une String ("OnAwaken", "OnGrief"...)
		if trigger.type != ctx.trigger_name:
			continue

		match ctx.trigger_name:
			"OnAwaken":
				return enchantment_owner_is_player == ctx.is_player_event
			"OnResonance":
				if ctx.source_minion == null:
					return false
				if enchantment_owner_is_player != ctx.is_player_event:
					return false
				return card_data.race == ctx.source_minion.card_data.race
			"OnGrief":
				return enchantment_owner_is_player == ctx.is_player_event
			"OnCarnage":
				return enchantment_owner_is_player == ctx.is_player_event
			"OnSpell":
				return enchantment_owner_is_player != ctx.is_player_event
			"OnAura":
				return true
			"OnSummon":
				return enchantment_owner_is_player == ctx.is_player_event
			_:
				return enchantment_owner_is_player == ctx.is_player_event

	return false

func _execute_enchantment_effects_with_proxy(proxy: Minion, card_data: CardData, is_player: bool, ctx: TriggerContext) -> void:
	# Cible contextuelle : la cible explicite de l'évènement si fournie (ex: le
	# défenseur d'une attaque pour OnResonance), sinon la source de l'évènement.
	var context_target: Minion = ctx.extra.get("target", ctx.source_minion)

	var base_effects: Array[CardEffect] = []
	var bonus_effects: Array[CardEffect] = []
	for effect in card_data.effects:
		if effect.trigger != "" and effect.trigger != ctx.trigger_name:
			continue
		if effect.pact_bonus:
			bonus_effects.append(effect)
		else:
			base_effects.append(effect)

	var pact_paid: bool = false
	if not bonus_effects.is_empty():
		var pact_value: int = card_data.get_demon_keyword_value(KeywordDemon.Type.PACTE)
		if pact_value > 0:
			pact_paid = await battle.pact_choice_system.resolve_trigger(card_data, is_player)
			# Garde-fou : voir activate_sacrifice_ritual ci-dessus.
			if not is_instance_valid(battle):
				return
			if pact_paid:
				await battle.hero_system.self_damage(is_player, pact_value)

	var replaces_base: bool = pact_paid and bonus_effects.any(func(e: CardEffect) -> bool: return e.pact_replaces_base)
	if not replaces_base:
		for effect in base_effects:
			await battle.effect_manager.execute_effect(battle, proxy, effect, _effect_target(effect, ctx, context_target))
	if pact_paid:
		for effect in bonus_effects:
			await battle.effect_manager.execute_effect(battle, proxy, effect, _effect_target(effect, ctx, context_target))

# Certains effets (ex: Aura de Décrépitude) doivent viser le serviteur à
# l'origine de l'évènement (l'attaquant) plutôt que context_target (qui, pour
# OnResonance, porte la cible de l'attaque — voir commentaire ci-dessus).
func _effect_target(effect: CardEffect, ctx: TriggerContext, context_target: Minion) -> Minion:
	if effect.target == "TriggerSource":
		return ctx.source_minion
	return context_target

func _make_proxy(card_data: CardData, is_player: bool) -> Minion:
	return Minion.new(card_data, is_player, "")

func _is_spell_cancel_card(card_data: CardData) -> bool:
	return card_data.effects.any(func(e: CardEffect): return e.effect_id in ["CancelSpellOnRaceTarget", "CancelFirstEnemySpellPerTurn"])

# ─── Annulation de sort (Rituel de l'Éclipse Rouge) ──────────────────────────
# Appelé par CardSystem AVANT de résoudre un sort ciblé : si le camp adverse au
# lanceur possède un rituel/enchantement à trigger OnSpell portant un effet
# "CancelSpellOnRaceTarget" dont la race correspond à la cible (qui doit
# appartenir au camp du rituel), le sort est annulé. Les autres effets du rituel
# (ex: perte de HP de son propriétaire) s'exécutent et une charge est consommée.
# Retourne true si le sort a été annulé.
func try_cancel_spell(caster_is_player: bool, target: Minion) -> bool:
	if target == null:
		return false
	var owner_is_player: bool = not caster_is_player
	if target.owner_is_player != owner_is_player:
		return false
	for entry in _enchantments[owner_is_player].duplicate():
		var card_data: CardData = entry["card_data"]
		if not card_data.get_trigger_names().has("OnSpell"):
			continue
		var cancel_effect: CardEffect = null
		for effect in card_data.effects:
			if effect.effect_id == "CancelSpellOnRaceTarget":
				cancel_effect = effect
				break
		if cancel_effect == null:
			continue
		if not cancel_effect.race_filter.is_empty() \
				and target.card_data.race != Race.from_string(cancel_effect.race_filter):
			continue
		# Mur Infranchissable : "un serviteur Humain allié en rangée Avant".
		if not cancel_effect.row_filter.is_empty() \
				and target.board_row != cancel_effect.row_filter:
			continue
		# PACTE : le paiement (par annulation) conditionne l'annulation elle-même ;
		# refusé, le sort n'est pas annulé par CE rituel mais la charge est quand
		# même consommée (il a réagi à l'évènement).
		var pact_value: int = card_data.get_demon_keyword_value(KeywordDemon.Type.PACTE)
		if pact_value > 0:
			var pact_paid: bool = await battle.pact_choice_system.resolve_trigger(card_data, owner_is_player)
			# Garde-fou : voir activate_sacrifice_ritual plus haut.
			if not is_instance_valid(battle):
				return false
			if not pact_paid:
				_consume_ritual_charge(entry, owner_is_player)
				continue
			await battle.hero_system.self_damage(owner_is_player, pact_value)
		var proxy := _make_proxy(card_data, owner_is_player)
		for effect in card_data.effects:
			if effect.effect_id == "CancelSpellOnRaceTarget":
				continue
			await battle.effect_manager.execute_effect(battle, proxy, effect)
		_consume_ritual_charge(entry, owner_is_player)
		battle.board_visual_system.refresh_board()
		return true
	return false

# ─── Annulation du premier sort ennemi du tour (Bouclier de la Foi) ──────────
# Contrairement à try_cancel_spell (qui ne réagit qu'aux sorts CIBLANT un
# serviteur du camp du rituel), ceci annule le premier sort ennemi du tour
# quel que soit son type de cible (serviteur, héros, aucune cible) — gated par
# CardData.trigger_once_per_turn, comme n'importe quel autre "une fois par tour".
# Appelé par CardSystem AVANT de résoudre tout sort (Éphémère/Rituel/Enchantement).
func try_cancel_first_enemy_spell(caster_is_player: bool) -> bool:
	var owner_is_player: bool = not caster_is_player
	for entry in _enchantments[owner_is_player].duplicate():
		var card_data: CardData = entry["card_data"]
		if not card_data.get_trigger_names().has("OnSpell"):
			continue
		if not card_data.effects.any(func(e: CardEffect): return e.effect_id == "CancelFirstEnemySpellPerTurn"):
			continue
		if card_data.trigger_once_per_turn and entry["triggered_this_turn"]:
			continue
		entry["triggered_this_turn"] = true
		_consume_ritual_charge(entry, owner_is_player)
		battle.board_visual_system.refresh_board()
		return true
	return false
