extends GutTest

# Couvre CollectionManager (scripts/collection/CollectionManager.gd) : la
# partie pure du script (owned_quantity/is_owned), sans passer par
# sync_from_backend/buy_card qui dépendent de BackendClient/CardLibrary/
# CurrencyManager — non instanciés ici (voir CLAUDE.md, ne pas dépendre des
# autoloads globaux dans les tests GUT en mode -s). Chargé via load().new()
# plutôt que via l'autoload : _ready() n'est jamais appelé (le nœud n'est
# ajouté à aucun arbre), donc la connexion à AchievementManager.check_collector
# n'est jamais exercée par ces tests.

var collection

func before_each() -> void:
	collection = load("res://scripts/collection/CollectionManager.gd").new()

func _card(resource_path: String) -> CardData:
	var data := CardData.new()
	data.card_name = "TEST_CARD"
	data.resource_path = resource_path
	return data

func test_owned_quantity_defaults_to_zero_for_unknown_card() -> void:
	var card := _card("res://resources/cards/undead/skeleton.tres")
	assert_eq(collection.owned_quantity(card), 0)

func test_owned_quantity_null_card_is_zero() -> void:
	assert_eq(collection.owned_quantity(null), 0)

func test_owned_quantity_reflects_synced_data() -> void:
	var card := _card("res://resources/cards/undead/skeleton.tres")
	collection.owned_quantities[card.resource_path] = 3
	assert_eq(collection.owned_quantity(card), 3)

func test_is_owned_false_when_quantity_zero() -> void:
	var card := _card("res://resources/cards/undead/skeleton.tres")
	assert_false(collection.is_owned(card))

func test_is_owned_true_when_quantity_positive() -> void:
	var card := _card("res://resources/cards/undead/skeleton.tres")
	collection.owned_quantities[card.resource_path] = 1
	assert_true(collection.is_owned(card))

func test_is_owned_null_card_is_false() -> void:
	assert_false(collection.is_owned(null))

func test_is_synced_starts_false() -> void:
	assert_false(collection.is_synced)
