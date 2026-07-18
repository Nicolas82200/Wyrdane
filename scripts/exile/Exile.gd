# Exile.gd
# Zone sans retour : contrairement au Cimetière, aucun effet ne doit jamais
# lire `entries` pour ramener une carte en jeu. Utilisée pour l'instant par
# les cartes-ressource consommées (voir Battle.play_resource_card).
extends RefCounted
class_name Exile

enum Origin { RESOURCE_PLAYED }

signal exile_changed

var entries: Array[Dictionary] = []

func add_resource(card_data: CardData) -> void:
	_add(card_data, Origin.RESOURCE_PLAYED)

func _add(card_data: CardData, origin: Origin) -> void:
	entries.append({ "card_data": card_data, "origin": origin })
	exile_changed.emit()

func size() -> int:
	return entries.size()
