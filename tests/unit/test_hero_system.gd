extends GutTest

# Couvre HeroSystem (scripts/systems/HeroSystem.gd) : damage(), self_damage()
# (garde-fou, blocages, réduction), _on_self_damage_dealt() (SANG NOIR,
# OnSelfDamage) et update_ui(). Utilise FakeBattle (tests/unit/doubles/
# fake_battle.gd), conformément à la convention GUT du projet (voir
# CLAUDE.md). Attention : FakeBattle expose déjà un `hero_system` interne
# (FakeBattle.FakeHeroSystem, utilisé par les tests EffectManager) — ce
# fichier teste le VRAI HeroSystem.gd, chargé et instancié séparément.

var hero_system: HeroSystem
var battle: FakeBattle

func before_each() -> void:
	hero_system = load("res://scripts/systems/HeroSystem.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()
	hero_system.init(battle)

func _minion(is_player: bool = true, demon_kw: int = -1) -> Minion:
	var data := CardData.new()
	data.card_name = "TEST_CARD"
	data.race = Race.Type.DEMON
	data.attack = 2
	data.health = 4
	if demon_kw != -1:
		var kw := KeywordChoiceDemon.new()
		kw.keyword_type = demon_kw
		data.demon_keywords = [kw]
	var minion := Minion.new(data, is_player)
	if is_player:
		battle.player_minions.append(minion)
	else:
		battle.enemy_minions.append(minion)
	return minion

# ─── damage() ───────────────────────────────────────────────────────────────

func test_damage_reduces_hero_health() -> void:
	await hero_system.damage(battle.player_hero, 5)
	assert_eq(battle.player_hero.health, 25)

func test_damage_updates_ui_label_without_crashing() -> void:
	await hero_system.damage(battle.player_hero, 5)
	assert_eq(battle._player_health_label.text, "25")

func test_damage_to_zero_does_not_crash() -> void:
	await hero_system.damage(battle.enemy_hero, 30)
	assert_eq(battle.enemy_hero.health, 0)
	assert_eq(battle._enemy_health_label.text, "0")

# ─── self_damage() ──────────────────────────────────────────────────────────

func test_self_damage_reduces_health_and_returns_dealt_amount() -> void:
	var dealt: int = await hero_system.self_damage(true, 5)
	assert_eq(dealt, 5)
	assert_eq(battle.player_hero.health, 25)

func test_self_damage_never_drops_hero_below_one_hp() -> void:
	battle.player_hero.health = 3
	var dealt: int = await hero_system.self_damage(true, 10)
	assert_eq(dealt, 2, "garde-fou : jamais sous 1 HP")
	assert_eq(battle.player_hero.health, 1)

func test_self_damage_blocked_by_blocks_self_damage_card() -> void:
	var guardian := _minion(true)
	guardian.card_data.blocks_self_damage = true
	var dealt: int = await hero_system.self_damage(true, 5)
	assert_eq(dealt, 0)
	assert_eq(battle.player_hero.health, 30)

func test_self_damage_blocked_for_this_turn() -> void:
	hero_system.self_damage_blocked[true] = true
	var dealt: int = await hero_system.self_damage(true, 5)
	assert_eq(dealt, 0)
	assert_eq(battle.player_hero.health, 30)

func test_self_damage_reduction_lowers_amount() -> void:
	hero_system.self_damage_reduction[true] = 2
	var dealt: int = await hero_system.self_damage(true, 5)
	assert_eq(dealt, 3, "Sceau de Préservation : -N par occurrence")

func test_self_damage_reduction_clamped_to_zero() -> void:
	hero_system.self_damage_reduction[true] = 10
	var dealt: int = await hero_system.self_damage(true, 5)
	assert_eq(dealt, 0)
	assert_eq(battle.player_hero.health, 30)

func test_self_damage_with_non_positive_amount_returns_zero() -> void:
	var dealt: int = await hero_system.self_damage(true, 0)
	assert_eq(dealt, 0)
	assert_eq(battle.player_hero.health, 30)

# ─── _on_self_damage_dealt() (via self_damage) ──────────────────────────────

func test_sang_noir_ally_gains_attack_on_self_damage() -> void:
	var minion := _minion(true, KeywordDemon.Type.SANG_NOIR)
	await hero_system.self_damage(true, 3)
	assert_eq(minion.base_attack, 3, "SANG NOIR : +1 ATK permanent après une perte de HP auto-infligée")

func test_sang_noir_on_other_camp_is_not_affected() -> void:
	var minion := _minion(false, KeywordDemon.Type.SANG_NOIR)
	await hero_system.self_damage(true, 3)
	assert_eq(minion.base_attack, 2, "SANG NOIR d'un autre camp ne doit pas réagir")

func test_self_damage_does_not_crash_with_no_sang_noir_minions() -> void:
	await hero_system.self_damage(true, 3)
	assert_eq(battle.player_hero.health, 27)

func test_self_damage_fires_on_self_damage_trigger_for_owner_camp() -> void:
	await hero_system.self_damage(true, 3)
	var calls: Array = battle.trigger_system.fired_calls.filter(
		func(c: Dictionary) -> bool: return c["trigger_name"] == "OnSelfDamage"
	)
	assert_eq(calls.size(), 1, "les dégâts auto-infligés doivent déclencher OnSelfDamage (Autel de la Souffrance)")
	assert_true(calls[0]["is_player"])

func test_self_damage_does_not_fire_on_self_damage_trigger_when_zero_dealt() -> void:
	hero_system.self_damage_blocked[true] = true
	await hero_system.self_damage(true, 3)
	var calls: Array = battle.trigger_system.fired_calls.filter(
		func(c: Dictionary) -> bool: return c["trigger_name"] == "OnSelfDamage"
	)
	assert_eq(calls.size(), 0, "aucun dégât réellement infligé : pas de déclenchement")

# ─── update_ui() ────────────────────────────────────────────────────────────

func test_update_ui_reflects_current_health() -> void:
	battle.player_hero.health = 12
	battle.enemy_hero.health = 8
	hero_system.update_ui()
	assert_eq(battle._player_health_label.text, "12")
	assert_eq(battle._enemy_health_label.text, "8")

func test_update_ui_clamps_negative_health_to_zero() -> void:
	battle.player_hero.health = -5
	hero_system.update_ui()
	assert_eq(battle._player_health_label.text, "0")
