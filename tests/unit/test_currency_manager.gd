extends GutTest

# Couvre CurrencyManager (scripts/collection/CurrencyManager.gd) : la partie
# pure du script (tarifs affichés, mise à jour de solde et de ses signaux),
# sans passer par sync_from_backend/open_pack/report_solo_match_result qui
# dépendent de BackendClient — non instancié ici (voir CLAUDE.md, ne pas
# dépendre des autoloads globaux dans les tests GUT en mode -s). Chargé via
# load().new() plutôt que via l'autoload : _ready() n'est jamais appelé
# (le nœud n'est ajouté à aucun arbre), donc aucune dépendance autoload
# n'est exercée par ces tests.

var currency

func before_each() -> void:
	currency = load("res://scripts/collection/CurrencyManager.gd").new()

func test_initial_balance_and_free_packs_are_zero() -> void:
	assert_eq(currency.balance, 0)
	assert_eq(currency.free_packs, 0)
	assert_false(currency.is_synced)

func test_card_price_known_rarities() -> void:
	assert_eq(currency.card_price("Common"), 100)
	assert_eq(currency.card_price("Rare"), 150)
	assert_eq(currency.card_price("Epic"), 200)
	assert_eq(currency.card_price("Legendary"), 250)

func test_card_price_unknown_rarity_is_zero() -> void:
	# Cartes-ressource (non vendables à l'unité) et toute rareté inconnue.
	assert_eq(currency.card_price("Ressource"), 0)
	assert_eq(currency.card_price(""), 0)

func test_apply_balance_update_sets_balance_and_emits_signal() -> void:
	watch_signals(currency)
	currency.apply_balance_update(750)
	assert_eq(currency.balance, 750)
	assert_signal_emitted_with_parameters(currency, "balance_changed", [750])

func test_apply_balance_update_can_be_called_repeatedly() -> void:
	currency.apply_balance_update(100)
	currency.apply_balance_update(50)
	assert_eq(currency.balance, 50)
