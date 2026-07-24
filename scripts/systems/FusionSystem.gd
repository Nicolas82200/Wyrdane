extends Node
class_name FusionSystem

# Activation volontaire du mot-clé FUSION (Abomination) : le joueur clique sur
# un serviteur allié possédant FUSION déjà en jeu, puis choisit un allié
# adjacent (même rangée) à sacrifier. Le serviteur FUSION absorbe les stats
# restantes (ATK/HP actuels) du sacrifié ET un de ses mots-clés au choix, de
# façon permanente. Clic droit / Échap pour annuler tant que la victime n'a
# pas encore été choisie.

signal fusion_cancelled

var battle
var _active: bool = false
var _source: Minion = null
var _highlighted: Array[BoardMinion] = []

const HIGHLIGHT_COLOR := Color(0.65, 0.3, 0.85, 0.6)

func init(_battle) -> void:
	battle = _battle

func is_active() -> bool:
	return _active

# ─── Activation ───────────────────────────────────────────────────────────────

func can_activate(minion: Minion) -> bool:
	if minion == null or not minion.owner_is_player or minion.is_dead():
		return false
	if battle.game_over or battle.reconnecting or battle.enemy_turn_active or battle.waiting_for_target:
		return false
	if _active or battle.targeting_system.is_targeting() or battle.sacrifice_system.is_active():
		return false
	if not minion.has_abomination_keyword(KeywordAbomination.Type.FUSION):
		return false
	return not _valid_victims(minion).is_empty()

func try_begin(minion: Minion) -> void:
	if not can_activate(minion):
		return
	_source = minion
	_active = true
	_highlight_victims(minion)

func cancel() -> void:
	if not _active:
		return
	_active = false
	_source = null
	_clear_highlights()
	fusion_cancelled.emit()

# ─── Sélection de la victime ──────────────────────────────────────────────────

func on_ally_minion_clicked(minion: Minion, _visual: BoardMinion) -> void:
	if not _active:
		return
	if not _is_valid_victim(_source, minion):
		return
	var source: Minion = _source
	var victim: Minion = minion
	_active = false
	_source = null
	_clear_highlights()
	await _execute(source, victim)

func _valid_victims(source: Minion) -> Array[Minion]:
	return battle.effect_manager._get_adjacent_minions(battle, source).filter(
		func(m: Minion): return _is_valid_victim(source, m))

func _is_valid_victim(source: Minion, victim: Minion) -> bool:
	return source != null and victim != null and victim != source \
		and victim.owner_is_player == source.owner_is_player and not victim.is_dead()

# ─── Exécution ────────────────────────────────────────────────────────────────

func _execute(source: Minion, victim: Minion) -> void:
	var options: Array = _collect_keyword_choices(victim)
	var chosen: Dictionary = {}
	if options.size() == 1:
		chosen = options[0]
	elif options.size() > 1:
		var picked = await _show_keyword_popup(options)
		if picked == null:
			return
		chosen = picked

	var source_id: int = source.net_id
	var victim_id: int = victim.net_id
	var pool: String = chosen.get("pool", "")
	var keyword: int = chosen.get("keyword", -1)

	await apply_fusion(source, victim, pool, keyword)

	if battle.net_emitter != null:
		var keyword_name: String = keyword_to_name(pool, keyword) if pool != "" else ""
		battle.net_emitter.activate_fusion(source_id, victim_id, pool, keyword_name)

# Cœur de l'effet, rejouable tel quel côté réseau distant (NetworkOpponent).
func apply_fusion(source: Minion, victim: Minion, pool: String, keyword: int) -> void:
	if source == null or victim == null or source.is_dead() or victim.is_dead():
		return
	var remaining_attack: int = victim.attack
	var remaining_health: int = victim.health
	victim.sacrificed = true
	victim.health = 0
	await battle.death_system.process_deaths()
	if source.is_dead():
		return
	source.base_attack     += remaining_attack
	source.base_max_health += remaining_health
	if pool != "" and keyword >= 0:
		_grant_keyword(source, pool, keyword)
	battle.board_visual_system.refresh_board()

# Encode/décode un mot-clé en son nom d'enum (Type.keys()[value]), pour le
# transmettre au pair réseau sans dépendre d'un ordre d'enum partagé implicite
# entre versions — même mécanique que CardEffect.granted_keyword.
static func keyword_to_name(pool: String, keyword: int) -> String:
	match pool:
		"keywords":              return Keyword.Type.keys()[keyword]
		"human_keywords":        return KeywordHuman.Type.keys()[keyword]
		"undead_keywords":       return KeywordUndead.Type.keys()[keyword]
		"demon_keywords":        return KeywordDemon.Type.keys()[keyword]
		"abomination_keywords":  return KeywordAbomination.Type.keys()[keyword]
		_:                       return ""

static func keyword_from_name(pool: String, keyword_name: String) -> int:
	match pool:
		"keywords":              return Keyword.from_name(keyword_name)
		"human_keywords":        return KeywordHuman.from_name(keyword_name)
		"undead_keywords":       return KeywordUndead.from_name(keyword_name)
		"demon_keywords":        return KeywordDemon.from_name(keyword_name)
		"abomination_keywords":  return KeywordAbomination.from_name(keyword_name)
		_:                       return -1

func _grant_keyword(source: Minion, pool: String, keyword: int) -> void:
	match pool:
		"keywords":
			source.add_keyword(keyword)
		"human_keywords":
			source.add_human_keyword(keyword)
		"undead_keywords":
			if keyword not in source.undead_keywords:
				source.undead_keywords.append(keyword)
		"demon_keywords":
			source.add_demon_keyword(keyword)
		"abomination_keywords":
			source.add_abomination_keyword(keyword)

# Union des 5 pools de mots-clés du sacrifié, chacun avec son libellé traduit.
func _collect_keyword_choices(victim: Minion) -> Array:
	var out: Array = []
	for kw in victim.keywords:
		out.append({"pool": "keywords", "keyword": kw, "label": Keyword.get_keyword_name(kw)})
	for kw in victim.human_keywords:
		out.append({"pool": "human_keywords", "keyword": kw, "label": KeywordHuman.get_keyword_name(kw)})
	for kw in victim.undead_keywords:
		out.append({"pool": "undead_keywords", "keyword": kw, "label": KeywordUndead.get_keyword_name(kw)})
	for kw in victim.demon_keywords:
		out.append({"pool": "demon_keywords", "keyword": kw, "label": KeywordDemon.get_keyword_name(kw)})
	for kw in victim.abomination_keywords:
		out.append({"pool": "abomination_keywords", "keyword": kw, "label": KeywordAbomination.get_keyword_name(kw)})
	return out

# ─── Surbrillance ─────────────────────────────────────────────────────────────

func _highlight_victims(source: Minion) -> void:
	_clear_highlights()
	for minion in _valid_victims(source):
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

# ─── Popup de choix du mot-clé absorbé ────────────────────────────────────────

# Construit une popup minimale (aucune scène dédiée, comme les overlays de
# statut de BoardMinion) listant les mots-clés du sacrifié ; retourne l'entrée
# choisie, ou null si annulé (Échap/clic droit/bouton Annuler).
func _show_keyword_popup(options: Array) -> Variant:
	var layer := CanvasLayer.new()
	layer.layer = 15
	battle.add_child(layer)

	var blocker := Control.new()
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(blocker)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.add_child(center)

	var style := StyleBoxFlat.new()
	style.bg_color            = Color(0.08, 0.06, 0.1, 0.96)
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_color        = Color(0.65, 0.3, 0.85)
	style.corner_radius_top_left     = 10
	style.corner_radius_top_right    = 10
	style.corner_radius_bottom_left  = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left   = 16
	style.content_margin_right  = 16
	style.content_margin_top    = 14
	style.content_margin_bottom = 14

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = SettingsManager.t("FUSION_CHOOSE_KEYWORD")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var result := {"resolved": false, "value": null}
	for opt in options:
		var btn := Button.new()
		btn.text = opt["label"]
		btn.pressed.connect(func():
			result["value"] = opt
			result["resolved"] = true
		)
		vbox.add_child(btn)

	var cancel_btn := Button.new()
	cancel_btn.text = SettingsManager.t("controls.cancel")
	cancel_btn.pressed.connect(func():
		result["value"] = null
		result["resolved"] = true
	)
	vbox.add_child(cancel_btn)

	while not result["resolved"]:
		if Input.is_action_just_pressed("ui_cancel"):
			result["resolved"] = true
			result["value"] = null
		await battle.get_tree().process_frame

	layer.queue_free()
	return result["value"]
