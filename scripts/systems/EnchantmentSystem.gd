# res://scripts/enchantment/EnchantmentSystem.gd
extends Node

const ENCHANTMENT_CARD_SCENE = preload("res://scenes/card/enchantment/EnchantmentCard.tscn")

var battle
var player_enchantments: Array[CardData] = []
var enemy_enchantments:  Array[CardData] = []

func init(_battle) -> void:
	battle = _battle

func add_enchantment(card_data: CardData, is_player: bool) -> void:
	var zone: VBoxContainer
	if is_player:
		player_enchantments.append(card_data)
		zone = battle.player_enchantment_zone
	else:
		enemy_enchantments.append(card_data)
		zone = battle.enemy_enchantment_zone
	if zone == null:
		push_warning("EnchantmentSystem: zone null pour is_player=%s" % str(is_player))
		return
	var visual = ENCHANTMENT_CARD_SCENE.instantiate()
	zone.add_child(visual)
	visual.setup(card_data, is_player)

func remove_enchantment(card_data: CardData, is_player: bool) -> void:
	var zone: VBoxContainer
	var list: Array[CardData]
	if is_player:
		zone = battle.player_enchantment_zone
		list = player_enchantments
	else:
		zone = battle.enemy_enchantment_zone
		list = enemy_enchantments
	list.erase(card_data)
	if zone == null:
		return
	for child in zone.get_children():
		if child.has_method("setup") and child.card_data == card_data:
			child.queue_free()
			return

func get_enchantments(is_player: bool) -> Array[CardData]:
	return player_enchantments if is_player else enemy_enchantments

func trigger_on_event(event: String, is_player: bool) -> void:
	for enc in get_enchantments(is_player):
		for trigger in enc.trigger_types:
			if trigger.type == event:
				for effect in enc.effects:
					battle.effect_manager.execute_effect(battle, null, effect)

func trigger_on_turn_start(is_player: bool) -> void:
	trigger_on_event("ONTURNSTART", is_player)

func trigger_on_turn_end(is_player: bool) -> void:
	trigger_on_event("ONTURNEND", is_player)

func has_enchantment(card_name: String, is_player: bool) -> bool:
	for enc in get_enchantments(is_player):
		if enc.card_name == card_name:
			return true
	return false
