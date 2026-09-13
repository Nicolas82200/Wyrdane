extends GutTest

# Couvre DeckManager.can_add_card (scripts/deck/DeckManager.gd) : logique de
# légalité de deck (plafond MAX_COPIES_PER_CARD, cartes-ressource en quantité
# illimitée). Ne dépend plus de ce qui est possédé (voir commit "feat: allow
# building decks with unowned cards, block invalid deck selection") : un deck
# peut être construit ou importé avant l'achat de toutes ses cartes ; c'est
# unowned_cards_warning() qui signale ensuite qu'il n'est pas jouable en
# l'état, pas can_add_card(). can_add_card() lit tout de même l'autoload
# global CollectionManager (non injectable) pour les cartes-ressource : on
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

func test_can_add_an_unowned_card() -> void:
	assert_true(deck_manager.can_add_card(deck, card), "une carte non possédée peut être ajoutée (deck importable avant achat)")

func test_can_add_an_owned_card_below_the_copy_limit() -> void:
	CollectionManager.owned_quantities[card.resource_path] = 4
	assert_true(deck_manager.can_add_card(deck, card))

func test_cannot_exceed_max_copies_even_if_more_are_owned() -> void:
	CollectionManager.owned_quantities[card.resource_path] = 10
	for i in range(DeckManager.MAX_COPIES_PER_CARD):
		deck.add_card(card)
	assert_false(deck_manager.can_add_card(deck, card), "déjà au plafond (4 copies) malgré 10 possédées")

func test_can_exceed_owned_quantity_below_max_copies() -> void:
	CollectionManager.owned_quantities[card.resource_path] = 2
	deck.add_card(card)
	deck.add_card(card)
	assert_true(deck_manager.can_add_card(deck, card), "2 possédées, 2 déjà dans le deck : autorisé tant que MAX_COPIES n'est pas atteint")

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

# ─── suggested_resource_ratio / suggested_resource_count ───────────────────
# Formule README « Système de Ressources par Race » :
#   ratio = clamp(15% + (coût_moyen - 1) × 6%, min 15%, max 45%)
#   suggestion = round(taille_deck × ratio), jamais sous MIN_RESOURCE_CARDS
#
# get_cards() recharge chaque carte depuis son resource_path (voir DeckData.gd)
# : il faut donc de vraies ressources .tres existantes, pas des CardData
# construits à la volée avec un chemin fictif (elles seraient filtrées, load()
# renvoyant null).

const COST_4_CARD := "res://resources/cards/undead/bloated-giant.tres"  # cost 4
const COST_8_CARD := "res://resources/cards/undead/grand-necrotic-ritual.tres"  # cost 8
const COST_5_CARD := "res://resources/cards/undead/cadaverous-symbiosis.tres"  # cost 5, vérifié ci-dessous

func test_empty_deck_uses_floor_ratio() -> void:
	assert_almost_eq(deck_manager.suggested_resource_ratio(deck), 0.15, 0.001, "sans carte jouable, coût moyen par défaut = 1 → ratio plancher 15%")

func test_ratio_increases_with_average_cost() -> void:
	var c := load(COST_4_CARD) as CardData
	assert_eq(c.cost, 4, "carte de fixture attendue à coût 4")
	deck.add_card(c)
	deck.add_card(c)
	# coût moyen 4 → 15% + (4-1)*6% = 33%
	assert_almost_eq(deck_manager.suggested_resource_ratio(deck), 0.33, 0.001)

func test_ratio_is_clamped_to_45_percent() -> void:
	var c := load(COST_8_CARD) as CardData
	assert_eq(c.cost, 8, "carte de fixture attendue à coût 8")
	deck.add_card(c)
	# coût moyen 8 → 15% + 7*6% = 57%, clampé à 45%
	assert_almost_eq(deck_manager.suggested_resource_ratio(deck), 0.45, 0.001)

func test_suggested_count_never_below_minimum() -> void:
	assert_eq(deck_manager.suggested_resource_count(deck), DeckManager.MIN_RESOURCE_CARDS, "deck vide : suggestion plancher = MIN_RESOURCE_CARDS")

func test_suggested_count_scales_with_deck_size_and_cost() -> void:
	var c := load(COST_5_CARD) as CardData
	assert_eq(c.cost, 5, "carte de fixture attendue à coût 5")
	for i in range(40):
		deck.add_card(c)
	# taille prise en compte = max(taille réelle, MIN_TOTAL_CARDS=50) = 50
	# coût moyen 5 → ratio = 15% + 4*6% = 39% → round(50*0.39) = 19.5 -> 20 (round-half-away-from-zero)
	assert_eq(deck_manager.suggested_resource_count(deck), 20)
