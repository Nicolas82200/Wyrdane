extends GutTest

func _make_minion() -> Minion:
	var data := CardData.new()
	data.card_name = "TEST_CARD"
	data.attack = 1
	data.health = 1
	return Minion.new(data)

func test_add_to_hand_fills_hand_before_suspending() -> void:
	var player := ArenaPlayerState.new("Test")
	for i in ArenaConstants.HAND_MAX:
		player.add_to_hand(_make_minion())
	assert_eq(player.hand.size(), ArenaConstants.HAND_MAX)
	assert_true(player.suspended.is_empty())

func test_add_to_hand_suspends_when_full() -> void:
	var player := ArenaPlayerState.new("Test")
	for i in ArenaConstants.HAND_MAX:
		player.add_to_hand(_make_minion())
	var overflow := _make_minion()
	player.add_to_hand(overflow)
	assert_true(player.suspended.has(overflow))
	assert_false(player.hand.has(overflow))

func test_removing_from_hand_releases_a_suspended_card() -> void:
	var player := ArenaPlayerState.new("Test")
	for i in ArenaConstants.HAND_MAX:
		player.add_to_hand(_make_minion())
	var overflow := _make_minion()
	player.add_to_hand(overflow)
	var freed := player.hand[0]
	player.remove_from_hand(freed)
	assert_true(player.hand.has(overflow), "une place libérée doit accueillir automatiquement la carte suspendue")
	assert_false(player.suspended.has(overflow))

func test_place_on_board_respects_row_max() -> void:
	var player := ArenaPlayerState.new("Test")
	for i in ArenaConstants.BOARD_ROW_MAX:
		var m := _make_minion()
		player.hand.append(m)
		assert_true(player.place_on_board(m, true))
	var overflow := _make_minion()
	player.hand.append(overflow)
	assert_false(player.place_on_board(overflow, true), "la rangée Avant est pleine à 10")

func test_discard_overflow_returns_to_hand_max() -> void:
	var player := ArenaPlayerState.new("Test")
	for i in ArenaConstants.HAND_MAX + 3:
		player.hand.append(_make_minion())
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var discarded := player.discard_overflow(rng)
	assert_eq(discarded.size(), 3)
	assert_eq(player.hand_count(), ArenaConstants.HAND_MAX)

func test_reset_after_combat_clears_damage_not_permanent_stats() -> void:
	var player := ArenaPlayerState.new("Test")
	var m := _make_minion()
	m.base_attack = 5
	m.base_max_health = 5
	m.take_damage(3)
	player.board_front.append(m)
	player.reset_after_combat()
	assert_eq(m.damage_taken, 0)
	assert_eq(m.base_attack, 5)
	assert_eq(m.base_max_health, 5)
