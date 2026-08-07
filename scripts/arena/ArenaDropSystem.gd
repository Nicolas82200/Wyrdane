extends Node
class_name ArenaDropSystem

# Remplace DropSystem.gd (pensé pour le mana/ciblage 1v1) comme `drop_system`
# de la main Arena : même contrat que Card.gd attend via `battle.get(
# "drop_system")` (get_player_drop_row_at/get_player_drop_index_at/
# clear_player_drop_highlight/update_player_drop_highlight), avec une rangée
# virtuelle en plus, ROW_SHOP : lâcher une carte de la main sur la boutique la
# vend au lieu de la poser sur le plateau (voir ArenaBattle._on_hand_card_played).
# Le surlignage de dépôt (vert, même couleur que Battle.tscn) ne couvre que
# les deux rangées du joueur (player_front_highlight/player_back_highlight,
# voir ArenaBattle._make_drop_highlight) : la boutique n'a pas de surlignage
# dédié (poser dessus n'a pas de sens, elle sert à vendre).

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

func get_player_drop_index_at(mouse: Vector2, row: String) -> int:
	var container: Control = null
	if row == battle.ROW_FRONT:
		container = battle.player_front_container
	elif row == battle.ROW_BACK:
		container = battle.player_back_container
	if container == null:
		return -1
	var index := 0
	for child in container.get_children():
		var rect: Rect2 = child.get_global_rect()
		if mouse.x < rect.position.x + rect.size.x * 0.5:
			return index
		index += 1
	return index

func update_player_drop_highlight(card_data: CardData, mouse: Vector2, display_show: bool) -> bool:
	var allowed: Array[String] = battle.get_allowed_rows_for_card(card_data)
	var over_front: bool = display_show and battle.ROW_FRONT in allowed \
		and _rect_of(battle.player_front_container).has_point(mouse)
	var over_back: bool = display_show and battle.ROW_BACK in allowed \
		and _rect_of(battle.player_back_container).has_point(mouse)
	battle.player_front_highlight.visible = over_front
	battle.player_back_highlight.visible = over_back
	return over_front or over_back

func clear_player_drop_highlight() -> void:
	battle.player_front_highlight.visible = false
	battle.player_back_highlight.visible = false

func _rect_of(control: Control) -> Rect2:
	if control == null or not is_instance_valid(control):
		return Rect2()
	return control.get_global_rect()
