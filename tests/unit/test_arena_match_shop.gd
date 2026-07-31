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

func test_buy_card_fails_when_another_player_already_took_the_last_copy() -> void:
	# draw_card() (voir _refresh_shop_offer) ne réserve rien : à 8 joueurs, la
	# même copie rare peut apparaître dans plusieurs boutiques la même
	# manche. Le premier acheteur doit vider vraiment le pool, et un second
	# acheteur voyant encore la même carte dans SA propre offre ne doit pas
	# pouvoir l'obtenir quand même.
	var card := _make_card("Rare1Copy", 2, "res://fake/shop_contested.tres")
	var pool := ArenaCardPool.new([card])
	var p1 := ArenaPlayerState.new("P1")
	var p2 := ArenaPlayerState.new("P2")
	p1.gold = 5
	p2.gold = 5
	var players: Array[ArenaPlayerState] = [p1, p2]
	var m := ArenaMatch.new(players, pool)
	# Une seule copie dans le pool, offerte aux deux joueurs simultanément.
	for i in m.pool.copies_remaining(card) - 1:
		m.pool.take(card)
	assert_eq(m.pool.copies_remaining(card), 1)
	p1.shop_offer = [card, null, null, null, null]
	p2.shop_offer = [card, null, null, null, null]

	assert_true(m.buy_card(p1, 0), "le premier acheteur doit obtenir la dernière copie")
	assert_eq(m.pool.copies_remaining(card), 0)
	assert_false(m.buy_card(p2, 0), "un second acheteur ne doit pas obtenir une copie qui n'existe plus")
	assert_eq(p2.hand.size(), 0, "P2 ne doit pas recevoir la carte")
	assert_null(p2.shop_offer[0], "l'offre devenue indisponible doit être vidée plutôt que de rester bloquée")

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

func test_selling_a_merged_2_star_card_returns_all_3_base_copies_to_the_pool() -> void:
	# README « Upgrade de cartes » : vendre une 2★ rend les 3 exemplaires de
	# base l'ayant constituée, comme avant la fusion — pas une seule copie.
	var card := _make_card("Merged", 2, "res://fake/shop_merged_2star.tres")
	var m := _make_match([card])
	var player := m.players[0]
	for i in 3:
		m.pool.take(card)
	var copies_before: int = m.pool.copies_remaining(card)
	var merged := Minion.new(card, true, "Front")
	merged.star_level = 2
	player.hand.append(merged)
	m.sell_card(player, merged, false)
	assert_eq(m.pool.copies_remaining(card), copies_before + 3,
		"vendre une 2★ doit rendre 3 copies de base au pool")

func test_hand_overflow_is_discarded_at_end_of_shop_phase() -> void:
	var card := _make_card("Filler", 1, "res://fake/shop_filler.tres")
	var m := _make_match([card])
	var player := m.players[0]
	for i in ArenaConstants.HAND_MAX + 2:
		player.hand.append(Minion.new(card))
	m.end_shop_phase()
	assert_eq(player.hand_count(), ArenaConstants.HAND_MAX)
