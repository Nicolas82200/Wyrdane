extends GutTest

func _make_card(name: String, cost: int, rarity: String, path: String) -> CardData:
	var data := CardData.new()
	data.card_name = name
	data.cost = cost
	data.rarity = rarity
	data.card_type = "Minion"
	data.resource_path = path
	return data

func _sample_cards() -> Array[CardData]:
	var cards: Array[CardData] = []
	cards.append(_make_card("Common1", 1, "Common", "res://fake/common1.tres"))
	cards.append(_make_card("Rare1", 1, "Rare", "res://fake/rare1.tres"))
	cards.append(_make_card("Epic3", 3, "Epic", "res://fake/epic3.tres"))
	return cards

func test_take_decrements_and_release_increments_copies() -> void:
	var cards := _sample_cards()
	var pool := ArenaCardPool.new(cards)
	var card := cards[0]
	var before: int = pool.copies_remaining(card)
	pool.take(card)
	assert_eq(pool.copies_remaining(card), before - 1)
	pool.release(card)
	assert_eq(pool.copies_remaining(card), before)

func test_release_never_exceeds_rarity_cap() -> void:
	var cards := _sample_cards()
	var pool := ArenaCardPool.new(cards)
	var card := cards[0]
	var cap: int = ArenaConstants.POOL_COPIES_BY_RARITY[card.rarity]
	pool.release(card)
	assert_eq(pool.copies_remaining(card), cap, "release() ne doit jamais dépasser le plafond de rareté")

func test_draw_card_returns_null_when_pool_exhausted() -> void:
	var cards: Array[CardData] = [_make_card("Solo", 1, "Common", "res://fake/solo.tres")]
	var pool := ArenaCardPool.new(cards)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in ArenaConstants.POOL_COPIES_BY_RARITY["Common"]:
		pool.take(cards[0])
	var drawn: CardData = pool.draw_card(1, rng)
	assert_null(drawn, "aucune copie restante -> aucune carte tirée à ce coût/rareté")

func test_draw_card_only_returns_available_cost_at_level_1() -> void:
	var pool := ArenaCardPool.new(_sample_cards())
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 20:
		var drawn: CardData = pool.draw_card(1, rng)
		if drawn != null:
			assert_eq(drawn.cost, 1, "niveau 1 ne débloque que le coût 1")

func test_draw_card_can_return_higher_cost_at_higher_level() -> void:
	var pool := ArenaCardPool.new(_sample_cards())
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var saw_cost_3 := false
	for i in 200:
		var drawn: CardData = pool.draw_card(4, rng)
		if drawn != null and drawn.cost == 3:
			saw_cost_3 = true
			break
	assert_true(saw_cost_3, "niveau 4 débloque le coût 3, doit finir par être tiré")
