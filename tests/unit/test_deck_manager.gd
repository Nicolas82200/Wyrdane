extends GutTest

# Couvre DeckManager.can_add_card (scripts/deck/DeckManager.gd) : logique de
# légalité de deck (plafond MAX_COPIES_PER_CARD, cartes-ressource en quantité
# illimitée, sans lien avec ce qui est possédé). can_add_card() lit
# directement l'autoload global CollectionManager (non injectable) : on
# manipule donc owned_quantities sur l'instance réelle, restaurée après
# chaque test pour ne pas polluer les autres fichiers GUT (voir CLAUDE.md sur
# la prudence avec les autoloads dans le runner -s).

var deck_manager
var deck: DeckData
var card: CardData

func before_each() -> void:
	deck_manager = load("res://scripts/deck/DeckManager.gd").new()
	deck = DeckData.new()
	card = CardData.new()
	card.card_name = "TEST_CARD"
	card.card_type = "Minion"
	card.resource_path = "res://__test_fake__/can_add_card.tres"
	CollectionManager.owned_quantities[card.resource_path] = 0

func after_each() -> void:
	CollectionManager.owned_quantities.erase(card.resource_path)
	deck_manager.free()

func test_cannot_add_an_unowned_card() -> void:
	assert_false(deck_manager.can_add_card(deck, card))

func test_can_add_an_owned_card_below_the_copy_limit() -> void:
	CollectionManager.owned_quantities[card.resource_path] = 4
	assert_true(deck_manager.can_add_card(deck, card))

func test_cannot_exceed_max_copies_even_if_more_are_owned() -> void:
	CollectionManager.owned_quantities[card.resource_path] = 10
	for i in range(DeckManager.MAX_COPIES_PER_CARD):
		deck.add_card(card)
	assert_false(deck_manager.can_add_card(deck, card), "déjà au plafond (4 copies) malgré 10 possédées")

func test_cannot_exceed_owned_quantity_even_below_max_copies() -> void:
	CollectionManager.owned_quantities[card.resource_path] = 2
	deck.add_card(card)
	deck.add_card(card)
	assert_false(deck_manager.can_add_card(deck, card), "2 possédées, 2 déjà dans le deck : plafond atteint avant MAX_COPIES")

func test_resource_cards_ignore_the_max_copies_cap() -> void:
	card.card_type = "Resource"
	CollectionManager.owned_quantities[card.resource_path] = 10
	for i in range(6):
		deck.add_card(card)
	assert_true(deck_manager.can_add_card(deck, card), "les cartes-ressource n'ont pas de plafond MAX_COPIES_PER_CARD")

func test_resource_cards_are_unlimited_regardless_of_owned_quantity() -> void:
	card.card_type = "Resource"
	CollectionManager.owned_quantities[card.resource_path] = 2
	deck.add_card(card)
	deck.add_card(card)
	assert_true(deck_manager.can_add_card(deck, card), "les cartes-ressource sont illimitées, même au-delà de ce qui est possédé")

func test_resource_cards_ignore_zero_owned_quantity() -> void:
	card.card_type = "Resource"
	CollectionManager.owned_quantities[card.resource_path] = 0
	assert_true(deck_manager.can_add_card(deck, card), "les cartes-ressource sont jouables même sans en posséder aucune")
