# Graveyard.gd
extends RefCounted
class_name Graveyard

enum Origin { MINION_DEATH, SPELL_PLAYED, CARD_DISCARDED }

signal graveyard_changed

var entries: Array[Dictionary] = []

func add_minion(card_data: CardData) -> void:
	_add(card_data, Origin.MINION_DEATH)

func add_spell(card_data: CardData) -> void:
	_add(card_data, Origin.SPELL_PLAYED)

func add_discarded(card_data: CardData) -> void:
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

# Appelée par EffectManager (_resurrect, _resurrect_last, _return_from_grave)
# Retourne uniquement les cartes mortes au combat, pas les sorts ni les défausses
func get_minions() -> Array[CardData]:
	var result: Array[CardData] = []
	for entry in entries:
		if entry["origin"] == Origin.MINION_DEATH:
			result.append(entry["card_data"])
	return result

# Retire du cimetière la carte ramenée en jeu/en main par un effet de résurrection
# (_resurrect, _resurrect_last, _resurrect_self, _return_from_grave,
# _resurrect_chosen_from_grave) : une carte ramenée ne doit plus pouvoir être
# ramenée une seconde fois ni rester listée comme morte. Retire l'entrée
# MINION_DEATH la plus récente correspondant à ce card_data (cohérent avec la
# sélection "dernier mort" faite par les appelants).
func remove_minion(card_data: CardData) -> void:
	for i in range(entries.size() - 1, -1, -1):
		if entries[i]["origin"] == Origin.MINION_DEATH and entries[i]["card_data"] == card_data:
			entries.remove_at(i)
			graveyard_changed.emit()
			return
