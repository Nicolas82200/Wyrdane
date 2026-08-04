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

func test_reroll_keeps_locked_slot_untouched() -> void:
	var kept := _make_card("Kept", 2, "res://fake/shop_kept.tres")
	var other := _make_card("Other", 3, "res://fake/shop_other.tres")
	var m := _make_match([kept, other, other, other, other, other])
	var player := m.players[0]
	player.gold = 10
	player.shop_offer = [kept, other, other, other, other]
	player.toggle_shop_lock(0)
	assert_true(player.shop_locked[0])
	m.reroll(player)
	assert_eq(player.shop_offer[0], kept, "la case verrouillée doit garder exactement la même carte")
	assert_true(player.shop_locked[0], "le verrou doit survivre au reroll")

func test_reroll_replaces_unlocked_slots() -> void:
	# Pool délibérément vidé (draw_card() ne peut plus rien proposer) : une
	# case NON verrouillée doit donc être effacée par le reroll, alors qu'une
	# case verrouillée n'est jamais redemandée au pool et garde sa carte —
	# c'est ce qui distingue "verrouillé" de "juste retombé sur la même carte
	# par hasard" (il n'y a qu'une seule carte possible dans ce pool).
	var kept := _make_card("Kept", 2, "res://fake/shop_kept2.tres")
	var pool := ArenaCardPool.new([kept])
	var players: Array[ArenaPlayerState] = [ArenaPlayerState.new("Player")]
	var match_ := ArenaMatch.new(players, pool)
	var player := match_.players[0]
	player.gold = 10
	while pool.copies_remaining(kept) > 0:
		pool.take(kept)
	player.shop_offer = [kept, kept, kept, kept, kept]
	player.shop_locked = [true, false, false, false, false]
	match_.reroll(player)
	assert_eq(player.shop_offer[0], kept, "la case verrouillée doit garder sa carte même si le pool est vide")
	assert_null(player.shop_offer[1], "une case non verrouillée doit être rafraîchie (et vidée si le pool n'a plus rien à offrir)")

func test_new_round_clears_all_locks() -> void:
	var kept := _make_card("Kept", 2, "res://fake/shop_kept3.tres")
	var m := _make_match([kept, kept, kept, kept, kept, kept])
	var player := m.players[0]
	player.shop_offer = [kept, kept, kept, kept, kept]
	player.toggle_shop_lock(0)
	assert_true(player.shop_locked[0])
	m.start_shop_phase()
	assert_false(player.shop_locked[0], "une nouvelle manche doit repartir d'une offre entièrement déverrouillée")

func test_buying_a_locked_slot_clears_its_lock() -> void:
	var card := _make_card("C1", 2, "res://fake/shop_lockbuy.tres")
	var m := _make_match([card])
	var player := m.players[0]
	player.gold = 5
	player.toggle_shop_lock(0)
	assert_true(player.shop_locked[0])
	m.buy_card(player, 0)
	assert_false(player.shop_locked[0], "acheter une case verrouillée doit lever le verrou (case désormais vide)")

func test_cannot_lock_an_empty_slot() -> void:
	var card := _make_card("C1", 2, "res://fake/shop_lockempty.tres")
	var m := _make_match([card])
	var player := m.players[0]
	player.toggle_shop_lock(1)  # case vide (null) dans _make_match
	assert_eq(player.shop_locked.size(), 0, "aucun redimensionnement/verrou ne doit se produire sur une case vide")

func test_hand_overflow_is_discarded_at_end_of_shop_phase() -> void:
	var card := _make_card("Filler", 1, "res://fake/shop_filler.tres")
	var m := _make_match([card])
	var player := m.players[0]
	for i in ArenaConstants.HAND_MAX + 2:
		player.hand.append(Minion.new(card))
	m.end_shop_phase()
	assert_eq(player.hand_count(), ArenaConstants.HAND_MAX)
