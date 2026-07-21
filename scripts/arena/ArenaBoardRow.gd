extends HBoxContainer
class_name ArenaBoardRow

# Rangée du plateau joueur (Avant ou Arrière) : reçoit le drop d'une carte de
# boutique (voir ArenaShopCardSlot) et délègue l'achat+pose à ArenaBattle via
# `on_drop`, plutôt que de connaître ArenaMatch/ArenaPlayerState directement.

@export var is_front: bool = true
var on_drop: Callable = Callable()

func _can_drop_data(_at_position: Vector2, data) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("arena_shop_index")

func _drop_data(_at_position: Vector2, data) -> void:
	if on_drop.is_valid():
		on_drop.call(int(data["arena_shop_index"]), is_front)
