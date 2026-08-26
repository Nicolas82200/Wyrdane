extends HBoxContainer
class_name ArenaSellZone

# Rangée de boutique (Avant ou Arrière) : en plus d'accueillir les offres à
# acheter (ArenaShopCardSlot, glissées vers le plateau), elle accepte aussi le
# drop d'un serviteur déjà sur le plateau (voir ArenaBoardMinionSlot) pour le
# vendre — glisser une carte sur la boutique est le seul moyen de vendre,
# il n'y a plus de bouton dédié.

var on_sell: Callable = Callable()

func _can_drop_data(_at_position: Vector2, data) -> bool:
	return on_sell.is_valid() and typeof(data) == TYPE_DICTIONARY and data.has("arena_board_minion")

func _drop_data(_at_position: Vector2, data) -> void:
	if on_sell.is_valid():
		on_sell.call(data["arena_board_minion"])
