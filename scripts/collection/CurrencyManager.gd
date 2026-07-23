# CurrencyManager.gd
extends Node

# Solde de monnaie molle (gagnée en jouant, dépensée en packs), autoritaire
# côté wyrdane-backend — même philosophie que CollectionManager : pas de
# cache hors-ligne, seule la dernière sync backend fait foi.

# Affiché à titre indicatif dans l'UI ; le coût réel est appliqué et vérifié
# côté serveur (voir PACK_COST dans wyrdane-backend/backend/src/model/packModel.ts).
const PACK_COST := 500
# Doivent rester synchronisées avec SOLO_WIN_REWARD/SOLO_DEFEAT_REWARD côté
# wyrdane-backend/backend/src/controller/rewardsController.ts.
const SOLO_WIN_REWARD_DISPLAY := 25
const SOLO_DEFEAT_REWARD_DISPLAY := 10

# Prix d'achat à l'unité dans le deckbuilder, par rareté — affiché à titre
# indicatif ; le prix réel est appliqué et vérifié côté serveur (voir
# CARD_PRICE_BY_RARITY dans wyrdane-backend/backend/src/model/collectionModel.ts).
const CARD_PRICE_BY_RARITY := {
	"Common": 100,
	"Rare": 150,
	"Epic": 200,
	"Legendary": 250,
}

var balance: int = 0
var is_synced: bool = false

signal balance_changed(new_balance: int)

func sync_from_backend() -> void:
	BackendClient.request(HTTPClient.METHOD_GET, "/api/currency/balance", {}, func(code: int, parsed) -> void:
		if code != 200 or not (parsed is Dictionary):
			return
		is_synced = true
		_set_balance(int(parsed.get("balance", balance)))
	)

# À appeler après une victoire vs IA (pas de report réseau pour ces matchs) :
# le backend crédite (plafonné par jour) et renvoie le solde à jour.
func report_solo_match_result(won: bool, on_complete: Callable = Callable()) -> void:
	var body := {"result": "victory" if won else "defeat"}
	BackendClient.request(HTTPClient.METHOD_POST, "/api/rewards/solo-match", body, func(code: int, parsed) -> void:
		var credited := false
		if code == 200 and parsed is Dictionary:
			credited = bool(parsed.get("credited", false))
			_set_balance(int(parsed.get("balance", balance)))
		if on_complete.is_valid():
			on_complete.call(credited)
	)

# Ouvre un pack (coût fixe côté serveur) : renvoie les cartes tirées (tableau
# de dictionnaires bruts backend, avec au moins "id") au callback, vide si échec.
func open_pack(on_complete: Callable = Callable()) -> void:
	BackendClient.request(HTTPClient.METHOD_POST, "/api/packs/open", {}, func(code: int, parsed) -> void:
		var cards: Array = []
		if code == 200 and parsed is Dictionary:
			cards = parsed.get("cards", [])
			_set_balance(int(parsed.get("balance", balance)))
		if on_complete.is_valid():
			on_complete.call(code, cards)
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
