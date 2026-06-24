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
