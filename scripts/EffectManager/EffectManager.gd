extends RefCounted
class_name EffectManager

func execute_effect(
	battle,
	source_minion: Minion,
	effect: CardEffect,
	selected_target: Minion = null
) -> void:
	if source_minion != null and source_minion.card_data != null:
		battle.card_popup_system.show_card_popup(source_minion.card_data)
	match effect.effect_id:
		"Damage":           await _damage(battle, source_minion, effect, selected_target)
		"Heal":             _heal(battle, source_minion, effect, selected_target)
		"Buff":             _buff(battle, source_minion, effect, selected_target)
		"Debuff":           _debuff(battle, source_minion, effect, selected_target)
		"Destroy":          _destroy(battle, source_minion, effect, selected_target)
		"DrawCard":         _draw_cards(battle, effect.value)
		"SummonMinion":     await _summon_minion(battle, source_minion, effect)
		"SummonRandom":     await _summon_random(battle, source_minion, effect)
		"StealHealth":      await _steal_health(battle, source_minion, effect, selected_target)
		"HealHero":         _heal_hero(battle, source_minion, effect)
		"ReturnToHand":     _return_to_hand(battle, source_minion, effect, selected_target)
		"InfectEnemy":      _infect(battle, source_minion, effect, selected_target)
		"InfectAdjacent":   _infect_adjacent(battle, source_minion, effect)
		"Freeze":           _freeze(battle, source_minion, effect, selected_target)
		"Resurrect":        await _resurrect(battle, source_minion, effect)
		"ResurrectLast":    await _resurrect_last(battle, source_minion, effect)
		"StealMinion":      _steal_minion(battle, source_minion, effect, selected_target)
		"Silence":          _silence(battle, source_minion, effect, selected_target)
		"Transform":        _transform(battle, source_minion, effect, selected_target)
		"SummonSelf":       await _summon_self(battle, source_minion, effect)
		"DamageAll":        await _damage_all(battle, source_minion, effect)
		"BuffRow":          _buff_row(battle, source_minion, effect)
		"BuffAdjacent":     _buff_adjacent(battle, source_minion, effect)
		"SplashDamage":     await _splash_damage(battle, source_minion, effect, selected_target)
		"DebuffATK":        _debuff_atk(battle, source_minion, effect, selected_target)
		"DestroyLowHP":     _destroy_low_hp(battle, source_minion, effect)
		"BuffIfCondition":  _buff_if_condition(battle, source_minion, effect)
		"DamageAllMinions": await _damage_all_minions(battle, source_minion, effect)
		"ReturnFromGrave":  _return_from_grave(battle, source_minion, effect, selected_target)
		_:
			push_warning("Effet non implémenté : %s" % effect.effect_id)
	await battle.death_system.process_deaths()
	battle.board_visual_system.refresh_board()
	battle.hero_system.update_ui()

func execute_targeted_effect(battle, effect: CardEffect, target: Minion) -> void:
	await execute_effect(battle, null, effect, target)

# ─── Ciblage ──────────────────────────────────────────────────────────────────

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

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _get_adjacent_minions(battle, minion: Minion) -> Array[Minion]:
	var list: Array[Minion] = battle.player_minions if minion.owner_is_player else battle.enemy_minions
	var same_row: Array[Minion] = list.filter(func(m: Minion): return m.board_row == minion.board_row)
	var idx: int = same_row.find(minion)
	var result: Array[Minion] = []
	if idx > 0:
		result.append(same_row[idx - 1])
	if idx < same_row.size() - 1:
		result.append(same_row[idx + 1])
	return result

func _get_adjacent_enemies(battle, target: Minion) -> Array[Minion]:
	var list: Array[Minion] = battle.enemy_minions if target.owner_is_player else battle.player_minions
	var same_row: Array[Minion] = list.filter(func(m: Minion): return m.board_row == target.board_row)
	var idx: int = same_row.find(target)
	var result: Array[Minion] = []
	if idx > 0:
		result.append(same_row[idx - 1])
	if idx < same_row.size() - 1:
		result.append(same_row[idx + 1])
	return result

# ─── Effets existants ─────────────────────────────────────────────────────────

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
				var dealt: int = target.take_damage(effect.value)
				if dealt > 0 and not target.is_dead():
					await trigger_effects(battle, target, "OnDamaged")

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
	battle.hero_system.get_owner_hero(source_minion).heal(effect.value)

func _buff(battle, source_minion, effect, selected_target = null) -> void:
	for target in _resolve_targets(battle, source_minion, effect, selected_target):
		target.base_attack     += effect.value
		target.base_max_health += effect.value_2

func _debuff(battle, source_minion, effect, selected_target = null) -> void:
	for target in _resolve_targets(battle, source_minion, effect, selected_target):
		target.base_attack = max(0, target.base_attack - effect.value)
		target.health       = max(1, target.health - effect.value_2)

func _destroy(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	var is_ally_targeted := effect.target in ["Self", "AllyMinion", "AllAllies", "AllAlliesFront", "AllAlliesBack"]
	for target in _resolve_targets(battle, source_minion, effect, selected_target):
		if is_ally_targeted:
			target.sacrificed = true
		target.health = 0

func _silence(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	for target in _resolve_targets(battle, source_minion, effect, selected_target):
		if target.has_human_keyword(KeywordHuman.Type.DISCIPLINE):
			continue
		target.keywords.clear()
		target.human_keywords.clear()
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
		var requested: int = min(effect.value, target.health)
		var dealt: int = target.take_damage(requested)
		if dealt > 0 and not target.is_dead():
			await trigger_effects(battle, target, "OnDamaged")
		if source_minion:
			source_minion.heal(dealt)

func _return_to_hand(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	for target in _resolve_targets(battle, source_minion, effect, selected_target):
		if target.has_human_keyword(KeywordHuman.Type.FORTIFICATION) and _is_hostile_to(source_minion, target):
			continue
		var is_player: bool = target.owner_is_player
		if is_player:
			battle.hand_cards.append(target.card_data)
		target.health = 0
		if is_player:
			battle.hand.set_hand(battle.hand_cards)

func _transform(battle, source_minion, effect, selected_target = null) -> void:
	if effect.transform_card == null:
		return
	for target in _resolve_targets(battle, source_minion, effect, selected_target):
		target.card_data        = effect.transform_card
		target.base_attack      = effect.transform_card.attack
		target.base_max_health  = effect.transform_card.health
		target.aura_attack_bonus = 0
		target.aura_health_bonus = 0
		target.damage_taken     = 0
		target.keywords         = effect.transform_card.get_keyword_values()
		target.human_keywords   = effect.transform_card.get_human_keyword_values()
		target.silenced         = false

func _draw_cards(battle, count: int) -> void:
	for i in range(count):
		battle.deck_system.draw_card()

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

func _damage_all(battle, source_minion: Minion, effect: CardEffect) -> void:
	var targets: Array[Minion] = []
	match effect.target:
		"AllEnemies":       targets.append_array(battle.get_enemy_minions(source_minion))
		"AllAllies":        targets.append_array(battle.get_owner_minions(source_minion))
		"AllMinions":
			targets.append_array(battle.player_minions)
			targets.append_array(battle.enemy_minions)
		"AllEnemiesFront":
			var is_p: bool = source_minion != null and source_minion.owner_is_player
			targets.append_array(battle.get_front_minions(not is_p))
		_:
			targets.append_array(_resolve_targets(battle, source_minion, effect))
	for target in targets:
		var dealt: int = target.take_damage(effect.value)
		if dealt > 0 and not target.is_dead():
			await trigger_effects(battle, target, "OnDamaged")

func _buff_row(battle, source_minion, effect) -> void:
	var targets: Array[Minion] = []
	match effect.target:
		"AllAlliesFront": targets.append_array(battle.get_front_minions(source_minion == null or source_minion.owner_is_player))
		"AllAlliesBack":  targets.append_array(battle.get_back_minions(source_minion == null or source_minion.owner_is_player))
		"AllEnemiesFront": targets.append_array(battle.get_front_minions(source_minion != null and not source_minion.owner_is_player))
		"AllEnemiesBack":  targets.append_array(battle.get_back_minions(source_minion != null and not source_minion.owner_is_player))
		_: targets.append_array(_resolve_targets(battle, source_minion, effect))
	for target in targets:
		target.base_attack     += effect.value
		target.base_max_health += effect.value_2

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
		await battle.summon_minion(pool.pick_random(), is_player, row)
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
			push_warning("Board plein")
			break
		await battle.summon_minion(source_minion.card_data, is_player, row)
		await battle.get_tree().create_timer(0.15).timeout

# ─── Nouveaux effets ──────────────────────────────────────────────────────────

# Infecte les serviteurs adjacents à la source (Dernier Souffle du Charognard Putride)
func _infect_adjacent(battle, source_minion: Minion, _effect: CardEffect) -> void:
	if source_minion == null:
		return
	var enemies: Array[Minion] = battle.get_enemy_minions(source_minion)
	var same_row: Array[Minion] = enemies.filter(func(m: Minion): return m.board_row == source_minion.board_row)
	var idx: int = same_row.find(source_minion)
	# Cible les ennemis adjacents en face (position idx-1, idx, idx+1)
	for offset in [-1, 0, 1]:
		var i: int = idx + offset
		if i >= 0 and i < same_row.size():
			same_row[i].infected = true

# Buff le serviteur adjacent allié (Larve Cadavérique, Servant Décharné...)
func _buff_adjacent(battle, source_minion, effect) -> void:
	if source_minion == null:
		return
	for adjacent in _get_adjacent_minions(battle, source_minion):
		adjacent.base_attack     += effect.value
		adjacent.base_max_health += effect.value_2

# Dégâts splash aux serviteurs adjacents à la cible (Mâcheur d'Os, Idole de l'Apocalypse)
func _splash_damage(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	if selected_target == null:
		return
	for adjacent in _get_adjacent_enemies(battle, selected_target):
		var dealt: int = adjacent.take_damage(effect.value)
		if dealt > 0 and not adjacent.is_dead():
			await trigger_effects(battle, adjacent, "OnDamaged")

# Debuff ATK temporaire (Émissaire de la Peste : -2 ATK jusqu'à fin de tour)
func _debuff_atk(battle, source_minion, effect, selected_target = null) -> void:
	for target in _resolve_targets(battle, source_minion, effect, selected_target):
		target.base_attack = max(0, target.base_attack - effect.value)
		# TODO: restaurer à la fin du tour via TurnSystem si effect.duration > 0

# Détruit les serviteurs ennemis sous un seuil de HP (Faucheur, Destroy ≤ N HP)
func _destroy_low_hp(battle, source_minion: Minion, effect: CardEffect) -> void:
	var enemies: Array[Minion] = battle.get_enemy_minions(source_minion)
	for target in enemies:
		if target.health <= effect.value:
			target.health = 0

# Buff conditionnel (ex: Infecté Récent +1/+1 par ennemi infecté)
func _buff_if_condition(battle, source_minion, effect) -> void:
	if source_minion == null:
		return
	match effect.target:
		"PerInfectedEnemy":
			var count: int = 0
			for enemy in battle.get_enemy_minions(source_minion):
				if enemy.infected:
					count += 1
			source_minion.base_attack     += effect.value * count
			source_minion.base_max_health += effect.value_2 * count
# Dégâts à tous les serviteurs (alliés et ennemis) — Exhalation Toxique
func _damage_all_minions(battle, source_minion: Minion, effect: CardEffect) -> void:
	for minion in battle.player_minions + battle.enemy_minions:
		var dealt: int = minion.take_damage(effect.value)
		if dealt > 0 and not minion.is_dead():
			await trigger_effects(battle, minion, "OnDamaged")

# Ramène depuis le cimetière en main (Rituel d'Exhumation)
func _return_from_grave(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	var is_player: bool = source_minion.owner_is_player if source_minion else true
	var graveyard: Graveyard = battle.player_graveyard if is_player else battle.enemy_graveyard
	var dead: Array[CardData] = graveyard.get_minions()
	if dead.is_empty():
		return
	# Prend le dernier mort par défaut (ou le ciblé si implémenté plus tard)
	var card_data: CardData = dead.back()
	battle.hand_cards.append(card_data)
	battle.hand.set_hand(battle.hand_cards)

# Ressuscite le dernier mort avec 1 HP (Réveil Soudain, Nécromancien Putride)
func _resurrect_last(battle, source_minion: Minion, _effect: CardEffect) -> void:
	var is_player: bool = source_minion.owner_is_player if source_minion else true
	var graveyard: Graveyard = battle.player_graveyard if is_player else battle.enemy_graveyard
	var dead: Array[CardData] = graveyard.get_minions()
	if dead.is_empty():
		return
	var row: String = "Front"
	if not battle.can_summon_to_row(is_player, row):
		row = "Back"
	if not battle.can_summon_to_row(is_player, row):
		return
	await battle.summon_minion(dead.back(), is_player, row)
	var minions: Array[Minion] = battle.player_minions if is_player else battle.enemy_minions
	if not minions.is_empty():
		minions.back().health = 1

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

func _is_hostile_to(source_minion: Minion, target: Minion) -> bool:
	if source_minion != null:
		return source_minion.owner_is_player != target.owner_is_player
	# Pas de source minion = sort joué directement (actuellement, seul le joueur lance des sorts)
	return target.owner_is_player == false
