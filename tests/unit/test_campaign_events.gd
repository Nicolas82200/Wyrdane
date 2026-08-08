extends GutTest

func before_all() -> void:
	CardLibrary.load_all_cards()

func _run(race: int = Race.Type.UNDEAD, hp: int = 20, max_hp: int = 30) -> CampaignRun:
	var run := CampaignRun.new()
	run.race = race
	run.hero_health = hp
	run.hero_max_health = max_hp
	run.rng.seed = 1
	return run

func test_all_events_have_at_least_one_choice() -> void:
	for event in CampaignEvents.EVENTS:
		assert_gt((event["choices"] as Array).size(), 0, "%s : événement sans choix" % event["id"])

func test_heal_small_heals_without_exceeding_max() -> void:
	var run := _run(Race.Type.UNDEAD, 28, 30)
	CampaignEvents.apply_effect("heal_small", run)
	assert_eq(run.hero_health, 30, "le soin ne doit jamais dépasser hero_max_health")

func test_lose_hp_never_drops_below_the_survival_floor() -> void:
	var run := _run(Race.Type.UNDEAD, 3, 30)
	CampaignEvents.apply_effect("lose_hp", run)
	assert_eq(run.hero_health, CampaignEvents.MIN_HP_AFTER_EVENT, "un événement ne doit jamais tuer le héros")

func test_gain_max_hp_lose_hp_increases_max_and_reduces_current() -> void:
	var run := _run(Race.Type.UNDEAD, 20, 30)
	CampaignEvents.apply_effect("gain_max_hp_lose_hp", run)
	assert_eq(run.hero_max_health, 30 + CampaignEvents.ALTAR_MAX_HP_GAIN)
	assert_eq(run.hero_health, 20 - CampaignEvents.ALTAR_HP_COST)

func test_gain_card_rare_adds_a_rare_card_of_the_run_race() -> void:
	var run := _run(Race.Type.HUMAN, 20, 30)
	var before := run.board.size()
	CampaignEvents.apply_effect("gain_card_rare", run)
	assert_eq(run.board.size(), before + 1)
	assert_eq(run.board[0].race, Race.Type.HUMAN)
	assert_eq(run.board[0].rarity, "Rare")
	assert_ne(run.board[0].card_type, "Enchantment", "les Enchantements sont des Reliques, jamais une récompense d'événement")
	assert_ne(run.board[0].card_type, "Ritual", "les Rituels sont des Reliques, jamais une récompense d'événement")

func test_nothing_leaves_the_run_untouched() -> void:
	var run := _run(Race.Type.UNDEAD, 20, 30)
	var deck_before := run.board.size()
	CampaignEvents.apply_effect("nothing", run)
	assert_eq(run.hero_health, 20)
	assert_eq(run.hero_max_health, 30)
	assert_eq(run.board.size(), deck_before)

func test_random_event_is_deterministic_given_the_same_seed() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 99
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 99
	assert_eq(CampaignEvents.random_event(rng_a)["id"], CampaignEvents.random_event(rng_b)["id"])
