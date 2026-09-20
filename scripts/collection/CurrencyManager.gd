# CurrencyManager.gd
extends Node

# Solde de monnaie molle (gagnée en jouant, dépensée en packs), autoritaire
# côté wyrdane-backend — même philosophie que CollectionManager : pas de
# cache hors-ligne, seule la dernière sync backend fait foi.

# Affiché à titre indicatif dans l'UI ; le coût réel est appliqué et vérifié
# côté serveur (voir PACK_COST dans wyrdane-backend/backend/src/model/packModel.ts).
const PACK_COST := 500
# Le montant exact d'une récompense de victoire/défaite solo dépend de la
# série de victoires en cours (voir rewardsController.WIN_STREAK_REWARD_TIERS
# côté wyrdane-backend) — pas de constante d'affichage statique possible ici,
# report_solo_match_result renvoie le montant réellement crédité au callback.

# Prix d'achat à l'unité dans le deckbuilder, par rareté — affiché à titre
# indicatif ; le prix réel est appliqué et vérifié côté serveur (voir
# CARD_PRICE_BY_RARITY dans wyrdane-backend/backend/src/model/collectionModel.ts).
const CARD_PRICE_BY_RARITY := {
	"Common": 100,
	"Rare": 150,
	"Epic": 200,
	"Legendary": 250,
}

# Nombre de cartes par pack et pondération de tirage par rareté, affichés à
# titre indicatif dans la boutique (tooltip des probabilités) — les valeurs
# réelles sont appliquées côté serveur, doivent rester synchronisées avec
# CARDS_PER_PACK/RARITY_WEIGHTS dans wyrdane-backend/backend/src/model/packModel.ts.
# Clés en anglais (contrairement au backend) pour matcher CardData.rarity.
const CARDS_PER_PACK_DISPLAY := 4
const RARITY_WEIGHTS_DISPLAY := {
	"Common": 60,
	"Rare": 25,
	"Epic": 12,
	"Legendary": 3,
}

var balance: int = 0
var free_packs: int = 0
var is_synced: bool = false

signal balance_changed(new_balance: int)
signal free_packs_changed(new_free_packs: int)

# on_complete (optionnel) est appelé avec (success: bool) une fois la réponse
# reçue — permet à l'écran de chargement d'attendre la fin de la sync.
func sync_from_backend(on_complete: Callable = Callable()) -> void:
	BackendClient.request(HTTPClient.METHOD_GET, "/api/currency/balance", {}, func(code: int, parsed) -> void:
		var success := code == 200 and parsed is Dictionary
		if success:
			is_synced = true
			_set_balance(int(parsed.get("balance", balance)))
			_set_free_packs(int(parsed.get("free_packs", free_packs)))
		if on_complete.is_valid():
			on_complete.call(success)
	)

# Achète `quantity` packs SANS les ouvrir : débite l'or (PACK_COST * quantity,
# vérifié côté serveur) et crédite `quantity` packs au stock du joueur — même
# compteur free_packs que les packs gagnés gratuitement (quêtes hebdo,
# parrainage, niveau) : une fois en stock, un pack acheté et un pack gagné
# s'ouvrent exactement pareil, voir open_owned_pack ci-dessous. L'achat
# n'ouvre donc plus rien lui-même (voir PackShop.gd/ShopBuyPacksPanel.gd) —
# l'ouverture se fait à part, depuis l'onglet Collection.
func buy_packs(quantity: int, on_complete: Callable = Callable()) -> void:
	BackendClient.request(HTTPClient.METHOD_POST, "/api/packs/buy", {"quantity": quantity}, func(code: int, parsed) -> void:
		var success := code == 200 and parsed is Dictionary
		if success:
			_set_balance(int(parsed.get("balance", balance)))
			_set_free_packs(int(parsed.get("free_packs", free_packs)))
		if on_complete.is_valid():
			on_complete.call(success)
	)

# Ouvre un pack en consommant le stock de packs (achetés en Boutique OU
# gagnés gratuitement — quêtes hebdo, parrainage, voir
# docs/backend-contracts/weekly-quests-and-referral.md), pas directement
# l'or : voir buy_packs ci-dessus. on_complete(code, cards).
func open_owned_pack(on_complete: Callable = Callable()) -> void:
	BackendClient.request(HTTPClient.METHOD_POST, "/api/packs/open-owned", {}, func(code: int, parsed) -> void:
		var cards: Array = []
		if code == 200 and parsed is Dictionary:
			cards = parsed.get("cards", [])
			_set_free_packs(int(parsed.get("free_packs", free_packs)))
		if on_complete.is_valid():
			on_complete.call(code, cards)
	)

# À appeler après un match vs IA (pas de report réseau pour ces matchs) : le
# backend crédite (sans plafond quotidien, montant de victoire dépendant de la
# série en cours — voir CARDS.md/README « Économie ») et renvoie le solde à
# jour. on_complete(credited, reward) : reward est le montant réellement
# crédité, à afficher tel quel (aucune constante d'affichage statique côté
# client, voir commentaire au-dessus de PACK_COST).
func report_solo_match_result(won: bool, cards_played_by_race: Dictionary = {}, deck_races: Array = [],
		on_complete: Callable = Callable()) -> void:
	var body := {
		"result": "victory" if won else "defeat",
		"cardsPlayedByRace": cards_played_by_race,
		"deckRaces": deck_races,
	}
	BackendClient.request(HTTPClient.METHOD_POST, "/api/rewards/solo-match", body, func(code: int, parsed) -> void:
		var credited := false
		var reward := 0
		if code == 200 and parsed is Dictionary:
			credited = bool(parsed.get("credited", false))
			reward = int(parsed.get("reward", 0))
			_set_balance(int(parsed.get("balance", balance)))
		if on_complete.is_valid():
			on_complete.call(credited, reward)
	)

## Prix affiché pour une carte de la rareté donnée, 0 si non tarifée (ex.
## cartes-ressource, non vendables à l'unité — voir CollectionManager.buy_card).
func card_price(rarity: String) -> int:
	return CARD_PRICE_BY_RARITY.get(rarity, 0)

# Permet à un autre autoload (CollectionManager.buy_card) de répercuter le
# solde renvoyé par un appel réseau qu'il a lui-même déclenché, sans dupliquer
# une requête GET /api/currency/balance juste après.
func apply_balance_update(new_balance: int) -> void:
	_set_balance(new_balance)

func _set_balance(new_balance: int) -> void:
	balance = new_balance
	balance_changed.emit(balance)

func _set_free_packs(new_free_packs: int) -> void:
	free_packs = new_free_packs
	free_packs_changed.emit(free_packs)
