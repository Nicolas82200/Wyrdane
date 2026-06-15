extends RefCounted
class_name EffectManager

static func execute_effect(
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


static func execute_targeted_effect(battle, effect: CardEffect, target: Minion) -> void:
	execute_effect(battle, null, effect, target)


# ─── Effets ───────────────────────────────────────────────────────────────────

static func _heal(
	battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null
) -> void:
	match effect.target:
		"OwnerHero": battle.get_owner_hero(source_minion).heal(effect.value)
		"EnemyHero": battle.get_enemy_hero(source_minion).heal(effect.value)
		_:
			for target in _resolve_targets(battle, source_minion, effect, selected_target):
				target.heal(effect.value)


static func _draw_cards(battle, _source: Minion, count: int) -> void:
	for i in range(count):
		battle.draw_card()
	battle.hand.set_hand(battle.hand_cards)


static func _buff(
	battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null
) -> void:
	for target in _resolve_targets(battle, source_minion, effect, selected_target):
		target.attack += effect.value
		target.health += effect.value_2
		target.max_health += effect.value_2


static func _summon_minion(battle, source_minion: Minion, effect: CardEffect) -> void:
	if effect.summon_card == null:
		return
	for i in range(effect.count):
		battle.summon_minion(effect.summon_card, source_minion.owner_is_player)

static func _steal_health(
	battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null
) -> void:
	for target in _resolve_targets(battle, source_minion, effect, selected_target):
		var actual = min(effect.value, target.health)
		target.take_damage(actual)
		source_minion.heal(actual)


static func _damage(
	battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null
) -> void:
	match effect.target:
		"EnemyHero": battle.get_enemy_hero(source_minion).take_damage(effect.value)
		"OwnerHero": battle.get_owner_hero(source_minion).take_damage(effect.value)
		_:
			for target in _resolve_targets(battle, source_minion, effect, selected_target):
				target.take_damage(effect.value)


static func _destroy(
	battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null
) -> void:
	for target in _resolve_targets(battle, source_minion, effect, selected_target):
		target.health = 0


# ─── Ciblage ──────────────────────────────────────────────────────────────────

static func _resolve_targets(
	battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null
) -> Array:
	var targets := _get_targets(battle, source_minion, effect, selected_target)
	return _filter_targets(targets, effect)


static func _get_targets(
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
			all.append_array(battle.player_minions)
			all.append_array(battle.enemy_minions)
			return all
		"RandomEnemy":
			var enemies = battle.get_enemy_minions(source_minion)
			return [] if enemies.is_empty() else [enemies.pick_random()]
		"RandomAlly":
			var allies = battle.get_owner_minions(source_minion)
			return [] if allies.is_empty() else [allies.pick_random()]
	return []


static func _filter_targets(targets: Array, effect: CardEffect) -> Array:
	if effect.race_filter.is_empty():
		return targets
	return targets.filter(
		func(t): return t is Minion and t.card_data.race == Race.from_string(effect.race_filter)
	)
