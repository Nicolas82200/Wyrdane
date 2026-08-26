# BoardMinion.gd
extends Control
class_name BoardMinion

signal minion_clicked(minion, board_minion)
signal fusion_requested(minion)

var minion = null
var is_selected := false

@onready var art              = $Art
@onready var attack_label     = $AttackLabel
@onready var health_label     = $HealthLabel
@onready var border_highlight: Panel     = $BorderHighlight
@onready var border_color: Panel         = get_node_or_null("BorderColor")
@onready var keyword_icons: HBoxContainer = $KeywordIcons

const BORDER_RACE_COLORS := {
	Race.Type.UNDEAD: Color("342e1ae1"),
	Race.Type.HUMAN:  Color("5a4a35e1"),
	Race.Type.ELF:    Color("2f5d50e1"),
	Race.Type.DWARF:  Color("5a3a22e1"),
	Race.Type.DEMON:  Color("5a1f1fe1"),
}

var _keyword_tooltips: Array[Control] = []
var _highlight_style: StyleBoxFlat
var _race_style: StyleBoxFlat
var _targetable_style: StyleBoxFlat = null
var _targetable: bool = false
var _pulse_time: float = 0.0
var _mouse_is_over: bool = false
var _ready_glow: Panel = null
var _ready_style: StyleBoxFlat = null
var _ready_pulse: float = 0.0
var _fusion_button: Button = null

# Halo pulsant affiché pendant que la popup d'effet de CE serviteur est jouée
# (CardPopupSystem.show_card_popup) — identifie visuellement quelle carte du
# plateau déclenche l'effet en cours de preview, vert pour un allié, rouge
# pour un adversaire (voir set_effect_preview_highlight).
var _effect_preview_glow: Panel = null
var _effect_preview_style: StyleBoxFlat = null
var _effect_preview_pulse: float = 0.0

# ─── Statuts persistants (Rempart, Égide, Gel, Infection, Terreur, Silence,
# Corruption, Immunité aux sorts) ──────────────────────────────────────────────
var _taunt_shield: Panel = null
var _taunt_shield_style: StyleBoxFlat = null
var _aegis_glow: Panel = null
var _aegis_glow_style: StyleBoxFlat = null
var _corruption_border: Panel = null
var _corruption_border_style: StyleBoxFlat = null
var _spell_ward: Panel = null
var _spell_ward_style: StyleBoxFlat = null
var _status_pulse: float = 0.0
var _frost_particles: CPUParticles2D = null
var _infection_particles: CPUParticles2D = null
var _terror_particles: CPUParticles2D = null
# Panneaux à faire pulser en continu tant qu'ils sont visibles (rempli par
# BoardMinionStatusVFX.setup, parcouru par BoardMinionStatusVFX.update_pulse).
var _pulsing_overlays: Array[Dictionary] = []

const READY_GLOW_COLOR := Color(1.0, 0.85, 0.2)
const EXHAUSTED_TINT   := Color(0.5, 0.5, 0.5)
# GEL : teinte persistante tant que frozen_turns > 0, visible des deux joueurs
# (contrairement à EXHAUSTED_TINT, qui ne s'affiche que côté propriétaire).
const FROZEN_TINT      := Color(0.55, 0.75, 1.0)
# INFECTION : teinte persistante tant que infected == true.
const INFECTED_TINT    := Color(0.65, 0.85, 0.55)
# TERREUR : teinte persistante tant que terror_turns > 0 (même couleur que le
# flash de AnimationSystem.play_terror, pour rester cohérent).
const TERROR_TINT      := Color(0.62, 0.5, 0.75)
# SILENCE : teinte persistante tant que silenced == true (même gris terne que
# AnimationSystem.play_silence).
const SILENCE_TINT     := Color(0.65, 0.65, 0.68)

const TAUNT_SHIELD_COLOR      := Color(0.55, 0.7, 0.85)
const AEGIS_GLOW_COLOR        := Color(1.0, 0.84, 0.2)
const CORRUPTION_BORDER_COLOR := Color(0.75, 0.15, 0.2)
const SPELL_WARD_COLOR        := Color(0.35, 0.85, 0.8)
const EFFECT_PREVIEW_ALLY_COLOR  := Color(0.25, 0.9, 0.3)
const EFFECT_PREVIEW_ENEMY_COLOR := Color(0.95, 0.2, 0.2)

# ─── Coloration des stats (buff/debuff) ───────────────────────────────────────
const STAT_COLOR_DEFAULT           := Color(1, 1, 1, 1)
const STAT_COLOR_BUFF              := Color(0.35, 0.95, 0.35)
const STAT_COLOR_DEBUFF_PERMANENT  := Color(0.95, 0.25, 0.25)
const STAT_COLOR_DEBUFF_TEMPORARY  := Color(1.0, 0.6, 0.15)

const CARD_SCENE = preload("res://scenes/card/Card.tscn")
var _hover_preview: Card = null
var _last_card_scene_error_msec: int = -999999
var _tooltip_layer: CanvasLayer = null

# Référence Battle mise en cache
var _battle: Node = null

# Filet de sécurité : si CE nœud est détruit (queue_free) pendant qu'il
# affiche un aperçu de survol — ex. la boutique Arena se reconstruit
# entièrement après un achat (voir ArenaBattle._refresh_shop), y compris la
# case qu'on vient de glisser-déposer, encore "survolée" au moment du drop —
# rien n'appelle jamais _on_mouse_exited() (le sondage de survol dans
# _process() ne tourne plus, ce nœud n'existe déjà plus) et l'aperçu (`Card`
# ajoutée à `_battle`, PAS un enfant de ce nœud) reste affiché indéfiniment,
# orphelin. _exit_tree() est le seul point garanti d'être appelé quelle que
# soit la raison de la destruction (queue_free, changement de scène...).
func _exit_tree() -> void:
	_cleanup_hover()

func _ready() -> void:
	_battle = get_tree().current_scene

	# Chaque instance crée son propre StyleBoxFlat — pas de partage accidentel
	_highlight_style = StyleBoxFlat.new()
	_highlight_style.bg_color            = Color.TRANSPARENT
	_highlight_style.border_width_left   = 2
	_highlight_style.border_width_right  = 2
	_highlight_style.border_width_top    = 2
	_highlight_style.border_width_bottom = 2
	_highlight_style.border_color        = Color(1.0, 0.9, 0.3)
	border_highlight.add_theme_stylebox_override("panel", _highlight_style)
	border_highlight.visible = false

	_race_style = StyleBoxFlat.new()
	_race_style.bg_color            = Color.TRANSPARENT
	_race_style.border_width_left   = 8
	_race_style.border_width_right  = 8
	_race_style.border_width_top    = 15
	_race_style.border_width_bottom = 0
	_race_style.border_blend        = true
	if border_color:
		border_color.add_theme_stylebox_override("panel", _race_style)

	# Halo « prêt à attaquer » — bordure dorée pulsante autour du serviteur
	_ready_style = StyleBoxFlat.new()
	_ready_style.bg_color            = Color.TRANSPARENT
	_ready_style.border_width_left   = 4
	_ready_style.border_width_right  = 4
	_ready_style.border_width_top    = 4
	_ready_style.border_width_bottom = 4
	_ready_style.border_color        = READY_GLOW_COLOR
	_ready_style.corner_radius_top_left     = 8
	_ready_style.corner_radius_top_right    = 8
	_ready_style.corner_radius_bottom_left  = 8
	_ready_style.corner_radius_bottom_right = 8
	_ready_glow = Panel.new()
	_ready_glow.name = "ReadyGlow"
	_ready_glow.position = Vector2(-5, -5)
	_ready_glow.size = Vector2(110, 160)
	_ready_glow.add_theme_stylebox_override("panel", _ready_style)
	_ready_glow.visible = false
	add_child(_ready_glow)
	move_child(_ready_glow, border_highlight.get_index())

	# Halo « effet en cours de preview » — léger contour pulsant, vert/rouge
	# selon le camp (voir set_effect_preview_highlight).
	_effect_preview_style = StyleBoxFlat.new()
	_effect_preview_style.bg_color            = Color.TRANSPARENT
	_effect_preview_style.border_width_left   = 3
	_effect_preview_style.border_width_right  = 3
	_effect_preview_style.border_width_top    = 3
	_effect_preview_style.border_width_bottom = 3
	_effect_preview_style.border_color        = EFFECT_PREVIEW_ALLY_COLOR
	_effect_preview_style.corner_radius_top_left     = 8
	_effect_preview_style.corner_radius_top_right    = 8
	_effect_preview_style.corner_radius_bottom_left  = 8
	_effect_preview_style.corner_radius_bottom_right = 8
	_effect_preview_glow = Panel.new()
	_effect_preview_glow.name = "EffectPreviewGlow"
	_effect_preview_glow.position = Vector2(-4, -4)
	_effect_preview_glow.size = Vector2(108, 158)
	_effect_preview_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect_preview_glow.add_theme_stylebox_override("panel", _effect_preview_style)
	_effect_preview_glow.visible = false
	add_child(_effect_preview_glow)
	move_child(_effect_preview_glow, border_highlight.get_index())

	BoardMinionStatusVFX.setup(self)

	mouse_filter = Control.MOUSE_FILTER_STOP
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_PASS

	# Bouton d'activation du mot-clé FUSION (Abomination) : seule capacité
	# activée manuellement depuis un serviteur déjà en jeu — pas de contrepartie
	# passive/déclenchée, donc pas de tooltip standard (voir TooltipData).
	# Ajouté APRÈS la boucle ci-dessus pour garder son propre mouse_filter STOP :
	# sans cela, ses clics fuiraient vers la sélection d'attaquant du serviteur.
	_fusion_button = Button.new()
	_fusion_button.name = "FusionButton"
	_fusion_button.text = "F"
	_fusion_button.custom_minimum_size = Vector2(26, 26)
	_fusion_button.position = Vector2(70, 2)
	_fusion_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_fusion_button.visible = false
	_fusion_button.add_theme_font_size_override("font_size", 14)
	_fusion_button.tooltip_text = TranslationServer.translate("KW_FUSION_NAME")
	_fusion_button.pressed.connect(func(): fusion_requested.emit(minion))
	add_child(_fusion_button)

func _process(delta: float) -> void:
	# Repose sur un sondage plutôt que sur mouse_entered/exited : la ligne de
	# serviteurs (HBoxContainer) se réorganise souvent (mort, invocation,
	# placeholder de drop) sans que la souris ne bouge, ce qui ne redéclenche
	# pas les signaux natifs de survol et laissait parfois le hover coincé.
	# Le sondage ignore l'overlay de l'écran de fin de partie (contrairement aux
	# signaux GUI natifs) : bloquer explicitement le hover une fois la partie finie.
	var over: bool = mouse_filter != Control.MOUSE_FILTER_IGNORE \
		and is_visible_in_tree() \
		and not _is_game_over() \
		and get_global_rect().has_point(get_global_mouse_position())
	if over and not _mouse_is_over:
		_on_mouse_entered()
	elif not over and _mouse_is_over:
		_on_mouse_exited()
	elif over and _mouse_is_over and _hover_preview == null and not _is_dragging_card():
		# La souris est restée sur le serviteur pendant qu'une carte était en
		# train d'être glissée (preview alors bloquée) : une fois le drag
		# terminé, aucune transition over/exit ne se reproduit tant que la
		# souris ne bouge pas, donc on retente ici plutôt que de rester coincé.
		_on_mouse_entered()
	if _ready_glow != null and _ready_glow.visible:
		_ready_pulse += delta * 2.5
		_ready_style.border_color.a = 0.55 + sin(_ready_pulse) * 0.35
		_ready_glow.queue_redraw()
	if _effect_preview_glow != null and _effect_preview_glow.visible:
		_effect_preview_pulse += delta * 4.0
		_effect_preview_style.border_color.a = 0.5 + sin(_effect_preview_pulse) * 0.4
		_effect_preview_glow.queue_redraw()
	BoardMinionStatusVFX.update_pulse(self, delta)
	_update_fusion_button()
	if not _targetable or _targetable_style == null:
		return
	_pulse_time += delta * 3.0
	var alpha: float = 0.6 + sin(_pulse_time) * 0.4
	_targetable_style.border_color.a = alpha
	border_highlight.queue_redraw()

# ─── Données ──────────────────────────────────────────────────────────────────

func set_minion(new_minion) -> void:
	minion = new_minion
	update_display()

func update_display() -> void:
	if minion == null or minion.card_data == null:
		return
	attack_label.text = str(minion.attack)
	health_label.text = str(max(minion.health, 0))
	var c: Color = status_tint()
	modulate.r = c.r
	modulate.g = c.g
	modulate.b = c.b
	_update_ready_glow()
	if minion.card_data.texture:
		art.texture = minion.card_data.texture
	_race_style.border_color = BORDER_RACE_COLORS.get(minion.card_data.race, Color.WHITE)
	if border_color:
		border_color.queue_redraw()
	_refresh_keyword_icons()
	BoardMinionStatusVFX.refresh(self)
	_apply_stat_colors()

## Teinte persistante d'état (Gel, Terreur, Silence, Infection, épuisement).
## Toute animation qui flashe `modulate` doit revenir à cette couleur — jamais
## à Color.WHITE — pour ne pas effacer le visuel d'un statut encore actif.
func status_tint() -> Color:
	if minion == null:
		return Color.WHITE
	if minion.frozen_turns > 0:
		return FROZEN_TINT
	if minion.terror_turns > 0:
		return TERROR_TINT
	if minion.silenced:
		return SILENCE_TINT
	if minion.infected:
		return INFECTED_TINT
	# Grisage uniquement pendant le tour du propriétaire : un serviteur adverse
	# n'a pas à paraître « épuisé » pendant le tour du joueur (et inversement)
	if minion.owner_is_player == _is_player_turn() and not minion.can_attack():
		return EXHAUSTED_TINT
	return Color.WHITE

# ─── Activation de FUSION ─────────────────────────────────────────────────────

func _update_fusion_button() -> void:
	if _fusion_button == null or minion == null or _battle == null:
		return
	_fusion_button.visible = "fusion_system" in _battle \
		and _battle.fusion_system.can_activate(minion)

# ─── Halo « effet en cours de preview » ──────────────────────────────────────

# Affiché/masqué par CardPopupSystem pendant que la popup d'effet de ce
# serviteur est jouée à l'écran (voir CardPopupSystem._play_popup) : identifie
# la carte du plateau qui déclenche l'effet en cours de preview.
func set_effect_preview_highlight(active: bool, is_ally: bool) -> void:
	if _effect_preview_glow == null:
		return
	if active:
		_effect_preview_style.border_color = EFFECT_PREVIEW_ALLY_COLOR if is_ally else EFFECT_PREVIEW_ENEMY_COLOR
		_effect_preview_pulse = 0.0
	_effect_preview_glow.visible = active

# ─── Halo « prêt à attaquer » ────────────────────────────────────────────────

func _is_player_turn() -> bool:
	if _battle == null or not ("enemy_turn_active" in _battle):
		return false
	if "game_over" in _battle and _battle.game_over:
		return false
	return not _battle.enemy_turn_active

func _update_ready_glow() -> void:
	if _ready_glow == null or minion == null:
		return
	var should_show: bool = minion.owner_is_player \
		and _is_player_turn() \
		and minion.can_attack() \
		and not is_selected \
		and not _targetable
	if should_show and not _ready_glow.visible:
		_ready_pulse = 0.0
		_ready_style.border_color = READY_GLOW_COLOR
	_ready_glow.visible = should_show

# ─── Coloration des stats (buff/debuff) ───────────────────────────────────────

# Vert si la stat effective dépasse la valeur imprimée sur la carte ; rouge si
# elle est réduite par un effet permanent (Corruption, Buff négatif...) ; orange
# si la réduction ne vient que d'un effet à durée limitée (aura ou
# TempEffectSystem) qui disparaîtra à son expiration.
func _stat_color(total_delta: int, temp_component: int) -> Color:
	if total_delta > 0:
		return STAT_COLOR_BUFF
	if total_delta < 0:
		var permanent_component: int = total_delta - temp_component
		if permanent_component < 0:
			return STAT_COLOR_DEBUFF_PERMANENT
		return STAT_COLOR_DEBUFF_TEMPORARY
	return STAT_COLOR_DEFAULT

func _apply_stat_colors() -> void:
	var temp_delta := Vector2i.ZERO
	if _battle != null and "temp_effect_system" in _battle and _battle.temp_effect_system != null:
		temp_delta = _battle.temp_effect_system.get_temp_stat_delta(minion)

	var attack_temp: int = temp_delta.x + minion.aura_attack_bonus
	var attack_total: int = minion.attack - minion.card_data.attack
	attack_label.add_theme_color_override("font_color", _stat_color(attack_total, attack_temp))

	var health_temp: int = temp_delta.y + minion.aura_health_bonus
	var health_total: int = minion.max_health - minion.card_data.health
	health_label.add_theme_color_override("font_color", _stat_color(health_total, health_temp))

# ─── Sélection / Ciblage ──────────────────────────────────────────────────────

func set_selected(value: bool, multi: bool = false) -> void:
	is_selected = value
	if not _targetable:
		border_highlight.visible = value
		border_highlight.add_theme_stylebox_override("panel", _highlight_style)
	_highlight_style.border_color = Color(1.0, 0.45, 0.05) if (value and multi) else Color(1.0, 0.9, 0.3)
	border_highlight.queue_redraw()
	_update_ready_glow()

func set_targetable(value: bool, color: Color = Color.WHITE) -> void:
	_targetable = value
	_pulse_time = 0.0
	if value:
		if _targetable_style == null:
			_targetable_style = StyleBoxFlat.new()
			_targetable_style.bg_color            = Color.TRANSPARENT
			_targetable_style.border_width_left   = 3
			_targetable_style.border_width_right  = 3
			_targetable_style.border_width_top    = 3
			_targetable_style.border_width_bottom = 3
		_targetable_style.border_color = color
		border_highlight.add_theme_stylebox_override("panel", _targetable_style)
		border_highlight.visible = true
	else:
		border_highlight.add_theme_stylebox_override("panel", _highlight_style)
		border_highlight.visible = is_selected
	_update_ready_glow()

# ─── Input ────────────────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		minion_clicked.emit(minion, self)

# ─── Hover & Preview ──────────────────────────────────────────────────────────

func _is_dragging_card() -> bool:
	return _battle != null and _battle.has_method("is_dragging_card") and _battle.call("is_dragging_card")

func _is_game_over() -> bool:
	return _battle != null and "game_over" in _battle and _battle.game_over

func _on_mouse_entered() -> void:
	_mouse_is_over = true
	if _targetable:
		var t := create_tween()
		t.tween_property(self, "scale", Vector2(1.08, 1.08), 0.1)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if _is_dragging_card():
		return
	if _hover_preview != null:
		return
	if CARD_SCENE == null or not CARD_SCENE.can_instantiate():
		# _process() retente ce hover à chaque frame tant qu'aucune preview
		# n'existe : sans throttle, un échec transitoire (ex. réimport
		# d'assets en cours pendant que le jeu tourne dans l'éditeur) spamme
		# la console en continu au --lieu de simplement réessayer plus tard.
		var now := Time.get_ticks_msec()
		if now - _last_card_scene_error_msec > 2000:
			push_error("BoardMinion: CARD_SCENE is invalid")
			_last_card_scene_error_msec = now
		return
	_hover_preview = CARD_SCENE.instantiate()
	if _hover_preview == null:
		push_error("BoardMinion: instantiate() returned null")
		return
	_hover_preview.drag_enabled = false
	_hover_preview.z_index = 1000
	_hover_preview.visible = false
	_battle.add_child(_hover_preview)
	_hover_preview.set_data(minion.card_data)
	_hover_preview.scale = Vector2(0.9, 0.9)
	await get_tree().process_frame

	# Évite les états invalides si la souris sort pendant l'await
	if not _mouse_is_over or not is_instance_valid(_hover_preview):
		_cleanup_hover()
		return

	_hover_preview.global_position = global_position + Vector2(
		size.x + 15,
		(size.y - _hover_preview.size.y * 0.9) / 2.0
	)
	_hover_preview.visible = true
	var tooltip_x := _hover_preview.global_position.x + _hover_preview.size.x * 0.9 + 15
	var tooltip_y := _hover_preview.global_position.y
	await _show_keyword_tooltips(tooltip_x, tooltip_y)

func _on_mouse_exited() -> void:
	_mouse_is_over = false
	if _targetable:
		var t := create_tween()
		t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	_cleanup_hover()

func _cleanup_hover() -> void:
	_hide_keyword_tooltips()
	if _hover_preview:
		# `visible = false` synchrone AVANT queue_free() : la destruction
		# réelle du nœud est différée à la fin de la frame (voir SceneTree),
		# donc en passant rapidement d'une carte à sa voisine directe (ex. en
		# boutique, cartes serrées côte à côte), l'ancienne preview restait
		# affichée un instant pendant que la nouvelle apparaissait déjà —
		# deux previews visibles en même temps. Masquer explicitement supprime
		# cette fenêtre, sans dépendre de l'ordre exact des suppressions différées.
		_hover_preview.visible = false
		_hover_preview.queue_free()
		_hover_preview = null

# ─── Tooltips — délégués à TooltipData ───────────────────────────────────────

func _show_keyword_tooltips(base_x: float, base_y_override: float = -1.0) -> void:
	_hide_keyword_tooltips()
	if minion == null:
		return
	_tooltip_layer = CanvasLayer.new()
	_tooltip_layer.layer = 20
	_battle.add_child(_tooltip_layer)

	var panels: Array[Control] = TooltipData.build_panels_for_card(minion.card_data, _tooltip_layer)
	await get_tree().process_frame

	if not _mouse_is_over:
		_hide_keyword_tooltips()
		return

	var vp := get_viewport_rect().size
	var base_y := base_y_override if base_y_override >= 0.0 else get_screen_position().y

	# Reste sur l'écran : bascule à gauche de la carte si la pile déborde à
	# droite, et remonte le point de départ si elle déborde en bas.
	var stack_height := 0.0
	for panel in panels:
		if is_instance_valid(panel):
			stack_height += panel.size.y + 6.0
	if stack_height > 0.0:
		stack_height -= 6.0
		base_y = clampf(base_y, 4.0, maxf(4.0, vp.y - stack_height - 4.0))

	var panel_width := 220.0
	if panels.size() > 0 and is_instance_valid(panels[0]):
		panel_width = panels[0].size.x
	if base_x + panel_width > vp.x - 4.0:
		base_x = maxf(4.0, global_position.x - panel_width - 15)

	for panel in panels:
		if not is_instance_valid(panel):
			continue
		panel.global_position = Vector2(base_x, base_y)
		base_y += panel.size.y + 6
		_keyword_tooltips.append(panel)

	if TooltipData.RACE_DESCRIPTIONS.has(minion.card_data.race):
		if not is_instance_valid(_tooltip_layer):
			return
		var race_panel := TooltipData.make_race_tooltip(TooltipData.RACE_DESCRIPTIONS[minion.card_data.race])
		race_panel.position = Vector2(-9999, -9999)
		_tooltip_layer.add_child(race_panel)
		await get_tree().process_frame
		if is_instance_valid(race_panel) and is_instance_valid(_hover_preview):
			var preview_bottom  := _hover_preview.global_position.y + _hover_preview.size.y * 0.9
			var preview_center_x := _hover_preview.global_position.x + (_hover_preview.size.x * 0.9) / 2.0
			var rx: float = clampf(
				preview_center_x - race_panel.size.x / 2.0, 4.0, vp.x - race_panel.size.x - 4.0)
			var ry := preview_bottom + 6
			if ry + race_panel.size.y > vp.y - 4.0:
				ry = _hover_preview.global_position.y - race_panel.size.y - 6
			race_panel.global_position = Vector2(rx, ry)
			_keyword_tooltips.append(race_panel)

func _hide_keyword_tooltips() -> void:
	for tooltip in _keyword_tooltips:
		if is_instance_valid(tooltip):
			tooltip.queue_free()
	_keyword_tooltips.clear()
	if _tooltip_layer and is_instance_valid(_tooltip_layer):
		_tooltip_layer.queue_free()
		_tooltip_layer = null

# ─── Icônes de keywords ───────────────────────────────────────────────────────

func _refresh_keyword_icons() -> void:
	if not is_node_ready() or keyword_icons == null:
		return
	for child in keyword_icons.get_children():
		child.queue_free()
	var pools := [
		[minion.keywords, TooltipData.KEYWORD_ICONS],
		[minion.human_keywords, TooltipData.KEYWORD_HUMAN_ICONS],
		[minion.undead_keywords, TooltipData.KEYWORD_UNDEAD_ICONS],
		[minion.demon_keywords, TooltipData.KEYWORD_DEMON_ICONS],
		[minion.abomination_keywords, TooltipData.KEYWORD_ABOMINATION_ICONS],
	]
	for pool in pools:
		var pool_keywords: Array = pool[0]
		var pool_icons: Dictionary = pool[1]
		for keyword in pool_keywords:
			if not pool_icons.has(keyword):
				continue
			var icon := TextureRect.new()
			icon.texture             = pool_icons[keyword]
			icon.custom_minimum_size = Vector2(22, 22)
			icon.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter        = Control.MOUSE_FILTER_PASS
			keyword_icons.add_child(icon)
