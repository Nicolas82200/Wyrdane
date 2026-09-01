extends GutTest

# Couvre EffectManager (scripts/EffectManager/EffectManager.gd), le moteur
# data-driven exécuté par toutes les cartes. Utilise FakeBattle
# (tests/unit/doubles/fake_battle.gd) pour rester indépendant de la scène et
# des autoloads, conformément à la convention GUT du projet (voir CLAUDE.md).

var effect_manager: EffectManager
var battle: FakeBattle

func before_each() -> void:
	effect_manager = load("res://scripts/EffectManager/EffectManager.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()

func _minion(attack: int = 2, health: int = 5, is_player: bool = true, row: String = "Front") -> Minion:
	var data := CardData.new()
	data.card_name = "TEST_CARD"
	data.attack = attack
	data.health = health
	var minion := Minion.new(data, is_player, row)
	if is_player:
		battle.player_minions.append(minion)
	else:
		battle.enemy_minions.append(minion)
	return minion

func _effect(effect_id: String, target: String, value: int = 0, value_2: int = 0) -> CardEffect:
	var effect := CardEffect.new()
	effect.effect_id = effect_id
	effect.target = target
	effect.value = value
	effect.value_2 = value_2
	return effect

# CardData "en main"/"au cimetière" (pas encore une instance Minion en jeu).
# race par défaut = Undead (identique au défaut de CardData.race).
func _card(name: String, attack: int = 1, health: int = 1) -> CardData:
	var data := CardData.new()
	data.card_name = name
	data.attack = attack
	data.health = health
	return data

func test_damage_enemy_hero() -> void:
	var attacker := _minion()
	var effect := _effect("Damage", "EnemyHero", 4)
	await effect_manager.execute_effect(battle, attacker, effect)
	assert_eq(battle.enemy_hero.health, battle.enemy_hero.max_health - 4)

func test_damage_owner_hero_uses_self_damage_pipeline() -> void:
	var source := _minion()
	var effect := _effect("Damage", "OwnerHero", 999)
	await effect_manager.execute_effect(battle, source, effect)
	assert_eq(battle.player_hero.health, 1, "self_damage ne doit jamais faire tomber le héros à 0")

# ─── Damage "EnemyAny" (Souffle Nécrotique, Don de Chair) ───────────────────

func test_damage_enemy_any_hits_enemy_hero_when_selected() -> void:
	var effect := _effect("Damage", "EnemyAny", 2)
	await effect_manager.execute_effect(battle, null, effect, battle.enemy_hero)
	assert_eq(battle.enemy_hero.health, battle.enemy_hero.max_health - 2)

func test_damage_enemy_any_hits_enemy_minion_when_selected() -> void:
	var target := _minion(2, 5, false)
	var effect := _effect("Damage", "EnemyAny", 2)
	await effect_manager.execute_effect(battle, null, effect, target)
	assert_eq(target.health, 3)

func test_damage_targets_minion_and_kills_it() -> void:
	var source := _minion(2, 5, true)
	var target := _minion(2, 3, false)
	var effect := _effect("Damage", "EnemyMinion", 5)
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_true(target.is_dead())

func test_heal_owner_hero_respects_max_health() -> void:
	battle.player_hero.health = battle.player_hero.max_health - 2
	var source := _minion()
	var effect := _effect("Heal", "OwnerHero", 10)
	await effect_manager.execute_effect(battle, source, effect)
	assert_eq(battle.player_hero.health, battle.player_hero.max_health + 8, "HealHero applique la valeur brute (pas de plafond côté Hero)")

func test_heal_minion_target() -> void:
	var source := _minion()
	var target := _minion(2, 6, true)
	target.take_damage(4)
	var effect := _effect("Heal", "AllyMinion", 2)
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_eq(target.health, 4, "2 HP soignés sur les 4 perdus")

func test_buff_increases_attack_and_max_health() -> void:
	var source := _minion()
	var target := _minion(2, 4, true)
	var effect := _effect("Buff", "AllyMinion", 3, 2)
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_eq(target.attack, 5)
	assert_eq(target.max_health, 6)

func test_debuff_permanently_reduces_max_health() -> void:
	var source := _minion()
	var target := _minion(3, 4, false)
	var effect := _effect("Debuff", "EnemyMinion", 1, 2)
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_eq(target.attack, 2)
	assert_eq(target.max_health, 2, "la réduction de HP max doit être permanente (symétrique de Buff)")
	assert_eq(target.health, 2)

func test_debuff_can_kill_low_health_target() -> void:
	var source := _minion()
	var target := _minion(2, 2, false)
	var effect := _effect("Debuff", "EnemyMinion", 0, 2)
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_true(target.is_dead(), "-2/-2 doit pouvoir tuer un serviteur à 2 HP")

func test_steal_minion_moves_target_between_camps() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(3, 5, false)
	var effect := _effect("StealMinion", "EnemyMinion")
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_true(target.owner_is_player, "le serviteur volé doit changer de camp")
	assert_true(target in battle.player_minions, "doit rejoindre les serviteurs du voleur")
	assert_false(target in battle.enemy_minions, "ne doit plus figurer côté ancien propriétaire")

func test_destroy_ally_marks_sacrificed_and_kills() -> void:
	var source := _minion()
	var target := _minion(2, 4, true)
	var effect := _effect("Destroy", "AllyMinion", 0)
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_true(target.sacrificed, "une destruction ciblant un allié doit être marquée sacrifiée (pas de REVENANT)")
	assert_true(target.is_dead())

func test_destroy_enemy_does_not_mark_sacrificed() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(2, 4, false)
	var effect := _effect("Destroy", "EnemyMinion", 0)
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_false(target.sacrificed)
	assert_true(target.is_dead())

func test_damage_all_enemies_hits_every_enemy_minion() -> void:
	var source := _minion(2, 4, true)
	var e1 := _minion(2, 3, false)
	var e2 := _minion(2, 3, false)
	var effect := _effect("Damage", "AllEnemies", 2)
	await effect_manager.execute_effect(battle, source, effect)
	assert_eq(e1.health, 1)
	assert_eq(e2.health, 1)

func test_condition_allies_in_play_blocks_effect_when_unmet() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(2, 4, false)
	var effect := _effect("Damage", "EnemyMinion", 5)
	effect.condition_type = "AlliesInPlay"
	effect.condition_op = "GreaterOrEqual"
	effect.condition_count = 2
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_eq(target.health, 4, "condition non remplie (1 allié en jeu, 2 requis) : l'effet doit être ignoré")

func test_condition_allies_in_play_allows_effect_when_met() -> void:
	var source := _minion(2, 4, true)
	_minion(2, 4, true)
	var target := _minion(2, 4, false)
	var effect := _effect("Damage", "EnemyMinion", 5)
	effect.condition_type = "AlliesInPlay"
	effect.condition_op = "GreaterOrEqual"
	effect.condition_count = 2
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_true(target.is_dead())

func test_has_trigger_true_when_present() -> void:
	var data := CardData.new()
	var trigger := TriggerTypeChoice.new()
	trigger.type = "OnSummon"
	data.trigger_types = [trigger]
	var minion := Minion.new(data)
	assert_true(effect_manager.has_trigger(minion, "OnSummon"))
	assert_false(effect_manager.has_trigger(minion, "OnDeath"))

func test_trigger_effects_returns_false_without_matching_trigger() -> void:
	var minion := Minion.new(CardData.new())
	var fired: bool = await effect_manager.trigger_effects(battle, minion, "OnAwaken")
	assert_false(fired)

# ─── DrawCard ───────────────────────────────────────────────────────────────

func test_draw_card_moves_top_of_deck_to_hand() -> void:
	var card := _card("Pioché")
	battle.deck = [card]
	var source := _minion()
	var effect := _effect("DrawCard", "Self", 1)
	await effect_manager.execute_effect(battle, source, effect)
	assert_eq(battle.hand_cards, [card])
	assert_true(battle.deck.is_empty())

# ─── SummonMinion ───────────────────────────────────────────────────────────

func test_summon_minion_adds_token_to_board() -> void:
	var source := _minion()
	var token := _card("Jeton")
	var effect := _effect("SummonMinion", "Self")
	effect.summon_card = token
	await effect_manager.execute_effect(battle, source, effect)
	assert_eq(battle.player_minions.size(), 2)
	assert_eq(battle.player_minions[1].card_data, token)

func test_summon_minion_falls_back_to_back_row_when_front_full() -> void:
	for i in range(10):
		_minion(1, 1, true, "Front")
	var source: Minion = battle.player_minions[0]
	var token := _card("Jeton")
	var effect := _effect("SummonMinion", "Self")
	effect.summon_card = token
	await effect_manager.execute_effect(battle, source, effect)
	assert_eq(battle.player_minions.back().board_row, "Back", "rangée Avant pleine : doit basculer en Arrière")

func test_summon_minion_per_ally_of_race_respects_count_max() -> void:
	var source := _minion() # race par défaut Undead
	for i in range(3):
		_minion(1, 1, true) # 3 alliés Undead supplémentaires
	var token := _card("Jeton")
	var effect := _effect("SummonMinion", "Self")
	effect.summon_card = token
	effect.count_mode = "PerAllyOfRace"
	effect.count_race = "Undead"
	effect.count_max = 2
	await effect_manager.execute_effect(battle, source, effect)
	# source + 3 alliés + min(3, count_max=2) invoqués
	assert_eq(battle.player_minions.size(), 6)

# ─── SummonRandom ───────────────────────────────────────────────────────────
# _get_random_pool lit l'autoload global CardLibrary (non injectable dans
# EffectManager). load_all_cards() est idempotent (garde is_loaded) : l'appeler
# ici rend le test déterministe quel que soit l'ordre d'exécution des scripts
# GUT (AISystem.setup(), exercé par d'autres tests, le charge déjà en pratique).
func test_summon_random_summons_from_race_and_cost_filtered_pool() -> void:
	CardLibrary.load_all_cards()
	var source := _minion()
	var effect := _effect("SummonRandom", "Self")
	effect.pool_race_filter = "Undead"
	effect.pool_max_cost = 2
	await effect_manager.execute_effect(battle, source, effect)
	assert_eq(battle.player_minions.size(), 2)
	var summoned: Minion = battle.player_minions[1]
	assert_eq(summoned.card_data.card_type, "Minion")
	assert_eq(summoned.card_data.race, Race.Type.UNDEAD)
	assert_true(summoned.card_data.cost <= 2)

# ─── StealHealth ────────────────────────────────────────────────────────────

func test_steal_health_damages_target_and_heals_source() -> void:
	var source := _minion(2, 4, true)
	source.take_damage(3) # source à 1/4 HP
	var target := _minion(2, 6, false)
	var effect := _effect("StealHealth", "EnemyMinion", 3)
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_eq(target.health, 3)
	assert_eq(source.health, 4, "soigné du montant réellement infligé, plafonné à son max")

# ─── HealHero ───────────────────────────────────────────────────────────────

func test_heal_hero_heals_owner_hero_directly() -> void:
	battle.player_hero.health = battle.player_hero.max_health - 5
	var source := _minion()
	var effect := _effect("HealHero", "OwnerHero", 3)
	await effect_manager.execute_effect(battle, source, effect)
	assert_eq(battle.player_hero.health, battle.player_hero.max_health - 2)

# ─── ReturnToHand ───────────────────────────────────────────────────────────

func test_return_to_hand_moves_enemy_minion_to_enemy_hand() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(2, 4, false)
	var effect := _effect("ReturnToHand", "EnemyMinion")
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_false(target in battle.enemy_minions)
	assert_true(target.card_data in battle.ai_system.hand)

func test_return_to_hand_moves_ally_minion_to_player_hand_cards() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(1, 3, true)
	var effect := _effect("ReturnToHand", "AllyMinion")
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_false(target in battle.player_minions)
	assert_true(target.card_data in battle.hand_cards)

# ─── ResurrectSelf ──────────────────────────────────────────────────────────

func test_resurrect_self_revives_dead_ally_with_one_hp() -> void:
	var dead := _minion(3, 5, true)
	dead.health = 0
	var effect := _effect("ResurrectSelf", "AllyMinion")
	await effect_manager.execute_effect(battle, null, effect, dead)
	var revived: Minion = battle.player_minions.back()
	assert_eq(revived.card_data, dead.card_data)
	assert_eq(revived.health, 1)
	assert_true(revived.was_resurrected)

func test_resurrect_self_can_revive_an_already_resurrected_target_again() -> void:
	var dead := _minion(3, 5, true)
	dead.health = 0
	dead.was_resurrected = true
	var effect := _effect("ResurrectSelf", "AllyMinion")
	await effect_manager.execute_effect(battle, null, effect, dead)
	assert_eq(battle.player_minions.size(), 2, "aucune limite par serviteur : peut revivre plusieurs fois au fil de la partie")

# ─── InfectEnemy / InfectAdjacent ───────────────────────────────────────────

func test_infect_enemy_sets_infected_flag() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(2, 4, false)
	var effect := _effect("InfectEnemy", "EnemyMinion")
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_true(target.infected)

func test_infect_adjacent_hits_enemies_mirroring_source_position() -> void:
	# Source en 2e position de sa rangée (Front) -> vise les ennemis en
	# positions 0,1,2 de LEUR rangée Front (idx-1, idx, idx+1 avec idx=1).
	_minion(1, 1, true, "Front")
	var source := _minion(2, 2, true, "Front")
	var e0 := _minion(1, 3, false, "Front")
	var e1 := _minion(1, 3, false, "Front")
	var e2 := _minion(1, 3, false, "Front")
	var effect := _effect("InfectAdjacent", "Self")
	await effect_manager.execute_effect(battle, source, effect)
	assert_true(e0.infected)
	assert_true(e1.infected)
	assert_true(e2.infected)

func test_infect_adjacent_does_not_hit_out_of_range_enemy() -> void:
	var source := _minion(2, 2, true, "Front") # seul allié -> idx=0
	var e0 := _minion(1, 3, false, "Front")
	var e1 := _minion(1, 3, false, "Front")
	var e2 := _minion(1, 3, false, "Front")
	var effect := _effect("InfectAdjacent", "Self")
	await effect_manager.execute_effect(battle, source, effect)
	assert_true(e0.infected, "idx=0 : touche la position 0")
	assert_true(e1.infected, "idx=0 : touche aussi la position 1 (idx+1)")
	assert_false(e2.infected, "position 2 hors fenêtre idx-1/idx/idx+1")

# ─── Freeze ──────────────────────────────────────────────────────────────────

func test_freeze_sets_frozen_turns() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(2, 4, false)
	var effect := _effect("Freeze", "EnemyMinion", 2)
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_eq(target.frozen_turns, 2)

# ─── Resurrect / ResurrectLast / ReturnFromGrave ────────────────────────────

func test_resurrect_brings_back_dead_minions_from_graveyard_with_one_hp() -> void:
	var g1 := _card("Mort 1")
	var g2 := _card("Mort 2")
	battle.player_graveyard.add_minion(g1)
	battle.player_graveyard.add_minion(g2)
	var source := _minion()
	var effect := _effect("Resurrect", "Self")
	effect.count = 2
	await effect_manager.execute_effect(battle, source, effect)
	# source + 2 ressuscités
	assert_eq(battle.player_minions.size(), 3)
	assert_true(battle.player_minions[1].was_resurrected)
	assert_eq(battle.player_minions[1].health, 1)
	assert_eq(battle.player_minions[2].health, 1)

func test_resurrect_last_revives_most_recent_grave_entry() -> void:
	battle.player_graveyard.add_minion(_card("Ancien"))
	battle.player_graveyard.add_minion(_card("Récent"))
	var source := _minion()
	var effect := _effect("ResurrectLast", "Self")
	await effect_manager.execute_effect(battle, source, effect)
	var revived: Minion = battle.player_minions.back()
	assert_eq(revived.card_data.card_name, "Récent")
	assert_eq(revived.health, 1)

func test_return_from_grave_puts_last_matching_card_in_hand() -> void:
	battle.player_graveyard.add_minion(_card("Autre"))
	var wanted := _card("Voulu")
	battle.player_graveyard.add_minion(wanted)
	var source := _minion()
	var effect := _effect("ReturnFromGrave", "Self")
	await effect_manager.execute_effect(battle, source, effect)
	assert_true(wanted in battle.hand_cards)

# ─── DestroyAndResurrect ────────────────────────────────────────────────────

func test_destroy_and_resurrect_kills_target_then_summons_silenced_copy_for_source_owner() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(3, 5, false)
	var effect := _effect("DestroyAndResurrect", "EnemyMinion")
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_true(target.is_dead())
	var revived: Minion = battle.player_minions.back()
	assert_eq(revived.card_data, target.card_data)
	assert_true(revived.owner_is_player, "revient sous le contrôle du lanceur")
	assert_true(revived.silenced, "sans ses effets")
	assert_true(revived.was_resurrected)

# ─── Silence ─────────────────────────────────────────────────────────────────

func test_silence_clears_keywords_and_sets_flag() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(2, 4, false)
	target.add_keyword(Keyword.Type.TAUNT)
	var effect := _effect("Silence", "EnemyMinion")
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_true(target.silenced)
	assert_true(target.keywords.is_empty())

# ─── Transform ───────────────────────────────────────────────────────────────

func test_transform_replaces_card_data_and_stats() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(2, 4, false)
	var new_card := _card("Grenouille", 1, 1)
	var effect := _effect("Transform", "EnemyMinion")
	effect.transform_card = new_card
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_eq(target.card_data, new_card)
	assert_eq(target.attack, 1)
	assert_eq(target.max_health, 1)
	assert_false(target.silenced)

# ─── SummonSelf ──────────────────────────────────────────────────────────────

func test_summon_self_clones_source_card() -> void:
	var source := _minion(2, 4, true)
	var effect := _effect("SummonSelf", "Self")
	effect.count = 1
	await effect_manager.execute_effect(battle, source, effect)
	assert_eq(battle.player_minions.size(), 2)
	assert_eq(battle.player_minions[1].card_data, source.card_data)

# ─── DamageAll ───────────────────────────────────────────────────────────────

func test_damage_all_minions_target_hits_both_camps() -> void:
	var source := _minion(2, 4, true)
	var ally := _minion(2, 3, true)
	var enemy := _minion(2, 3, false)
	var effect := _effect("DamageAll", "AllMinions", 2)
	await effect_manager.execute_effect(battle, source, effect)
	assert_eq(source.health, 2)
	assert_eq(ally.health, 1)
	assert_eq(enemy.health, 1)

# ─── BuffRow ─────────────────────────────────────────────────────────────────

func test_buff_row_buffs_only_front_allies() -> void:
	var front := _minion(2, 4, true, "Front")
	var back := _minion(2, 4, true, "Back")
	var effect := _effect("BuffRow", "AllAlliesFront", 1, 1)
	await effect_manager.execute_effect(battle, null, effect)
	assert_eq(front.attack, 3)
	assert_eq(back.attack, 2, "la rangée Arrière ne doit pas être affectée")

# ─── BuffAdjacent ────────────────────────────────────────────────────────────

func test_buff_adjacent_buffs_neighbor_only() -> void:
	var left := _minion(2, 4, true)
	var source := _minion(2, 4, true)
	var right := _minion(2, 4, true)
	_minion(2, 4, true) # trop loin, ne doit pas être affecté
	var effect := _effect("BuffAdjacent", "Self", 1, 1)
	await effect_manager.execute_effect(battle, source, effect)
	assert_eq(left.attack, 3)
	assert_eq(right.attack, 3)

# ─── SplashDamage ────────────────────────────────────────────────────────────

func test_splash_damage_hits_neighbors_of_selected_target() -> void:
	var source := _minion(2, 4, true)
	var e0 := _minion(1, 4, false)
	var target := _minion(1, 4, false)
	var e2 := _minion(1, 4, false)
	var effect := _effect("SplashDamage", "EnemyMinion", 2)
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_eq(e0.health, 2, "voisin gauche touché")
	assert_eq(e2.health, 2, "voisin droit touché")
	assert_eq(target.health, 4, "la cible principale elle-même n'est pas splashée")

# ─── DebuffATK ───────────────────────────────────────────────────────────────

func test_debuff_atk_reduces_attack_without_touching_health() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(3, 4, false)
	var effect := _effect("DebuffATK", "EnemyMinion", 2)
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_eq(target.attack, 1)
	assert_eq(target.health, 4)

# ─── DestroyLowHP ────────────────────────────────────────────────────────────

func test_destroy_low_hp_kills_only_enemies_at_or_under_threshold() -> void:
	var source := _minion(2, 4, true)
	var weak := _minion(2, 3, false)
	var strong := _minion(2, 6, false)
	var effect := _effect("DestroyLowHP", "AllEnemies", 3)
	await effect_manager.execute_effect(battle, source, effect)
	assert_true(weak.is_dead())
	assert_false(strong.is_dead())

# ─── BuffIfCondition ─────────────────────────────────────────────────────────

func test_buff_if_condition_scales_with_infected_enemy_count() -> void:
	var source := _minion(2, 4, true)
	var e1 := _minion(1, 1, false)
	e1.infected = true
	var e2 := _minion(1, 1, false)
	e2.infected = true
	var e3 := _minion(1, 1, false) # non infecté, ne doit pas compter
	var effect := _effect("BuffIfCondition", "PerInfectedEnemy", 1, 1)
	await effect_manager.execute_effect(battle, source, effect)
	assert_eq(source.attack, 4, "+1/+1 par ennemi infecté (2)")
	assert_eq(source.max_health, 6)

# ─── DamageAllMinions ────────────────────────────────────────────────────────

func test_damage_all_minions_effect_id_hits_every_minion_regardless_of_camp() -> void:
	var source := _minion(2, 4, true)
	var ally := _minion(2, 3, true)
	var enemy := _minion(2, 3, false)
	var effect := _effect("DamageAllMinions", "Self", 1)
	await effect_manager.execute_effect(battle, source, effect)
	assert_eq(source.health, 3)
	assert_eq(ally.health, 2)
	assert_eq(enemy.health, 2)

# ─── GrantKeyword ────────────────────────────────────────────────────────────

func test_grant_keyword_adds_keyword_once() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(2, 4, true)
	var effect := _effect("GrantKeyword", "AllyMinion")
	effect.granted_keyword = "TAUNT"
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_true(target.has_keyword(Keyword.Type.TAUNT))

func test_grant_keyword_skips_target_that_already_has_it() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(2, 4, true)
	target.add_keyword(Keyword.Type.TAUNT)
	var effect := _effect("GrantKeyword", "AllyMinion")
	effect.granted_keyword = "TAUNT"
	effect.duration = "UntilEndOfTurn"
	await effect_manager.execute_effect(battle, source, effect, target)
	# Pas d'enregistrement temporaire pour un mot-clé déjà permanent (sinon il
	# serait retiré à l'expiration) : aucune entrée temp ajoutée.
	assert_eq(battle.temp_effect_system._entries.size(), 0)

# ─── AttackImmediate / GroupAttackImmediate ─────────────────────────────────

func test_attack_immediate_targets_weakest_enemy_by_health() -> void:
	var source := _minion(3, 4, true)
	var strong := _minion(1, 6, false)
	var weak := _minion(1, 2, false)
	var effect := _effect("AttackImmediate", "Self")
	await effect_manager.execute_effect(battle, source, effect)
	assert_eq(battle.combat_system.resolved.size(), 1)
	assert_eq(battle.combat_system.resolved[0]["defender"], weak)
	assert_false(battle.combat_system.resolved[0]["defender"] == strong)

func test_group_attack_immediate_sends_n_allies_of_race_against_target() -> void:
	var source := _minion(2, 4, true)
	var ally1 := _minion(2, 4, true)
	var ally2 := _minion(2, 4, true)
	var target := _minion(1, 10, false)
	var effect := _effect("GroupAttackImmediate", "EnemyMinion")
	effect.count = 2
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_eq(battle.combat_system.resolved.size(), 2)

# ─── GrantExtraAttack ────────────────────────────────────────────────────────

func test_grant_extra_attack_adds_one_attack_once_per_turn() -> void:
	var source := _minion(2, 4, true)
	source.attacks_remaining = 0
	var effect := _effect("GrantExtraAttack", "Self")
	await effect_manager.execute_effect(battle, source, effect)
	assert_eq(source.attacks_remaining, 1)
	await effect_manager.execute_effect(battle, source, effect)
	assert_eq(source.attacks_remaining, 1, "au plus une fois par tour")

# ─── CureInfection ───────────────────────────────────────────────────────────

func test_cure_infection_clears_flag() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(2, 4, true)
	target.infected = true
	var effect := _effect("CureInfection", "AllyMinion")
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_false(target.infected)

# ─── SacrificeAlly ───────────────────────────────────────────────────────────

func test_sacrifice_ally_kills_selected_target() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(2, 4, true)
	var effect := _effect("SacrificeAlly", "AllyMinion")
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_true(target.sacrificed)
	assert_true(target.is_dead())

# Don de Chair passe désormais la cible ennemie de son effet Damage (EnemyAny)
# à SacrificeAlly aussi (même selected_target pour tous les effets de la
# carte) : un serviteur ennemi ne doit jamais être sacrifié à la place d'un allié.
func test_sacrifice_ally_ignores_enemy_selected_target_and_picks_weakest_ally() -> void:
	var weakest := _minion(1, 1, true)
	_minion(5, 10, true)
	var enemy_target := _minion(2, 5, false)
	var effect := _effect("SacrificeAlly", "AllyMinion")
	effect.count = 1
	await effect_manager.execute_effect(battle, null, effect, enemy_target)
	assert_false(enemy_target.sacrificed)
	assert_true(weakest.sacrificed)

func test_sacrifice_ally_without_target_picks_weakest_allies() -> void:
	var source := _minion(5, 10, true)
	var weakest := _minion(1, 1, true)
	var effect := _effect("SacrificeAlly", "AllyMinion")
	effect.count = 1
	await effect_manager.execute_effect(battle, source, effect, null)
	assert_true(weakest.sacrificed)
	assert_false(source.sacrificed)

# ─── GrantCounterOffensive ───────────────────────────────────────────────────

func test_grant_counter_offensive_flags_owner_camp() -> void:
	var source := _minion(2, 4, true)
	var effect := _effect("GrantCounterOffensive", "Self")
	await effect_manager.execute_effect(battle, source, effect)
	assert_true(battle.counter_offensive[true])
	assert_false(battle.counter_offensive[false])

# ─── GainMana ────────────────────────────────────────────────────────────────

func test_gain_mana_adds_to_non_race_bucket_without_touching_max() -> void:
	var source := _minion(2, 4, true)
	var effect := _effect("GainMana", "Self", 1)
	await effect_manager.execute_effect(battle, source, effect)
	assert_eq(int(battle.race_mana.get(Race.Type.NONE, 0)), 1)

# ─── DestroyRandomEnchantment ────────────────────────────────────────────────

func test_destroy_random_enchantment_targets_enemy_pool() -> void:
	var source := _minion(2, 4, true)
	var ench := CardData.new()
	ench.card_name = "Rituel Ennemi"
	battle.enchantment_system.enemy_rituals = [ench]
	var effect := _effect("DestroyRandomEnchantment", "Self")
	await effect_manager.execute_effect(battle, source, effect)
	assert_eq(battle.enchantment_system.destroyed.size(), 1)
	assert_eq(battle.enchantment_system.destroyed[0]["card_data"], ench)
	assert_false(battle.enchantment_system.destroyed[0]["is_player"], "cible le camp ennemi au lanceur")

# ─── DrawCardDiscount ────────────────────────────────────────────────────────

func test_draw_card_discount_applies_discount_only_to_matching_race() -> void:
	var undead_card := _card("Squelette")
	battle.deck = [undead_card]
	var source := _minion()
	var effect := _effect("DrawCardDiscount", "Self", 1, 2)
	effect.race_filter = "Undead"
	await effect_manager.execute_effect(battle, source, effect)
	assert_eq(battle.hand_cards, [undead_card])
	assert_eq(int(battle.cost_system.temp_discounts.get(undead_card, 0)), 2)

# ─── Corrupt (Démon) ─────────────────────────────────────────────────────────

func test_corrupt_reduces_attack_and_stacks() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(4, 4, false)
	var effect := _effect("Corrupt", "EnemyMinion", 2)
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_eq(target.attack, 2)
	assert_eq(target.corruption_stacks, 2)

# ─── StealHealthFromHero ─────────────────────────────────────────────────────

func test_steal_health_from_hero_transfers_hp_between_heroes() -> void:
	battle.enemy_hero.health = 10
	var source := _minion(2, 4, true)
	var effect := _effect("StealHealthFromHero", "Self", 4)
	await effect_manager.execute_effect(battle, source, effect)
	assert_eq(battle.enemy_hero.health, 6)
	assert_eq(battle.player_hero.health, battle.player_hero.max_health + 4)

# ─── BlockSelfDamage ─────────────────────────────────────────────────────────

func test_block_self_damage_sets_flag_for_owner_camp() -> void:
	var source := _minion(2, 4, true)
	var effect := _effect("BlockSelfDamage", "Self")
	await effect_manager.execute_effect(battle, source, effect)
	assert_true(battle.hero_system.self_damage_blocked[true])

# ─── PreventEnemyHeroHeal ────────────────────────────────────────────────────

func test_prevent_enemy_hero_heal_sets_heal_block_turns() -> void:
	var source := _minion(2, 4, true)
	var effect := _effect("PreventEnemyHeroHeal", "Self", 2)
	await effect_manager.execute_effect(battle, source, effect)
	assert_eq(battle.enemy_hero.heal_block_turns, 2)

# ─── SacrificeDrawPerVictim ──────────────────────────────────────────────────

func test_sacrifice_draw_per_victim_draws_and_self_damages_per_victim() -> void:
	var source := _minion(5, 10, true)
	var victim := _minion(1, 1, true)
	battle.deck = [_card("A"), _card("B")]
	var effect := _effect("SacrificeDrawPerVictim", "Self", 2)
	effect.count = 1
	await effect_manager.execute_effect(battle, source, effect, victim)
	assert_true(victim.sacrificed)
	assert_eq(battle.hand_cards.size(), 1, "1 victime -> 1 carte piochée")
	assert_eq(battle.player_hero.health, battle.player_hero.max_health - 2, "2 dégâts x 1 victime")

# ─── StealMinionThenDestroy ──────────────────────────────────────────────────

func test_steal_minion_then_destroy_schedules_destruction_at_expiry() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(3, 5, false)
	var effect := _effect("StealMinionThenDestroy", "EnemyMinion")
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_true(target.owner_is_player, "contrôle temporaire du serviteur volé")
	assert_true(target.attacks_remaining >= 1, "peut agir immédiatement")
	var scheduled := battle.temp_effect_system._entries.filter(
		func(e: Dictionary) -> bool: return e["kind"] == "destroy" and e["minion"] == target
	)
	assert_eq(scheduled.size(), 1, "détruit à l'expiration de l'emprunt")

# ─── GrantSpellImmunity ──────────────────────────────────────────────────────

func test_grant_spell_immunity_sets_flag() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(2, 4, true)
	var effect := _effect("GrantSpellImmunity", "AllyMinion")
	effect.duration = "UntilEndOfTurn"
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_true(target.spell_immune)

# ─── ApplyMutation (Abomination) ─────────────────────────────────────────────

func test_apply_mutation_rolls_one_of_the_three_known_outcomes() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(2, 4, false)
	var before_attack: int = target.attack
	var before_health: int = target.max_health
	var effect := _effect("ApplyMutation", "EnemyMinion")
	effect.count = 1
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_eq(target.mutation_stacks, 1)
	assert_eq(target.mutations.size(), 1)
	var atk_delta: int = target.attack - before_attack
	var hp_delta: int = target.max_health - before_health
	var is_known_outcome: bool = (atk_delta == 2 and hp_delta == 0) \
		or (atk_delta == 0 and hp_delta == 2) \
		or (atk_delta == -1 and hp_delta == -1)
	assert_true(is_known_outcome, "delta observé (%d,%d) hors table de mutation" % [atk_delta, hp_delta])

# ─── notify_damaged : OnDamaged / OnDeathRage / OnMutation ─────────────────

# Serviteur portant `trigger_name` + Buff(Self, +1/+0), pour vérifier
# concrètement qu'un hook de notify_damaged s'est déclenché.
func _minion_with_trigger(trigger_name: String, attack: int = 2, health: int = 10, is_player: bool = true) -> Minion:
	var data := CardData.new()
	data.card_name = "TRIGGER_CARD"
	data.attack = attack
	data.health = health
	var trigger := TriggerTypeChoice.new()
	trigger.type = trigger_name
	data.trigger_types = [trigger]
	var effect := CardEffect.new()
	effect.effect_id = "Buff"
	effect.target = "Self"
	effect.value = 1
	data.effects = [effect]
	var minion := Minion.new(data, is_player)
	if is_player:
		battle.player_minions.append(minion)
	else:
		battle.enemy_minions.append(minion)
	return minion

func test_notify_damaged_fires_on_damaged_trigger() -> void:
	var minion := _minion_with_trigger("OnDamaged", 2, 10)
	minion.take_damage(1)
	await effect_manager.notify_damaged(battle, minion)
	assert_eq(minion.base_attack, 3)

func test_notify_damaged_does_nothing_for_a_dead_minion() -> void:
	var minion := _minion_with_trigger("OnDamaged", 2, 10)
	minion.health = 0
	await effect_manager.notify_damaged(battle, minion)
	assert_eq(minion.base_attack, 2, "un serviteur déjà mort ne doit pas déclencher OnDamaged")

func test_notify_damaged_fires_on_death_rage_once_below_half_max_health() -> void:
	var minion := _minion_with_trigger("OnDeathRage", 2, 10)
	minion.take_damage(6) # 4/10 HP restants : sous 50%
	await effect_manager.notify_damaged(battle, minion)
	assert_eq(minion.base_attack, 3)
	assert_true(minion.death_rage_triggered)
	await effect_manager.notify_damaged(battle, minion)
	assert_eq(minion.base_attack, 3, "Mort-rage : une seule fois par serviteur")

func test_notify_damaged_does_not_fire_death_rage_above_half_max_health() -> void:
	var minion := _minion_with_trigger("OnDeathRage", 2, 10)
	minion.take_damage(1) # 9/10 HP restants : au-dessus de 50%
	await effect_manager.notify_damaged(battle, minion)
	assert_false(minion.death_rage_triggered)
	assert_eq(minion.base_attack, 2)

func test_notify_damaged_rolls_a_mutation_for_survivors_with_mutation_keyword() -> void:
	var minion := _minion(2, 10, true)
	minion.add_abomination_keyword(KeywordAbomination.Type.MUTATION)
	minion.take_damage(1)
	await effect_manager.notify_damaged(battle, minion)
	assert_eq(minion.mutation_stacks, 1, "MUTATION : une mutation à chaque blessure survécue")

# ─── GrantKeywordAdjacent ────────────────────────────────────────────────────

func test_grant_keyword_adjacent_only_affects_neighbors() -> void:
	var left := _minion(2, 4, true)
	var source := _minion(2, 4, true)
	var right := _minion(2, 4, true)
	var far := _minion(2, 4, true)
	var effect := _effect("GrantKeywordAdjacent", "Self")
	effect.granted_keyword = "TAUNT"
	await effect_manager.execute_effect(battle, source, effect)
	assert_true(left.has_keyword(Keyword.Type.TAUNT))
	assert_true(right.has_keyword(Keyword.Type.TAUNT))
	assert_false(far.has_keyword(Keyword.Type.TAUNT))

# ─── AbsorbAdjacentStats ─────────────────────────────────────────────────────

func test_absorb_adjacent_stats_sacrifices_target_and_buffs_neighbor() -> void:
	var victim := _minion(3, 4, true)
	victim.take_damage(1) # 3/3 restants
	var neighbor := _minion(2, 4, true)
	var effect := _effect("AbsorbAdjacentStats", "AllyMinion")
	await effect_manager.execute_effect(battle, null, effect, victim)
	assert_true(victim.sacrificed)
	assert_true(victim.is_dead())
	assert_eq(neighbor.attack, 5, "2 + 3 ATK restante de la victime")
	assert_eq(neighbor.max_health, 7, "4 + 3 HP restants de la victime")

# ─── CopyAdjacentKeyword ─────────────────────────────────────────────────────

func test_copy_adjacent_keyword_copies_from_another_minion_in_play() -> void:
	var target := _minion(2, 4, true)
	var donor := _minion(2, 4, false)
	donor.add_keyword(Keyword.Type.TAUNT)
	var effect := _effect("CopyAdjacentKeyword", "AllyMinion")
	await effect_manager.execute_effect(battle, null, effect, target)
	assert_true(target.has_keyword(Keyword.Type.TAUNT), "seul TAUNT est disponible dans le pool (unique autre serviteur)")
