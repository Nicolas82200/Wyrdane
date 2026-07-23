# CollectionManager.gd
extends Node

# Collection de cartes débloquées par le joueur, autoritaire côté
# wyrdane-backend (GET /api/collection) — même philosophie que DeckManager :
# pas de cache hors-ligne, seule la dernière sync backend fait foi. Tant
# qu'aucune sync n'a réussi, toute carte est considérée comme non possédée
# (quantité 0), ce qui verrouille prudemment le deck builder plutôt que de
# laisser construire un deck que le serveur refusera à la sauvegarde.

var owned_quantities: Dictionary = {}  # resource_path (String) -> int
var is_synced: bool = false

signal collection_loaded

# À appeler après CardLibrary.sync_backend_catalog() (le mapping id -> carte
# doit exister pour résoudre les cardId renvoyés par l'API vers un resource_path).
# on_complete (optionnel) est appelé avec (success: bool) une fois la réponse
# reçue — permet à l'écran de chargement d'attendre la fin de la sync.
func sync_from_backend(on_complete: Callable = Callable()) -> void:
	BackendClient.request(HTTPClient.METHOD_GET, "/api/collection", {}, func(code: int, parsed) -> void:
		if code != 200 or not (parsed is Array):
			if on_complete.is_valid():
				on_complete.call(false)
			return
		owned_quantities.clear()
		for row in parsed:
			var card: CardData = CardLibrary.card_by_backend_id.get(row.get("id"), null)
			if card == null:
				continue
			owned_quantities[card.resource_path] = int(row.get("quantity", 0))
		is_synced = true
		collection_loaded.emit()
		if on_complete.is_valid():
			on_complete.call(true)
	)

func owned_quantity(card_data: CardData) -> int:
	if card_data == null:
		return 0
	return owned_quantities.get(card_data.resource_path, 0)

func is_owned(card_data: CardData) -> bool:
	return owned_quantity(card_data) > 0

## Achète un exemplaire de card_data à l'unité (boutique du deckbuilder, prix
## par rareté — voir CurrencyManager.card_price). Le prix réel est appliqué et
## vérifié côté serveur (POST /api/collection/buy-card). on_complete est
## appelé avec (success: bool) une fois la réponse reçue.
func buy_card(card_data: CardData, on_complete: Callable = Callable()) -> void:
	var backend_id: int = CardLibrary.backend_id_by_path.get(card_data.resource_path, -1)
	if backend_id == -1:
		if on_complete.is_valid():
			on_complete.call(false)
		return

	BackendClient.request(HTTPClient.METHOD_POST, "/api/collection/buy-card", {"cardId": backend_id}, func(code: int, parsed) -> void:
		var success := code == 200 and parsed is Dictionary
		if success:
			owned_quantities[card_data.resource_path] = int(parsed.get("quantity", 0))
			CurrencyManager.apply_balance_update(int(parsed.get("balance", CurrencyManager.balance)))
			collection_loaded.emit()
		if on_complete.is_valid():
			on_complete.call(success)
	)
