extends GutTest

# Couvre PactActivationSystem (scripts/systems/PactActivationSystem.gd) :
# activation manuelle du bonus de Pacte "standalone" (CardData.pact_standalone,
# ex. Larve Infernale) — can_activate() et le cœur rejouable
# apply_pact_activation() (aussi rejoué côté réseau via NetworkOpponent).
# try_activate() (popup Oui/Non via PactChoiceSystem.ask) est hors scope, comme
# FusionSystem.try_begin/_execute (voir test_fusion_system.gd).

var system: PactActivationSystem
var battle: FakeBattle

func before_each() -> void:
	system = load("res://scripts/systems/PactActivationSystem.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()
	system.init(battle)

func after_each() -> void:
	system.free()

func _standalone_minion(pact_value: int = 1, is_player: bool = true) -> Minion:
	var data := CardData.new()
	data.card_name = "TEST_STANDALONE_PACT"
	data.attack = 2
	data.health = 1
	data.pact_standalone = true
	var kw := KeywordChoiceDemon.new()
	kw.keyword_type = KeywordDemon.Type.PACTE
	kw.value = pact_value
	data.demon_keywords = [kw]
	var effect := CardEffect.new()
	effect.effect_id = "Buff"
	effect.target = "Self"
	effect.duration = "Permanent"
	effect.value = 1
	effect.value_2 = 1
	effect.pact_bonus = true
	data.effects = [effect]
	var minion := Minion.new(data, is_player)
	if is_player:
		battle.player_minions.append(minion)
	else:
		battle.enemy_minions.append(minion)
	return minion

# ─── can_activate ─────────────────────────────────────────────────────────────

func test_can_activate_true_for_fresh_standalone_pact_minion() -> void:
	var minion := _standalone_minion()
	assert_true(system.can_activate(minion))

func test_can_activate_false_once_already_activated() -> void:
	var minion := _standalone_minion()
	minion.pact_activated = true
	assert_false(system.can_activate(minion))

func test_can_activate_false_for_enemy_minion() -> void:
	var minion := _standalone_minion(1, false)
	assert_false(system.can_activate(minion))

func test_can_activate_false_for_non_standalone_card() -> void:
	var minion := _standalone_minion()
	minion.card_data.pact_standalone = false
	assert_false(system.can_activate(minion))

func test_can_activate_false_for_dead_minion() -> void:
	var minion := _standalone_minion()
	minion.health = 0
	assert_false(system.can_activate(minion))

func test_can_activate_false_during_enemy_turn() -> void:
	var minion := _standalone_minion()
	battle.enemy_turn_active = true
	assert_false(system.can_activate(minion))

# ─── apply_pact_activation (cœur rejouable) ──────────────────────────────────

func test_apply_pact_activation_applies_effect_and_marks_activated() -> void:
	var minion := _standalone_minion()
	var effect: CardEffect = minion.card_data.effects[0]
	await system.apply_pact_activation(minion, effect, 1)
	assert_true(minion.pact_activated)
	assert_eq(minion.base_attack, 3, "+1/+1 doit s'appliquer une fois payé")
	assert_eq(minion.base_max_health, 2)

func test_apply_pact_activation_deals_self_damage_equal_to_pact_value() -> void:
	var minion := _standalone_minion(3)
	var effect: CardEffect = minion.card_data.effects[0]
	var hero_before: int = battle.player_hero.health
	await system.apply_pact_activation(minion, effect, 3)
	assert_eq(battle.player_hero.health, hero_before - 3)

func test_apply_pact_activation_is_noop_if_already_activated() -> void:
	var minion := _standalone_minion()
	minion.pact_activated = true
	var effect: CardEffect = minion.card_data.effects[0]
	var hero_before: int = battle.player_hero.health
	await system.apply_pact_activation(minion, effect, 1)
	assert_eq(minion.base_attack, 2, "aucun effet supplémentaire si déjà activé")
	assert_eq(battle.player_hero.health, hero_before, "aucun dégât auto-infligé supplémentaire")

# ─── EffectManager.trigger_effects : jamais proposé automatiquement ──────────

func test_onplay_trigger_never_offers_standalone_pact_bonus() -> void:
	var minion := _standalone_minion()
	var trig := TriggerTypeChoice.new()
	trig.type = "ONPLAY"
	minion.card_data.trigger_types = [trig]
	var effect_manager := EffectManager.new()
	await effect_manager.trigger_effects(battle, minion, "ONPLAY")
	assert_false(minion.pact_activated, "l'Arrivée ne doit jamais activer un Pacte standalone")
	assert_eq(minion.base_attack, 2, "aucun buff appliqué automatiquement à l'Arrivée")
