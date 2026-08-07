extends GutTest

func before_all() -> void:
	CardLibrary.load_all_cards()

func test_roll_rarity_respects_weight_ratios_over_many_rolls() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var counts: Dictionary = {"Common": 0, "Rare": 0, "Epic": 0, "Legendary": 0}
	const TRIALS := 4000
	for i in range(TRIALS):
		var rarity := CampaignRewardPicker.roll_rarity(rng)
		counts[rarity] += 1
	# Common (poids 60/100) doit rester très majoritaire, Legendary (3/100) rare.
	assert_true(counts["Common"] > counts["Rare"], "Common devrait être plus fréquent que Rare")
	assert_true(counts["Rare"] > counts["Epic"], "Rare devrait être plus fréquent qu'Epic")
	assert_true(counts["Epic"] >= counts["Legendary"], "Epic devrait être au moins aussi fréquent que Legendary")
	var common_ratio := float(counts["Common"]) / float(TRIALS)
	assert_almost_eq(common_ratio, 0.60, 0.06, "ratio Common éloigné du poids attendu (60%%)")

func test_pick_three_returns_cards_of_the_requested_race() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for race in Race.get_implemented_races():
		var cards: Array[CardData] = CampaignRewardPicker.pick_three(race, rng)
		assert_eq(cards.size(), CampaignRewardPicker.CANDIDATE_COUNT, "race %d : nombre de candidats inattendu" % race)
		for card in cards:
			assert_eq(card.race, race)
			assert_eq(card.card_type, "Minion", "une récompense de Campagne ne doit être qu'une créature")
			assert_false(card.is_token)

func test_pick_relic_returns_an_enchantment_or_ritual() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for race in Race.get_implemented_races():
		var card: CardData = CampaignRewardPicker.pick_relic(race, rng)
		assert_not_null(card, "race %d : aucune Relique trouvée" % race)
		assert_true(card.card_type == "Enchantment" or card.card_type == "Ritual")
		assert_eq(card.race, race)

func test_pick_one_falls_back_to_lower_rarity_when_pool_is_empty() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	# Race NONE : aucune carte de cette race dans CardLibrary, force le repli
	# en cascade Legendary -> Epic -> Rare -> Common -> pool vide -> null.
	var card: CardData = CampaignRewardPicker._pick_one(Race.Type.NONE, "Legendary", rng)
	assert_null(card, "aucune carte ne devrait exister pour Race.Type.NONE, quelle que soit la rareté")
