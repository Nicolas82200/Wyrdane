extends GutTest

func _make_card(name: String, cost: int, path: String) -> CardData:
	var data := CardData.new()
	data.card_name = name
	data.cost = cost
	data.rarity = "Common"
	data.card_type = "Minion"
	data.resource_path = path
	return data

func _make_match(cards: Array[CardData]) -> ArenaMatch:
	var pool := ArenaCardPool.new(cards)
	var players: Array[ArenaPlayerState] = [ArenaPlayerState.new("Player")]
	var m := ArenaMatch.new(players, pool)
	m.players[0].shop_offer = [cards[0], null, null, null, null]
	m.players[0].shop_locked = [false, false, false, false, false]
	return m

func test_buy_card_spends_gold_and_takes_from_pool() -> void:
	var card := _make_card("C1", 2, "res://fake/shop_c1.tres")
	var m := _make_match([card])
	var player := m.players[0]
	player.gold = 5
	var copies_before: int = m.pool.copies_remaining(card)
	assert_true(m.buy_card(player, 0))
	assert_eq(player.gold, 3)
	assert_eq(m.pool.copies_remaining(card), copies_before - 1)
	assert_eq(player.hand.size(), 1)
	assert_null(player.shop_offer[0])

func test_buy_card_fails_without_enough_gold() -> void:
	var card := _make_card("Costly", 8, "res://fake/shop_costly.tres")
	var m := _make_match([card])
	var player := m.players[0]
	player.gold = 1
	assert_false(m.buy_card(player, 0))
	assert_eq(player.hand.size(), 0)

func test_sell_from_hand_refunds_full_price() -> void:
	var card := _make_card("C1", 4, "res://fake/shop_sellhand.tres")
	var m := _make_match([card])
	var player := m.players[0]
	player.gold = 4
	m.buy_card(player, 0)
	var minion: Minion = player.hand[0]
	m.sell_card(player, minion, false)
	assert_eq(player.gold, 4, "vente depuis la main = remboursement 100%")

func test_sell_from_board_refunds_half_price() -> void:
	var card := _make_card("C1", 4, "res://fake/shop_sellboard.tres")
	var m := _make_match([card])
	var player := m.players[0]
	player.gold = 4
	m.buy_card(player, 0)
	var minion: Minion = player.hand[0]
	player.place_on_board(minion, true)
	m.sell_card(player, minion, true)
	assert_eq(player.gold, 2, "vente depuis le plateau = remboursement 50%")

func test_hand_overflow_is_discarded_at_end_of_shop_phase() -> void:
	var card := _make_card("Filler", 1, "res://fake/shop_filler.tres")
	var m := _make_match([card])
	var player := m.players[0]
	for i in ArenaConstants.HAND_MAX + 2:
		player.hand.append(Minion.new(card))
	m.end_shop_phase()
	assert_eq(player.hand_count(), ArenaConstants.HAND_MAX)
