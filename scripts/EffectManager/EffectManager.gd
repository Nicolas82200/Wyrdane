extends RefCounted
class_name EffectManager

func execute_effect(
	battle,
	source_minion: Minion,
	effect: CardEffect,
	selected_target: Minion = null
) -> void:
	if source_minion != null and source_minion.card_data != null:
		await battle.card_popup_system.show_targeting_popup(source_minion.card_data)
		await battle.get_tree().create_timer(0.5).timeout
		battle.card_popup_system.hide_targeting_popup()
	match effect.effect_id:
		"Damage":        _damage(battle, source_minion, effect, selected_target)
		"Heal":          _heal(battle, source_minion, effect, selected_target)
		"Buff":          _buff(battle, source_minion, effect, selected_target)
		"Debuff":        _debuff(battle, source_minion, effect, selected_target)
		"Destroy":       _destroy(battle, source_minion, effect, selected_target)
		"DrawCard":      _draw_cards(battle, effect.value)
		"SummonMinion":  await _summon_minion(battle, source_minion, effect)
		"SummonRandom":  await _summon_random(battle, source_minion, effect)
		"StealHealth":   _steal_health(battle, source_minion, effect, selected_target)
		"HealHero":      _heal_hero(battle, source_minion, effect)
		"ReturnToHand":  _return_to_hand(battle, source_minion, effect, selected_target)
		"InfectEnemy":   _infect(battle, source_minion, effect, selected_target)
		"Freeze":        _freeze(battle, source_minion, effect, selected_target)
		"Resurrect":     await _resurrect(battle, source_minion, effect)
		"StealMinion":   _steal_minion(battle, source_minion, effect, selected_target)
		"Silence":       _silence(battle, source_minion, effect, selected_target)
		"Transform":     _transform(battle, source_minion, effect, selected_target)
		"SummonSelf":  await _summon_self(battle, source_minion, effect)
		"DamageAll":   _damage_all(battle, source_minion, effect)
		"BuffRow":     _buff_row(battle, source_minion, effect)
		_:
			push_warning("Effet non implémenté : %s" % effect.effect_id)
	await battle.death_system.process_deaths()
	battle.board_visual_system.refresh_board()
	battle.hero_system.update_ui()

func execute_targeted_effect(battle, effect: CardEffect, target: Minion) -> void:
	await execute_effect(battle, null, effect, target)

# ─── Ciblage (déclaré en premier pour être visible) ───────────────────────────

func _get_targets(
	battle,
	source_minion: Minion,
	effect: CardEffect,
	selected_target: Minion = null
) -> Array[Minion]:
	var result: Array[Minion] = []
	match effect.target:
		"Self":
			if source_minion:
				result.append(source_minion)
		"EnemyMinion", "AllyMinion", "AnyMinion":
			if selected_target:
				result.append(selected_target)
			else:
				push_warning("Effet '%s' attend une cible mais selected_target est null." % effect.effect_id)
		"AllEnemies":
			result.append_array(battle.get_enemy_minions(source_minion))
		"AllAllies":
			result.append_array(battle.get_owner_minions(source_minion))
		"AllMinions":
			result.append_array(battle.player_minions)
			result.append_array(battle.enemy_minions)
		"AllEnemiesFront":
			var is_p: bool = source_minion != null and source_minion.owner_is_player
			result.append_array(battle.get_front_minions(not is_p))
		"AllEnemiesBack":
			var is_p: bool = source_minion != null and source_minion.owner_is_player
			result.append_array(battle.get_back_minions(not is_p))
		"AllAlliesFront":
			var is_p: bool = source_minion == null or source_minion.owner_is_player
			result.append_array(battle.get_front_minions(is_p))
		"AllAlliesBack":
			var is_p: bool = source_minion == null or source_minion.owner_is_player
			result.append_array(battle.get_back_minions(is_p))
		"RandomEnemy":
			var enemies: Array[Minion] = battle.get_enemy_minions(source_minion)
			if not enemies.is_empty():
				result.append(enemies.pick_random())
		"RandomAlly":
			var allies: Array[Minion] = battle.get_owner_minions(source_minion)
			if not allies.is_empty():
				result.append(allies.pick_random())
	return result

func _filter_targets(targets: Array[Minion], effect: CardEffect) -> Array[Minion]:
	var result: Array[Minion] = targets
	if not effect.race_filter.is_empty():
		result = result.filter(func(t: Minion) -> bool:
			return t.card_data.race == Race.from_string(effect.race_filter)
		)
	if not effect.row_filter.is_empty():
		result = result.filter(func(t: Minion) -> bool:
			return t.board_row == effect.row_filter
		)
	return result

func _resolve_targets(
	battle,
	source_minion: Minion,
	effect: CardEffect,
	selected_target: Minion = null
) -> Array[Minion]:
	return _filter_targets(_get_targets(battle, source_minion, effect, selected_target), effect)

# ─── Effets ───────────────────────────────────────────────────────────────────

func _damage(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	match effect.target:
		"EnemyHero":
			battle.hero_system.damage(battle.hero_system.get_enemy_hero(source_minion), effect.value)
		"OwnerHero":
			battle.hero_system.damage(battle.hero_system.get_owner_hero(source_minion), effect.value)
		_:
			for target in _resolve_targets(battle, source_minion, effect, selected_target):
				var visual = battle.board_visual_system.get_visual(target)
				if visual:
					var flash: Tween = battle.create_tween()
					flash.tween_property(visual, "modulate", Color(1.8, 0.3, 0.3, 1.0), 0.04)
					flash.tween_property(visual, "modulate", Color.WHITE, 0.18)
				target.take_damage(effect.value)

func _heal(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	match effect.target:
		"OwnerHero":
			battle.hero_system.get_owner_hero(source_minion).heal(effect.value)
		"EnemyHero":
			battle.hero_system.get_enemy_hero(source_minion).heal(effect.value)
		_:
			for target in _resolve_targets(battle, source_minion, effect, selected_target):
				target.heal(effect.value)

func _heal_hero(battle, source_minion: Minion, effect: CardEffect) -> void:
	var hero: Hero = battle.hero_system.get_owner_hero(source_minion)
	hero.heal(effect.value)

func _buff(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	for target in _resolve_targets(battle, source_minion, effect, selected_target):
		target.attack     += effect.value
		target.health     += effect.value_2
		target.max_health += effect.value_2

func _debuff(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	for target in _resolve_targets(battle, source_minion, effect, selected_target):
		target.attack = max(0, target.attack - effect.value)
		target.health = max(1, target.health - effect.value_2)

func _destroy(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	for target in _resolve_targets(battle, source_minion, effect, selected_target):
		target.health = 0

func _silence(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	for target in _resolve_targets(battle, source_minion, effect, selected_target):
		target.keywords.clear()
		target.silenced = true

func _freeze(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	for target in _resolve_targets(battle, source_minion, effect, selected_target):
		var turns: int = effect.value if effect.value > 0 else 1
		target.frozen_turns = max(target.frozen_turns, turns)

func _infect(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	for target in _resolve_targets(battle, source_minion, effect, selected_target):
		target.infected = true

func _steal_health(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	for target in _resolve_targets(battle, source_minion, effect, selected_target):
		var actual: int = min(effect.value, target.health)
		target.take_damage(actual)
		if source_minion:
			source_minion.heal(actual)

func _return_to_hand(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	for target in _resolve_targets(battle, source_minion, effect, selected_target):
		var is_player: bool = target.owner_is_player
		if is_player:
			battle.hand_cards.append(target.card_data)
		target.health = 0
		if is_player:
			battle.hand.set_hand(battle.hand_cards)

func _transform(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	if effect.transform_card == null:
		return
	for target in _resolve_targets(battle, source_minion, effect, selected_target):
		target.card_data  = effect.transform_card
		target.attack     = effect.transform_card.attack
		target.health     = effect.transform_card.health
		target.max_health = effect.transform_card.health
		target.keywords   = effect.transform_card.get_keyword_values()
		target.silenced   = false

func _draw_cards(battle, count: int) -> void:
	for i in range(count):
		battle.deck_system.draw_card()

func _summon_minion(battle, source_minion: Minion, effect: CardEffect) -> void:
	if effect.summon_card == null:
		return
	var is_player: bool = source_minion.owner_is_player if source_minion else true
	var preferred_row: String = source_minion.board_row if source_minion else "Front"
	for i in range(effect.count):
		var row: String = preferred_row
		if not battle.can_summon_to_row(is_player, row):
			row = "Back" if row == "Front" else "Front"
		if not battle.can_summon_to_row(is_player, row):
			push_warning("Board plein")
			break
		await battle.summon_minion(effect.summon_card, is_player, row)
		await battle.get_tree().create_timer(0.15).timeout

func _summon_random(battle, source_minion: Minion, effect: CardEffect) -> void:
	var is_player: bool = source_minion.owner_is_player if source_minion else true
	var pool: Array[CardData] = _get_random_pool(effect)
	if pool.is_empty():
		return
	for i in range(effect.count):
		var row: String = source_minion.board_row if source_minion else "Front"
		if not battle.can_summon_to_row(is_player, row):
			row = "Back" if row == "Front" else "Front"
		if not battle.can_summon_to_row(is_player, row):
			break
		var card: CardData = pool.pick_random()
		await battle.summon_minion(card, is_player, row)
		await battle.get_tree().create_timer(0.15).timeout

func _resurrect(battle, source_minion: Minion, effect: CardEffect) -> void:
	var is_player: bool = source_minion.owner_is_player if source_minion else true
	var graveyard: Graveyard = battle.player_graveyard if is_player else battle.enemy_graveyard
	var dead: Array[CardData] = graveyard.get_minions()
	if dead.is_empty():
		return
	var count: int = mini(effect.count, dead.size())
	for i in range(count):
		var card_data: CardData = dead[dead.size() - 1 - i]
		var row: String = "Front"
		if not battle.can_summon_to_row(is_player, row):
			row = "Back"
		if not battle.can_summon_to_row(is_player, row):
			break
		await battle.summon_minion(card_data, is_player, row)
		var minions: Array[Minion] = battle.player_minions if is_player else battle.enemy_minions
		if not minions.is_empty():
			minions.back().health = 1
		await battle.get_tree().create_timer(0.15).timeout

func _summon_self(battle, source_minion: Minion, effect: CardEffect) -> void:
	if source_minion == null:
		return
	var is_player: bool = source_minion.owner_is_player
	var row: String = source_minion.board_row
	for i in range(effect.count):
		if not battle.can_summon_to_row(is_player, row):
			row = "Back" if row == "Front" else "Front"
		if not battle.can_summon_to_row(is_player, row):
			push_warning("Board plein, impossible d'invoquer une copie")
			break
		await battle.summon_minion(source_minion.card_data, is_player, row)
		await battle.get_tree().create_timer(0.15).timeout

func _damage_all(battle, source_minion: Minion, effect: CardEffect) -> void:
	var targets: Array[Minion] = []
	match effect.target:
		"AllEnemies":
			targets.append_array(battle.get_enemy_minions(source_minion))
		"AllAllies":
			targets.append_array(battle.get_owner_minions(source_minion))
		"AllMinions":
			targets.append_array(battle.player_minions)
			targets.append_array(battle.enemy_minions)
		"AllEnemiesFront":
			var is_p: bool = source_minion != null and source_minion.owner_is_player
			targets.append_array(battle.get_front_minions(not is_p))
		"AllEnemiesBack":
			var is_p: bool = source_minion != null and source_minion.owner_is_player
			targets.append_array(battle.get_back_minions(not is_p))
		_:
			targets.append_array(_resolve_targets(battle, source_minion, effect))
	for target in targets:
		target.take_damage(effect.value)

func _buff_row(battle, source_minion: Minion, effect: CardEffect) -> void:
	var targets: Array[Minion] = []
	match effect.target:
		"AllAlliesFront":
			targets.append_array(battle.get_front_minions(
				source_minion == null or source_minion.owner_is_player
			))
		"AllAlliesBack":
			targets.append_array(battle.get_back_minions(
				source_minion == null or source_minion.owner_is_player
			))
		"AllEnemiesFront":
			targets.append_array(battle.get_front_minions(
				source_minion != null and not source_minion.owner_is_player
			))
		"AllEnemiesBack":
			targets.append_array(battle.get_back_minions(
				source_minion != null and not source_minion.owner_is_player
			))
		_:
			targets.append_array(_resolve_targets(battle, source_minion, effect))
	for target in targets:
		target.attack     += effect.value
		target.health     += effect.value_2
		target.max_health += effect.value_2
	# Buff temporaire si value_2 indique une durée — à gérer dans TurnSystem si besoin

func _steal_minion(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	for target in _resolve_targets(battle, source_minion, effect, selected_target):
		var from_player: bool = target.owner_is_player
		target.owner_is_player = not from_player
		if from_player:
			battle.enemy_minions.erase(target)
			battle.player_minions.append(target)
		else:
			battle.player_minions.erase(target)
			battle.enemy_minions.append(target)
		var visual: BoardMinion = battle.board_visual_system.find_visual(target)
		if visual:
			if from_player:
				if visual.minion_clicked.is_connected(battle.selection_system.on_player_minion_clicked):
					visual.minion_clicked.disconnect(battle.selection_system.on_player_minion_clicked)
				visual.minion_clicked.connect(battle.selection_system.on_enemy_minion_clicked)
			else:
				if visual.minion_clicked.is_connected(battle.selection_system.on_enemy_minion_clicked):
					visual.minion_clicked.disconnect(battle.selection_system.on_enemy_minion_clicked)
				visual.minion_clicked.connect(battle.selection_system.on_player_minion_clicked)

# ─── Pool aléatoire ───────────────────────────────────────────────────────────

func _get_random_pool(_effect: CardEffect) -> Array[CardData]:
	push_warning("_get_random_pool : CardDatabase non connecté")
	return []

func trigger_effects(battle, minion: Minion, trigger_name: String) -> void:
	if minion == null:
		return
	var trigger_found := false
	for trigger in minion.card_data.trigger_types:
		if trigger.type == trigger_name:
			trigger_found = true
			break
	if not trigger_found:
		return
	for effect in minion.card_data.effects:
		await execute_effect(battle, minion, effect)
