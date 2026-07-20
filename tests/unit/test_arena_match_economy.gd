extends GutTest

func _make_card(name: String, cost: int, path: String) -> CardData:
	var data := CardData.new()
	data.card_name = name
	data.cost = cost
	data.rarity = "Common"
	data.card_type = "Minion"
	data.resource_path = path
	return data

func _make_match() -> ArenaMatch:
	var cards: Array[CardData] = [_make_card("C1", 1, "res://fake/eco_c1.tres")]
	var pool := ArenaCardPool.new(cards)
	var players: Array[ArenaPlayerState] = [ArenaPlayerState.new("Player")]
	return ArenaMatch.new(players, pool)

func test_gold_is_fixed_at_round_1() -> void:
	var match_ := _make_match()
	match_.players[0].gold = 99  # ne doit pas influencer le round 1
	match_.start_shop_phase()
	assert_eq(match_.players[0].gold, ArenaConstants.STARTING_GOLD)

func test_gold_increments_and_caps() -> void:
	var match_ := _make_match()
	match_.round_number = 2
	match_.players[0].gold = ArenaConstants.GOLD_CAP
	match_.start_shop_phase()
	assert_eq(match_.players[0].gold, ArenaConstants.GOLD_CAP, "l'or ne doit jamais dépasser le plafond")

func test_gold_income_grows_even_when_fully_spent_each_round() -> void:
	# Un joueur qui dépense tout son or chaque round (comportement encouragé
	# par le design, voir README « Philosophie de design ») ne doit jamais
	# rester bloqué à 1 or/round : le revenu doit croître de round en round.
	assert_eq(ArenaEconomy.compute_gold_for_round(2, 0), 2)
	assert_eq(ArenaEconomy.compute_gold_for_round(3, 0), 3)
	assert_eq(ArenaEconomy.compute_gold_for_round(10, 0), 10)
	assert_eq(ArenaEconomy.compute_gold_for_round(20, 0), ArenaConstants.GOLD_CAP, "le revenu par round est plafonné à 15")

func test_xp_purchase_locked_at_round_1() -> void:
	var match_ := _make_match()
	match_.players[0].gold = 10
	assert_false(match_.buy_xp(match_.players[0]), "achat d'XP interdit au round 1")

func test_xp_purchase_allowed_from_round_2() -> void:
	var match_ := _make_match()
	match_.round_number = 2
	match_.players[0].gold = 10
	var xp_before: int = match_.players[0].xp
	assert_true(match_.buy_xp(match_.players[0]))
	assert_eq(match_.players[0].xp, xp_before + ArenaConstants.GOLD_TO_XP_RATE)
	assert_eq(match_.players[0].gold, 10 - ArenaConstants.GOLD_TO_XP_RATE)

func test_hero_level_matches_xp_thresholds() -> void:
	assert_eq(ArenaEconomy.hero_level_for_xp(0), 1)
	assert_eq(ArenaEconomy.hero_level_for_xp(3), 1)
	assert_eq(ArenaEconomy.hero_level_for_xp(4), 2)
	assert_eq(ArenaEconomy.hero_level_for_xp(70), 8)
	assert_eq(ArenaEconomy.hero_level_for_xp(999), 8, "niveau plafonné à 8")

func test_unlocked_costs_grow_with_level() -> void:
	assert_eq(ArenaEconomy.unlocked_costs_for_level(1), [1])
	assert_eq(ArenaEconomy.unlocked_costs_for_level(8), [1, 2, 3, 4, 5, 6, 7, 8])
