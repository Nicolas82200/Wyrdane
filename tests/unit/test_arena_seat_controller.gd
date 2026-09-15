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

func test_bot_seat_controller_buys_positions_and_casts_like_the_raw_driver() -> void:
	var card := _make_card("Filler", 1, "res://fake/seat_filler.tres")
	var m := _make_match([card])
	var player := m.players[0]
	player.gold = 1
	player.shop_offer = [card, null, null, null, null]
	var driver := ArenaBotDriver.new(RandomNumberGenerator.new())
	var seat := ArenaBotSeatController.new(player, driver)
	await seat.take_shop_turn(m)
	assert_eq(player.hand.size() + player.board_front.size() + player.board_back.size(), 1,
		"la carte achetée doit avoir été posée quelque part par le passage complet de la phase Boutique")
	assert_eq(player.gold, 0, "la carte à 1 doit avoir été payée avec l'or de départ")

func test_bot_seat_controller_exposes_the_wrapped_player() -> void:
	var player := ArenaPlayerState.new("Bot", true)
	var driver := ArenaBotDriver.new(RandomNumberGenerator.new())
	var seat := ArenaBotSeatController.new(player, driver)
	assert_eq(seat.player, player)
