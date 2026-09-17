extends GutTest

# Couvre SelectionSystem (scripts/systems/SelectionSystem.gd), la seule partie
# testable sans un vrai visuel BoardMinion (les clics de sélection appellent
# `board_minion.set_selected(...)`, typé BoardMinion — hors scope GUT, voir
# CLAUDE.md) : le tri des attaquants multi-sélectionnés selon leur position
# sur le plateau (_sort_attackers_left_to_right), qui détermine l'ordre de
# résolution d'une multi-attaque. Utilise FakeBattle
# (tests/unit/doubles/fake_battle.gd), conformément à la convention GUT du
# projet (voir CLAUDE.md).

var selection_system: SelectionSystem
var battle: FakeBattle

func before_each() -> void:
	selection_system = load("res://scripts/systems/SelectionSystem.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()
	selection_system.init(battle)

func after_each() -> void:
	selection_system.free()

func _minion() -> Minion:
	var data := CardData.new()
	data.card_name = "TEST_ATTACKER"
	var minion := Minion.new(data, true)
	battle.player_minions.append(minion)
	return minion

func test_sort_attackers_left_to_right_matches_board_order() -> void:
	var first := _minion()
	var second := _minion()
	var third := _minion()
	var unsorted: Array[Minion] = [third, first, second]
	var sorted := selection_system._sort_attackers_left_to_right(unsorted)
	assert_eq(sorted, [first, second, third])

func test_sort_attackers_left_to_right_does_not_mutate_input_array() -> void:
	var first := _minion()
	var second := _minion()
	var unsorted: Array[Minion] = [second, first]
	selection_system._sort_attackers_left_to_right(unsorted)
	assert_eq(unsorted, [second, first], "le tableau d'origine ne doit pas être modifié en place")

func test_sort_attackers_left_to_right_handles_single_attacker() -> void:
	var only := _minion()
	var sorted := selection_system._sort_attackers_left_to_right([only])
	assert_eq(sorted, [only])
