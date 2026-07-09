extends Node

var battle
var player_enchantments: Array[CardData] = []
var enemy_enchantments:  Array[CardData] = []
var player_rituals: Array[CardData] = []
var enemy_rituals:  Array[CardData] = []

const ENCHANTMENT_CARD_SCENE = preload("res://scenes/card/enchantment/EnchantmentCard.tscn")

# Largeur d'une carte posée et espacement par défaut dans les zones
const CARD_WIDTH := 100.0
const DEFAULT_SEPARATION := 10
# Marge intérieure pour que les bordures noires ne touchent pas le cadre de la zone
const ZONE_PADDING := 20.0

func init(_battle) -> void:
	battle = _battle

# ─── Zones ────────────────────────────────────────────────────────────────────
# Les Enchantements et les Rituels à durée partagent le même visuel mais
# chacun sa bande (colonne de droite du board, façon lignes de serviteurs).

func _zone_for(card_data: CardData, is_player: bool) -> HBoxContainer:
	if card_data.card_type == "Ritual":
		return battle.player_ritual_zone if is_player else battle.enemy_ritual_zone
	return battle.player_enchantment_zone if is_player else battle.enemy_enchantment_zone

func _list_for(card_data: CardData, is_player: bool) -> Array[CardData]:
	if card_data.card_type == "Ritual":
		return player_rituals if is_player else enemy_rituals
	return player_enchantments if is_player else enemy_enchantments

# ─── Ajout / Suppression (visuel uniquement) ──────────────────────────────────
# L'exécution des effets est gérée par TriggerSystem

func add_enchantment(card_data: CardData, is_player: bool) -> void:
	_add_card(card_data, is_player, 0)

func add_ritual(card_data: CardData, is_player: bool, duration: int) -> void:
	_add_card(card_data, is_player, duration)

func _add_card(card_data: CardData, is_player: bool, duration: int) -> void:
	var zone: HBoxContainer = _zone_for(card_data, is_player)
	_list_for(card_data, is_player).append(card_data)
	if zone == null:
		push_warning("EnchantmentSystem: zone null pour is_player=%s" % str(is_player))
		return
	var visual = ENCHANTMENT_CARD_SCENE.instantiate()
	zone.add_child(visual)
	visual.setup(card_data, is_player)
	visual.activate_requested.connect(_on_card_activate_requested)
	if duration > 0:
		visual.set_turns_left(duration)
	_relayout(zone)
	refresh_activatable()

# Clic sur un rituel posé : demande d'activation (Rituels de Sacrifice)
func _on_card_activate_requested(card_data: CardData, is_player: bool) -> void:
	battle.sacrifice_system.try_begin(card_data, is_player)

# Met à jour la surbrillance "activable" des rituels posés (Sacrifice possible)
func refresh_activatable() -> void:
	for zone in [battle.player_ritual_zone, battle.enemy_ritual_zone,
			battle.player_enchantment_zone, battle.enemy_enchantment_zone]:
		if zone == null:
			continue
		for child in zone.get_children():
			if child.has_method("set_activatable") and not child.is_queued_for_deletion():
				child.set_activatable(
					battle.sacrifice_system.can_activate(child.card_data, child.is_player))

func remove_enchantment(card_data: CardData, is_player: bool) -> void:
	var zone: HBoxContainer = _zone_for(card_data, is_player)
	_list_for(card_data, is_player).erase(card_data)
	# Synchronise aussi le TriggerSystem
	battle.trigger_system.unregister_enchantment(card_data, is_player)
	if zone == null:
		return
	for child in zone.get_children():
		if child.has_method("setup") and child.card_data == card_data:
			child.queue_free()
			break
	_relayout(zone)

# Resserre les cartes (séparation négative = chevauchement) pour que la bande
# puisse en accumuler sans jamais déborder de son cadre.
func _relayout(zone: HBoxContainer) -> void:
	var count := 0
	for child in zone.get_children():
		if not child.is_queued_for_deletion():
			count += 1
	if count <= 1:
		zone.add_theme_constant_override("separation", DEFAULT_SEPARATION)
		return
	var available := zone.custom_minimum_size.x - ZONE_PADDING
	var separation := int(floor((available - count * CARD_WIDTH) / float(count - 1)))
	zone.add_theme_constant_override("separation", clampi(separation, -int(CARD_WIDTH) + 20, DEFAULT_SEPARATION))

# Destruction : retire du jeu, envoie au cimetière et recalcule les auras.
# À utiliser pour toute sortie de jeu (effet "détruire enchantement", expiration...)
func destroy_enchantment(card_data: CardData, is_player: bool) -> void:
	remove_enchantment(card_data, is_player)
	var graveyard: Graveyard = battle.player_graveyard if is_player else battle.enemy_graveyard
	graveyard.add_spell(card_data)
	battle.aura_system.recompute_all()
	battle.board_visual_system.refresh_board()

# Met à jour le compteur "X tours" affiché sur un rituel à durée limitée
func update_turns_left(card_data: CardData, is_player: bool, turns: int) -> void:
	var zone: HBoxContainer = _zone_for(card_data, is_player)
	if zone == null:
		return
	for child in zone.get_children():
		if child.has_method("set_turns_left") and child.card_data == card_data:
			child.set_turns_left(turns)
			return

func get_enchantments(is_player: bool) -> Array[CardData]:
	return player_enchantments if is_player else enemy_enchantments

func get_rituals(is_player: bool) -> Array[CardData]:
	return player_rituals if is_player else enemy_rituals

func has_enchantment(card_name: String, is_player: bool) -> bool:
	for enc in get_enchantments(is_player):
		if enc.card_name == card_name:
			return true
	return false
