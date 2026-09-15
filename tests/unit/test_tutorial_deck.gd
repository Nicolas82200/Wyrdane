extends GutTest

# Couvre TutorialDeck (scripts/tutorial/TutorialDeck.gd) : classe pure de
# constantes/chargement de ressources, sans dépendance à CardLibrary (chemins
# resources/cards/ directs) — testable telle quelle, même pattern que
# AISystem (voir CLAUDE.md).

func test_all_card_getters_load_real_resources() -> void:
	assert_not_null(TutorialDeck.resource_card())
	assert_not_null(TutorialDeck.zombie_card())
	assert_not_null(TutorialDeck.wandering_corpse_card())
	assert_not_null(TutorialDeck.necrotic_breath_card())
	assert_not_null(TutorialDeck.doomed_whisper_card())
	assert_not_null(TutorialDeck.gaunt_servant_card())
	assert_not_null(TutorialDeck.enemy_zombie_card())
	assert_not_null(TutorialDeck.enemy_pestilent_card())

func test_player_hand_has_eight_cards() -> void:
	assert_eq(TutorialDeck.player_hand().size(), 8)

func test_player_hand_starts_with_three_resource_cards() -> void:
	var hand := TutorialDeck.player_hand()
	for i in range(3):
		assert_eq(hand[i].resource_path, TutorialDeck.RESOURCE)

func test_player_deck_padding_has_six_cards() -> void:
	# 4 zombies + 2 cadavres errants, voir player_deck_padding().
	assert_eq(TutorialDeck.player_deck_padding().size(), 6)

func test_is_swappable_during_tutorial_true_for_resource_card() -> void:
	assert_true(TutorialDeck.is_swappable_during_tutorial(TutorialDeck.resource_card()))

func test_is_swappable_during_tutorial_false_for_other_cards() -> void:
	assert_false(TutorialDeck.is_swappable_during_tutorial(TutorialDeck.zombie_card()))

func test_is_swappable_during_tutorial_false_for_null() -> void:
	assert_false(TutorialDeck.is_swappable_during_tutorial(null))
