extends GutTest

# Couvre DeckData (scripts/deck/DeckData.gd) : CRUD en mémoire (add_card/
# remove_card_at/size) et le format d'export/import to_code()/from_code(),
# utilisé pour partager un deck en texte. from_code() valide les chemins via
# ResourceLoader.exists() et applique MAX_COPIES_PER_CARD : ces deux tests
# chargent donc une vraie carte du jeu plutôt qu'une CardData factice.

const REAL_CARD_PATH := "res://resources/cards/undead/bloated-giant.tres"

var deck: DeckData

func before_each() -> void:
	deck = DeckData.new()

func test_new_deck_has_default_name_and_is_empty() -> void:
	assert_eq(deck.name, "Nouveau Deck")
	assert_eq(deck.size(), 0)

func test_add_card_appends_resource_path() -> void:
	var card := CardData.new()
	card.resource_path = "res://__test_fake__/card_a.tres"
	deck.add_card(card)
	assert_eq(deck.card_paths, ["res://__test_fake__/card_a.tres"])
	assert_eq(deck.size(), 1)

func test_remove_card_at_removes_by_index() -> void:
	var a := CardData.new()
	a.resource_path = "res://__test_fake__/a.tres"
	var b := CardData.new()
	b.resource_path = "res://__test_fake__/b.tres"
	deck.add_card(a)
	deck.add_card(b)
	deck.remove_card_at(0)
	assert_eq(deck.card_paths, ["res://__test_fake__/b.tres"])

func test_get_cards_loads_real_resources_and_skips_invalid_paths() -> void:
	deck.card_paths = [REAL_CARD_PATH, "res://__test_fake__/does_not_exist.tres"]
	var cards: Array[CardData] = deck.get_cards()
	assert_eq(cards.size(), 1, "un chemin invalide doit être ignoré, pas planter le chargement")
	assert_eq(cards[0].resource_path, REAL_CARD_PATH)

func test_to_code_and_from_code_round_trip_with_real_cards() -> void:
	deck.name = "Mon Deck"
	deck.card_paths = [REAL_CARD_PATH, REAL_CARD_PATH]
	var code: String = deck.to_code()
	var decoded: DeckData = DeckData.from_code(code)
	assert_not_null(decoded)
	assert_eq(decoded.name, "Mon Deck")
	assert_eq(decoded.card_paths, [REAL_CARD_PATH, REAL_CARD_PATH])

func test_from_code_returns_null_for_garbage_input() -> void:
	assert_null(DeckData.from_code("pas du base64 valide de deck"))

func test_from_code_enforces_max_copies_per_card() -> void:
	deck.name = "Trop de copies"
	var paths: Array[String] = []
	for i in range(DeckManager.MAX_COPIES_PER_CARD + 2):
		paths.append(REAL_CARD_PATH)
	deck.card_paths = paths
	var code: String = deck.to_code()
	var decoded: DeckData = DeckData.from_code(code)
	assert_not_null(decoded)
	assert_eq(decoded.card_paths.size(), DeckManager.MAX_COPIES_PER_CARD, "from_code doit tronquer au plafond de copies")
