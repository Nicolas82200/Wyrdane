extends RefCounted
class_name EffectManager

func execute_effect(
	battle,
	source_minion: Minion,
	effect: CardEffect,
	selected_target: Minion = null
) -> void:
	match effect.effect_id:
		"Damage":       _damage(battle, source_minion, effect, selected_target)
		"Heal":         _heal(battle, source_minion, effect, selected_target)
		"Buff":         _buff(battle, source_minion, effect, selected_target)
		"Destroy":      _destroy(battle, source_minion, effect, selected_target)
		"DrawCard":     _draw_cards(battle, source_minion, effect.value)
		"SummonMinion": _summon_minion(battle, source_minion, effect)
		"StealHealth":  _steal_health(battle, source_minion, effect, selected_target)
		_:
			push_warning("Effet non implémenté : %s" % effect.effect_id)

	battle.remove_dead_minions()
	battle.refresh_board()
	battle.update_hero_ui()


func execute_targeted_effect(battle, effect: CardEffect, target: Minion) -> void:
	execute_effect(battle, null, effect, target)


# ─── Effets ───────────────────────────────────────────────────────────────────

func _heal(
	battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null
) -> void:
	match effect.target:
		"OwnerHero": battle.get_owner_hero(source_minion).heal(effect.value)
		"EnemyHero": battle.get_enemy_hero(source_minion).heal(effect.value)
		_:
			for target in _resolve_targets(battle, source_minion, effect, selected_target):
				target.heal(effect.value)


func _draw_cards(battle, _source: Minion, count: int) -> void:
	for i in range(count):
		battle.draw_card()
	battle.hand.set_hand(battle.hand_cards)


func _buff(
	battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null
) -> void:
	for target in _resolve_targets(battle, source_minion, effect, selected_target):
		target.attack += effect.value
		target.health += effect.value_2
		target.max_health += effect.value_2


func _summon_minion(battle, source_minion: Minion, effect: CardEffect) -> void:
	if effect.summon_card == null:
		return
	var is_player = source_minion.owner_is_player if source_minion else true
	var preferred_row: String = source_minion.board_row if source_minion else "Front"
	for i in range(effect.count):
		var row := preferred_row
		if not battle.can_summon_to_row(is_player, row):
			# Essaie l'autre rangée
			row = "Back" if row == "Front" else "Front"
		if not battle.can_summon_to_row(is_player, row):
			push_warning("Board plein, impossible d'invoquer")
			break
		await battle.summon_minion(effect.summon_card, is_player, row)
		await battle.get_tree().create_timer(0.3).timeout

func _steal_health(
	battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null
) -> void:
	for target in _resolve_targets(battle, source_minion, effect, selected_target):
		var actual = min(effect.value, target.health)
		target.take_damage(actual)
		source_minion.heal(actual)


func _damage(
	battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null
) -> void:
	match effect.target:
		"EnemyHero": battle.get_enemy_hero(source_minion).take_damage(effect.value)
		"OwnerHero": battle.get_owner_hero(source_minion).take_damage(effect.value)
		_:
			for target in _resolve_targets(battle, source_minion, effect, selected_target):
				target.take_damage(effect.value)


func _destroy(
	battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null
) -> void:
	for target in _resolve_targets(battle, source_minion, effect, selected_target):
		target.health = 0


# ─── Ciblage ──────────────────────────────────────────────────────────────────

func _resolve_targets(
	battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null
) -> Array:
	var targets := _get_targets(battle, source_minion, effect, selected_target)
	return _filter_targets(targets, effect)


func _get_targets(
	battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null
) -> Array:
	match effect.target:
		"Self":
			return [source_minion]
		"EnemyMinion", "AllyMinion", "AnyMinion":
			if selected_target:
				return [selected_target]
			push_warning("Effet '%s' attend une cible mais selected_target est null." % effect.effect_id)
		"AllEnemies":
			return battle.get_enemy_minions(source_minion)
		"AllAllies":
			return battle.get_owner_minions(source_minion)
		"AllMinions":
			var all: Array = []
			all.append_array(battle.get_front_minions(true))
			all.append_array(battle.get_back_minions(true))
			all.append_array(battle.get_front_minions(false))
			all.append_array(battle.get_back_minions(false))
			return all
		"RandomEnemy":
			var enemies = battle.get_enemy_minions(source_minion)
			return [] if enemies.is_empty() else [enemies.pick_random()]
		"RandomAlly":
			var allies = battle.get_owner_minions(source_minion)
			return [] if allies.is_empty() else [allies.pick_random()]
	return []


func _filter_targets(targets: Array, effect: CardEffect) -> Array:
	if effect.race_filter.is_empty():
		return targets
	return targets.filter(
		func(t): return t is Minion and t.card_data.race == Race.from_string(effect.race_filter)
	)
