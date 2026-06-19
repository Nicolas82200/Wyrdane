extends RefCounted
class_name Graveyard

enum Origin { MINION_DEATH, SPELL_PLAYED, CARD_DISCARDED }

signal graveyard_changed

var entries: Array[Dictionary] = []

func add_minion(card_data: CardData) -> void:
	_add(card_data, Origin.MINION_DEATH)

func add_spell(card_data: CardData) -> void:
	_add(card_data, Origin.SPELL_PLAYED)

func add_discard(card_data: CardData) -> void:
	_add(card_data, Origin.CARD_DISCARDED)

func _add(card_data: CardData, origin: Origin) -> void:
	entries.append({ "card_data": card_data, "origin": origin })
	graveyard_changed.emit()

func size() -> int:
	return entries.size()

func is_face_down(entry: Dictionary) -> bool:
	return entry["origin"] == Origin.CARD_DISCARDED

func last_card_data() -> CardData:
	if entries.is_empty():
		return null
	return entries.back()["card_data"]
