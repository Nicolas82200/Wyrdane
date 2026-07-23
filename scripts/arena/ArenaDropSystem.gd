extends Node
class_name ArenaDropSystem

# Remplace DropSystem.gd (pensé pour le mana/ciblage 1v1) comme `drop_system`
# de la main Arena : même contrat que Card.gd attend via `battle.get(
# "drop_system")` (get_player_drop_row_at/get_player_drop_index_at/
# clear_player_drop_highlight/update_player_drop_highlight), avec une rangée
# virtuelle en plus, ROW_SHOP : lâcher une carte de la main sur la boutique la
# vend au lieu de la poser sur le plateau (voir ArenaBattle._on_hand_card_played).
# Pas de surlignage de dépôt (update_player_drop_highlight ne fait rien) —
# simplification acceptée pour ce prototype.

const ROW_SHOP := "Shop"

var battle: Node

func init(_battle: Node) -> void:
	battle = _battle

func get_player_drop_row_at(mouse: Vector2, card_data: CardData = null) -> String:
	if _rect_of(battle.shop_front_row).has_point(mouse) or _rect_of(battle.shop_back_row).has_point(mouse):
		return ROW_SHOP
	var allowed: Array[String] = battle.get_allowed_rows_for_card(card_data)
	if _rect_of(battle.player_front_container).has_point(mouse):
		return battle.ROW_FRONT if battle.ROW_FRONT in allowed else ""
	if _rect_of(battle.player_back_container).has_point(mouse):
		return battle.ROW_BACK if battle.ROW_BACK in allowed else ""
	return ""

func get_player_drop_index_at(_mouse: Vector2, _row: String) -> int:
	return -1

func update_player_drop_highlight(_card_data: CardData, _mouse: Vector2, _display_show: bool) -> bool:
	return false

func clear_player_drop_highlight() -> void:
	pass

func _rect_of(control: Control) -> Rect2:
	if control == null or not is_instance_valid(control):
		return Rect2()
	return control.get_global_rect()
