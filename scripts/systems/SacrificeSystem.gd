extends Node
class_name SacrificeSystem

# Activation volontaire des Rituels de Sacrifice ("Sacrifice (un serviteur
# allié) : effet"). Le joueur clique sur le rituel posé dans sa zone, puis
# choisit le ou les serviteurs alliés à sacrifier ; les victimes meurent
# (marquées `sacrificed` : pas de REVENANT), l'effet du rituel s'exécute et
# une charge est consommée. Clic droit / Échap pour annuler.

signal sacrifice_cancelled

var battle
var _active: bool = false
var _pending_ritual: CardData = null
var _selected: Array[Minion] = []
var _highlighted: Array[BoardMinion] = []

const HIGHLIGHT_COLOR := Color(1.0, 0.35, 0.25, 0.6)

func init(_battle) -> void:
	battle = _battle

func is_active() -> bool:
	return _active

# ─── Activation ───────────────────────────────────────────────────────────────

# Le rituel est-il activable par le joueur local en l'état ?
func can_activate(card_data: CardData, is_player: bool) -> bool:
	if card_data == null or not is_player:
		return false
	if battle.game_over or battle.reconnecting or battle.enemy_turn_active or battle.waiting_for_target:
		return false
	if _active or battle.targeting_system.is_targeting():
		return false
	if card_data.sacrifice_count <= 0:
		return false
	if not _is_registered_ritual(card_data):
		return false
	return _valid_victims(card_data).size() >= card_data.sacrifice_count

func try_begin(card_data: CardData, is_player: bool) -> void:
	if not can_activate(card_data, is_player):
		return
	_pending_ritual = card_data
	_selected.clear()
	_active = true
	await battle.card_popup_system.show_targeting_popup(card_data)
	_highlight_victims(card_data)

func cancel() -> void:
	if not _active:
		return
	_active = false
	_pending_ritual = null
	_selected.clear()
	_clear_highlights()
	battle.card_popup_system.hide_targeting_popup()
	sacrifice_cancelled.emit()

# ─── Sélection des victimes ───────────────────────────────────────────────────

func on_ally_minion_clicked(minion: Minion, visual: BoardMinion) -> void:
	if not _active:
		return
	if minion in _selected or not _is_valid_victim(minion, _pending_ritual):
		return
	_selected.append(minion)
	visual.set_targetable(true, HIGHLIGHT_COLOR.lightened(0.3))
	if _selected.size() >= _pending_ritual.sacrifice_count:
		await _execute()

func _execute() -> void:
	var ritual: CardData = _pending_ritual
	var victims: Array[Minion] = _selected.duplicate()
	_active = false
	_pending_ritual = null
	_selected.clear()
	_clear_highlights()
	battle.card_popup_system.hide_targeting_popup()

	# Capture les serviteurs créés par l'effet (ex. invocation) pour le rejeu réseau.
	if battle.net_emitter != null:
		battle.net_registry.begin_capture()
	var victim_ids: Array = []
	for v in victims:
		victim_ids.append(v.net_id)
	await battle.trigger_system.activate_sacrifice_ritual(ritual, true, victims)
	if battle.net_emitter != null:
		var ids: Array = battle.net_registry.end_capture()
		battle.net_emitter.activate_ritual(ritual, victim_ids, ids)

# ─── Validité ─────────────────────────────────────────────────────────────────

func _is_registered_ritual(card_data: CardData) -> bool:
	if not card_data.get_trigger_names().has("OnSacrifice"):
		return false
	for entry in battle.trigger_system.get_active_enchantments(true):
		if entry["card_data"] == card_data:
			return true
	return false

func _is_valid_victim(minion: Minion, ritual: CardData) -> bool:
	if minion == null or ritual == null or not minion.owner_is_player or minion.is_dead():
		return false
	if ritual.sacrifice_max_hp >= 0 and minion.health > ritual.sacrifice_max_hp:
		return false
	return true

func _valid_victims(ritual: CardData) -> Array[Minion]:
	return battle.player_minions.filter(func(m: Minion): return _is_valid_victim(m, ritual))

# ─── Surbrillance ─────────────────────────────────────────────────────────────

func _highlight_victims(ritual: CardData) -> void:
	_clear_highlights()
	for minion in _valid_victims(ritual):
		var visual: BoardMinion = battle.board_visual_system.find_visual(minion) as BoardMinion
		if visual == null or not is_instance_valid(visual):
			continue
		visual.set_targetable(true, HIGHLIGHT_COLOR)
		_highlighted.append(visual)

func _clear_highlights() -> void:
	for visual in _highlighted:
		if is_instance_valid(visual):
			visual.set_targetable(false, Color.WHITE)
	_highlighted.clear()
