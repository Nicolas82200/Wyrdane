extends GutTest

# Couvre CardSystem (scripts/systems/CardSystem.gd), la partie testable sans
# dépendance de scène : conditions_met (jouabilité d'un sort : cimetière vide,
# alliés insuffisants pour un sacrifice, aucune cible valide) et
# _remove_from_hand. handle_card_played/play_card/resolve_with_target/_resolve
# orchestrent une douzaine d'appels UI (popup, layout de main, tutoriel...) non
# stubés dans FakeBattle et sont laissés hors scope ici. Utilise FakeBattle
# (tests/unit/doubles/fake_battle.gd), conformément à la convention GUT du
# projet (voir CLAUDE.md).

var card_system: CardSystem
var battle: FakeBattle

func before_each() -> void:
	card_system = load("res://scripts/systems/CardSystem.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()
	card_system.init(battle)

func after_each() -> void:
	card_system.free()

func _minion_card() -> CardData:
	var data := CardData.new()
	data.card_name = "TEST_MINION"
	data.card_type = "Minion"
	data.attack = 1
	data.health = 1
	return data

func _spell_with_effect(effect_id: String, count: int = 1) -> CardData:
	var data := CardData.new()
	data.card_name = "TEST_SPELL"
	data.card_type = "Instant"
	var effect := CardEffect.new()
	effect.effect_id = effect_id
	effect.count = count
	data.effects = [effect]
	return data

# ─── conditions_met ─────────────────────────────────────────────────────────────

func test_conditions_met_false_for_null_card() -> void:
	assert_false(card_system.conditions_met(null))

func test_conditions_met_always_true_for_minions() -> void:
	var card := _minion_card()
	card.requires_target = true
	battle.targeting_system.has_valid_target = false
	assert_true(card_system.conditions_met(card), "un serviteur n'est jamais bloqué par conditions_met (géré à la pose)")

func test_conditions_met_false_when_requires_target_and_none_available() -> void:
	var card := CardData.new()
	card.card_type = "Instant"
	card.requires_target = true
	battle.targeting_system.has_valid_target = false
	assert_false(card_system.conditions_met(card))

func test_conditions_met_true_when_requires_target_and_one_available() -> void:
	var card := CardData.new()
	card.card_type = "Instant"
	card.requires_target = true
	battle.targeting_system.has_valid_target = true
	assert_true(card_system.conditions_met(card))

func test_conditions_met_false_for_resurrect_with_empty_graveyard() -> void:
	var card := _spell_with_effect("Resurrect")
	assert_false(card_system.conditions_met(card))

func test_conditions_met_true_for_resurrect_with_a_minion_in_graveyard() -> void:
	var card := _spell_with_effect("Resurrect")
	battle.player_graveyard.add_minion(CardData.new())
	assert_true(card_system.conditions_met(card))

func test_conditions_met_false_for_resurrect_last_with_empty_graveyard() -> void:
	var card := _spell_with_effect("ResurrectLast")
	assert_false(card_system.conditions_met(card))

func test_conditions_met_false_for_return_from_grave_with_empty_graveyard() -> void:
	var card := _spell_with_effect("ReturnFromGrave")
	assert_false(card_system.conditions_met(card))

func test_conditions_met_false_for_sacrifice_ally_without_enough_allies() -> void:
	var card := _spell_with_effect("SacrificeAlly", 2)
	var data := CardData.new()
	battle.player_minions.append(Minion.new(data, true))
	assert_false(card_system.conditions_met(card), "1 allié en jeu, sacrifice de 2 exigé")

func test_conditions_met_true_for_sacrifice_ally_with_enough_allies() -> void:
	var card := _spell_with_effect("SacrificeAlly", 2)
	var data := CardData.new()
	battle.player_minions.append(Minion.new(data, true))
	battle.player_minions.append(Minion.new(data, true))
	assert_true(card_system.conditions_met(card))

func test_conditions_met_true_for_spell_without_special_conditions() -> void:
	var card := CardData.new()
	card.card_type = "Instant"
	assert_true(card_system.conditions_met(card))

# ─── _remove_from_hand ──────────────────────────────────────────────────────────

func test_remove_from_hand_erases_matching_card() -> void:
	var card := _minion_card()
	battle.hand_cards = [card]
	card_system._remove_from_hand(card)
	assert_eq(battle.hand_cards.size(), 0)

func test_remove_from_hand_does_nothing_if_card_absent() -> void:
	var card := _minion_card()
	var other := _minion_card()
	battle.hand_cards = [other]
	card_system._remove_from_hand(card)
	assert_eq(battle.hand_cards.size(), 1, "aucune carte ne correspond : la main ne doit pas changer")
