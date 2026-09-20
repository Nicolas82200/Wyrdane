extends GutTest

# NetCardResolver factorise une vérification de sécurité utilisée par
# NetworkOpponent (1v1) et ArenaBoardSnapshot (Arena) : un pair ne doit
# jamais pouvoir faire charger un chemin arbitraire du projet, ni désigner
# un jeton d'invocation.

const REAL_CARD_PATH := "res://resources/cards/undead/bloated-giant.tres"
const REAL_TOKEN_PATH := "res://resources/cards/undead/minor-zombie-token.tres"

func test_resolves_a_real_card_by_its_resource_path() -> void:
	var card: CardData = NetCardResolver.resolve(REAL_CARD_PATH)
	assert_not_null(card)
	assert_eq(card.resource_path, REAL_CARD_PATH)

func test_rejects_a_path_outside_the_cards_folder() -> void:
	assert_null(NetCardResolver.resolve("res://scripts/net/NetCardResolver.gd"))

func test_rejects_a_path_not_ending_in_tres() -> void:
	assert_null(NetCardResolver.resolve("res://resources/cards/undead/bloated-giant.tres.bak"))

func test_rejects_a_summon_token() -> void:
	assert_null(NetCardResolver.resolve(REAL_TOKEN_PATH))

func test_rejects_a_nonexistent_card() -> void:
	assert_null(NetCardResolver.resolve("res://resources/cards/undead/this-card-does-not-exist.tres"))
