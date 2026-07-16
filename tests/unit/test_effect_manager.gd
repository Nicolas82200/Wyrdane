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
