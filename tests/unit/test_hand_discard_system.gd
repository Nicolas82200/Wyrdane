extends GutTest

# Couvre HandDiscardSystem (scripts/systems/HandDiscardSystem.gd) : limite de
# 10 cartes en main en fin de tour. Teste directement la logique de sélection/
# confirmation/timeout (_on_card_clicked, _on_timeout, _confirm) plutôt que
# run_if_needed() dans son ensemble, qui dépend de TurnTimer/turn_banner/
# add_child (nœuds réels) et d'une boucle await get_tree().process_frame —
# hors du périmètre visé par ces tests unitaires (voir convention dans
# test_turn_system.gd).

var system: HandDiscardSystem
var battle: FakeBattle

func before_each() -> void:
	system = load("res://scripts/systems/HandDiscardSystem.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()
	system.init(battle)

func _make_card(name: String) -> CardData:
	var data := CardData.new()
	data.card_name = name
	return data

func _fill_hand(count: int) -> void:
	battle.hand_cards.clear()
	for i in range(count):
		battle.hand_cards.append(_make_card("CARD_%d" % i))

func test_click_selects_card() -> void:
	_fill_hand(11)
	system._required = 1
	system._on_card_clicked(2, battle.hand_cards[2])
	assert_eq(system._selected_indices, [2])
	assert_true(battle.hand.discard_selected.get(2, false))

func test_click_again_deselects_card() -> void:
	_fill_hand(12)
	system._required = 2
	system._on_card_clicked(2, battle.hand_cards[2])
	system._on_card_clicked(2, battle.hand_cards[2])
	assert_eq(system._selected_indices, [])
	assert_false(battle.hand.discard_selected.get(2, true))

func test_confirm_fires_once_required_selections_reached() -> void:
	_fill_hand(11)
	system._required = 1
	system._on_card_clicked(5, battle.hand_cards[5])
	assert_true(system._resolved, "la sélection du nombre requis doit confirmer immédiatement")

func test_confirm_removes_selected_cards_from_hand_and_graveyard_gets_them() -> void:
	_fill_hand(12)
	var discarded_card: CardData = battle.hand_cards[3]
	system._required = 2
	system._on_card_clicked(3, battle.hand_cards[3])
	system._on_card_clicked(7, battle.hand_cards[7])
	assert_eq(battle.hand_cards.size(), 10, "la main doit revenir exactement à 10")
	assert_eq(battle.player_graveyard.size(), 2)
	assert_true(battle.player_graveyard.is_face_down(battle.player_graveyard.entries[0]),
		"une carte défaussée doit être face cachée au cimetière")
	assert_false(battle.hand_cards.has(discarded_card), "la carte défaussée ne doit plus être en main")

func test_confirm_emits_net_discard_command_with_count() -> void:
	_fill_hand(11)
	battle.net_emitter = load("res://tests/unit/doubles/fake_battle.gd").FakeNetEmitter.new()
	system._required = 1
	system._on_card_clicked(0, battle.hand_cards[0])
	assert_eq(battle.net_emitter.discard_calls, [1])

func test_timeout_fills_remaining_selection_randomly_and_confirms() -> void:
	_fill_hand(13)
	system._required = 3
	system._on_card_clicked(0, battle.hand_cards[0])  # 1 carte déjà choisie manuellement
	system._on_timeout()
	assert_true(system._resolved)
	assert_eq(battle.hand_cards.size(), 10)
	assert_eq(battle.player_graveyard.size(), 3)

func test_timeout_does_nothing_if_already_resolved() -> void:
	_fill_hand(11)
	system._required = 1
	system._on_card_clicked(0, battle.hand_cards[0])
	var count_after_confirm: int = battle.player_graveyard.size()
	system._on_timeout()
	assert_eq(battle.player_graveyard.size(), count_after_confirm, "un timeout après confirmation ne doit rien changer")
