# Card.gd
extends Control
class_name Card

signal card_clicked(card: CardData, row: String, insert_index: int)
signal drag_started
signal drag_ended(played: bool)
signal mulligan_clicked
signal discard_clicked

const DRAG_THRESHOLD      := 350.0
const HAND_RETURN_DISTANCE := 50.0
const BOARD_MINION_SIZE   := Vector2(100, 150)
const CARD_BACK_TEX       = preload("res://assets/card_back/card-back.png")
# Teinte grisée d'une carte déjà échangée pendant le mulligan (cohérent avec
# DeckBuilder.MAXED_TINT).
const MULLIGAN_SWAPPED_TINT := Color(0.38, 0.38, 0.38, 1)
# Teinte d'une carte sélectionnée pour la défausse de fin de tour (limite 10
# cartes en main, voir Hand.set_discard_mode) — rougeâtre pour se distinguer
# du grisé neutre du mulligan.
const DISCARD_SELECTED_TINT := Color(1.0, 0.55, 0.55, 1)
# Halo vert léger pulsant autour d'une carte jouable (mana + conditions réunis)
const PLAYABLE_GLOW_COLOR := Color(0.45, 1.0, 0.5)

# NameLabel (voir Card.tscn) : hauteur par defaut et croissance maximale vers
# le BAS (offset_top fixe) quand un nom de carte trop long deborderait sinon
# de sa case. DescLabel juste en-dessous est alors decale d'autant pour
# conserver l'espacement d'origine entre titre et description (voir
# _fit_name_label/_fit_desc_label).
const NAME_LABEL_DEFAULT_TOP    := 158.0
const NAME_LABEL_DEFAULT_BOTTOM := 183.0
const NAME_LABEL_MAX_GROWTH     := 34.0

# DescLabel (voir Card.tscn) : position/hauteur par defaut (le haut est decale
# par la croissance de NameLabel, voir ci-dessus), et jusqu'ou on peut
# l'agrandir vers le BAS (avant de recouvrir AttackLabel/HealthLabel juste
# en-dessous) si le texte (effet + flavour) deborde toujours de sa case.
# AttackLabel / HealthLabel sont alors decales d'autant. TypeLabel (bandeau de
# type) est desormais fixe en haut de carte (voir Card.tscn), independant.
const DESC_LABEL_DEFAULT_TOP    := 186.0
const DESC_LABEL_DEFAULT_BOTTOM := 328.5
const DESC_LABEL_MAX_GROWTH     := 3.0

# LaneIcon (filigrane central) : hauteur fixe (voir Card.tscn), recentree
# verticalement sur le centre reel de DescLabel par _center_lane_icon (celui-ci
# se decale selon la croissance de NameLabel/DescLabel, voir _fit_desc_label).
const LANE_ICON_DEFAULT_TOP    := 176.0
const LANE_ICON_DEFAULT_BOTTOM := 316.0

# AttackLabel/HealthLabel (voir Card.tscn) : position par defaut, decalee par
# _fit_desc_label si DescLabel deborde (voir DESC_LABEL_MAX_GROWTH).
const STATS_LABEL_DEFAULT_TOP    := 330.0
const STATS_LABEL_DEFAULT_BOTTOM := 364.0

const BORDER_TEXTURES := {
	Race.Type.DEMON: preload("res://assets/borders/demon-border-card.png"),
	Race.Type.UNDEAD: preload("res://assets/borders/undead-border-card.png"),
	Race.Type.ABOMINATION: preload("res://assets/borders/abomination-border-card.png"),
	Race.Type.HUMAN:  preload("res://assets/borders/human-border-card.png")
}

const RARITY_COLORS := {
	"Common":    Color("808080"),
	"Rare":      Color("3498db"),
	"Epic":      Color("9b59b6"),
	"Legendary": Color("f39c12")
}

const RACE_COLORS := {
	Race.Type.UNDEAD: Color("#0a0806d6"),
	Race.Type.ABOMINATION: Color("020a00d6"),
	Race.Type.HUMAN:  Color("#28200cd6"),
	Race.Type.ELF:    Color("#1f4038b0"),
	Race.Type.DWARF:  Color("#3f280fb0"),
	Race.Type.DEMON:  Color("#1e0308d6"),
}

# Teinte du logo de type/rangée selon la race (remplace l'ancien badge circulaire)
const RACE_ICON_COLORS := {
	Race.Type.NONE:   Color("#c9b389"),
	Race.Type.UNDEAD: Color("#e2e2e2"),
	Race.Type.ABOMINATION: Color("#bdeb9c"),
	Race.Type.HUMAN:  Color("#f2d98f"),
	Race.Type.ELF:    Color("#a6e6d8"),
	Race.Type.DWARF:  Color("#e8c295"),
	Race.Type.DEMON:  Color("#f2a3b0"),
}

# Libellé français du bandeau de type (la couleur du bandeau vient de la rareté)
const TYPE_LABELS := {
	"Minion":      "cardtype.minion",
	"Instant":     "cardtype.instant",
	"Ritual":      "cardtype.ritual",
	"Enchantment": "cardtype.enchantment",
	"Resource":    "cardtype.resource",
}

# TypeLabel (bandeau sur la bordure dorée, voir Card.tscn) : largeur ajustee
# au texte affiche (ex. "Rituel • 3 charges" est plus long que "Ritule")
# plutot que fixe, entre ces deux bornes, toujours centre horizontalement.
# TYPE_LABEL_PADDING doit rester egal a la somme des content_margin_left/right
# de _type_style (voir _ready) pour que le texte ne touche jamais le bord.
# Le noeud est ancre a 50% (anchor_left = anchor_right = 0.5, voir Card.tscn)
# plutot que positionne a un pixel fixe : offset_left/right sont donc relatifs
# a ce point d'ancrage (0 = centre), pas a une largeur de carte supposee fixe
# (la carte est etiree a des largeurs differentes selon le contexte : main,
# grille du deck builder, apercu au survol).
const TYPE_LABEL_MIN_WIDTH := 160.0
const TYPE_LABEL_MAX_WIDTH := 175.0
const TYPE_LABEL_PADDING   := 16.0

# Icône indiquant la rangée où le serviteur se pose (serviteurs uniquement)
const LANE_ICONS := {
	"Front":  preload("res://assets/icons/front_lane.png"),
	"Back":   preload("res://assets/icons/back_lane.png"),
	"Hybrid": preload("res://assets/icons/hibrid_lane.png"),
}

# Icône filigrane indiquant le type des cartes non-serviteur
const TYPE_ICONS := {
	"Instant":     preload("res://assets/icons/instant.png"),
	"Ritual":      preload("res://assets/icons/ritual.png"),
	"Enchantment": preload("res://assets/icons/enchantment.png"),
}

@onready var art: TextureRect          = $Art
@onready var name_label: Label         = $NameLabel
@onready var cost_label: Label         = $CostLabel
@onready var generic_cost_label: Label = $GenericCostLabel
@onready var attack_label: Label       = $AttackLabel
@onready var health_label: Label       = $HealthLabel
@onready var desc_label: RichTextLabel = $DescLabel
@onready var border: TextureRect       = $BorderFrame
@onready var type_label: Label         = $TypeLabel
@onready var lane_icon: TextureRect    = $LaneIcon

var data: CardData
var drag_enabled := true
# En phase de mulligan : un simple clic remplace la carte, aucun drag possible.
var mulligan_mode := false
# Cette carte a déjà été échangée pendant le mulligan en cours : grisée, plus
# cliquable tant que la phase de mulligan n'est pas terminée.
var mulligan_swapped := false
# En phase de défausse de fin de tour (limite 10 cartes) : un simple clic
# sélectionne/désélectionne la carte pour la défausse, aucun drag possible —
# même patron que mulligan_mode.
var discard_mode := false
var discard_selected := false

# Référence vers la main, injectée par Hand
var hand_ref: Control = null

# Drag state
var dragging          := false
var original_position : Vector2
var original_scale    : Vector2
var drag_start_mouse  : Vector2
var last_drag_mouse   : Vector2
var drag_rotation     := 0.0
var _drag_board_minion: Control = null
var _drag_released    := false

# Référence battle mise en cache au début du drag
var _battle: Node = null

var can_drag_check: Callable = Callable()
var create_drag_preview: Callable = Callable()

var _name_bg_style: StyleBoxFlat
var _desc_bg_style: StyleBoxFlat
var _cost_bg_style: StyleBoxFlat
var _type_style    := StyleBoxFlat.new()

var _playable_glow: Panel = null
var _playable_style: StyleBoxFlat = null
var _playable_pulse: float = 0.0
var _is_playable: bool = false

func _ready() -> void:
	_battle = get_tree().current_scene
	_name_bg_style = (name_label.get_theme_stylebox("normal") as StyleBoxFlat).duplicate()
	name_label.add_theme_stylebox_override("normal", _name_bg_style)
	_desc_bg_style = (desc_label.get_theme_stylebox("normal") as StyleBoxFlat).duplicate()
	desc_label.add_theme_stylebox_override("normal", _desc_bg_style)
	_cost_bg_style = (cost_label.get_theme_stylebox("normal") as StyleBoxFlat).duplicate()
	cost_label.add_theme_stylebox_override("normal", _cost_bg_style)
	_type_style.set_corner_radius_all(8)
	_type_style.set_border_width_all(1)
	_type_style.content_margin_left = 8.0
	_type_style.content_margin_right = 8.0
	type_label.add_theme_stylebox_override("normal", _type_style)
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_PASS

	SettingsManager.language_changed.connect(func(_l): update_display())

	_playable_style = StyleBoxFlat.new()
	_playable_style.bg_color            = Color.TRANSPARENT
	_playable_style.border_width_left   = 3
	_playable_style.border_width_right  = 3
	_playable_style.border_width_top    = 3
	_playable_style.border_width_bottom = 3
	_playable_style.border_color        = PLAYABLE_GLOW_COLOR
	_playable_style.set_corner_radius_all(10)
	_playable_glow = Panel.new()
	_playable_glow.name = "PlayableGlow"
	_playable_glow.position = Vector2(-9, -10)
	_playable_glow.size = Vector2(268, 393)
	_playable_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playable_glow.add_theme_stylebox_override("panel", _playable_style)
	_playable_glow.visible = false
	add_child(_playable_glow)

# ─── Données ──────────────────────────────────────────────────────────────────

func set_data(new_data: CardData) -> void:
	if new_data == null:
		push_warning("Card.set_data: card_data est null, carte ignorée")
		return
	data = new_data
	update_display()

# Coût effectif affiché (remises de mana comprises), en badge de race (icône
# colorée par race, ex. "Âme" Mort-Vivant) et badge générique (surplus payable
# depuis n'importe quel pool) : vert si le total est réduit par une remise.
# Utilisé par la main en bataille ; ailleurs le coût de base reste affiché.
func set_display_cost(cost_split: Dictionary) -> void:
	if data == null:
		return
	var is_resource := data.card_type == "Resource"
	cost_label.visible = not is_resource
	if is_resource:
		generic_cost_label.visible = false
		return
	var race_cost: int = cost_split.get("race", 0)
	var generic_cost: int = cost_split.get("generic", 0)
	var reduced: bool = race_cost + generic_cost < data.cost
	var color := Color(0.45, 1.0, 0.45) if reduced else Color.WHITE
	cost_label.text = str(race_cost)
	cost_label.add_theme_color_override("font_color", color)
	generic_cost_label.visible = generic_cost > 0
	generic_cost_label.text = str(generic_cost)
	generic_cost_label.add_theme_color_override("font_color", color)

func update_display() -> void:
	if data == null:
		return
	name_label.text   = data.display_name()
	var is_resource := data.card_type == "Resource"
	var base_race_cost: int = CostSystem.compute_race_cost(
		data.cost, data.race, data.rarity, data.race_cost_override)
	cost_label.visible = not is_resource
	cost_label.text = str(base_race_cost)
	generic_cost_label.visible = not is_resource and data.cost - base_race_cost > 0
	generic_cost_label.text = str(data.cost - base_race_cost)
	attack_label.text = str(data.attack)
	health_label.text = str(data.health)

	var is_minion := data.card_type == "Minion"
	attack_label.visible = is_minion
	health_label.visible = is_minion

	# Filigrane central : icône de rangée (serviteurs) ou de type (cartes non-serviteur),
	# teintée par race (plus de badge circulaire en fond)
	if is_minion:
		lane_icon.visible = LANE_ICONS.has(data.board_position)
		if lane_icon.visible:
			lane_icon.texture = LANE_ICONS[data.board_position]
	else:
		lane_icon.visible = TYPE_ICONS.has(data.card_type)
		if lane_icon.visible:
			lane_icon.texture = TYPE_ICONS[data.card_type]
	if lane_icon.visible:
		lane_icon.modulate = RACE_ICON_COLORS.get(data.race, Color("#bebebe"))

	if not data.flavour_text.is_empty() and data.description.is_empty():
		desc_label.text = "[center][font_size=12][i]" + data.display_flavour() + "[/i][/font_size][/center]"
	elif not data.flavour_text.is_empty():
		desc_label.text = bold_keywords_and_triggers(data.display_description())
		desc_label.text += "\n[font_size=12][i]" + data.display_flavour() + "[/i][/font_size]"
	else:
		desc_label.text = bold_keywords_and_triggers(data.display_description())

	if data.texture:
		art.texture = data.texture

	if BORDER_TEXTURES.has(data.race):
		border.texture = BORDER_TEXTURES[data.race]
	else:
		push_warning("Pas de bordure pour la race: %s" % Race.get_race_name(data.race))

	var name_growth := _fit_name_label()
	_fit_desc_label(name_growth)
	_center_lane_icon()

	_apply_race_style()
	_apply_type_style()
	update_playable_highlight()

# Agrandit NameLabel vers le BAS (offset_top fixe) quand le nom de la carte,
# une fois retourne a la ligne dans la largeur de la case, prend plus de
# hauteur que la case par defaut — ne mange donc plus l'artwork au-dessus.
# Plafonne a NAME_LABEL_MAX_GROWTH ; DescLabel juste en-dessous est decale
# d'autant par l'appelant (voir _fit_desc_label) pour garder le meme
# espacement entre le titre et la description qu'a l'etat par defaut.
# Retourne la croissance appliquee (0.0 si le nom tient dans sa case).
func _fit_name_label() -> float:
	name_label.offset_top = NAME_LABEL_DEFAULT_TOP
	name_label.offset_bottom = NAME_LABEL_DEFAULT_BOTTOM
	var font: Font = name_label.get_theme_font("font")
	var font_size: int = name_label.get_theme_font_size("font_size")
	if font == null:
		return 0.0
	var line_count: int = maxi(name_label.get_line_count(), 1)
	var needed: float = line_count * font.get_height(font_size)
	var default_height: float = NAME_LABEL_DEFAULT_BOTTOM - NAME_LABEL_DEFAULT_TOP
	if needed <= default_height:
		return 0.0
	var growth: float = minf(needed - default_height, NAME_LABEL_MAX_GROWTH)
	name_label.offset_bottom = NAME_LABEL_DEFAULT_BOTTOM + growth
	return growth

# Agrandit DescLabel vers le BAS si le texte (effet + flavour) deborde de sa
# case par defaut, et decale AttackLabel/HealthLabel d'autant pour eviter
# que la case ne les recouvre. Plafonne a DESC_LABEL_MAX_GROWTH (peu de
# marge avant le bas de la carte) : au-dela, le texte redevient legerement
# rogne plutot que de faire deborder les stats hors de la carte.
# name_growth : decalage vers le bas deja applique a NameLabel (voir
# _fit_name_label) — reporte sur le haut de DescLabel pour preserver
# l'espacement d'origine entre les deux.
func _fit_desc_label(name_growth: float) -> void:
	desc_label.offset_top = DESC_LABEL_DEFAULT_TOP + name_growth
	desc_label.offset_bottom = DESC_LABEL_DEFAULT_BOTTOM
	if attack_label:
		attack_label.offset_top = STATS_LABEL_DEFAULT_TOP
		attack_label.offset_bottom = STATS_LABEL_DEFAULT_BOTTOM
	if health_label:
		health_label.offset_top = STATS_LABEL_DEFAULT_TOP
		health_label.offset_bottom = STATS_LABEL_DEFAULT_BOTTOM
	var overflow: float = desc_label.get_content_height() - (DESC_LABEL_DEFAULT_BOTTOM - desc_label.offset_top)
	if overflow <= 0.0:
		return
	var growth: float = min(overflow, DESC_LABEL_MAX_GROWTH)
	desc_label.offset_bottom += growth
	if attack_label:
		attack_label.offset_top += growth
		attack_label.offset_bottom += growth
	if health_label:
		health_label.offset_top += growth
		health_label.offset_bottom += growth

# Recentre verticalement le filigrane (LaneIcon) sur le centre reel de
# DescLabel : celui-ci se decale (croissance de NameLabel) et peut grandir
# (croissance de DescLabel), voir _fit_desc_label — appele juste apres pour
# que le filigrane suive. Hauteur d'icone fixe, seul le centre bouge.
func _center_lane_icon() -> void:
	var icon_height: float = LANE_ICON_DEFAULT_BOTTOM - LANE_ICON_DEFAULT_TOP
	var desc_center_y: float = (desc_label.offset_top + desc_label.offset_bottom) / 2.0
	lane_icon.offset_top = desc_center_y - icon_height / 2.0
	lane_icon.offset_bottom = desc_center_y + icon_height / 2.0

# Met en gras, dans le bbcode de DescLabel, le nom de declencheur en debut de
# ligne ("Trigger : ...") et les mots-cles tout en majuscules (REMPART,
# VENIN MORTEL...). Ignore les sigles courts (ATK) pour ne pas les mettre en
# gras par erreur.
static func bold_keywords_and_triggers(text: String) -> String:
	var trigger_re := RegEx.new()
	trigger_re.compile("^([^\n:]{2,40}) : (.*)$")
	var out: PackedStringArray = []
	for line in text.split("\n"):
		var m := trigger_re.search(line)
		if m:
			out.append("[b]" + m.get_string(1) + "[/b] : " + _bold_caps_words(m.get_string(2)))
		else:
			out.append(_bold_caps_words(line))
	return "\n".join(out)

# Met en gras les suites de majuscules (mots-cles) d'au moins 4 lettres,
# espaces/tirets internes toleres (ex: "VENIN MORTEL", "RANG INFERNAL").
static func _bold_caps_words(line: String) -> String:
	var caps_re := RegEx.new()
	caps_re.compile("[À-ÝA-Z][À-ÝA-Z\\-]*(?: [À-ÝA-Z][À-ÝA-Z\\-]*)*")
	var result := ""
	var pos := 0
	for m in caps_re.search_all(line):
		var matched: String = m.get_string()
		var letters_only: String = matched.replace(" ", "").replace("-", "")
		result += line.substr(pos, m.get_start() - pos)
		if letters_only.length() >= 4:
			result += "[b]" + matched + "[/b]"
		else:
			result += matched
		pos = m.get_end()
	result += line.substr(pos)
	return result

# Recalcule si la carte est jouable (mana + conditions) et bascule le halo vert.
# À appeler chaque fois qu'un état pouvant changer la jouabilité évolue (mana,
# tour, cimetière...) — voir Hand.refresh_playable_highlights().
func update_playable_highlight() -> void:
	if _playable_glow == null:
		return
	var should_show: bool = data != null and not mulligan_mode and not discard_mode and not dragging \
		and _is_players_turn() \
		and can_drag_check.is_valid() and can_drag_check.call(data)
	if should_show != _is_playable:
		_is_playable = should_show
		_playable_pulse = 0.0
		_playable_style.border_color = PLAYABLE_GLOW_COLOR
		_playable_glow.visible = should_show

func _is_players_turn() -> bool:
	if _battle == null or not ("enemy_turn_active" in _battle):
		return true
	if "game_over" in _battle and _battle.game_over:
		return false
	return not _battle.enemy_turn_active

# Le bandeau de type affiche le type (FR) ; sa couleur reflète la rareté
func _apply_type_style() -> void:
	var translation_key: String = TYPE_LABELS.get(data.card_type, "cardtype.minion")
	var label_text: String = SettingsManager.t(translation_key)
	if data.card_type == "Ritual":
		if data.ritual_duration > 0:
			label_text += " • %d charge%s" % [data.ritual_duration, "s" if data.ritual_duration > 1 else ""]
		elif data.ritual_duration == -1:
			label_text += " • Permanent"
	type_label.text = label_text
	_fit_type_label()

	var rarity_color: Color = RARITY_COLORS.get(data.rarity, Color("808080"))
	var bg := rarity_color
	bg.a = 0.85
	_type_style.bg_color = bg
	_type_style.border_color = Color(0.65882355, 0.47843137, 0.20392157, 0.9)
	_type_style.set_border_width_all(2)

# Redimensionne le bandeau TypeLabel a la largeur de son texte (ex. "Rituel •
# 3 charges" est plus long que "Enchantement"), entre TYPE_LABEL_MIN_WIDTH et
# TYPE_LABEL_MAX_WIDTH, toujours centre sur le point d'ancrage (voir const
# ci-dessus).
func _fit_type_label() -> void:
	# Repli sur ThemeDB.fallback_font : sans thème de projet appliqué (ex.
	# scène instanciée seule dans un test GUT headless), get_theme_font("font")
	# renvoie null et la mesure ne se ferait jamais, laissant le bandeau à sa
	# largeur par défaut dans Card.tscn quel que soit le texte réel.
	var font: Font = type_label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var font_size: int = type_label.get_theme_font_size("font_size")
	if font_size <= 0:
		font_size = ThemeDB.fallback_font_size
	if font == null:
		return
	var text_width: float = font.get_string_size(type_label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	var width: float = clampf(text_width + TYPE_LABEL_PADDING, TYPE_LABEL_MIN_WIDTH, TYPE_LABEL_MAX_WIDTH)
	type_label.offset_left  = -width / 2.0
	type_label.offset_right = width / 2.0

func _apply_race_style() -> void:
	var race_color: Color = RACE_COLORS.get(data.race, Color.WHITE)
	_name_bg_style.bg_color = race_color
	_desc_bg_style.bg_color = race_color
	# Badge de coût "race" teinté par la race de la carte : distingue au premier
	# coup d'œil le mana verrouillé (icône/couleur) du mana générique à côté.
	var cost_color := race_color
	cost_color.a = 0.9
	_cost_bg_style.bg_color = cost_color
	_cost_bg_style.border_color = cost_color

# ─── Mulligan ─────────────────────────────────────────────────────────────────

func set_mulligan_swapped(swapped: bool) -> void:
	mulligan_swapped = swapped
	modulate = MULLIGAN_SWAPPED_TINT if swapped else Color.WHITE

func set_discard_selected(selected: bool) -> void:
	discard_selected = selected
	modulate = DISCARD_SELECTED_TINT if selected else Color.WHITE

# ─── Drag & Drop ──────────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if discard_mode:
		if event is InputEventMouseButton \
				and event.button_index == MOUSE_BUTTON_LEFT \
				and event.pressed:
			discard_clicked.emit()
			get_viewport().set_input_as_handled()
		return
	if mulligan_mode:
		if event is InputEventMouseButton \
				and event.button_index == MOUSE_BUTTON_LEFT \
				and event.pressed:
			mulligan_clicked.emit()
			get_viewport().set_input_as_handled()
		return
	if not drag_enabled:
		return
	if not (event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed):
		return

	var battle: Node = get_tree().current_scene
	# Vérifie explicitement game_over/reconnecting ici (comme Battle._on_card_played),
	# plutôt que de compter uniquement sur un overlay plein écran pour bloquer le
	# clic : ce dernier n'apparaît qu'~1s après game_over=true (voir _show_game_over),
	# fenêtre pendant laquelle une carte glissée-déposée était détruite sans effet.
	if battle and "enemy_turn_active" in battle \
			and (battle.enemy_turn_active \
				or ("game_over" in battle and battle.game_over) \
				or ("reconnecting" in battle and battle.reconnecting)):
		get_viewport().set_input_as_handled()
		return

	var can_drag: bool = not can_drag_check.is_valid() or can_drag_check.call(data)
	if not can_drag:
		get_viewport().set_input_as_handled()
		return

	if data.card_type == "Minion":
		if battle and battle.has_method("get_allowed_rows_for_card"):
			var allowed_rows = battle.call("get_allowed_rows_for_card", data)
			var can_place := false
			for r in allowed_rows:
				if battle.call("can_summon_to_row", true, r):
					can_place = true
					break
			if not can_place:
				get_viewport().set_input_as_handled()
				return

	original_position = position
	original_scale    = scale
	drag_start_mouse  = get_global_mouse_position()
	last_drag_mouse   = drag_start_mouse
	drag_rotation     = 0.0
	dragging          = true
	_drag_released    = false
	update_playable_highlight()
	z_index           = 100
	visible           = false

	_battle = battle

	if create_drag_preview.is_valid():
		_drag_board_minion = create_drag_preview.call(data)

	_set_children_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	drag_started.emit()
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _playable_glow != null and _playable_glow.visible:
		_playable_pulse += delta * 2.0
		_playable_style.border_color.a = 0.5 + sin(_playable_pulse) * 0.3
		_playable_glow.queue_redraw()

	if not dragging:
		return

	var current_mouse := get_global_mouse_position()
	var delta_x := current_mouse.x - last_drag_mouse.x
	drag_rotation = clamp(drag_rotation + delta_x * 0.4, -20.0, 20.0)
	drag_rotation = lerpf(drag_rotation, 0.0, 0.1)
	last_drag_mouse = current_mouse

	if _drag_board_minion:
		_drag_board_minion.global_position = current_mouse - Vector2(50, 75)
		_drag_board_minion.rotation_degrees = drag_rotation

	# Toujours appelé pendant le drag : sans highlights, le placeholder
	# continue d'écarter les serviteurs pour prévisualiser le placement
	if _battle and _battle.get("drop_system"):
		_battle.drop_system.update_player_drop_highlight(
			data, get_viewport().get_mouse_position(), SettingsManager.show_play_highlights)

func _input(event: InputEvent) -> void:
	if not dragging:
		return
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		_on_drag_released()
		get_viewport().set_input_as_handled()

func _on_drag_released() -> void:
	dragging      = false
	drag_rotation = 0.0

	if _drag_board_minion:
		_drag_board_minion.queue_free()
		_drag_board_minion = null

	var mouse_pos := get_viewport().get_mouse_position()

	var drop_row := ""
	if _battle and _battle.get("drop_system"):
		drop_row = _battle.drop_system.get_player_drop_row_at(mouse_pos, data)

	if not drop_row.is_empty():
		var insert_index := -1
		if _battle and _battle.get("drop_system"):
			insert_index = _battle.drop_system.get_player_drop_index_at(mouse_pos, drop_row)
			_battle.drop_system.clear_player_drop_highlight()
		_battle = null
		# Pour une carte-ressource, la popup d'effet instanciée par
		# CardPopupSystem.show_resource_popup se charge de représenter la carte
		# et de la désintégrer vers le pool de mana — cette carte (invisible
		# depuis le début du drag) n'a donc plus qu'à se libérer.
		card_clicked.emit(data, drop_row, insert_index)
		drag_ended.emit(true)
		queue_free()
		return

	if _battle and _battle.get("drop_system"):
		_battle.drop_system.clear_player_drop_highlight()
	_battle = null
	_restore_in_hand()
	drag_ended.emit(false)

func _restore_in_hand() -> void:
	visible = true
	rotation_degrees = 0.0
	_set_children_mouse_filter(Control.MOUSE_FILTER_PASS)
	update_playable_highlight()
	if hand_ref and hand_ref.has_method("_update_hand_layout"):
		hand_ref._update_hand_layout()

# Les deux faisaient la même chose avec une navigation fragile — supprimés

# ─── Utilitaires ──────────────────────────────────────────────────────────────

# Décalage de l'ombre portée sous une carte/aperçu en cours de glisser-déposer
const DRAG_SHADOW_OFFSET := Vector2(10, 14)
const DRAG_SHADOW_COLOR  := Color(0, 0, 0, 0.45)

# Ajoute une ombre portée derrière `preview` (aperçu de carte suivant la
# souris pendant un drag, voir Battle._create_card_drag_preview) : détache
# visuellement la carte glissée du plateau, comme si elle flottait au-dessus.
# Statique et réutilisable par toutes les scènes ayant leur propre aperçu de
# glisser-déposer (Battle, ArenaBattle...).
static func add_drag_shadow(preview: Control) -> void:
	var shadow := Panel.new()
	shadow.name = "DragShadow"
	var style := StyleBoxFlat.new()
	style.bg_color = DRAG_SHADOW_COLOR
	style.set_corner_radius_all(10)
	shadow.add_theme_stylebox_override("panel", style)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.position = DRAG_SHADOW_OFFSET
	shadow.size = BOARD_MINION_SIZE
	preview.add_child(shadow)
	preview.move_child(shadow, 0)

func _set_children_mouse_filter(filter: int) -> void:
	for child in get_children():
		if child is Control:
			child.mouse_filter = filter

func set_non_interactive() -> void:
	drag_enabled = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_back(show_card_back: bool) -> void:
	if show_card_back:
		art.texture = CARD_BACK_TEX
		name_label.hide()
		cost_label.hide()
		generic_cost_label.hide()
		attack_label.hide()
		health_label.hide()
		desc_label.hide()
		border.hide()
		lane_icon.hide()
		type_label.hide()
	else:
		if data:
			update_display()
		name_label.show()
		cost_label.show()
		attack_label.show()
		health_label.show()
		desc_label.show()
		border.show()
		type_label.show()
