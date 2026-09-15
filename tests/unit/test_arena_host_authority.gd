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
	var players: Array[ArenaPlayerState] = [ArenaPlayerState.new("Hôte"), ArenaPlayerState.new("Client")]
	return ArenaMatch.new(players, pool)  # seat_id 0 = hôte, 1 = client (voir ArenaMatch._init)

func test_apply_unknown_seat_returns_empty_dictionary() -> void:
	var m := _make_match([])
	var result: Dictionary = ArenaHostAuthority.apply(m, 99, ArenaGameCommand.request_reroll())
	assert_true(result.is_empty())

func test_request_buy_spends_gold_and_returns_public_and_private_syncs() -> void:
	var card := _make_card("C1", 1, "res://fake/host_c1.tres")
	var m := _make_match([card])
	var player: ArenaPlayerState = m.find_by_seat(1)
	player.gold = 1
	player.shop_offer = [card, null, null, null, null]
	var result: Dictionary = ArenaHostAuthority.apply(m, 1, ArenaGameCommand.request_buy(0))
	assert_eq(player.gold, 0)
	assert_eq(player.hand.size(), 1)
	assert_eq(ArenaGameCommand.type_of(result["public"]), ArenaGameCommand.BOARD_SYNC)
	assert_eq(result["public"]["seat_id"], 1)
	# Le BOARD_SYNC (public) ne doit jamais révéler la main/boutique.
	assert_false(result["public"].has("hand"))
	assert_false(result["public"].has("shop_offer"))
	# Seul le PRIVATE_STATE_SYNC (destiné au seul siège concerné) les contient —
	# c'est l'unique moyen pour le client demandeur de savoir ce qu'il a reçu.
	assert_eq(ArenaGameCommand.type_of(result["private"]), ArenaGameCommand.PRIVATE_STATE_SYNC)
	assert_eq(result["private"]["gold"], 0)
	assert_eq(result["private"]["hand"].size(), 1)
	assert_eq(result["private"]["hand"][0]["resource_path"], "res://fake/host_c1.tres")

func test_request_place_moves_the_card_from_hand_to_the_board() -> void:
	var card := _make_card("C1", 1, "res://fake/host_place.tres")
	var m := _make_match([card])
	var player: ArenaPlayerState = m.find_by_seat(1)
	player.hand.append(Minion.new(card, true, "Front"))
	var result: Dictionary = ArenaHostAuthority.apply(m, 1, ArenaGameCommand.request_place(0, true, -1))
	assert_true(player.hand.is_empty())
	assert_eq(player.board_front.size(), 1)
	assert_eq(result["public"]["front"].size(), 1)
	assert_eq(result["public"]["front"][0]["resource_path"], "res://fake/host_place.tres")
	assert_eq(result["private"]["hand"].size(), 0, "la carte posée doit aussi disparaître de la main privée renvoyée")

func test_request_move_repositions_a_board_minion() -> void:
	var card_a := _make_card("A", 1, "res://fake/host_move_a.tres")
	var card_b := _make_card("B", 1, "res://fake/host_move_b.tres")
	var m := _make_match([card_a, card_b])
	var player: ArenaPlayerState = m.find_by_seat(1)
	var minion_a := Minion.new(card_a, true, "Front")
	var minion_b := Minion.new(card_b, true, "Front")
	player.board_front.append(minion_a)
	player.board_front.append(minion_b)
	ArenaHostAuthority.apply(m, 1, ArenaGameCommand.request_move(true, 1, true, 0))
	assert_eq(player.board_front, [minion_b, minion_a])

func test_request_sell_from_board_refunds_gold_and_clears_the_slot() -> void:
	var card := _make_card("Filler", 4, "res://fake/host_sell.tres")
	var m := _make_match([card])
	var player: ArenaPlayerState = m.find_by_seat(1)
	player.board_front.append(Minion.new(card, true, "Front"))
	var gold_before: int = player.gold
	var result: Dictionary = ArenaHostAuthority.apply(m, 1, ArenaGameCommand.request_sell_from_board(true, 0))
	assert_true(player.board_front.is_empty())
	assert_gt(player.gold, gold_before)
	assert_eq(result["public"]["front"].size(), 0)
	assert_eq(result["private"]["gold"], player.gold, "l'or renvoyé côté privé doit refléter le remboursement")

func test_out_of_range_index_is_a_no_op_but_still_returns_both_syncs() -> void:
	var m := _make_match([])
	var player: ArenaPlayerState = m.find_by_seat(1)
	var gold_before: int = player.gold
	var result: Dictionary = ArenaHostAuthority.apply(m, 1, ArenaGameCommand.request_sell_from_hand(5))
	assert_eq(player.gold, gold_before, "un index hors bornes ne doit rien vendre")
	assert_eq(ArenaGameCommand.type_of(result["public"]), ArenaGameCommand.BOARD_SYNC, "même un no-op renvoie l'état public actuel")
	assert_eq(ArenaGameCommand.type_of(result["private"]), ArenaGameCommand.PRIVATE_STATE_SYNC, "même un no-op renvoie l'état privé actuel")

func test_unknown_command_type_returns_empty_dictionary() -> void:
	var m := _make_match([])
	var result: Dictionary = ArenaHostAuthority.apply(m, 1, {"type": "NOT_A_REAL_COMMAND"})
	assert_true(result.is_empty())

func test_reroll_result_lets_the_requester_see_its_own_new_shop_offer() -> void:
	# C'est exactement le scénario qui motive PRIVATE_STATE_SYNC : un reroll ne
	# touche jamais le plateau (aucun BOARD_SYNC utile), donc sans ce second
	# message le client n'aurait ABSOLUMENT aucun moyen de voir sa nouvelle offre.
	var card := _make_card("C1", 1, "res://fake/host_reroll.tres")
	var m := _make_match([card])
	var player: ArenaPlayerState = m.find_by_seat(1)
	player.gold = ArenaConstants.REROLL_COST
	player.shop_offer = [card, null, null, null, null]
	var result: Dictionary = ArenaHostAuthority.apply(m, 1, ArenaGameCommand.request_reroll())
	assert_eq(result["private"]["shop_offer"].size(), player.shop_offer.size())
	assert_eq(result["private"]["gold"], 0)
