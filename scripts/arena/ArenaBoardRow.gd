extends HBoxContainer
class_name ArenaBoardRow

# Rangée du plateau joueur (Avant ou Arrière) : reçoit soit le drop d'une carte
# de boutique (voir ArenaShopCardSlot -> `on_drop`, achat+pose), soit le drop
# d'un serviteur déjà sur CETTE MÊME ligne (voir ArenaBoardMinionSlot ->
# `on_reposition`) pour changer son emplacement au sein de la ligne — pas de
# changement de ligne (le joueur choisit la ligne à la pose, pas ensuite).
# Délégués à ArenaBattle plutôt que de connaître ArenaMatch/ArenaPlayerState
# directement.

@export var is_front: bool = true
var on_drop: Callable = Callable()
var on_reposition: Callable = Callable()

func _can_drop_data(_at_position: Vector2, data) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if data.has("arena_shop_index"):
		return on_drop.is_valid()
	if data.has("arena_board_minion"):
		var dragged: Minion = data["arena_board_minion"]
		var own_row: bool = dragged.board_row == ("Front" if is_front else "Back")
		return on_reposition.is_valid() and own_row
	return false  # plateau d'un autre joueur consulté en lecture seule (scoutage)

func _drop_data(at_position: Vector2, data) -> void:
	if data.has("arena_shop_index") and on_drop.is_valid():
		on_drop.call(int(data["arena_shop_index"]), is_front)
	elif data.has("arena_board_minion") and on_reposition.is_valid():
		var dragged: Minion = data["arena_board_minion"]
		on_reposition.call(dragged, is_front, _index_for_drop(at_position, dragged))

# `at_position` est déjà en coordonnées locales à cette rangée (contrat de
# Control._drop_data) : comparable directement à la position des enfants.
func _index_for_drop(at_position: Vector2, dragged: Minion) -> int:
	var index := 0
	for child in get_children():
		if child is ArenaBoardMinionSlot and child.minion != dragged:
			if at_position.x < child.position.x + child.size.x * 0.5:
				return index
			index += 1
	return index
