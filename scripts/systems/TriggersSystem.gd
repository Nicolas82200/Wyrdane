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
		"turns_left": duration
	})

func unregister_enchantment(card_data: CardData, is_player: bool) -> void:
	_enchantments[is_player] = _enchantments[is_player].filter(
		func(e): return e["card_data"] != card_data
	)

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
			if paced and acted:
				await battle.pace_actions()
			await _execute_enchantment_effects(card_data, is_player, ctx)
			acted = true
	return acted

func _enchantment_reacts(card_data: CardData, ctx: TriggerContext, enchantment_owner_is_player: bool) -> bool:
	for trigger in card_data.trigger_types:
		# trigger.type est une String ("OnAwaken", "OnGrief"...)
		if trigger.type != ctx.trigger_name:
			continue

		match ctx.trigger_name:
			"OnAwaken", "OnTurnStart":
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
			"OnRally":
				if ctx.source_minion == null:
					return false
				return enchantment_owner_is_player == ctx.is_player_event
			"OnSummon":
				return enchantment_owner_is_player == ctx.is_player_event
			"OnTurnEnd":
				return enchantment_owner_is_player == ctx.is_player_event
			_:
				return enchantment_owner_is_player == ctx.is_player_event

	return false

func _execute_enchantment_effects(card_data: CardData, is_player: bool, ctx: TriggerContext) -> void:
	var proxy := _make_proxy(card_data, is_player)
	for effect in card_data.effects:
		await battle.effect_manager.execute_effect(battle, proxy, effect, ctx.source_minion)

func _make_proxy(card_data: CardData, is_player: bool) -> Minion:
	return Minion.new(card_data, is_player, "")

# ─── Durées ───────────────────────────────────────────────────────────────────

func tick_enchantment_durations(is_player: bool) -> void:
	var expired: Array = []
	for entry in _enchantments[is_player]:
		if entry["turns_left"] == -1:
			continue
		entry["turns_left"] -= 1
		if entry["turns_left"] <= 0:
			expired.append(entry)
	for entry in expired:
		# Retire aussi le visuel de la zone et envoie la carte au cimetière
		battle.enchantment_system.destroy_enchantment(entry["card_data"], is_player)

func clear_all(is_player: bool) -> void:
	_enchantments[is_player].clear()

# ─── Présence (Aura) ──────────────────────────────────────────────────────────

func apply_auras() -> void:
	for is_player in [true, false]:
		for entry in _enchantments[is_player]:
			var card_data: CardData = entry["card_data"]
			var has_aura := card_data.trigger_types.any(
				func(t): return t.type == "OnAura"
			)
			if has_aura:
				var proxy := _make_proxy(card_data, is_player)
				for effect in card_data.effects:
					await battle.effect_manager.execute_effect(battle, proxy, effect)
