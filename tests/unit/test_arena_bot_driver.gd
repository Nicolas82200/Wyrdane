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
	var players: Array[ArenaPlayerState] = [ArenaPlayerState.new("Bot", true)]
	return ArenaMatch.new(players, pool)

func test_bot_never_spends_more_gold_than_it_has() -> void:
	var cards: Array[CardData] = [
		_make_card("C1", 1, "res://fake/bot_c1.tres"),
		_make_card("C2", 3, "res://fake/bot_c2.tres"),
	]
	var m := _make_match(cards)
	var player := m.players[0]
	player.gold = 3
	player.shop_offer = [cards[0], cards[1], null, null, null]
	var bot := ArenaBotDriver.new(RandomNumberGenerator.new())
	bot.play_shop_phase(player, m)
	assert_true(player.gold >= 0, "l'or ne doit jamais devenir négatif")

func test_bot_positioning_respects_row_max() -> void:
	var card := _make_card("Filler", 1, "res://fake/bot_filler.tres")
	var m := _make_match([card])
	var player := m.players[0]
	for i in ArenaConstants.BOARD_ROW_MAX * 2 + 3:
		player.hand.append(Minion.new(card))
	var bot := ArenaBotDriver.new(RandomNumberGenerator.new())
	bot.play_positioning_phase(player)
	assert_true(player.board_front.size() <= ArenaConstants.BOARD_ROW_MAX)
	assert_true(player.board_back.size() <= ArenaConstants.BOARD_ROW_MAX)
	assert_eq(player.hand.size(), 3, "l'excédent au-delà de 20 places doit rester en main")

func test_bot_handles_empty_shop_without_crashing() -> void:
	var card := _make_card("Solo", 1, "res://fake/bot_empty.tres")
	var m := _make_match([card])
	var player := m.players[0]
	player.gold = 0
	player.shop_offer = [null, null, null, null, null]
	var bot := ArenaBotDriver.new(RandomNumberGenerator.new())
	bot.play_shop_phase(player, m)
	assert_eq(player.hand.size(), 0)

func test_bot_buys_xp_from_round_2_with_enough_gold() -> void:
	var card := _make_card("C1", 100, "res://fake/bot_xp.tres")  # inabordable, force le passage direct à l'XP
	var m := _make_match([card])
	m.round_number = 2
	var player := m.players[0]
	player.gold = 5
	player.shop_offer = [card, null, null, null, null]
	var bot := ArenaBotDriver.new(RandomNumberGenerator.new())
	bot.play_shop_phase(player, m)
	assert_gt(player.xp, 0, "le bot doit acheter de l'XP quand il a de l'or inutile à partir du round 2")
