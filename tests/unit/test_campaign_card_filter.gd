extends GutTest

func before_all() -> void:
	CardLibrary.load_all_cards()

func _card_with_effect(effect_id: String) -> CardData:
	var card := CardData.new()
	var effect := CardEffect.new()
	effect.effect_id = effect_id
	card.effects = [effect]
	return card

func test_incompatible_effects_are_rejected() -> void:
	for effect_id in CampaignCardFilter.INCOMPATIBLE_EFFECT_IDS:
		assert_false(CampaignCardFilter.is_compatible(_card_with_effect(effect_id)), effect_id)

func test_compatible_effect_is_accepted() -> void:
	assert_true(CampaignCardFilter.is_compatible(_card_with_effect("Damage")))

func test_card_with_no_effects_is_accepted() -> void:
	assert_true(CampaignCardFilter.is_compatible(CardData.new()))

func test_filter_compatible_removes_only_incompatible_cards() -> void:
	var good := _card_with_effect("Damage")
	var bad := _card_with_effect("DrawCard")
	var cards: Array[CardData] = [good, bad]
	var result := CampaignCardFilter.filter_compatible(cards)
	assert_eq(result, [good])

func test_real_card_pools_exclude_incompatible_effects() -> void:
	for race in Race.get_implemented_races():
		var pool: Array[CardData] = CampaignCardFilter.filter_compatible(CardLibrary.get_cards_by_race(race, true))
		for card in pool:
			assert_true(CampaignCardFilter.is_compatible(card), card.card_name)
