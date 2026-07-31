extends GutTest

# Couvre AISystem (scripts/systems/AISystem.gd) : construction du deck/main de
# départ (setup, mulligan), pioche, et la logique de décision pure (choix de
# cible d'attaque, meilleur trade, cible de sort, sort létal/suppression
# prioritaire). take_turn/_play_cards_phase/_attack_phase/_cast_spell
# orchestrent une douzaine d'appels UI/réseau et sont laissés hors scope
# (comme CardSystem.handle_card_played, voir test_card_system.gd). Utilise
# FakeBattle (tests/unit/doubles/fake_battle.gd), conformément à la
# convention GUT du projet (voir CLAUDE.md).

var ai_system: AISystem
var battle: FakeBattle

func before_each() -> void:
	ai_system = load("res://scripts/systems/AISystem.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()
	ai_system.init(battle)

func after_each() -> void:
	ai_system.free()

func _minion(attack: int, health: int, is_player: bool, board_row: String = "Front") -> Minion:
	var data := CardData.new()
	data.card_name = "TEST_MINION"
	data.attack = attack
	data.health = health
	var minion := Minion.new(data, is_player, board_row)
	if is_player:
		battle.player_minions.append(minion)
	else:
		battle.enemy_minions.append(minion)
	return minion

func _spell_effect(effect_id: String, target: String, value: int = 0) -> CardEffect:
	var effect := CardEffect.new()
	effect.effect_id = effect_id
	effect.target = target
	effect.value = value
	return effect

func _spell_card(effect: CardEffect, card_type: String = "Instant") -> CardData:
	var data := CardData.new()
	data.card_name = "TEST_SPELL"
	data.card_type = card_type
	data.effects = [effect]
	return data

# ─── Deck / main de départ ──────────────────────────────────────────────────────

func test_setup_builds_a_deck_and_draws_starting_hand() -> void:
	ai_system.setup()
	assert_eq(ai_system.get_hand_count(), AISystem.STARTING_HAND)
	assert_eq(ai_system.get_deck_count() + ai_system.get_hand_count(),
		AISystem.DECK_SIZE + AISystem.RESOURCE_COUNT,
		"aucune carte ne doit être perdue entre pioche de départ et mulligan")

func test_setup_reads_difficulty_from_settings_manager() -> void:
	SettingsManager.ai_difficulty = "hard"
	ai_system.setup()
	assert_eq(ai_system.difficulty, "hard")
	SettingsManager.ai_difficulty = "normal"

func test_draw_card_moves_one_card_from_deck_to_hand() -> void:
	ai_system.setup()
	var deck_before: int = ai_system.get_deck_count()
	var hand_before: int = ai_system.get_hand_count()
	ai_system.draw_card()
	assert_eq(ai_system.get_deck_count(), deck_before - 1)
	assert_eq(ai_system.get_hand_count(), hand_before + 1)

func test_draw_card_is_a_noop_on_empty_deck() -> void:
	ai_system.deck.clear()
	ai_system.draw_card()
	assert_eq(ai_system.get_deck_count(), 0)
	assert_eq(ai_system.get_hand_count(), 0)

# ─── Cibles de sort ──────────────────────────────────────────────────────────────

func test_best_hostile_target_prefers_highest_attack() -> void:
	var weak := _minion(1, 5, true)
	var strong := _minion(4, 3, true)
	assert_eq(ai_system._best_hostile_target([weak, strong]), strong)

func test_best_hostile_target_breaks_attack_tie_with_lowest_health() -> void:
	var tanky := _minion(3, 8, true)
	var fragile := _minion(3, 2, true)
	assert_eq(ai_system._best_hostile_target([tanky, fragile]), fragile,
		"à ATK égale, préférer la cible la plus facile à achever")

func test_best_hostile_target_returns_null_for_empty_candidates() -> void:
	assert_null(ai_system._best_hostile_target([]))

func test_best_friendly_target_prefers_lowest_health() -> void:
	var healthy := _minion(2, 6, false)
	var wounded := _minion(2, 1, false)
	assert_eq(ai_system._best_friendly_target([healthy, wounded]), wounded)

func test_filter_spell_targets_applies_race_and_hp_filters() -> void:
	var human := _minion(2, 3, true)
	human.card_data.race = Race.Type.HUMAN
	var undead := _minion(2, 3, true)
	undead.card_data.race = Race.Type.UNDEAD
	var effect := CardEffect.new()
	effect.race_filter = "Undead"
	var result := ai_system._filter_spell_targets([human, undead], effect)
	assert_eq(result, [undead])

func test_pick_spell_target_enemy_minion_picks_the_biggest_threat() -> void:
	var weak := _minion(1, 5, true)
	var strong := _minion(5, 3, true)
	var card := _spell_card(_spell_effect("Damage", "EnemyMinion", 2))
	assert_eq(ai_system._pick_spell_target(card), strong)

func test_pick_spell_target_ally_minion_picks_the_weakest_ally() -> void:
	var healthy := _minion(2, 6, false)
	var wounded := _minion(2, 1, false)
	var card := _spell_card(_spell_effect("Heal", "AllyMinion", 3))
	assert_eq(ai_system._pick_spell_target(card), wounded)

func test_pick_spell_target_returns_null_for_hero_targets() -> void:
	var card := _spell_card(_spell_effect("Damage", "EnemyHero", 5))
	assert_null(ai_system._pick_spell_target(card))

func test_pick_spell_target_returns_null_for_auto_target_effects() -> void:
	var card := _spell_card(_spell_effect("SacrificeAlly", "AllyMinion"))
	_minion(2, 2, false)
	assert_null(ai_system._pick_spell_target(card),
		"EffectManager choisit lui-même la cible pour les effets à cible automatique")

func test_has_valid_spell_target_false_without_matching_minion() -> void:
	var card := _spell_card(_spell_effect("Damage", "EnemyMinion", 2))
	assert_false(ai_system._has_valid_spell_target(card))

func test_has_valid_spell_target_true_with_a_matching_minion() -> void:
	_minion(2, 2, true)
	var card := _spell_card(_spell_effect("Damage", "EnemyMinion", 2))
	assert_true(ai_system._has_valid_spell_target(card))

func test_has_valid_spell_target_auto_target_only_needs_an_ally_in_play() -> void:
	var card := _spell_card(_spell_effect("SacrificeAlly", "AllyMinion"))
	assert_false(ai_system._has_valid_spell_target(card), "aucun allié en jeu : pas de cible")
	_minion(1, 1, false)
	assert_true(ai_system._has_valid_spell_target(card))

# ─── Choix de carte à jouer ──────────────────────────────────────────────────────

func test_highest_cost_picks_the_most_expensive_card() -> void:
	var cheap := CardData.new()
	cheap.cost = 2
	var pricey := CardData.new()
	pricey.cost = 6
	assert_eq(ai_system._highest_cost([cheap, pricey]), pricey)

func test_find_lethal_burn_finds_direct_damage_that_finishes_the_player() -> void:
	battle.player_hero.take_damage(battle.player_hero.max_health - 3)  # 3 HP restants
	var lethal_card := _spell_card(_spell_effect("Damage", "EnemyHero", 3))
	var too_weak_card := _spell_card(_spell_effect("Damage", "EnemyHero", 1))
	assert_eq(ai_system._find_lethal_burn([too_weak_card, lethal_card]), lethal_card)

func test_find_lethal_burn_counts_ready_minion_attacks() -> void:
	battle.player_hero.take_damage(battle.player_hero.max_health - 5)  # 5 HP restants
	var attacker := _minion(3, 2, false)
	attacker.attacks_remaining = 1
	var burn_card := _spell_card(_spell_effect("Damage", "EnemyHero", 2))
	assert_eq(ai_system._find_lethal_burn([burn_card]), burn_card,
		"3 (attaque prête) + 2 (sort) = 5 : létal")

func test_find_lethal_burn_returns_null_when_not_lethal() -> void:
	var card := _spell_card(_spell_effect("Damage", "EnemyHero", 1))
	assert_null(ai_system._find_lethal_burn([card]))

func test_find_priority_removal_targets_removal_effect_on_a_big_threat() -> void:
	var threat := _minion(AISystem.HARD_THREAT_ATTACK, 3, true)
	var removal_card := _spell_card(_spell_effect("Freeze", "EnemyMinion"))
	assert_eq(ai_system._find_priority_removal([removal_card]), removal_card)

func test_find_priority_removal_ignores_small_threats() -> void:
	_minion(1, 3, true)
	var removal_card := _spell_card(_spell_effect("Freeze", "EnemyMinion"))
	assert_null(ai_system._find_priority_removal([removal_card]))

func test_find_priority_removal_ignores_non_removal_effects() -> void:
	_minion(AISystem.HARD_THREAT_ATTACK, 3, true)
	var buff_card := _spell_card(_spell_effect("Buff", "EnemyMinion"))
	assert_null(ai_system._find_priority_removal([buff_card]))

# ─── Trades / cible d'attaque ────────────────────────────────────────────────────

func test_ready_attack_total_sums_available_attackers() -> void:
	var a := _minion(3, 2, false)
	a.attacks_remaining = 1
	var b := _minion(2, 2, false)
	b.attacks_remaining = 2
	var frozen := _minion(5, 5, false)
	frozen.attacks_remaining = 0
	assert_eq(ai_system._ready_attack_total(), 3 + 2 * 2)

func test_best_trade_prefers_a_kill_over_a_bigger_survivor() -> void:
	var attacker := _minion(3, 5, false)
	var killable := _minion(3, 1, true)
	var survivor := _minion(10, 10, true)
	assert_eq(ai_system._best_trade(attacker, [killable, survivor]), killable,
		"tuer l'adversaire prime sur infliger plus de dégâts bruts")

func test_best_trade_without_any_kill_picks_highest_attack() -> void:
	var attacker := _minion(2, 5, false)
	var weak := _minion(1, 10, true)
	var strong := _minion(4, 10, true)
	assert_eq(ai_system._best_trade(attacker, [weak, strong]), strong)

func test_find_safe_kill_requires_killing_without_dying() -> void:
	var attacker := _minion(3, 4, false)
	var safe := _minion(2, 3, true)   # meurt (3 HP <= 3 ATK), riposte 2 < 4 HP attaquant
	var risky := _minion(4, 3, true)  # meurt aussi mais tue l'attaquant en retour (4 >= 4)
	assert_eq(ai_system._find_safe_kill(attacker, [safe, risky]), safe)

func test_find_safe_kill_returns_null_when_no_kill_is_safe() -> void:
	var attacker := _minion(2, 3, false)
	var tanky := _minion(1, 5, true)
	assert_null(ai_system._find_safe_kill(attacker, [tanky]))

func test_pick_attack_target_prioritizes_taunt() -> void:
	var attacker := _minion(3, 3, false)
	var taunt := _minion(2, 2, true)
	taunt.add_keyword(Keyword.Type.TAUNT)
	var juicier := _minion(5, 1, true)
	assert_eq(ai_system._pick_attack_target(attacker), taunt,
		"REMPART doit être attaqué en priorité, même si une autre cible serait un meilleur trade")

func test_pick_attack_target_returns_null_for_lethal_face() -> void:
	# Aucun serviteur adverse en Avant : le héros reste attaquable malgré un
	# allié présent en Arrière (get_attackable_enemy_minions retombe dessus,
	# mais _can_attack_hero ne regarde que la rangée Avant).
	_minion(1, 10, true, "Back")
	var attacker := _minion(10, 5, false)
	attacker.attacks_remaining = 1
	assert_eq(battle.player_hero.health, battle.player_hero.max_health)
	battle.player_hero.take_damage(battle.player_hero.max_health - 5)  # 5 HP restants
	assert_null(ai_system._pick_attack_target(attacker), "létal disponible : tout sur le héros")

func test_pick_attack_target_returns_safe_kill_when_available_and_no_lethal() -> void:
	var safe := _minion(2, 3, true, "Back")
	var attacker := _minion(3, 10, false)
	assert_eq(ai_system._pick_attack_target(attacker), safe)

func test_pick_attack_target_falls_back_to_hero_without_a_safe_kill() -> void:
	_minion(1, 10, true, "Back")  # increvable pour cet attaquant sans risque
	var attacker := _minion(2, 10, false)
	assert_null(ai_system._pick_attack_target(attacker))

func test_pick_attack_target_returns_best_trade_when_hero_is_not_attackable() -> void:
	# Un serviteur adverse en Avant bloque le héros : pas d'option "null" (héros).
	var attacker := _minion(3, 10, false)
	var blocker := _minion(2, 2, true, "Front")
	assert_eq(ai_system._pick_attack_target(attacker), blocker)

<<<<<<< HEAD
# ─── Rituels de Sacrifice ────────────────────────────────────────────────────
# L'IA doit activer d'elle-même les Rituels de Sacrifice qu'elle possède
# (contrairement au joueur, elle n'a pas de clic pour choisir ses victimes) :
# voir SacrificeSystem côté joueur.

func _sacrifice_ritual(count: int, max_hp: int = -1) -> CardData:
	var data := CardData.new()
	data.card_name = "TEST_RITUAL"
	data.card_type = "Ritual"
	data.sacrifice_count = count
	data.sacrifice_max_hp = max_hp
	var trigger := TriggerTypeChoice.new()
	trigger.type = "OnSacrifice"
	data.trigger_types = [trigger]
	return data

func test_pick_sacrifice_victims_picks_the_weakest_allies() -> void:
	var weak := _minion(1, 1, false)
	_minion(5, 5, false)
	var card := _sacrifice_ritual(1)
	assert_eq(ai_system._pick_sacrifice_victims(card), [weak])

func test_pick_sacrifice_victims_keeps_at_least_one_survivor() -> void:
	_minion(2, 2, false)
	var card := _sacrifice_ritual(1)
	assert_eq(ai_system._pick_sacrifice_victims(card), [],
		"un seul allié en jeu : le sacrifier viderait le plateau")

func test_pick_sacrifice_victims_respects_max_hp_filter() -> void:
	_minion(3, 3, false)  # trop de HP pour ce rituel
	var eligible := _minion(1, 1, false)
	var card := _sacrifice_ritual(1, 2)
	assert_eq(ai_system._pick_sacrifice_victims(card), [eligible])

func test_pick_sacrifice_victims_empty_without_enough_eligible_allies() -> void:
	_minion(1, 1, false)
	var card := _sacrifice_ritual(2)
	assert_eq(ai_system._pick_sacrifice_victims(card), [])

func test_maybe_activate_sacrifice_rituals_activates_an_affordable_ritual() -> void:
	var weak := _minion(1, 1, false)
	_minion(5, 5, false)
	var card := _sacrifice_ritual(1)
	battle.trigger_system.active_enchantments[false] = [{"card_data": card}]
	await ai_system._maybe_activate_sacrifice_rituals()
	assert_eq(battle.trigger_system.activated_rituals.size(), 1)
	assert_eq(battle.trigger_system.activated_rituals[0]["card_data"], card)
	assert_eq(battle.trigger_system.activated_rituals[0]["victims"], [weak])

func test_maybe_activate_sacrifice_rituals_skips_when_unaffordable() -> void:
	_minion(2, 2, false)
	var card := _sacrifice_ritual(1)
	battle.trigger_system.active_enchantments[false] = [{"card_data": card}]
	await ai_system._maybe_activate_sacrifice_rituals()
	assert_true(battle.trigger_system.activated_rituals.is_empty())

func test_maybe_activate_sacrifice_rituals_ignores_non_sacrifice_enchantments() -> void:
	var enchantment := CardData.new()
	enchantment.card_type = "Enchantment"
	battle.trigger_system.active_enchantments[false] = [{"card_data": enchantment}]
	await ai_system._maybe_activate_sacrifice_rituals()
	assert_true(battle.trigger_system.activated_rituals.is_empty())

# ─── Fusion (Abomination) ────────────────────────────────────────────────────
# Même bug que les Rituels de Sacrifice : sans contrepartie IA, un serviteur
# FUSION posé par l'IA n'aurait jamais absorbé de voisin.

func _fusion_minion(attack: int, health: int) -> Minion:
	var m := _minion(attack, health, false)
	m.add_abomination_keyword(KeywordAbomination.Type.FUSION)
	return m

func test_pick_fusion_victim_prefers_the_weakest_neighbor() -> void:
	var source := _fusion_minion(3, 3)
	var weak := _minion(1, 1, false)
	assert_eq(ai_system._pick_fusion_victim(source), weak)

func test_pick_fusion_victim_ignores_enemy_neighbors() -> void:
	var source := _fusion_minion(3, 3)
	_minion(1, 1, true)
	assert_null(ai_system._pick_fusion_victim(source))

func test_maybe_activate_fusion_fuses_with_the_weakest_neighbor() -> void:
	var source := _fusion_minion(3, 3)
	var victim := _minion(1, 1, false)
	await ai_system._maybe_activate_fusion()
	assert_eq(battle.fusion_system.applied_fusions.size(), 1)
	assert_eq(battle.fusion_system.applied_fusions[0]["source"], source)
	assert_eq(battle.fusion_system.applied_fusions[0]["victim"], victim)

func test_maybe_activate_fusion_skips_minions_without_a_valid_neighbor() -> void:
	_fusion_minion(3, 3)
	await ai_system._maybe_activate_fusion()
	assert_true(battle.fusion_system.applied_fusions.is_empty())

func test_maybe_activate_fusion_ignores_minions_without_the_keyword() -> void:
	_minion(3, 3, false)
	_minion(1, 1, false)
	await ai_system._maybe_activate_fusion()
	assert_true(battle.fusion_system.applied_fusions.is_empty())
=======
# ─── BLACK_WINGS (Infiltration) : formule de ciblage de battle.get_attackable_
# enemy_minions/_can_attack_hero, dupliquée depuis Battle.gd dans FakeBattle
# (voir son commentaire "Mêmes formules que Battle.gd") — testée ici via
# AISystem car aucun test dédié n'existe pour Battle.gd lui-même (scène
# complète, hors scope, voir CLAUDE.md).

func test_get_attackable_enemy_minions_only_returns_front_row_when_present() -> void:
	var front := _minion(1, 5, true, "Front")
	_minion(1, 5, true, "Back")
	var attacker := _minion(3, 5, false)
	assert_eq(battle.get_attackable_enemy_minions(attacker), [front])

func test_get_attackable_enemy_minions_with_black_wings_ignores_row_constraint() -> void:
	var front := _minion(1, 5, true, "Front")
	var back := _minion(1, 5, true, "Back")
	var attacker := _minion(3, 5, false)
	attacker.add_keyword(Keyword.Type.BLACK_WINGS)
	var result: Array[Minion] = battle.get_attackable_enemy_minions(attacker)
	assert_eq(result.size(), 2)
	assert_true(front in result)
	assert_true(back in result)

func test_can_attack_hero_blocked_by_front_row_without_black_wings() -> void:
	_minion(1, 5, true, "Front")
	var attacker := _minion(3, 5, false)
	assert_false(battle._can_attack_hero(attacker))

func test_can_attack_hero_allowed_with_black_wings_despite_front_row() -> void:
	_minion(1, 5, true, "Front")
	var attacker := _minion(3, 5, false)
	attacker.add_keyword(Keyword.Type.BLACK_WINGS)
	assert_true(battle._can_attack_hero(attacker))

func test_pick_attack_target_with_black_wings_can_reach_a_safe_back_row_kill() -> void:
	# Un Avant infaisable en trade sûr (tuerait l'attaquant en retour) ne doit
	# plus bloquer BLACK_WINGS : la cible sûre en Arrière reste accessible.
	_minion(5, 5, true, "Front")  # tue l'attaquant en riposte (5 >= 5 HP)
	var safe_back := _minion(1, 3, true, "Back")
	var attacker := _minion(3, 5, false)
	attacker.add_keyword(Keyword.Type.BLACK_WINGS)
	assert_eq(ai_system._pick_attack_target(attacker), safe_back)
>>>>>>> dev
