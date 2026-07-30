extends RefCounted
class_name EffectManager

func execute_effect(
	battle,
	source_minion: Minion,
	effect: CardEffect,
	selected_target: Minion = null
) -> void:
	# Condition d'exécution : si non remplie, l'effet est purement et simplement
	# ignoré (pas de popup, pas d'invocation, pas de pioche...).
	if not _condition_met(battle, source_minion, effect, selected_target):
		return
	if source_minion != null and source_minion.card_data != null:
		# Attend que la popup soit affichée pour que l'effet se produise en même temps
		await battle.card_popup_system.show_card_popup(source_minion.card_data, source_minion)
	match effect.effect_id:
		"Damage":           await _damage(battle, source_minion, effect, selected_target)
		"Heal":             await _heal(battle, source_minion, effect, selected_target)
		"Buff":             await _buff(battle, source_minion, effect, selected_target)
		"Debuff":           await _debuff(battle, source_minion, effect, selected_target)
		"Destroy":          await _destroy(battle, source_minion, effect, selected_target)
		"DrawCard":         _draw_cards(battle, source_minion, effect.value)
		"SummonMinion":     await _summon_minion(battle, source_minion, effect)
		"SummonRandom":     await _summon_random(battle, source_minion, effect)
		"StealHealth":      await _steal_health(battle, source_minion, effect, selected_target)
		"HealHero":         _heal_hero(battle, source_minion, effect)
		"ReturnToHand":     await _return_to_hand(battle, source_minion, effect, selected_target)
		"ResurrectSelf":    await _resurrect_self(battle, source_minion, effect, selected_target)
		"InfectEnemy":      await _infect(battle, source_minion, effect, selected_target)
		"InfectAdjacent":   await _infect_adjacent(battle, source_minion, effect)
		"Freeze":           await _freeze(battle, source_minion, effect, selected_target)
		"Resurrect":        await _resurrect(battle, source_minion, effect)
		"ResurrectLast":    await _resurrect_last(battle, source_minion, effect)
		"StealMinion":      await _steal_minion(battle, source_minion, effect, selected_target)
		"DestroyAndResurrect": await _destroy_and_resurrect(battle, source_minion, effect, selected_target)
		"Silence":          await _silence(battle, source_minion, effect, selected_target)
		"Transform":        await _transform(battle, source_minion, effect, selected_target)
		"SummonSelf":       await _summon_self(battle, source_minion, effect)
		"DamageAll":        await _damage_all(battle, source_minion, effect)
		"BuffRow":          await _buff_row(battle, source_minion, effect)
		"BuffAdjacent":     await _buff_adjacent(battle, source_minion, effect)
		"SplashDamage":     await _splash_damage(battle, source_minion, effect, selected_target)
		"DebuffATK":        await _debuff_atk(battle, source_minion, effect, selected_target)
		"DestroyLowHP":     await _destroy_low_hp(battle, source_minion, effect)
		"BuffIfCondition":  _buff_if_condition(battle, source_minion, effect)
		"DamageAllMinions": await _damage_all_minions(battle, source_minion, effect)
		"ReturnFromGrave":  _return_from_grave(battle, source_minion, effect, selected_target)
		"GrantKeyword":     await _grant_keyword(battle, source_minion, effect, selected_target)
		"AttackImmediate":  await _attack_immediate(battle, source_minion, effect)
		"GrantExtraAttack": _grant_extra_attack(battle, source_minion, effect)
		"CureInfection":    await _cure_infection(battle, source_minion, effect, selected_target)
		"SacrificeAlly":    await _sacrifice_ally(battle, source_minion, effect, selected_target)
		"GrantCounterOffensive": _grant_counter_offensive(battle, source_minion, effect)
		"GainMana":         _gain_mana(battle, source_minion, effect)
		"DestroyRandomEnchantment": await _destroy_random_enchantment(battle, source_minion, effect)
		"DrawCardDiscount": _draw_card_discount(battle, source_minion, effect)
		"Corrupt":          await _corrupt(battle, source_minion, effect, selected_target)
		"StealHealthFromHero": await _steal_health_from_hero(battle, source_minion, effect)
		"BlockSelfDamage":  _block_self_damage(battle, source_minion, effect)
		"PreventEnemyHeroHeal": _prevent_enemy_hero_heal(battle, source_minion, effect)
		"SacrificeDrawPerVictim": await _sacrifice_draw_per_victim(battle, source_minion, effect, selected_target)
		"StealMinionThenDestroy": await _steal_minion_then_destroy(battle, source_minion, effect, selected_target)
		"GrantSpellImmunity": await _grant_spell_immunity(battle, source_minion, effect, selected_target)
		"GroupAttackImmediate": await _group_attack_immediate(battle, source_minion, effect, selected_target)
		"ApplyMutation":    await _apply_mutation(battle, source_minion, effect, selected_target)
		"GrantKeywordAdjacent": await _grant_keyword_adjacent(battle, source_minion, effect)
		"AbsorbAdjacentStats": await _absorb_adjacent_stats(battle, source_minion, effect, selected_target)
		"CopyAdjacentKeyword": await _copy_adjacent_keyword_effect(battle, source_minion, effect, selected_target)
		"AuraSpellCostReduction", "AuraFirstOfRaceCostReduction":
			pass  # Auras de coût : lues à la volée par CostSystem, rien à exécuter
		"AuraBuffRow", "AuraBuffPerAllyInRow", "AuraSelfDamageReduction", "AuraDebuffEnemiesExceptRace":
			pass  # Auras d'enchantement : recalculées par AuraSystem, rien à exécuter
		"CancelSpellOnRaceTarget":
			pass  # Annulation de sort : résolue en amont par TriggerSystem.try_cancel_spell
		_:
			push_warning("Effet non implémenté : %s" % effect.effect_id)
	await battle.death_system.process_deaths()
	battle.board_visual_system.refresh_board()
	battle.hero_system.update_ui()

# Effet dont la cible choisie par le joueur est un enchantement/rituel posé
# (CardData), pas un Minion. Chemin séparé de execute_effect() car son
# selected_target est typé Minion — un enchantement en jeu n'a pas
# d'instance dédiée (deux exemplaires de la même carte partagent la même
# ressource CardData, comme en main : voir DeckSystem.mulligan_replace_one).
func execute_enchantment_targeted_effect(
	battle,
	source_minion: Minion,
	effect: CardEffect,
	target_enchantment: CardData
) -> void:
	if source_minion != null and source_minion.card_data != null:
		await battle.card_popup_system.show_card_popup(source_minion.card_data, source_minion)
	match effect.effect_id:
		"DestroyEnchantment": _destroy_target_enchantment(battle, target_enchantment)
		_: push_warning("Effet non implémenté pour cible enchantement : %s" % effect.effect_id)
	battle.board_visual_system.refresh_board()

func _destroy_target_enchantment(battle, card_data: CardData) -> void:
	for is_player in [true, false]:
		if card_data in battle.enchantment_system.get_enchantments(is_player) \
				or card_data in battle.enchantment_system.get_rituals(is_player):
			battle.enchantment_system.destroy_enchantment(card_data, is_player)
			return

# Tirage aléatoire via le RNG de jeu partagé (déterministe et synchronisé en
# réseau), et non le RNG global — sinon les deux clients divergeraient.
func _rng_pick(battle, array: Array):
	return array[battle.game_rng.randi() % array.size()]

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
			# Source nulle = sort lancé par le joueur => camp joueur (comme les
			# cibles "Allies"). On vise donc la rangée Avant du camp ADVERSE.
			var is_p: bool = source_minion == null or source_minion.owner_is_player
			result.append_array(battle.get_front_minions(not is_p))
		"AllEnemiesBack":
			var is_p: bool = source_minion == null or source_minion.owner_is_player
			result.append_array(battle.get_back_minions(not is_p))
		"AllAlliesFront":
			var is_p: bool = source_minion == null or source_minion.owner_is_player
			result.append_array(battle.get_front_minions(is_p))
		"AllAlliesBack":
			var is_p: bool = source_minion == null or source_minion.owner_is_player
			result.append_array(battle.get_back_minions(is_p))
		"RandomEnemy":
			# Filtres (rangée, race, HP...) appliqués AVANT le tirage : la cible
			# aléatoire est tirée parmi les candidats valides, sinon un row_filter
			# pourrait invalider le tirage au lieu de restreindre le pool.
			var enemies: Array[Minion] = _filter_targets(battle.get_enemy_minions(source_minion), effect)
			if not enemies.is_empty():
				result.append(_rng_pick(battle, enemies))
		"RandomAlly":
			var allies: Array[Minion] = _filter_targets(battle.get_owner_minions(source_minion), effect)
			if not allies.is_empty():
				result.append(_rng_pick(battle, allies))
	return result

func _filter_targets(targets: Array[Minion], effect: CardEffect) -> Array[Minion]:
	var result: Array[Minion] = targets
	if not effect.race_filter.is_empty():
		var race_id: int = Race.from_string(effect.race_filter)
		result = result.filter(func(t: Minion) -> bool:
			return t.card_data.race == race_id
		)
	if not effect.row_filter.is_empty():
		result = result.filter(func(t: Minion) -> bool:
			return t.board_row == effect.row_filter
		)
	if effect.target_max_hp >= 0:
		result = result.filter(func(t: Minion) -> bool:
			return t.health <= effect.target_max_hp
		)
	if effect.target_max_atk >= 0:
		result = result.filter(func(t: Minion) -> bool:
			return t.attack <= effect.target_max_atk
		)
	if effect.requires_resurrected_target:
		result = result.filter(func(t: Minion) -> bool: return t.was_resurrected)
	return result

func _resolve_targets(
	battle,
	source_minion: Minion,
	effect: CardEffect,
	selected_target: Minion = null
) -> Array[Minion]:
	return _filter_targets(_get_targets(battle, source_minion, effect, selected_target), effect)

# Certains effets déclenchés (ex: Dernier Souffle de Charognard Putride)
# demandent une cible ponctuelle qu'aucun joueur n'a encore choisie au moment
# où le trigger se déclenche (contrairement aux sorts ciblés joués depuis la
# main). Si le serviteur mourant appartient au joueur local et qu'on n'est pas
# dans un match réseau, on lui fait choisir la cible ; sinon (IA, adversaire
# distant) une cible valide est tirée au sort pour ne pas bloquer la partie.
func resolve_trigger_target(battle, minion: Minion, trigger_name: String) -> Minion:
	if not has_trigger(minion, trigger_name):
		return null
	for effect in minion.card_data.effects:
		if effect.target in ["EnemyMinion", "AllyMinion", "AnyMinion"]:
			return await _choose_trigger_target(battle, minion, effect)
	return null

func _choose_trigger_target(battle, minion: Minion, effect: CardEffect) -> Minion:
	var pool: Array[Minion] = _filter_targets(_trigger_target_pool(battle, minion, effect.target), effect)
	if pool.is_empty():
		return null
	if minion.owner_is_player and battle.network_manager == null:
		return await battle.targeting_system.prompt_trigger_target(minion.card_data)
	return _rng_pick(battle, pool)

func _trigger_target_pool(battle, minion: Minion, target_str: String) -> Array[Minion]:
	match target_str:
		"EnemyMinion": return battle.get_enemy_minions(minion)
		"AllyMinion":  return battle.get_owner_minions(minion)
		"AnyMinion":   return battle.get_owner_minions(minion) + battle.get_enemy_minions(minion)
		_:             return []

# ─── Seuils conditionnels ─────────────────────────────────────────────────────
# "Si N cibles ou plus : valeur/nombre différent" (Volée de Flèches, Cri des
# Damnés, Appel aux Armes...). Le seuil se compare à reference_count : nombre
# de cibles résolues, ou nombre d'alliés dans la rangée pour les invocations.

func _threshold_met(effect: CardEffect, reference_count: int) -> bool:
	match effect.threshold_op:
		"GreaterOrEqual": return reference_count >= effect.threshold_count
		"LessOrEqual":    return reference_count <= effect.threshold_count
		"Equal":          return reference_count == effect.threshold_count
		_:                return false

func _effective_value(effect: CardEffect, reference_count: int) -> int:
	if effect.threshold_op != "None" and _threshold_met(effect, reference_count):
		return effect.value_if_threshold
	return effect.value

func _effective_count(effect: CardEffect, reference_count: int) -> int:
	if effect.threshold_op != "None" and _threshold_met(effect, reference_count):
		return effect.count_if_threshold
	return effect.count

# ─── Conditions d'exécution ───────────────────────────────────────────────────

func _cmp(value: int, op: String, target: int) -> bool:
	match op:
		"GreaterOrEqual": return value >= target
		"LessOrEqual":    return value <= target
		"Equal":          return value == target
		_:                return true

func _condition_met(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> bool:
	if effect.condition_type == "None":
		return true
	var race: int = Race.from_string(effect.condition_race) if not effect.condition_race.is_empty() else -1
	match effect.condition_type:
		"AlliesInPlay":
			var n: int = battle.get_owner_minions(source_minion).size()
			return _cmp(n, effect.condition_op, effect.condition_count)
		"AlliesOfRaceInPlay":
			var n: int = battle.get_owner_minions(source_minion).filter(
				func(m: Minion): return race == -1 or m.card_data.race == race
			).size()
			return _cmp(n, effect.condition_op, effect.condition_count)
		"AlliesInRowInPlay":
			var n: int = battle.get_owner_minions(source_minion).filter(
				func(m: Minion): return effect.row_filter.is_empty() or m.board_row == effect.row_filter
			).size()
			return _cmp(n, effect.condition_op, effect.condition_count)
		"KeywordHumanInPlay":
			var kw: int = KeywordHuman.from_name(effect.granted_keyword)
			return battle.get_owner_minions(source_minion).any(
				func(m: Minion): return kw != -1 and m.has_human_keyword(kw)
			)
		"LegendaryAllyInPlay":
			var n: int = battle.get_owner_minions(source_minion).filter(
				func(m: Minion): return m.card_data.rarity == "Legendary" and (race == -1 or m.card_data.race == race)
			).size()
			return _cmp(n, effect.condition_op, effect.condition_count)
		"EnemyFrontCount":
			var n: int = battle.get_enemy_minions(source_minion).filter(
				func(m: Minion): return m.board_row == "Front"
			).size()
			return _cmp(n, effect.condition_op, effect.condition_count)
		"TriggerSourceLegendary":
			if selected_target == null or selected_target.card_data == null:
				return false
			if selected_target.card_data.rarity != "Legendary":
				return false
			return race == -1 or selected_target.card_data.race == race
		"TriggerSourceRace":
			if selected_target == null or selected_target.card_data == null:
				return false
			return race == -1 or selected_target.card_data.race == race
	return true

# True si au moins un effet de la carte peut s'appliquer (condition remplie).
# Sert aux enchantements/rituels pour ne pas consommer de charge à vide.
func any_condition_met(battle, source_minion: Minion, card_data: CardData, selected_target: Minion = null) -> bool:
	for effect in card_data.effects:
		if _condition_met(battle, source_minion, effect, selected_target):
			return true
	return false

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
	# La position adjacente se calcule dans le camp DE LA CIBLE (comme
	# _get_adjacent_minions) : le camp opposé ne contient jamais `target`,
	# donc find() y échouait toujours (-1), ce qui ne touchait que le
	# premier serviteur de la rangée au lieu du vrai voisin (bug corrigé).
	var list: Array[Minion] = battle.player_minions if target.owner_is_player else battle.enemy_minions
	var same_row: Array[Minion] = list.filter(func(m: Minion): return m.board_row == target.board_row)
	var idx: int = same_row.find(target)
	var result: Array[Minion] = []
	if idx > 0:
		result.append(same_row[idx - 1])
	if idx < same_row.size() - 1:
		result.append(same_row[idx + 1])
	return result

# ─── Courbes d'effet ──────────────────────────────────────────────────────────
# Trace la courbe depuis la popup d'effet vers les serviteurs ciblés (y compris
# les cibles aléatoires, déjà résolues) juste avant l'application de l'effet, pour
# montrer au joueur qui est touché.

# source_minion == null signifie que l'effet vient de la résolution immédiate
# d'un sort joué (Éphémère/Rituel sans durée) : CardSystem.gd a déjà lancé le
# vrai projectile VFXManager pour cette carte, donc on n'affiche pas aussi le
# projectile de secours d'AnimationSystem (double affichage sinon).
func _point_arrows_to(battle, targets: Array[Minion], source_minion: Minion = null) -> void:
	if targets.is_empty():
		return
	var positions: Array[Vector2] = []
	for t in targets:
		var v = battle.board_visual_system.get_visual(t)
		if v != null and is_instance_valid(v):
			positions.append(v.global_position + v.size * 0.5)
	if not positions.is_empty():
		await battle.card_popup_system.show_effect_arrows(positions, 0.35, source_minion == null)

func _point_arrow_to_hero(battle, is_enemy: bool, source_minion: Minion = null) -> Control:
	var panel = battle.get_node_or_null("EnemyHeroPanel" if is_enemy else "PlayerHeroPanel")
	if panel != null:
		await battle.card_popup_system.show_effect_arrows(
			[panel.global_position + panel.size * 0.5], 0.35, source_minion == null)
	return panel

# ─── Effets existants ─────────────────────────────────────────────────────────

func _damage(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	match effect.target:
		"EnemyHero":
			var hero_panel: Control = await _point_arrow_to_hero(battle, source_minion == null or source_minion.owner_is_player, source_minion)
			battle.hero_system.damage(battle.hero_system.get_enemy_hero(source_minion), effect.value)
			battle.animation_system.play_damage(hero_panel, effect.value)
		"OwnerHero":
			var hero_panel: Control = await _point_arrow_to_hero(battle, source_minion != null and not source_minion.owner_is_player, source_minion)
			# "Ton héros perd X HP" : dégâts auto-infligés — passent par le pipeline
			# self_damage (blocages, réduction, garde-fou 1 HP, SANG NOIR, OnSelfDamage)
			var is_p: bool = source_minion == null or source_minion.owner_is_player
			var dealt_self: int = await battle.hero_system.self_damage(is_p, effect.value)
			battle.animation_system.play_damage(hero_panel, dealt_self)
		_:
			var targets: Array[Minion] = _resolve_targets(battle, source_minion, effect, selected_target)
			var damage: int = _effective_value(effect, targets.size())
			await _point_arrows_to(battle, targets, source_minion)
			for target in targets:
				var visual = battle.board_visual_system.get_visual(target)
				var dealt: int = target.take_damage(damage)
				if visual:
					battle.animation_system.play_damage(visual, dealt)
				if dealt > 0:
					await notify_damaged(battle, target)

func _heal(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	match effect.target:
		"OwnerHero":
			var hero_panel: Control = await _point_arrow_to_hero(battle, source_minion != null and not source_minion.owner_is_player, source_minion)
			var hero: Hero = battle.hero_system.get_owner_hero(source_minion)
			var could_heal: bool = hero.heal_block_turns <= 0
			hero.heal(effect.value)
			if could_heal:
				battle.animation_system.play_heal(hero_panel, effect.value)
		"EnemyHero":
			var hero_panel: Control = await _point_arrow_to_hero(battle, source_minion == null or source_minion.owner_is_player, source_minion)
			var hero: Hero = battle.hero_system.get_enemy_hero(source_minion)
			var could_heal: bool = hero.heal_block_turns <= 0
			hero.heal(effect.value)
			if could_heal:
				battle.animation_system.play_heal(hero_panel, effect.value)
		_:
			var targets: Array[Minion] = _resolve_targets(battle, source_minion, effect, selected_target)
			await _point_arrows_to(battle, targets, source_minion)
			for target in targets:
				var could_heal: bool = not target.is_heal_immune()
				target.heal(effect.value)
				if could_heal:
					var visual = battle.board_visual_system.get_visual(target)
					if visual:
						battle.animation_system.play_heal(visual, effect.value)

func _heal_hero(battle, source_minion: Minion, effect: CardEffect) -> void:
	battle.hero_system.get_owner_hero(source_minion).heal(effect.value)

func _buff(battle, source_minion, effect, selected_target = null) -> void:
	var targets: Array[Minion] = _resolve_targets(battle, source_minion, effect, selected_target)
	var attack_gain: int = _effective_value(effect, targets.size())
	await _point_arrows_to(battle, targets, source_minion)
	for target in targets:
		target.base_attack     += attack_gain
		target.base_max_health += effect.value_2
		battle.temp_effect_system.add_temp_stat_change(target, attack_gain, effect.value_2, effect.duration)
		var visual = battle.board_visual_system.get_visual(target)
		if visual:
			battle.animation_system.play_generic_buff(visual, attack_gain, effect.value_2)

func _debuff(battle, source_minion, effect, selected_target = null) -> void:
	var targets: Array[Minion] = _resolve_targets(battle, source_minion, effect, selected_target)
	await _point_arrows_to(battle, targets, source_minion)
	for target in targets:
		var old_health: int = target.health
		target.base_attack     = max(0, target.base_attack - effect.value)
		# Réduction PERMANENTE des HP max (symétrique de _buff) — plus de
		# Heal ultérieur ne doit pouvoir restaurer les HP perdus ici.
		target.base_max_health = max(0, target.base_max_health - effect.value_2)
		# Applique aussi la perte aux HP actuels, sans plafonner à 1 : un
		# "-X/-X" doit pouvoir tuer un serviteur déjà bas en vie (Épidémie...)
		target.health = max(0, old_health - effect.value_2)
		var visual = battle.board_visual_system.get_visual(target)
		if visual:
			battle.animation_system.play_generic_debuff(visual, effect.value, effect.value_2)

func _destroy(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	var is_ally_targeted := effect.target in ["Self", "AllyMinion", "AllAllies", "AllAlliesFront", "AllAlliesBack"]
	var targets: Array[Minion] = _resolve_targets(battle, source_minion, effect, selected_target)
	await _point_arrows_to(battle, targets, source_minion)
	for target in targets:
		if is_ally_targeted:
			target.sacrificed = true
		target.health = 0

func _silence(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	var targets: Array[Minion] = _resolve_targets(battle, source_minion, effect, selected_target)
	await _point_arrows_to(battle, targets, source_minion)
	for target in targets:
		if target.has_human_keyword(KeywordHuman.Type.DISCIPLINE):
			continue
		# Instantané "Permanent" (défaut) ; sinon les mots-clés reviennent à
		# l'expiration (Inquisiteur de Fer, L'Éternel Gardien).
		battle.temp_effect_system.add_temp_silence(target, effect.duration)
		target.keywords.clear()
		target.human_keywords.clear()
		target.undead_keywords.clear()
		target.demon_keywords.clear()
		target.abomination_keywords.clear()
		target.silenced = true
		var visual: BoardMinion = battle.board_visual_system.get_visual(target)
		if visual:
			battle.animation_system.play_silence(visual)

# Éclaireur Infiltré : rend des cibles intargetables par les sorts ennemis.
# Contrairement à Assassin Décharné (immunité intrinsèque levée à sa propre
# attaque), cette immunité est accordée temporairement et expire par durée.
func _grant_spell_immunity(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	var targets: Array[Minion] = _resolve_targets(battle, source_minion, effect, selected_target)
	await _point_arrows_to(battle, targets, source_minion)
	for target in targets:
		if target.spell_immune:
			continue
		target.spell_immune = true
		battle.temp_effect_system.add_temp_spell_immunity(target, effect.duration)

func _freeze(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	var targets: Array[Minion] = _resolve_targets(battle, source_minion, effect, selected_target)
	await _point_arrows_to(battle, targets, source_minion)
	for target in targets:
		var turns: int = effect.value if effect.value > 0 else 1
		target.frozen_turns = max(target.frozen_turns, turns)
		var visual: BoardMinion = battle.board_visual_system.get_visual(target)
		if visual:
			battle.animation_system.play_freeze(visual)

func _infect(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	var targets: Array[Minion] = _resolve_targets(battle, source_minion, effect, selected_target)
	await _point_arrows_to(battle, targets, source_minion)
	for target in targets:
		target.infected = true
		var visual: BoardMinion = battle.board_visual_system.get_visual(target)
		if visual:
			battle.animation_system.play_infection(visual)

func _steal_health(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	var targets: Array[Minion] = _resolve_targets(battle, source_minion, effect, selected_target)
	await _point_arrows_to(battle, targets, source_minion)
	for target in targets:
		var requested: int = min(effect.value, target.health)
		var dealt: int = target.take_damage(requested)
		if dealt > 0:
			await notify_damaged(battle, target)
		if source_minion:
			source_minion.heal(dealt)

func _return_to_hand(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	var targets: Array[Minion] = _resolve_targets(battle, source_minion, effect, selected_target)
	await _point_arrows_to(battle, targets, source_minion)
	for target in targets:
		if target.has_human_keyword(KeywordHuman.Type.FORTIFICATION) and _is_hostile_to(source_minion, target):
			continue
		# Retour en main = retrait du plateau SANS passer par la mort
		# (pas de cimetière, pas de Dernier Souffle)
		_remove_from_board(battle, target)
		if target.owner_is_player:
			battle.hand_cards.append(target.card_data)
			battle.hand.set_hand(battle.hand_cards)
		else:
			battle.ai_system.hand.append(target.card_data)

func _remove_from_board(battle, minion: Minion) -> void:
	battle.player_minions.erase(minion)
	battle.enemy_minions.erase(minion)
	var visual = battle.board_visual_system.get_visual(minion)
	if visual and is_instance_valid(visual):
		visual.queue_free()
	battle.board_visual_system.remove_visual(minion)
	battle.aura_system.recompute_all()

func _transform(battle, source_minion, effect, selected_target = null) -> void:
	if effect.transform_card == null:
		return
	var targets: Array[Minion] = _resolve_targets(battle, source_minion, effect, selected_target)
	await _point_arrows_to(battle, targets, source_minion)
	for target in targets:
		target.card_data        = effect.transform_card
		target.base_attack      = effect.transform_card.attack
		target.base_max_health  = effect.transform_card.health
		target.aura_attack_bonus = 0
		target.aura_health_bonus = 0
		target.damage_taken     = 0
		target.keywords         = effect.transform_card.get_keyword_values()
		target.human_keywords   = effect.transform_card.get_human_keyword_values()
		target.undead_keywords  = effect.transform_card.get_undead_keyword_values()
		target.demon_keywords   = effect.transform_card.get_demon_keyword_values()
		target.abomination_keywords = effect.transform_card.get_abomination_keyword_values()
		target.silenced         = false

# Pioche `count` carte(s) pour le camp propriétaire de `source_minion` (joueur
# par défaut si absent, ex. carte piochée en main sans source). Le joueur
# pioche dans son propre deck (battle.deck_system) ; le camp adverse pioche via
# OpponentDriver (IA : vrai deck local ; réseau : compteurs cosmétiques, le
# pair distant pioche réellement de son côté).
func _draw_cards(battle, source_minion: Minion, count: int) -> void:
	var is_player: bool = source_minion == null or source_minion.owner_is_player
	for i in range(count):
		if is_player:
			battle.deck_system.draw_card()
		else:
			battle.opponent.draw_card()

func _steal_minion(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	var targets: Array[Minion] = _resolve_targets(battle, source_minion, effect, selected_target)
	await _point_arrows_to(battle, targets, source_minion)
	for target in targets:
		# Immunité au contrôle mental (DISCIPLINE, CHAIR DE SOUFRE)
		if target.is_mind_control_immune():
			continue
		var from_player: bool = target.owner_is_player
		var to_player: bool = not from_player
		# Si la rangée d'origine est pleine côté nouveau propriétaire, bascule
		# dans l'autre rangée plutôt que de dépasser MAX_MINIONS_PER_ROW
		if not battle.can_summon_to_row(to_player, target.board_row):
			var other_row: String = battle.ROW_BACK if target.board_row == battle.ROW_FRONT else battle.ROW_FRONT
			if battle.can_summon_to_row(to_player, other_row):
				target.board_row = other_row
		target.owner_is_player = to_player
		if from_player:
			battle.player_minions.erase(target)
			battle.enemy_minions.append(target)
		else:
			battle.enemy_minions.erase(target)
			battle.player_minions.append(target)
		battle.board_visual_system.reparent_minion_visual(target, to_player)

# Détruit un serviteur ennemi ciblé puis le ressuscite sous le contrôle du
# lanceur, sans ses effets (La Faucheuse). Contrairement à un simple
# Destroy + StealMinion (l'ancienne implémentation, qui volait un cadavre déjà
# retiré des tableaux/cimetière), on invoque une COPIE FRAÎCHE de sa
# card_data via summon_minion — même pattern que _resurrect/_resurrect_last —
# puis on la silencie pour retirer ses triggers ("sans ses effets").
func _destroy_and_resurrect(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	if selected_target == null or selected_target.card_data == null:
		return
	var card_data: CardData = selected_target.card_data
	await _point_arrows_to(battle, [selected_target], source_minion)
	selected_target.health = 0
	await battle.death_system.process_deaths()
	var is_player: bool = source_minion.owner_is_player if source_minion else true
	var row: String = "Front"
	if not battle.can_summon_to_row(is_player, row):
		row = "Back"
	if not battle.can_summon_to_row(is_player, row):
		return
	await battle.summon_minion(card_data, is_player, row, -1, true)
	var minions: Array[Minion] = battle.player_minions if is_player else battle.enemy_minions
	if minions.is_empty():
		return
	var revived: Minion = minions.back()
	revived.was_resurrected = true
	revived.keywords.clear()
	revived.human_keywords.clear()
	revived.undead_keywords.clear()
	revived.demon_keywords.clear()
	revived.abomination_keywords.clear()
	revived.silenced = true

func _damage_all(battle, source_minion: Minion, effect: CardEffect) -> void:
	var targets: Array[Minion] = []
	match effect.target:
		"AllEnemies":       targets.append_array(battle.get_enemy_minions(source_minion))
		"AllAllies":        targets.append_array(battle.get_owner_minions(source_minion))
		"AllMinions":
			targets.append_array(battle.player_minions)
			targets.append_array(battle.enemy_minions)
		"AllEnemiesFront":
			var is_p: bool = source_minion == null or source_minion.owner_is_player
			targets.append_array(battle.get_front_minions(not is_p))
		_:
			targets.append_array(_resolve_targets(battle, source_minion, effect))
	var damage: int = _effective_value(effect, targets.size())
	await _point_arrows_to(battle, targets, source_minion)
	for target in targets:
		var dealt: int = target.take_damage(damage)
		if dealt > 0:
			await notify_damaged(battle, target)

func _buff_row(battle, source_minion, effect) -> void:
	var targets: Array[Minion] = []
	match effect.target:
		"AllAlliesFront": targets.append_array(battle.get_front_minions(source_minion == null or source_minion.owner_is_player))
		"AllAlliesBack":  targets.append_array(battle.get_back_minions(source_minion == null or source_minion.owner_is_player))
		"AllEnemiesFront": targets.append_array(battle.get_front_minions(source_minion != null and not source_minion.owner_is_player))
		"AllEnemiesBack":  targets.append_array(battle.get_back_minions(source_minion != null and not source_minion.owner_is_player))
		_: targets.append_array(_resolve_targets(battle, source_minion, effect))
	var attack_gain: int = _effective_value(effect, targets.size())
	await _point_arrows_to(battle, targets, source_minion)
	for target in targets:
		target.base_attack     += attack_gain
		target.base_max_health += effect.value_2
		battle.temp_effect_system.add_temp_stat_change(target, attack_gain, effect.value_2, effect.duration)

# Nombre de serviteurs à invoquer (compte fixe, seuil, ou dynamique "par allié")
func _summon_count(battle, source_minion: Minion, effect: CardEffect, row_allies: int) -> int:
	if effect.count_mode == "PerAllyOfRace":
		var race: int = Race.from_string(effect.count_race) if not effect.count_race.is_empty() else -1
		var n: int = battle.get_owner_minions(source_minion).filter(
			func(m: Minion): return m != source_minion and (race == -1 or m.card_data.race == race)
		).size()
		if effect.count_max >= 0:
			n = mini(n, effect.count_max)
		return n
	return _effective_count(effect, row_allies)

# Rangée d'invocation voulue par l'effet (voir CardEffect.summon_row)
func _summon_row(effect: CardEffect, source_minion: Minion) -> String:
	match effect.summon_row:
		"Back":   return "Back"
		"Source": return source_minion.board_row if source_minion else "Front"
		_:        return "Front"

func _summon_minion(battle, source_minion: Minion, effect: CardEffect) -> void:
	if effect.summon_card == null:
		return
	var is_player: bool = source_minion.owner_is_player if source_minion else true
	var preferred_row: String = _summon_row(effect, source_minion)
	# Seuil comparé au nombre d'alliés déjà dans la rangée d'invocation
	# (Appel aux Armes : rangée Avant vide -> 3 Miliciens au lieu de 2)
	var row_allies: int = battle.get_row_minions(is_player, preferred_row).size()
	var summon_count: int = _summon_count(battle, source_minion, effect, row_allies)
	for i in range(summon_count):
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
	var preferred_row: String = _summon_row(effect, source_minion)
	var row_allies: int = battle.get_row_minions(is_player, preferred_row).size()
	var summon_count: int = _effective_count(effect, row_allies)
	for i in range(summon_count):
		var row: String = preferred_row
		if not battle.can_summon_to_row(is_player, row):
			row = "Back" if row == "Front" else "Front"
		if not battle.can_summon_to_row(is_player, row):
			break
		var summoned: Minion = await battle.board_system.summon_minion_return(_rng_pick(battle, pool), is_player, row)
		for m in range(effect.mutate_on_summon_count):
			if summoned == null or summoned.is_dead():
				break
			await roll_mutation(battle, summoned)
		await battle.get_tree().create_timer(0.15).timeout

# Fait entrer en jeu card_data avec 1 HP et was_resurrected=true, en rangée
# Avant si possible sinon Arrière. Retourne false si aucune rangée disponible
# (partagé par _resurrect/_resurrect_last/_resurrect_self).
func _resurrect_card_data(battle, card_data: CardData, is_player: bool) -> bool:
	var row: String = "Front"
	if not battle.can_summon_to_row(is_player, row):
		row = "Back"
	if not battle.can_summon_to_row(is_player, row):
		return false
	await battle.summon_minion(card_data, is_player, row)
	var minions: Array[Minion] = battle.player_minions if is_player else battle.enemy_minions
	if not minions.is_empty():
		minions.back().health = 1
		minions.back().was_resurrected = true
	return true

func _resurrect(battle, source_minion: Minion, effect: CardEffect) -> void:
	var is_player: bool = source_minion.owner_is_player if source_minion else true
	var graveyard: Graveyard = battle.player_graveyard if is_player else battle.enemy_graveyard
	var race: int = Race.from_string(effect.race_filter) if not effect.race_filter.is_empty() else -1
	var dead: Array[CardData] = graveyard.get_minions().filter(
		func(c: CardData): return race == -1 or c.race == race
	)
	if dead.is_empty():
		return
	var count: int = mini(effect.count, dead.size())
	for i in range(count):
		var card_data: CardData = dead[dead.size() - 1 - i]
		if not await _resurrect_card_data(battle, card_data, is_player):
			break
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
	# La position "en face" se lit dans le camp DE LA SOURCE (source_minion
	# n'apparaît jamais dans le camp adverse, donc chercher son index
	# directement dans `enemies` échouait toujours et ne touchait que le
	# premier ennemi de la rangée, quelle que soit la position réelle — bug
	# corrigé en calculant idx depuis le propre camp de la source).
	var own_row: Array[Minion] = battle.get_owner_minions(source_minion).filter(func(m: Minion): return m.board_row == source_minion.board_row)
	var idx: int = own_row.find(source_minion)
	var enemies: Array[Minion] = battle.get_enemy_minions(source_minion)
	var same_row: Array[Minion] = enemies.filter(func(m: Minion): return m.board_row == source_minion.board_row)
	# Cible les ennemis adjacents en face (position idx-1, idx, idx+1)
	var hit: Array[Minion] = []
	for offset in [-1, 0, 1]:
		var i: int = idx + offset
		if i >= 0 and i < same_row.size():
			hit.append(same_row[i])
	await _point_arrows_to(battle, hit, source_minion)
	for m in hit:
		m.infected = true
		var visual: BoardMinion = battle.board_visual_system.get_visual(m)
		if visual:
			battle.animation_system.play_infection(visual)

# Buff le serviteur adjacent allié (Larve Cadavérique, Servant Décharné...)
func _buff_adjacent(battle, source_minion, effect) -> void:
	if source_minion == null:
		return
	var adjacents: Array[Minion] = _get_adjacent_minions(battle, source_minion)
	await _point_arrows_to(battle, adjacents, source_minion)
	for adjacent in adjacents:
		adjacent.base_attack     += effect.value
		adjacent.base_max_health += effect.value_2

# Dégâts splash aux serviteurs adjacents à la cible (Mâcheur d'Os, Idole de l'Apocalypse)
func _splash_damage(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	if selected_target == null:
		return
	var adjacents: Array[Minion] = _get_adjacent_enemies(battle, selected_target)
	await _point_arrows_to(battle, adjacents, source_minion)
	for adjacent in adjacents:
		var dealt: int = adjacent.take_damage(effect.value)
		if dealt > 0:
			await notify_damaged(battle, adjacent)

# Debuff ATK temporaire (Émissaire de la Peste : -2 ATK jusqu'à fin de tour)
func _debuff_atk(battle, source_minion, effect, selected_target = null) -> void:
	var targets: Array[Minion] = _resolve_targets(battle, source_minion, effect, selected_target)
	await _point_arrows_to(battle, targets, source_minion)
	for target in targets:
		var removed: int = min(effect.value, target.base_attack)
		target.base_attack -= removed
		battle.temp_effect_system.add_temp_stat_change(target, -removed, 0, effect.duration)

# Détruit les serviteurs ennemis sous un seuil de HP (Faucheur, Purge Sainte)
# Respecte race_filter/row_filter (ex: "tous les Mort-Vivants ennemis à 3 HP ou moins")
func _destroy_low_hp(battle, source_minion: Minion, effect: CardEffect) -> void:
	var enemies: Array[Minion] = _filter_targets(battle.get_enemy_minions(source_minion), effect)
	var doomed: Array[Minion] = enemies.filter(func(m: Minion): return m.health <= effect.value)
	await _point_arrows_to(battle, doomed, source_minion)
	for target in doomed:
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
	var targets: Array[Minion] = []
	targets.append_array(battle.player_minions)
	targets.append_array(battle.enemy_minions)
	await _point_arrows_to(battle, targets, source_minion)
	for minion in targets:
		var dealt: int = minion.take_damage(effect.value)
		if dealt > 0:
			await notify_damaged(battle, minion)

# Ramène depuis le cimetière en main (Rituel d'Exhumation, Grand Rituel du
# Pacte). race_filter optionnel : prend le mort le plus récent de cette race.
func _return_from_grave(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	var is_player: bool = source_minion.owner_is_player if source_minion else true
	var graveyard: Graveyard = battle.player_graveyard if is_player else battle.enemy_graveyard
	var dead: Array[CardData] = graveyard.get_minions()
	if dead.is_empty():
		return
	# Prend le dernier mort (filtré par race si demandé)
	var race: int = Race.from_string(effect.race_filter) if not effect.race_filter.is_empty() else -1
	var card_data: CardData = null
	for i in range(dead.size() - 1, -1, -1):
		if race == -1 or dead[i].race == race:
			card_data = dead[i]
			break
	if card_data == null:
		return
	if is_player:
		battle.hand_cards.append(card_data)
		battle.hand.set_hand(battle.hand_cards)
	else:
		battle.ai_system.hand.append(card_data)

# Ramène EN JEU (pas en main) le serviteur allié qui vient de mourir, avec
# 1 HP (Cimetière Vivant : "ce Mort-Vivant revient en jeu à la fin du tour").
# Contrairement à _resurrect_last (qui pioche le dernier mort du cimetière),
# vise précisément selected_target = le serviteur mort ayant déclenché OnGrief.
# "Une seule fois par serviteur" : ignore les serviteurs déjà ressuscités
# (was_resurrected), pour ne pas boucler indéfiniment sur le même serviteur.
func _resurrect_self(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	if selected_target == null or selected_target.card_data == null or selected_target.was_resurrected:
		return
	await _resurrect_card_data(battle, selected_target.card_data, selected_target.owner_is_player)

# Ressuscite le dernier mort avec 1 HP (Réveil Soudain, Nécromancien Putride)
func _resurrect_last(battle, source_minion: Minion, effect: CardEffect) -> void:
	var is_player: bool = source_minion.owner_is_player if source_minion else true
	var graveyard: Graveyard = battle.player_graveyard if is_player else battle.enemy_graveyard
	var dead: Array[CardData] = graveyard.get_minions()
	if dead.is_empty():
		return
	# Prend le dernier mort (filtré par race si demandé, ex. Rituel de Résurrection)
	var race: int = Race.from_string(effect.race_filter) if not effect.race_filter.is_empty() else -1
	var card_data: CardData = null
	for i in range(dead.size() - 1, -1, -1):
		if race == -1 or dead[i].race == race:
			card_data = dead[i]
			break
	if card_data == null:
		return
	await _resurrect_card_data(battle, card_data, is_player)

# Octroie un mot-clé (Bouclier de Foi : ÉGIDE, Formation Défensive : REMPART...)
# Si le serviteur possède déjà le mot-clé, on ne l'enregistre pas en temporaire
# pour ne pas lui retirer un mot-clé permanent à l'expiration.
func _grant_keyword(battle, source_minion, effect: CardEffect, selected_target = null) -> void:
	if effect.granted_keyword.is_empty():
		return
	var targets: Array[Minion] = _resolve_targets(battle, source_minion, effect, selected_target)
	await _point_arrows_to(battle, targets, source_minion)
	for target in targets:
		if effect.granted_keyword_is_abomination:
			var kw: int = KeywordAbomination.from_name(effect.granted_keyword)
			if kw == -1:
				push_warning("GrantKeyword : mot-clé Abomination inconnu '%s'" % effect.granted_keyword)
				continue
			if target.has_abomination_keyword(kw):
				continue
			target.add_abomination_keyword(kw)
			battle.temp_effect_system.add_temp_abomination_keyword(target, kw, effect.duration)
		elif effect.granted_keyword_is_human:
			var kw: int = KeywordHuman.from_name(effect.granted_keyword)
			if target.has_human_keyword(kw):
				continue
			target.add_human_keyword(kw)
			battle.temp_effect_system.add_temp_keyword(target, kw, true, effect.duration)
		elif effect.granted_keyword_is_demon:
			var kw: int = KeywordDemon.from_name(effect.granted_keyword)
			if kw == -1:
				push_warning("GrantKeyword : mot-clé Démon inconnu '%s'" % effect.granted_keyword)
				continue
			if target.has_demon_keyword(kw):
				continue
			target.add_demon_keyword(kw)
			battle.temp_effect_system.add_temp_demon_keyword(target, kw, effect.duration)
			# PACTE octroyé après l'arrivée : donne aussi ASSAUT (le coût en HP ne
			# s'applique qu'à l'entrée en jeu, pas rétroactivement)
			if kw == KeywordDemon.Type.PACTE and not target.has_keyword(Keyword.Type.CHARGE):
				target.add_keyword(Keyword.Type.CHARGE)
				battle.temp_effect_system.add_temp_keyword(target, Keyword.Type.CHARGE, false, effect.duration)
			battle.aura_system.recompute_all()
		else:
			var kw: int = Keyword.from_name(effect.granted_keyword)
			if kw == -1:
				push_warning("GrantKeyword : mot-clé inconnu '%s'" % effect.granted_keyword)
				continue
			if target.has_keyword(kw):
				continue
			target.add_keyword(kw)
			battle.temp_effect_system.add_temp_keyword(target, kw, false, effect.duration)

# ─── Agression ────────────────────────────────────────────────────────────────

# Attaque immédiate d'une cible choisie automatiquement : le serviteur ennemi le
# plus faible en HP (Cavalier Zombie). Ignore la contrainte de rangée : c'est un
# effet, pas une attaque déclarée par le joueur.
func _attack_immediate(battle, source_minion: Minion, _effect: CardEffect) -> void:
	if source_minion == null:
		return
	var enemies: Array[Minion] = battle.get_enemy_minions(source_minion)
	if enemies.is_empty():
		return
	var target: Minion = enemies[0]
	for e in enemies:
		if e.health < target.health:
			target = e
	await battle.combat_system.resolve_combat(source_minion, target)

# Frappe Coordonnée : `effect.count` alliés (filtrés par race_filter, ex. Humain)
# attaquent immédiatement la cible ennemie choisie par le joueur (selected_target).
# Comme _attack_immediate, ce sont des attaques bonus : elles ne consomment pas
# l'attaque normale du tour des alliés concernés.
func _group_attack_immediate(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	if selected_target == null:
		return
	var is_player: bool = source_minion.owner_is_player if source_minion else true
	var race: int = Race.from_string(effect.race_filter) if not effect.race_filter.is_empty() else -1
	var allies: Array[Minion] = (battle.player_minions if is_player else battle.enemy_minions).filter(
		func(m: Minion): return race == -1 or m.card_data.race == race
	)
	for attacker in allies.slice(0, effect.count):
		if selected_target.is_dead():
			break
		await battle.combat_system.resolve_combat(attacker, selected_target)

# Retire l'Infection des cibles (Inquisiteur Suprême : tous les alliés).
func _cure_infection(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	var targets: Array[Minion] = _resolve_targets(battle, source_minion, effect, selected_target)
	await _point_arrows_to(battle, targets, source_minion)
	for target in targets:
		target.infected = false

# Accorde une attaque supplémentaire, au plus une fois par tour (Rongeur de Chair).
# Déclenché sur Exécution AVANT consume_attack : le +1 compense la consommation,
# offrant donc une relance nette une seule fois dans le tour.
func _grant_extra_attack(_battle, source_minion: Minion, _effect: CardEffect) -> void:
	if source_minion == null or source_minion.extra_attack_used_this_turn:
		return
	source_minion.extra_attack_used_this_turn = true
	source_minion.attacks_remaining += 1

# Sacrifie `count` alliés (coût du Don de Chair). Si une cible a été choisie par
# le joueur (target "AllyMinion" + requires_target), c'est elle qui est sacrifiée ;
# sinon (IA, pas de ciblage) on choisit automatiquement les plus faibles (HP puis
# ATK). Marqués `sacrificed` pour déclencher OnSacrifice et empêcher REVENANT.
func _sacrifice_ally(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	if selected_target != null and not selected_target.is_dead():
		await _point_arrows_to(battle, [selected_target], source_minion)
		selected_target.sacrificed = true
		selected_target.health = 0
		await battle.death_system.process_deaths()
		return
	var allies: Array[Minion] = battle.get_owner_minions(source_minion).duplicate()
	if allies.is_empty():
		return
	allies.sort_custom(func(a: Minion, b: Minion) -> bool:
		if a.health != b.health:
			return a.health < b.health
		return a.attack < b.attack
	)
	var n: int = mini(effect.count, allies.size())
	for i in range(n):
		allies[i].sacrificed = true
		allies[i].health = 0
	await battle.death_system.process_deaths()

# Active la Contre-Offensive pour le camp du lanceur : ce tour, chaque Humain de
# ce camp qui tue un ennemi gagne une attaque supplémentaire (voir CombatSystem).
func _grant_counter_offensive(battle, source_minion: Minion, _effect: CardEffect) -> void:
	var is_player: bool = source_minion.owner_is_player if source_minion else true
	battle.counter_offensive[is_player] = true

# Détruit un enchantement ou rituel ennemi actif aléatoire (La Grande
# Inquisitrice, Éveil). Tirage via le RNG partagé pour rester synchronisé en réseau.
func _destroy_random_enchantment(battle, source_minion: Minion, _effect: CardEffect) -> void:
	var enemy_is_player: bool = not (source_minion.owner_is_player if source_minion else true)
	var pool: Array[CardData] = []
	pool.append_array(battle.enchantment_system.get_enchantments(enemy_is_player))
	pool.append_array(battle.enchantment_system.get_rituals(enemy_is_player))
	if pool.is_empty():
		return
	battle.enchantment_system.destroy_enchantment(_rng_pick(battle, pool), enemy_is_player)

# Mana temporaire : ajoute `value` au mana DISPONIBLE du camp de la source, sans
# toucher au mana maximum — le surplus non dépensé est perdu au tour suivant
# (Vortex des Âmes : Carnage -> +1 mana ce tour).
func _gain_mana(battle, source_minion: Minion, effect: CardEffect) -> void:
	var is_player: bool = source_minion.owner_is_player if source_minion else true
	var amount: int = maxi(1, effect.value)
	# Bucket hors-race (Race.Type.NONE) : compte comme surplus générique dans
	# CostSystem, mais n'est jamais rechargé par refill_mana_pool -> perdu au
	# tour suivant, sans jamais toucher au maximum d'une race.
	var pool: Dictionary = battle.race_mana_pool(is_player)
	pool[Race.Type.NONE] = int(pool.get(Race.Type.NONE, 0)) + amount
	if is_player:
		battle.update_mana_ui()
	else:
		battle.update_enemy_mana_ui()

# Pioche `value` carte(s) ; chaque carte piochée de la race `race_filter` (ou
# toute carte si vide) coûte `value_2` de moins ce tour (Doigt Décharné). Pioche
# pour le camp propriétaire de `source_minion` : le joueur dans son deck, l'IA
# dans le sien (remise appliquée sur sa propre copie) ; côté réseau, la carte
# réelle du pair distant est inconnue localement donc seule la pioche
# cosmétique a lieu, sans remise (que le pair applique de son côté).
func _draw_card_discount(battle, source_minion: Minion, effect: CardEffect) -> void:
	var is_player: bool = source_minion == null or source_minion.owner_is_player
	var count: int = maxi(1, effect.value)
	var discount: int = maxi(1, effect.value_2)
	var ai_opponent: AISystem = battle.opponent as AISystem
	for i in range(count):
		var drawn: CardData = null
		if is_player:
			if battle.deck.is_empty():
				return
			drawn = battle.deck.back()
			battle.deck_system.draw_card()
		else:
			if ai_opponent != null:
				if ai_opponent.deck.is_empty():
					return
				drawn = ai_opponent.deck.back()
			elif battle.opponent.get_deck_count() <= 0:
				return
			battle.opponent.draw_card()
		if drawn != null and (effect.race_filter.is_empty() \
				or drawn.race == Race.from_string(effect.race_filter)):
			battle.cost_system.add_temp_discount(drawn, discount)

# ─── Effets Démon ─────────────────────────────────────────────────────────────

# Inflige `value` marqueur(s) de Corruption (min 1) aux cibles : -1 ATK permanent
# par marqueur, cumulable. Immunité gérée par Minion.apply_corruption (CHAIR DE
# SOUFRE). Cartes : Souffle Corrupteur, Le Corrupteur, Vague de Corruption...
func _corrupt(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	var targets: Array[Minion] = _resolve_targets(battle, source_minion, effect, selected_target)
	await _point_arrows_to(battle, targets, source_minion)
	var stacks: int = maxi(1, effect.value)
	for target in targets:
		target.apply_corruption(stacks)

# Vole `value` HP au héros ENNEMI et en soigne le héros allié d'autant
# (Suceur d'Âmes). Distinct de StealHealth, qui vise les serviteurs.
func _steal_health_from_hero(battle, source_minion: Minion, effect: CardEffect) -> void:
	var is_p: bool = source_minion == null or source_minion.owner_is_player
	var enemy_hero_panel: Control = await _point_arrow_to_hero(battle, is_p, source_minion)
	var enemy_hero: Hero = battle.hero_system.get_enemy_hero(source_minion)
	var stolen: int = mini(effect.value, maxi(enemy_hero.health, 0))
	battle.hero_system.damage(enemy_hero, stolen)
	battle.animation_system.play_damage(enemy_hero_panel, stolen)
	var owner_hero: Hero = battle.hero_system.get_owner_hero(source_minion)
	var could_heal: bool = owner_hero.heal_block_turns <= 0
	owner_hero.heal(stolen)
	if could_heal and stolen > 0:
		var owner_panel: Control = battle.get_node_or_null("PlayerHeroPanel" if is_p else "EnemyHeroPanel")
		battle.animation_system.play_heal(owner_panel, stolen)

# Absolution Écarlate : les dégâts que tes propres cartes infligeraient à ton
# héros ce tour sont annulés. Expiré par TurnSystem en fin de tour.
func _block_self_damage(battle, source_minion: Minion, _effect: CardEffect) -> void:
	var is_p: bool = source_minion == null or source_minion.owner_is_player
	battle.hero_system.self_damage_blocked[is_p] = true

# Rituel de la Terreur : le héros ennemi ne peut pas soigner jusqu'à la fin de
# son prochain tour (décrément dans TurnSystem, vérifié par Hero.heal).
func _prevent_enemy_hero_heal(battle, source_minion: Minion, effect: CardEffect) -> void:
	var enemy_hero: Hero = battle.hero_system.get_enemy_hero(source_minion)
	enemy_hero.heal_block_turns = maxi(enemy_hero.heal_block_turns, maxi(1, effect.value))

# Ultime Sacrifice : sacrifie jusqu'à `count` alliés (les plus faibles si aucune
# cible choisie), puis pioche 1 carte ET inflige `value` dégâts auto-infligés au
# héros PAR victime effectivement sacrifiée.
func _sacrifice_draw_per_victim(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	var is_p: bool = source_minion == null or source_minion.owner_is_player
	var victims: Array[Minion] = []
	if selected_target != null and not selected_target.is_dead():
		victims.append(selected_target)
	else:
		var allies: Array[Minion] = battle.get_owner_minions(source_minion).duplicate()
		allies.sort_custom(func(a: Minion, b: Minion) -> bool:
			if a.health != b.health:
				return a.health < b.health
			return a.attack < b.attack
		)
		victims = allies.slice(0, mini(effect.count, allies.size()))
	if victims.is_empty():
		return
	await _point_arrows_to(battle, victims, source_minion)
	for victim in victims:
		victim.sacrificed = true
		victim.health = 0
	await battle.death_system.process_deaths()
	_draw_cards(battle, source_minion, victims.size())
	await battle.hero_system.self_damage(is_p, effect.value * victims.size())

# Emprise Écarlate : prend le contrôle d'un serviteur ennemi jusqu'à la fin de
# ce tour, puis le détruit (TempEffectSystem). Respecte l'immunité au contrôle
# mental (DISCIPLINE, CHAIR DE SOUFRE).
func _steal_minion_then_destroy(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	if selected_target == null or selected_target.is_mind_control_immune():
		return
	await _steal_minion(battle, source_minion, effect, selected_target)
	# Le serviteur volé peut agir immédiatement pendant ce tour d'emprunt
	selected_target.attacks_remaining = maxi(selected_target.attacks_remaining, 1)
	var duration: String = effect.duration if effect.duration != "Permanent" else "UntilEndOfTurn"
	battle.temp_effect_system.add_destroy_at_expiry(selected_target, duration)

# ─── Pool aléatoire ───────────────────────────────────────────────────────────

func _get_random_pool(effect: CardEffect) -> Array[CardData]:
	# Puise dans toutes les cartes chargées (CardLibrary est un autoload global).
	# Ne retient que des serviteurs, filtrés par coût et par race si demandé.
	if CardLibrary == null or not CardLibrary.is_loaded or CardLibrary.all_cards.is_empty():
		push_warning("_get_random_pool : CardLibrary non chargé (test direct de Battle.tscn ?)")
		return []
	var race_filter: int = -1
	if not effect.pool_race_filter.is_empty():
		race_filter = Race.from_string(effect.pool_race_filter)
	var pool: Array[CardData] = []
	for card in CardLibrary.all_cards:
		if card.card_type != "Minion":
			continue
		if effect.pool_max_cost >= 0 and card.cost > effect.pool_max_cost:
			continue
		if effect.pool_min_cost >= 0 and card.cost < effect.pool_min_cost:
			continue
		if race_filter != -1 and card.race != race_filter:
			continue
		pool.append(card)
	return pool

# Point d'entrée unique après des dégâts non létaux : déclenche Blessure
# (OnDamaged) puis Mort-rage (OnDeathRage) une seule fois quand le serviteur
# passe sous 50% de ses HP max.
func notify_damaged(battle, minion: Minion) -> void:
	if minion == null or minion.is_dead():
		return
	await trigger_effects(battle, minion, "OnDamaged")
	# MUTATION (Abomination) : mute chaque fois qu'il survit à une blessure.
	if minion.has_abomination_keyword(KeywordAbomination.Type.MUTATION):
		await roll_mutation(battle, minion)
	if minion.death_rage_triggered:
		return
	if minion.health * 2 < minion.max_health:
		minion.death_rage_triggered = true
		var visual: BoardMinion = battle.board_visual_system.get_visual(minion)
		if visual:
			battle.animation_system.play_death_rage(visual)
		await trigger_effects(battle, minion, "OnDeathRage")

# ─── Mutation (Abomination) ────────────────────────────────────────────────────
# Table de Mutation : 40% Croissance (+2/+0), 40% Renforcement (+0/+2),
# 20% Dégénérescence (-1/-1, cumulable, peut tuer). Tirage via le RNG de jeu
# partagé (déterministe/synchronisé en réseau). Effets permanents et cumulables.
func roll_mutation(battle, minion: Minion) -> void:
	if minion == null or minion.is_dead():
		return
	var roll: int = battle.game_rng.randi() % 100
	var outcome: String
	if roll < 40:
		minion.base_attack += 2
		outcome = "Croissance"
	elif roll < 80:
		minion.base_max_health += 2
		outcome = "Renforcement"
	else:
		minion.base_attack = max(0, minion.base_attack - 1)
		minion.base_max_health -= 1
		outcome = "Dégénérescence"
	minion.mutations.append(outcome)
	minion.mutation_stacks += 1
	var visual: BoardMinion = battle.board_visual_system.get_visual(minion)
	if visual and not minion.is_dead():
		battle.animation_system.play_mutation(visual, outcome)
	battle.aura_system.recompute_all()
	# Résonance (Abomination) : un allié Abomination vient de muter.
	await trigger_effects(battle, minion, "OnMutation")
	await battle.trigger_system.fire("OnMutation", minion, minion.owner_is_player)

# Déclenche une (ou plusieurs, via effect.count) mutation(s) immédiate(s) sur
# la/les cible(s) résolue(s) (Premier Tressaut, Le Trieur de Chairs...).
func _apply_mutation(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	var targets: Array[Minion] = _resolve_targets(battle, source_minion, effect, selected_target)
	await _point_arrows_to(battle, targets, source_minion)
	var rolls: int = max(1, effect.count)
	for target in targets:
		for i in range(rolls):
			if target.is_dead():
				break
			await roll_mutation(battle, target)

# Octroie effect.granted_keyword au serviteur allié adjacent à la source, de
# façon permanente ou temporaire selon effect.duration (Voix-Sous-la-Peau).
func _grant_keyword_adjacent(battle, source_minion: Minion, effect: CardEffect) -> void:
	if source_minion == null or effect.granted_keyword.is_empty():
		return
	var adjacents: Array[Minion] = _get_adjacent_minions(battle, source_minion)
	await _point_arrows_to(battle, adjacents, source_minion)
	for target in adjacents:
		if effect.granted_keyword_is_abomination:
			var kw: int = KeywordAbomination.from_name(effect.granted_keyword)
			if kw == -1 or target.has_abomination_keyword(kw):
				continue
			target.add_abomination_keyword(kw)
			battle.temp_effect_system.add_temp_abomination_keyword(target, kw, effect.duration)
		else:
			var kw: int = Keyword.from_name(effect.granted_keyword)
			if kw == -1 or target.has_keyword(kw):
				continue
			target.add_keyword(kw)
			battle.temp_effect_system.add_temp_keyword(target, kw, false, effect.duration)

# Partage Forcé : sacrifie selected_target, le serviteur allié adjacent à la
# victime (capturé AVANT sa mort) absorbe ses stats restantes (ATK/HP actuels,
# pas ses valeurs de base) de façon permanente.
func _absorb_adjacent_stats(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	if selected_target == null or selected_target.is_dead():
		return
	await _point_arrows_to(battle, [selected_target], source_minion)
	var adjacents: Array[Minion] = _get_adjacent_minions(battle, selected_target)
	var remaining_attack: int = selected_target.attack
	var remaining_health: int = selected_target.health
	selected_target.sacrificed = true
	selected_target.health = 0
	await battle.death_system.process_deaths()
	for adjacent in adjacents:
		if adjacent.is_dead():
			continue
		adjacent.base_attack     += remaining_attack
		adjacent.base_max_health += remaining_health

# Emprunt Instantané : la cible copie un mot-clé présent sur un AUTRE
# serviteur en jeu tiré au hasard (allié ou ennemi). Simplification par
# rapport au texte (« n'importe quel autre serviteur », choix libre) : le
# serviteur source est tiré au sort faute d'UI de sélection double cible.
func _copy_adjacent_keyword_effect(battle, source_minion: Minion, effect: CardEffect, selected_target: Minion = null) -> void:
	if selected_target == null:
		return
	await _point_arrows_to(battle, [selected_target], source_minion)
	var pool: Array[Minion] = (battle.player_minions + battle.enemy_minions).filter(
		func(m: Minion) -> bool: return m != selected_target)
	if pool.is_empty():
		return
	var source: Minion = _rng_pick(battle, pool)
	if not source.keywords.is_empty():
		selected_target.add_keyword(_rng_pick(battle, source.keywords))
	elif not source.human_keywords.is_empty():
		selected_target.add_human_keyword(_rng_pick(battle, source.human_keywords))
	elif not source.undead_keywords.is_empty():
		var kw: int = _rng_pick(battle, source.undead_keywords)
		if kw not in selected_target.undead_keywords:
			selected_target.undead_keywords.append(kw)
	elif not source.demon_keywords.is_empty():
		selected_target.add_demon_keyword(_rng_pick(battle, source.demon_keywords))
	elif not source.abomination_keywords.is_empty():
		selected_target.add_abomination_keyword(_rng_pick(battle, source.abomination_keywords))

func has_trigger(minion: Minion, trigger_name: String) -> bool:
	if minion == null:
		return false
	for trigger in minion.card_data.trigger_types:
		if trigger.type == trigger_name:
			return true
	return false

# Retourne true si le trigger a réellement déclenché des effets,
# pour que l'appelant puisse espacer les actions (pacing) si besoin.
# selected_target : cible contextuelle de l'évènement (ex: défenseur d'une
# attaque pour OnAttack) transmise aux effets qui en ont besoin (SplashDamage...).
func trigger_effects(battle, minion: Minion, trigger_name: String, selected_target: Minion = null) -> bool:
	if not has_trigger(minion, trigger_name):
		return false
	for effect in minion.card_data.effects:
		await execute_effect(battle, minion, effect, selected_target)
	return true

func _is_hostile_to(source_minion: Minion, target: Minion) -> bool:
	if source_minion != null:
		return source_minion.owner_is_player != target.owner_is_player
	# Pas de source minion = sort joué directement (actuellement, seul le joueur lance des sorts)
	return target.owner_is_player == false
