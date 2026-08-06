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

const KEYWORD_ICONS := {
	Keyword.Type.TAUNT: preload("res://assets/icons/taunt-icon.png"),
	Keyword.Type.AEGIS: preload("res://assets/icons/aegis-icon.png"),
	Keyword.Type.DEADLY_POISON: preload("res://assets/icons/poison-icon.png"),
	Keyword.Type.CHARGE: preload("res://assets/icons/charge-icon.png"),
	Keyword.Type.FURY: preload("res://assets/icons/fury-icon.png")
}

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
# _setup_status_vfx, parcouru par _update_status_pulse).
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

	_setup_status_vfx()

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
	_update_status_pulse(delta)
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
	_refresh_status_vfx()
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

# ─── Statuts persistants (Rempart, Égide, Gel, Infection) ─────────────────────

func _setup_status_vfx() -> void:
	# REMPART (TAUNT) : anneau façon bouclier autour de la carte, visible tant
	# que le mot-clé est présent (retiré uniquement par Silence/mort).
	_taunt_shield_style = StyleBoxFlat.new()
	_taunt_shield_style.bg_color            = Color.TRANSPARENT
	_taunt_shield_style.border_width_left   = 5
	_taunt_shield_style.border_width_right  = 5
	_taunt_shield_style.border_width_top    = 5
	_taunt_shield_style.border_width_bottom = 5
	_taunt_shield_style.border_color        = TAUNT_SHIELD_COLOR
	_taunt_shield_style.corner_radius_top_left     = 20
	_taunt_shield_style.corner_radius_top_right    = 20
	_taunt_shield_style.corner_radius_bottom_left  = 20
	_taunt_shield_style.corner_radius_bottom_right = 20
	_taunt_shield = Panel.new()
	_taunt_shield.name = "TauntShield"
	_taunt_shield.position = Vector2(-8, -8)
	_taunt_shield.size = Vector2(116, 166)
	_taunt_shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_taunt_shield.add_theme_stylebox_override("panel", _taunt_shield_style)
	_taunt_shield.visible = false
	add_child(_taunt_shield)

	# ÉGIDE (AEGIS) : halo doré persistant tant que le bouclier n'a pas absorbé
	# de dégâts (retiré instantanément par Minion.take_damage).
	_aegis_glow_style = StyleBoxFlat.new()
	_aegis_glow_style.bg_color            = Color(AEGIS_GLOW_COLOR.r, AEGIS_GLOW_COLOR.g, AEGIS_GLOW_COLOR.b, 0.12)
	_aegis_glow_style.border_width_left   = 4
	_aegis_glow_style.border_width_right  = 4
	_aegis_glow_style.border_width_top    = 4
	_aegis_glow_style.border_width_bottom = 4
	_aegis_glow_style.border_color        = AEGIS_GLOW_COLOR
	_aegis_glow_style.corner_radius_top_left     = 12
	_aegis_glow_style.corner_radius_top_right    = 12
	_aegis_glow_style.corner_radius_bottom_left  = 12
	_aegis_glow_style.corner_radius_bottom_right = 12
	_aegis_glow = Panel.new()
	_aegis_glow.name = "AegisGlow"
	_aegis_glow.position = Vector2(-2, -2)
	_aegis_glow.size = Vector2(104, 154)
	_aegis_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aegis_glow.add_theme_stylebox_override("panel", _aegis_glow_style)
	_aegis_glow.visible = false
	add_child(_aegis_glow)

	# CORRUPTION (Démon) : liseré sombre permanent tant que corruption_stacks > 0,
	# jamais retiré (perte d'ATK définitive). Ne pulse pas : marque un état figé,
	# contrairement aux protections actives (Rempart/Égide/Immunité aux sorts).
	_corruption_border_style = StyleBoxFlat.new()
	_corruption_border_style.bg_color            = Color.TRANSPARENT
	_corruption_border_style.border_width_left   = 3
	_corruption_border_style.border_width_right  = 3
	_corruption_border_style.border_width_top    = 3
	_corruption_border_style.border_width_bottom = 3
	_corruption_border_style.border_color        = CORRUPTION_BORDER_COLOR
	_corruption_border_style.corner_radius_top_left     = 8
	_corruption_border_style.corner_radius_top_right    = 8
	_corruption_border_style.corner_radius_bottom_left  = 8
	_corruption_border_style.corner_radius_bottom_right = 8
	_corruption_border = Panel.new()
	_corruption_border.name = "CorruptionBorder"
	_corruption_border.position = Vector2(-1, -1)
	_corruption_border.size = Vector2(102, 152)
	_corruption_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_corruption_border.add_theme_stylebox_override("panel", _corruption_border_style)
	_corruption_border.visible = false
	add_child(_corruption_border)

	# IMMUNITÉ AUX SORTS (spell_immune) : voile chatoyant tant que la protection
	# n'a pas été levée par la 1ère attaque (Assassin Décharné) ou son expiration
	# (Éclaireur Infiltré, TempEffectSystem).
	_spell_ward_style = StyleBoxFlat.new()
	_spell_ward_style.bg_color            = Color.TRANSPARENT
	_spell_ward_style.border_width_left   = 3
	_spell_ward_style.border_width_right  = 3
	_spell_ward_style.border_width_top    = 3
	_spell_ward_style.border_width_bottom = 3
	_spell_ward_style.border_color        = SPELL_WARD_COLOR
	_spell_ward_style.corner_radius_top_left     = 16
	_spell_ward_style.corner_radius_top_right    = 16
	_spell_ward_style.corner_radius_bottom_left  = 16
	_spell_ward_style.corner_radius_bottom_right = 16
	_spell_ward = Panel.new()
	_spell_ward.name = "SpellWard"
	_spell_ward.position = Vector2(-5, -5)
	_spell_ward.size = Vector2(110, 160)
	_spell_ward.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spell_ward.add_theme_stylebox_override("panel", _spell_ward_style)
	_spell_ward.visible = false
	add_child(_spell_ward)

	_pulsing_overlays = [
		{"panel": _taunt_shield, "style": _taunt_shield_style},
		{"panel": _aegis_glow,   "style": _aegis_glow_style},
		{"panel": _spell_ward,   "style": _spell_ward_style},
	]

	# GEL : flocons qui dérivent tant que frozen_turns > 0.
	_frost_particles = CPUParticles2D.new()
	_frost_particles.name = "FrostParticles"
	_frost_particles.position = Vector2(50, 75)
	_frost_particles.amount = 10
	_frost_particles.lifetime = 2.2
	_frost_particles.preprocess = 2.2
	_frost_particles.emitting = false
	_frost_particles.local_coords = true
	_frost_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_frost_particles.emission_rect_extents = Vector2(48, 73)
	_frost_particles.direction = Vector2(0, 1)
	_frost_particles.spread = 180.0
	_frost_particles.gravity = Vector2(0, 6)
	_frost_particles.initial_velocity_min = 2.0
	_frost_particles.initial_velocity_max = 8.0
	_frost_particles.angular_velocity_min = -60.0
	_frost_particles.angular_velocity_max = 60.0
	_frost_particles.scale_amount_min = 1.5
	_frost_particles.scale_amount_max = 3.0
	_frost_particles.color = Color(0.85, 0.93, 1.0, 0.85)
	add_child(_frost_particles)

	# INFECTION : vapeurs toxiques qui montent tant que infected == true.
	_infection_particles = CPUParticles2D.new()
	_infection_particles.name = "InfectionParticles"
	_infection_particles.position = Vector2(50, 140)
	_infection_particles.amount = 7
	_infection_particles.lifetime = 1.8
	_infection_particles.preprocess = 1.8
	_infection_particles.emitting = false
	_infection_particles.local_coords = true
	_infection_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_infection_particles.emission_rect_extents = Vector2(45, 4)
	_infection_particles.direction = Vector2(0, -1)
	_infection_particles.spread = 20.0
	_infection_particles.gravity = Vector2(0, -14)
	_infection_particles.initial_velocity_min = 4.0
	_infection_particles.initial_velocity_max = 10.0
	_infection_particles.scale_amount_min = 1.0
	_infection_particles.scale_amount_max = 2.2
	_infection_particles.color = Color(0.4, 0.9, 0.4, 0.6)
	add_child(_infection_particles)

	# TERREUR : volutes sombres qui s'échappent tant que terror_turns > 0.
	_terror_particles = CPUParticles2D.new()
	_terror_particles.name = "TerrorParticles"
	_terror_particles.position = Vector2(50, 75)
	_terror_particles.amount = 8
	_terror_particles.lifetime = 1.6
	_terror_particles.preprocess = 1.6
	_terror_particles.emitting = false
	_terror_particles.local_coords = true
	_terror_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_terror_particles.emission_rect_extents = Vector2(48, 73)
	_terror_particles.direction = Vector2(0, -1)
	_terror_particles.spread = 100.0
	_terror_particles.gravity = Vector2(0, -4)
	_terror_particles.initial_velocity_min = 3.0
	_terror_particles.initial_velocity_max = 9.0
	_terror_particles.scale_amount_min = 1.5
	_terror_particles.scale_amount_max = 3.2
	_terror_particles.color = Color(0.35, 0.1, 0.5, 0.5)
	add_child(_terror_particles)

func _refresh_status_vfx() -> void:
	if minion == null or _taunt_shield == null:
		return
	_taunt_shield.visible      = minion.has_keyword(Keyword.Type.TAUNT)
	_aegis_glow.visible        = minion.has_keyword(Keyword.Type.AEGIS)
	_spell_ward.visible        = minion.spell_immune
	_corruption_border.visible = minion.corruption_stacks > 0
	if _corruption_border.visible:
		_corruption_border_style.border_color.a = clampf(0.3 + minion.corruption_stacks * 0.15, 0.3, 0.9)
	_frost_particles.emitting      = minion.frozen_turns > 0
	_infection_particles.emitting  = minion.infected
	_terror_particles.emitting     = minion.terror_turns > 0

func _update_status_pulse(delta: float) -> void:
	if _pulsing_overlays.is_empty():
		return
	var any_visible := false
	for entry in _pulsing_overlays:
		if entry["panel"].visible:
			any_visible = true
			break
	if not any_visible:
		return
	_status_pulse += delta * 2.0
	var alpha := 0.65 + sin(_status_pulse) * 0.3
	for entry in _pulsing_overlays:
		var panel: Panel = entry["panel"]
		if not panel.visible:
			continue
		var style: StyleBoxFlat = entry["style"]
		style.border_color.a = alpha
		panel.queue_redraw()

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
	for keyword in minion.keywords:
		if not KEYWORD_ICONS.has(keyword):
			continue
		var icon := TextureRect.new()
		icon.texture             = KEYWORD_ICONS[keyword]
		icon.custom_minimum_size = Vector2(22, 22)
		icon.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter        = Control.MOUSE_FILTER_PASS
		keyword_icons.add_child(icon)
