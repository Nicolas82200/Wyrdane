extends Node

var battle
var player_enchantments: Array[CardData] = []
var enemy_enchantments:  Array[CardData] = []

const ENCHANTMENT_CARD_SCENE = preload("res://scenes/card/enchantment/EnchantmentCard.tscn")

func init(_battle) -> void:
	battle = _battle

# ─── Ajout / Suppression (visuel uniquement) ──────────────────────────────────
# L'exécution des effets est gérée par TriggerSystem

func add_enchantment(card_data: CardData, is_player: bool) -> void:
	var zone: VBoxContainer = battle.player_enchantment_zone if is_player else battle.enemy_enchantment_zone
	if is_player:
		player_enchantments.append(card_data)
	else:
		enemy_enchantments.append(card_data)
	if zone == null:
		push_warning("EnchantmentSystem: zone null pour is_player=%s" % str(is_player))
		return
	var visual = ENCHANTMENT_CARD_SCENE.instantiate()
	zone.add_child(visual)
	visual.setup(card_data, is_player)

func remove_enchantment(card_data: CardData, is_player: bool) -> void:
	var zone: VBoxContainer = battle.player_enchantment_zone if is_player else battle.enemy_enchantment_zone
	var list: Array[CardData] = player_enchantments if is_player else enemy_enchantments
	list.erase(card_data)
	# Synchronise aussi le TriggerSystem
	battle.trigger_system.unregister_enchantment(card_data, is_player)
	if zone == null:
		return
	for child in zone.get_children():
		if child.has_method("setup") and child.card_data == card_data:
			child.queue_free()
			return

func get_enchantments(is_player: bool) -> Array[CardData]:
	return player_enchantments if is_player else enemy_enchantments

func has_enchantment(card_name: String, is_player: bool) -> bool:
	for enc in get_enchantments(is_player):
		if enc.card_name == card_name:
			return true
	return false
