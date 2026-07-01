# DeckManager.gd
extends Node

const SAVE_PATH := "user://decks.cfg"

# [NOTE] Vérifier laquelle est la bonne limite — DeckBuilder avait MAX_CARDS = 60
# Ces constantes doivent être cohérentes entre DeckManager et DeckBuilder
const MAX_CARDS_PER_DECK   := 60
const MAX_COPIES_PER_CARD  := 4

var decks: Array[DeckData] = []
var active_deck_index: int = 0

func _ready() -> void:
	load_decks()

# ─── Deck actif ───────────────────────────────────────────────────────────────

func get_active_deck() -> DeckData:
	if decks.is_empty():
		return null
	active_deck_index = clamp(active_deck_index, 0, decks.size() - 1)
	return decks[active_deck_index]

func set_active_deck(index: int) -> void:
	active_deck_index = clamp(index, 0, decks.size() - 1)
	# [FIX] _save_meta supprimé — save_decks() suffit, pas besoin de recharger le fichier
	save_decks()

# ─── CRUD ─────────────────────────────────────────────────────────────────────

func create_deck(deck_name: String = "Nouveau Deck") -> DeckData:
	var deck := DeckData.new()
	deck.name = deck_name
	decks.append(deck)
	save_decks()
	return deck

func delete_deck(index: int) -> void:
	if index < 0 or index >= decks.size():
		return
	decks.remove_at(index)
	if active_deck_index >= decks.size():
		active_deck_index = max(0, decks.size() - 1)
	save_decks()

func can_add_card(deck: DeckData, card_data: CardData) -> bool:
	if deck.size() >= MAX_CARDS_PER_DECK:
		return false
	var count := 0
	for path in deck.card_paths:
		if path == card_data.resource_path:
			count += 1
	return count < MAX_COPIES_PER_CARD

# ─── Sauvegarde ───────────────────────────────────────────────────────────────

func save_decks() -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "active_deck_index", active_deck_index)
	config.set_value("meta", "deck_count", decks.size())
	for i in range(decks.size()):
		var dict := decks[i].to_dict()
		config.set_value("deck_%d" % i, "name",       dict["name"])
		config.set_value("deck_%d" % i, "card_paths", dict["card_paths"])
	config.save(SAVE_PATH)

func load_decks() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	active_deck_index = config.get_value("meta", "active_deck_index", 0)
	var deck_count: int = config.get_value("meta", "deck_count", 0)
	decks.clear()
	for i in range(deck_count):
		var dict := {
			"name":       config.get_value("deck_%d" % i, "name",       "Deck"),
			"card_paths": config.get_value("deck_%d" % i, "card_paths", [])
		}
		decks.append(DeckData.from_dict(dict))
