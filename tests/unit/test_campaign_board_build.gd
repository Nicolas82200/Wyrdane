extends GutTest

func before_all() -> void:
	CardLibrary.load_all_cards()

func test_pick_candidates_returns_three_common_cards_of_the_race() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for race in Race.get_implemented_races():
		var candidates: Array[CardData] = CampaignBoardBuild.pick_candidates(race, rng)
		assert_eq(candidates.size(), CampaignBoardBuild.CANDIDATES_PER_CHOICE, "race %d : nombre de candidats inattendu" % race)
		for card in candidates:
			assert_eq(card.race, race)
			assert_eq(card.rarity, "Common")
			assert_ne(card.card_type, "Resource", "pas de ressource en Campagne (pas de pioche/mana)")
			assert_false(card.is_token)

func test_pick_candidates_avoids_already_chosen_cards_when_pool_is_large_enough() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var race := Race.Type.UNDEAD
	var already: Array[CardData] = CardLibrary.get_cards_by_race_and_rarity(race, "Common").filter(
		func(c: CardData) -> bool: return c.card_type != "Resource" and not c.is_token)
	# On "consomme" tout sauf 3 cartes : les candidats doivent forcément être ces 3-là.
	var kept := already.slice(0, max(0, already.size() - 3))
	var candidates: Array[CardData] = CampaignBoardBuild.pick_candidates(race, rng, kept)
	for card in candidates:
		assert_false(kept.has(card), "%s a déjà été proposée dans un choix précédent" % card.card_name)

func test_pick_candidates_is_deterministic_given_the_same_seed() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 42
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 42
	var a: Array[CardData] = CampaignBoardBuild.pick_candidates(Race.Type.HUMAN, rng_a)
	var b: Array[CardData] = CampaignBoardBuild.pick_candidates(Race.Type.HUMAN, rng_b)
	assert_eq(a, b)
