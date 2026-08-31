extends Node
class_name TargetingSystem

signal targeting_cancelled
signal target_selected(target)

var battle
var _active: bool = false
var _trigger_mode: bool = false
var _pending_card: CardData = null
var _pending_row: String = "Front"
var _pending_insert_index: int = -1
var _highlighted: Array[Control] = []
var _arrow: ArrowOverlay = null
var _origin_node: Control = null  # nœud de départ de la flèche (la carte jouée)

const HIGHLIGHT_COLOR      := Color(1.0, 0.85, 0.1, 0.55)
const HIGHLIGHT_ENEMY_COLOR := Color(1.0, 0.3, 0.3, 0.55)
const HIGHLIGHT_ALLY_COLOR  := Color(0.3, 0.8, 1.0, 0.55)

func init(_battle) -> void:
	battle = _battle
	_arrow = ArrowOverlay.new()
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 10
	battle.add_child(canvas_layer)
	canvas_layer.add_child(_arrow)
func is_targeting() -> bool:
	return _active

func is_trigger_targeting() -> bool:
	return _trigger_mode

# Ciblage à froid pour un effet déclenché en cours de partie (ex: Dernier
# Souffle de Charognard Putride), en dehors de toute pose de carte depuis la
# main. Pas de flèche (le serviteur source n'a déjà plus de visuel), juste les
# cibles valides en surbrillance ; ne peut pas être annulé (la mort a déjà eu
# lieu, il n'y a rien à défaire).
func prompt_trigger_target(card_data: CardData) -> Minion:
	_pending_card = card_data
	_trigger_mode = true
	_active       = true
	_show_valid_targets(card_data)
	var result = await target_selected
	return result

func begin_targeting(card_data: CardData, row: String, insert_index: int, origin: Control = null) -> void:
	# Un attaquant/groupe d'attaquants deja selectionne accepterait un clic
	# destine au ciblage du sort comme un ordre d'attaque (meme cible cliquee).
	battle.selection_system.clear_selection()
	_pending_card         = card_data
	_pending_row          = row
	_pending_insert_index = insert_index
	_origin_node          = origin
	_active               = true
	_show_valid_targets(card_data)
	_arrow.show_arrow(Vector2.ZERO, Vector2.ZERO)  # ← initialise visible dès le début
	battle.set_process(true)

func update_arrow() -> void:
	if not _active or _arrow == null:
		return
	# Départ = bord droit de la popup de ciblage
	var from: Vector2 = battle.card_popup_system.get_targeting_popup_tip()
	if from == Vector2.ZERO:
		# Fallback si pas de popup
		if _origin_node and is_instance_valid(_origin_node):
			from = _origin_node.global_position + _origin_node.size * 0.5
		else:
			from = battle.get_viewport().get_mouse_position() - Vector2(0, 80)
	var to: Vector2 = battle.get_viewport().get_mouse_position()
	_arrow.show_arrow(from, to)

# ─── Clicks ───────────────────────────────────────────────────────────────────

func on_enemy_minion_clicked(minion: Minion, visual: BoardMinion) -> void:
	if not _active:
		return
	if not _is_valid_target_minion(minion, _pending_card):
		return
	# Flèche pointe vers le centre du visual au moment du clic
	var to: Vector2 = visual.global_position + visual.size * 0.5
	_snap_arrow_to(to)
	_finish(minion)

func on_ally_minion_clicked(minion: Minion, visual: BoardMinion) -> void:
	if not _active:
		return
	if not _is_valid_target_minion(minion, _pending_card):
		return
	var to: Vector2 = visual.global_position + visual.size * 0.5
	_snap_arrow_to(to)
	_finish(minion)

func on_enchantment_clicked(card_data: CardData, is_player: bool, visual: Control) -> void:
	if not _active:
		return
	if not _is_valid_target_enchantment(card_data, is_player, _pending_card):
		return
	if visual and is_instance_valid(visual):
		_snap_arrow_to(visual.global_position + visual.size * 0.5)
	_finish(card_data)

func on_enemy_hero_clicked() -> void:
	if not _active:
		return
	var target_str := _pending_card.effects[0].target if _pending_card and _pending_card.effects.size() > 0 else ""
	if target_str not in ["EnemyHero", "AnyMinion"]:
		return
	var hero_panel: Control = battle.get_node("EnemyHeroPanel")
	if hero_panel:
		_snap_arrow_to(hero_panel.global_position + hero_panel.size * 0.5)
	_finish(battle.enemy_hero)

# ─── Interne ──────────────────────────────────────────────────────────────────

func _snap_arrow_to(to: Vector2) -> void:
	if _origin_node and is_instance_valid(_origin_node):
		_arrow.show_arrow(
			_origin_node.global_position + _origin_node.size * 0.5,
			to
		)

func _finish(target) -> void:
	_active = false
	_clear_highlights()
	_arrow.hide_arrow()
	battle.set_process(false)
	if _trigger_mode:
		_trigger_mode = false
		_pending_card = null
		target_selected.emit(target)
		return
	# ← Cache la popup de ciblage
	battle.card_popup_system.hide_targeting_popup()
	var card   := _pending_card
	var row    := _pending_row
	var index  := _pending_insert_index
	_pending_card = null
	_origin_node  = null
	battle.card_system.resolve_with_target(card, row, index, target)
	target_selected.emit(target)

func cancel() -> void:
	if not _active:
		return
	_active = false
	_pending_card = null
	_origin_node  = null
	_clear_highlights()
	_arrow.hide_arrow()
	battle.set_process(false)
	# ← Cache la popup si annulation
	battle.card_popup_system.hide_targeting_popup()
	targeting_cancelled.emit()

func _show_valid_targets(card_data: CardData) -> void:
	_clear_highlights()
	# La flèche de ciblage reste toujours affichée ; seules les surbrillances
	# des cibles valides sont conditionnées par le réglage d'affichage.
	if not SettingsManager.show_play_highlights:
		return
	if card_data == null or card_data.effects.is_empty():
		return
	var target_str: String = card_data.effects[0].target
	match target_str:
		"EnemyMinion":
			_highlight_side(battle.enemy_minions, HIGHLIGHT_ENEMY_COLOR, card_data)
		"AllyMinion":
			_highlight_side(battle.player_minions, HIGHLIGHT_ALLY_COLOR, card_data)
		"AnyMinion":
			_highlight_side(battle.enemy_minions, HIGHLIGHT_ENEMY_COLOR, card_data)
			_highlight_side(battle.player_minions, HIGHLIGHT_ALLY_COLOR, card_data)
		"EnemyHero":
			_highlight_hero(false)
		"OwnerHero":
			_highlight_hero(true)
		"EnemyEnchantment":
			_highlight_enchantment_side(false, HIGHLIGHT_ENEMY_COLOR)
		"AllyEnchantment":
			_highlight_enchantment_side(true, HIGHLIGHT_ALLY_COLOR)
		"AnyEnchantment":
			_highlight_enchantment_side(false, HIGHLIGHT_ENEMY_COLOR)
			_highlight_enchantment_side(true, HIGHLIGHT_ALLY_COLOR)

func _highlight_side(minions: Array[Minion], color: Color, card_data: CardData) -> void:
	for minion in minions:
		if _is_valid_target_minion(minion, card_data):
			_highlight_minion(minion, color)

func _highlight_minion(minion: Minion, color: Color) -> void:
	var visual: BoardMinion = battle.board_visual_system.find_visual(minion) as BoardMinion
	if visual == null or not is_instance_valid(visual):
		return
	visual.set_targetable(true, color)
	_highlighted.append(visual)

func _highlight_hero(is_player: bool) -> void:
	var panel: Control = battle.get_node("PlayerHeroPanel") if is_player else battle.get_node("EnemyHeroPanel")
	if panel == null:
		return
	panel.modulate = HIGHLIGHT_ENEMY_COLOR
	_highlighted.append(panel)

func _highlight_enchantment_side(is_player: bool, color: Color) -> void:
	var cards: Array[CardData] = battle.enchantment_system.get_enchantments(is_player) \
			+ battle.enchantment_system.get_rituals(is_player)
	for card_data in cards:
		var visual: Control = battle.enchantment_system.find_visual(card_data, is_player)
		if visual == null or not is_instance_valid(visual):
			continue
		visual.modulate = color
		_highlighted.append(visual)

func _clear_highlights() -> void:
	for node in _highlighted:
		if not is_instance_valid(node):
			continue
		if node is BoardMinion:
			(node as BoardMinion).set_targetable(false, Color.WHITE)
		else:
			node.modulate = Color.WHITE
	_highlighted.clear()

# Rempart ne restreint que les ATTAQUES (SelectionSystem/CombatSystem),
# pas le ciblage des sorts et effets.
func _is_valid_target_minion(minion: Minion, card_data: CardData) -> bool:
	if card_data == null or card_data.effects.is_empty():
		return false
	var effect: CardEffect = card_data.effects[0]
	match effect.target:
		"EnemyMinion":
			if minion.owner_is_player:
				return false
		"AllyMinion":
			if not minion.owner_is_player:
				return false
		"AnyMinion":
			pass
		_:
			return false
	# Assassin Décharné / Éclaireur Infiltré : intargetable par les sorts
	# ennemis (pas par les effets d'invocation de serviteurs).
	if minion.spell_immune and not minion.owner_is_player \
			and card_data.card_type in ["Instant", "Ritual"]:
		return false
	return _matches_effect_conditions(minion, effect)

# Conditions déclarées sur l'effet : race, rangée, seuils de HP/ATK
# ("un serviteur ennemi de 3 HP ou moins", "un Mort-Vivant allié"...)
func _matches_effect_conditions(minion: Minion, effect: CardEffect) -> bool:
	if not effect.race_filter.is_empty() \
			and (minion.card_data.race == Race.from_string(effect.race_filter)) == effect.race_filter_exclude:
		return false
	if not effect.row_filter.is_empty() and minion.board_row != effect.row_filter:
		return false
	if effect.target_max_hp >= 0 and minion.health > effect.target_max_hp:
		return false
	if effect.target_max_atk >= 0 and minion.attack > effect.target_max_atk:
		return false
	if effect.requires_resurrected_target and not minion.was_resurrected:
		return false
	if effect.exclude_legendary and minion.card_data.rarity == "Legendary":
		return false
	if effect.requires_infected_target and not minion.infected:
		return false
	return true

# Un enchantement/rituel posé (côté is_player) est-il une cible valide pour
# cet effet ? Les enchantements et rituels partagent le même pool de cibles
# (comme pour DestroyRandomEnchantment).
func _is_valid_target_enchantment(_card_data: CardData, is_player: bool, pending_card: CardData) -> bool:
	if pending_card == null or pending_card.effects.is_empty():
		return false
	match pending_card.effects[0].target:
		"EnemyEnchantment":
			return not is_player
		"AllyEnchantment":
			return is_player
		"AnyEnchantment":
			return true
		_:
			return false

# Une carte à ciblage obligatoire est-elle jouable en l'état du plateau ?
func has_any_valid_target(card_data: CardData) -> bool:
	if card_data == null or card_data.effects.is_empty():
		return true
	match card_data.effects[0].target:
		"EnemyMinion", "AllyMinion", "AnyMinion":
			for minion in battle.player_minions + battle.enemy_minions:
				if _is_valid_target_minion(minion, card_data):
					return true
			return false
		"EnemyEnchantment":
			return not (battle.enchantment_system.get_enchantments(false) + battle.enchantment_system.get_rituals(false)).is_empty()
		"AllyEnchantment":
			return not (battle.enchantment_system.get_enchantments(true) + battle.enchantment_system.get_rituals(true)).is_empty()
		"AnyEnchantment":
			return not (battle.enchantment_system.get_enchantments(true) + battle.enchantment_system.get_rituals(true)
					+ battle.enchantment_system.get_enchantments(false) + battle.enchantment_system.get_rituals(false)).is_empty()
		_:
			# EnemyHero/OwnerHero et cibles non sélectionnées : toujours disponibles
			return true
