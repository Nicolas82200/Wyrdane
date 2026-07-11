extends GutTest

# Couvre CostSystem (scripts/systems/CostSystem.gd) : remises temporaires,
# auras de coût, et suivi des serviteurs joués par tour/race.

var cost_system: CostSystem
var battle: FakeBattle

func before_each() -> void:
	cost_system = load("res://scripts/systems/CostSystem.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()
	cost_system.init(battle)

func _card(cost: int, card_type: String = "Minion", race: int = Race.Type.NONE) -> CardData:
	var data := CardData.new()
	data.card_name = "TEST_CARD"
	data.cost = cost
	data.card_type = card_type
	data.race = race
	return data

func _enchantment(effect_id: String, value: int, race_filter: String = "") -> CardData:
	var data := _card(3, "Enchantment")
	var trigger := TriggerTypeChoice.new()
	trigger.type = "OnAura"
	data.trigger_types = [trigger]
	var effect := CardEffect.new()
	effect.effect_id = effect_id
	effect.value = value
	effect.race_filter = race_filter
	data.effects = [effect]
	return data

func test_get_cost_returns_base_cost_with_no_modifiers() -> void:
	var card := _card(4)
	assert_eq(cost_system.get_cost(card, true), 4)

func test_get_cost_null_card_is_zero() -> void:
	assert_eq(cost_system.get_cost(null, true), 0)

func test_temp_discount_reduces_cost_and_can_reach_zero() -> void:
	var card := _card(2)
	cost_system.add_temp_discount(card, 5)
	assert_eq(cost_system.get_cost(card, true), 0, "les remises temporaires peuvent descendre le coût à 0")

func test_temp_discount_is_per_card_instance() -> void:
	var card_a := _card(3)
	var card_b := _card(3)
	cost_system.add_temp_discount(card_a, 1)
	assert_eq(cost_system.get_cost(card_a, true), 2)
	assert_eq(cost_system.get_cost(card_b, true), 3)

func test_on_card_played_clears_temp_discount() -> void:
	var card := _card(3)
	cost_system.add_temp_discount(card, 2)
	cost_system.on_card_played(card, true)
	assert_eq(cost_system.get_cost(card, true), 3, "la remise ne doit s'appliquer qu'une fois, jusqu'à ce que la carte soit jouée")

func test_expire_end_of_player_turn_clears_all_discounts() -> void:
	var card := _card(3)
	cost_system.add_temp_discount(card, 2)
	cost_system.expire_end_of_player_turn()
	assert_eq(cost_system.get_cost(card, true), 3)

func test_aura_spell_cost_reduction_applies_to_spells_only() -> void:
	var enchant := _enchantment("AuraSpellCostReduction", 1)
	battle.trigger_system.active_enchantments[true] = [{"card_data": enchant}]
	var spell := _card(3, "Instant")
	var minion := _card(3, "Minion")
	assert_eq(cost_system.get_cost(spell, true), 2, "AuraSpellCostReduction doit réduire le coût d'un sort")
	assert_eq(cost_system.get_cost(minion, true), 3, "AuraSpellCostReduction ne doit pas réduire le coût d'un serviteur")

func test_aura_cost_reduction_never_drops_below_one() -> void:
	var enchant := _enchantment("AuraSpellCostReduction", 5)
	battle.trigger_system.active_enchantments[true] = [{"card_data": enchant}]
	var spell := _card(2, "Instant")
	assert_eq(cost_system.get_cost(spell, true), 1, "une aura de coût ne rend jamais une carte gratuite")

func test_aura_first_of_race_cost_reduction_only_first_of_turn() -> void:
	var enchant := _enchantment("AuraFirstOfRaceCostReduction", 1, "Undead")
	battle.trigger_system.active_enchantments[true] = [{"card_data": enchant}]
	var undead_minion := _card(4, "Minion", Race.Type.UNDEAD)
	assert_eq(cost_system.get_cost(undead_minion, true), 3, "le premier Mort-Vivant du tour bénéficie de la réduction")
	cost_system.on_card_played(undead_minion, true)
	var second_undead := _card(4, "Minion", Race.Type.UNDEAD)
	assert_eq(cost_system.get_cost(second_undead, true), 4, "un deuxième Mort-Vivant le même tour ne bénéficie plus de la réduction")

func test_on_turn_started_resets_first_of_race_tracking() -> void:
	var enchant := _enchantment("AuraFirstOfRaceCostReduction", 1, "Undead")
	battle.trigger_system.active_enchantments[true] = [{"card_data": enchant}]
	var first := _card(4, "Minion", Race.Type.UNDEAD)
	cost_system.on_card_played(first, true)
	cost_system.on_turn_started(true)
	var next_turn_undead := _card(4, "Minion", Race.Type.UNDEAD)
	assert_eq(cost_system.get_cost(next_turn_undead, true), 3, "le compteur repart à zéro au tour suivant")
