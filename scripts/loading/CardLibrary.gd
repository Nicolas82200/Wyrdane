extends Node

const ALL_CARDS_PATH := "res://resources/cards"

var all_cards: Array[CardData] = []
var is_loaded: bool = false

# Correspondance carte ↔ id numérique côté wyrdane-backend (table `cards`).
# Le seul lien entre les deux mondes est le nom (card_name == cards.name) :
# pas d'id partagé, donc construit une fois par session via /api/cards.
var backend_id_by_path: Dictionary = {}   # resource_path (String) -> int
var card_by_backend_id: Dictionary = {}   # int -> CardData
var backend_synced: bool = false

signal loading_finished
signal backend_catalog_synced(success: bool)

func load_all_cards() -> void:
	if is_loaded:
		return
	all_cards.clear()
	_scan_recursive(ALL_CARDS_PATH)
	all_cards.sort_custom(func(a: CardData, b: CardData) -> bool: return a.cost < b.cost)
	is_loaded = true
	loading_finished.emit()

# Construit backend_id_by_path / card_by_backend_id depuis GET /api/cards.
# Nécessite d'être authentifié (voir BackendClient.login_with_steam).
func sync_backend_catalog(on_complete: Callable = Callable()) -> void:
	if backend_synced:
		if on_complete.is_valid():
			on_complete.call(true)
		return

	BackendClient.request(HTTPClient.METHOD_GET, "/api/cards", {}, func(code: int, parsed) -> void:
		if code != 200 or not (parsed is Array):
			push_warning("CardLibrary : échec sync catalogue backend (HTTP %d)" % code)
			backend_catalog_synced.emit(false)
			if on_complete.is_valid():
				on_complete.call(false)
			return

		var by_name: Dictionary = {}
		for card in all_cards:
			by_name[card.card_name] = card

		for row in parsed:
			var card_name: String = row.get("name", "")
			if not by_name.has(card_name):
				continue
			var card: CardData = by_name[card_name]
			backend_id_by_path[card.resource_path] = row["id"]
			card_by_backend_id[row["id"]] = card

		backend_synced = true
		backend_catalog_synced.emit(true)
		if on_complete.is_valid():
			on_complete.call(true)
	)

## Cartes jouables d'une race donnée. Les jetons (is_token) ne peuvent jamais
## apparaître ici : déjà exclus en amont de all_cards par _scan_recursive.
func get_cards_by_race(race: int, include_resources: bool = false) -> Array[CardData]:
	var result: Array[CardData] = []
	for card in all_cards:
		if card.race != race:
			continue
		if not include_resources and card.card_type == "Resource":
			continue
		result.append(card)
	return result

## Cartes jouables d'une race et d'une rareté données (exclut toujours les
## cartes-ressource).
func get_cards_by_race_and_rarity(race: int, rarity: String) -> Array[CardData]:
	var result: Array[CardData] = []
	for card in get_cards_by_race(race, false):
		if card.rarity == rarity:
			result.append(card)
	return result

func _scan_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := path + "/" + file_name
		if dir.current_is_dir():
			_scan_recursive(full_path)
		elif file_name.ends_with(".tres"):
			var res := load(full_path)
			if res is CardData and not (res as CardData).is_token:
				all_cards.append(res as CardData)
		file_name = dir.get_next()
	dir.list_dir_end()
