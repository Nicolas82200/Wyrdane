class_name DeckData

var name: String = "Nouveau Deck"
var card_paths: Array[String] = []

func to_dict() -> Dictionary:
	return {
		"name": name,
		"card_paths": card_paths
	}

static func from_dict(dict: Dictionary) -> DeckData:
	var deck := DeckData.new()
	deck.name = dict.get("name", "Deck")
	deck.card_paths = Array(dict.get("card_paths", []), TYPE_STRING, "", null)
	return deck

func get_cards() -> Array[CardData]:
	var cards: Array[CardData] = []
	for path in card_paths:
		var card := load(path) as CardData
		if card:
			cards.append(card)
	return cards

func add_card(card_data: CardData) -> void:
	card_paths.append(card_data.resource_path)

func remove_card_at(index: int) -> void:
	card_paths.remove_at(index)

func size() -> int:
	return card_paths.size()

## Encode le deck en un code texte (nom + chemins des cartes) partageable.
func to_code() -> String:
	var lines: Array[String] = [name]
	lines.append_array(card_paths)
	return Marshalls.utf8_to_base64("\n".join(lines))

## Décode un code généré par to_code(). Retourne null si le code est invalide
## ou si aucune des cartes référencées n'existe plus.
static func from_code(code: String) -> DeckData:
	var raw := Marshalls.base64_to_utf8(code.strip_edges())
	if raw == "":
		return null
	var lines := raw.split("\n")
	if lines.is_empty():
		return null
	var deck := DeckData.new()
	deck.name = lines[0]
	var paths: Array[String] = []
	var copies: Dictionary = {}
	for i in range(1, lines.size()):
		var path := lines[i]
		if path == "" or not ResourceLoader.exists(path, "CardData"):
			continue
		var card := load(path) as CardData
		if card == null:
			continue
		if card.card_type != "Resource" and copies.get(path, 0) >= DeckManager.MAX_COPIES_PER_CARD:
			continue
		copies[path] = copies.get(path, 0) + 1
		paths.append(path)
	if paths.is_empty():
		return null
	deck.card_paths = paths
	return deck
