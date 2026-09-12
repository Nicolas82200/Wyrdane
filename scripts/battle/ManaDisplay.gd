extends PanelContainer
class_name ManaDisplay

## Affichage du mana utilisable : une grille de "cases" (une par race active,
## chaque race ayant son propre pool, voir README « Système de Ressources par
## Race »), chaque case affichant le logo de la race et un compteur "X / Y".
## Découpage de la grille selon le nombre de races actives :
##   1 → une seule case, centrée
##   2 → grille coupée en 2 parts égales (1 rangée de 2 cases)
##   3 → grille coupée en 4 parts égales, 1 case vide (2x2, 1 case libre)
##   4 → grille coupée en 4 parts égales, toutes remplies (2x2)
## Le mana temporaire hors-race (Race.Type.NONE, ex: Vortex des Âmes) n'entre
## jamais dans cette grille : une case dédiée occupant toute la largeur
## s'affiche au-dessus, uniquement tant qu'il en reste.

const FONT_BOLD := preload("res://assets/fonts/MedievalSharp-Bold.ttf")

const COLOR_TEXT := Color("cfe6ff")

# Opacité du fond coloré de chaque case (couleur de la race, atténuée).
const CELL_BG_ALPHA: float = 0.22
const CELL_BORDER_ALPHA: float = 0.55

# Teinte par race, utilisée pour le fond des cases et pour teinter le logo.
const RACE_MANA_COLORS := {
	Race.Type.HUMAN:      Color("e8c04a"),
	Race.Type.ELF:        Color("4fc2b0"),
	Race.Type.DWARF:      Color("c98a4a"),
	Race.Type.UNDEAD:     Color("9fd0d6"),
	Race.Type.DEMON:      Color("e0574a"),
	Race.Type.ABOMINATION: Color("7ee23a"),
	Race.Type.NONE:       Color("c9a6ff"),
}

# Logo de la carte-ressource de chaque race, affiché dans sa case.
# Elfe/Nain/mana temporaire (Type.NONE) n'ont pas de carte-ressource dédiée :
# pas d'entrée ici, fallback sur un simple carré de couleur (voir _make_cell).
const RACE_MANA_ICONS := {
	Race.Type.UNDEAD:      preload("res://assets/icons/fleshy-mass.svg"),
	Race.Type.HUMAN:       preload("res://assets/icons/wax-seal.svg"),
	Race.Type.DEMON:       preload("res://assets/icons/soul.svg"),
	Race.Type.ABOMINATION: preload("res://assets/icons/internal-organ.svg"),
}

const RACE_TRANSLATION_KEYS := {
	Race.Type.HUMAN:      "RACE_HUMAN",
	Race.Type.ELF:        "RACE_ELF",
	Race.Type.DWARF:      "RACE_DWARF",
	Race.Type.UNDEAD:     "RACE_UNDEAD",
	Race.Type.DEMON:      "RACE_DEMON",
	Race.Type.ABOMINATION: "RACE_ABOMINATION",
}

# Ordre d'affichage des cases (correspond à l'ordre de l'enum Race.Type).
const RACE_ORDER: Array[int] = [
	Race.Type.HUMAN,
	Race.Type.ELF,
	Race.Type.DWARF,
	Race.Type.UNDEAD,
	Race.Type.DEMON,
	Race.Type.ABOMINATION,
]

var _vbox: VBoxContainer
var _temp_cell: PanelContainer
var _temp_amount_label: Label
var _grid: GridContainer
var _last_total: int = -1
var _pulse_tween: Tween

func _ready() -> void:
	_build_style()
	_vbox = VBoxContainer.new()
	_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox.add_theme_constant_override("separation", 3)
	add_child(_vbox)

	_temp_cell = _make_cell_container(RACE_MANA_COLORS[Race.Type.NONE])
	_temp_cell.visible = false
	_temp_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var temp_hbox := HBoxContainer.new()
	temp_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	temp_hbox.add_theme_constant_override("separation", 3)
	_temp_amount_label = _make_amount_label()
	temp_hbox.add_child(_temp_amount_label)
	_temp_cell.add_child(temp_hbox)
	_vbox.add_child(_temp_cell)

	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	_vbox.add_child(_grid)

func _build_style() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color                   = Color("101a2bcc")
	bg.border_width_left          = 2
	bg.border_width_right         = 2
	bg.border_width_top           = 2
	bg.border_width_bottom        = 2
	bg.border_color               = Color("3f6fa8")
	bg.corner_radius_top_left     = 8
	bg.corner_radius_top_right    = 8
	bg.corner_radius_bottom_left  = 8
	bg.corner_radius_bottom_right = 8
	bg.content_margin_left        = 10.0
	bg.content_margin_right       = 10.0
	bg.content_margin_top         = 4.0
	bg.content_margin_bottom      = 4.0
	bg.shadow_color               = Color(0, 0, 0, 0.4)
	bg.shadow_size                = 4
	add_theme_stylebox_override("panel", bg)

func _make_amount_label() -> Label:
	var amount_label := Label.new()
	amount_label.add_theme_font_override("font", FONT_BOLD)
	amount_label.add_theme_font_size_override("font_size", 18)
	amount_label.add_theme_color_override("font_color", COLOR_TEXT)
	amount_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	amount_label.add_theme_constant_override("shadow_offset_x", 1)
	amount_label.add_theme_constant_override("shadow_offset_y", 1)
	return amount_label

func _make_cell_container(color: Color) -> PanelContainer:
	var cell := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color                   = Color(color.r, color.g, color.b, CELL_BG_ALPHA)
	sb.border_width_left          = 1
	sb.border_width_right         = 1
	sb.border_width_top           = 1
	sb.border_width_bottom        = 1
	sb.border_color                = Color(color.r, color.g, color.b, CELL_BORDER_ALPHA)
	sb.corner_radius_top_left     = 5
	sb.corner_radius_top_right    = 5
	sb.corner_radius_bottom_left  = 5
	sb.corner_radius_bottom_right = 5
	sb.content_margin_left        = 5.0
	sb.content_margin_right       = 5.0
	sb.content_margin_top         = 2.0
	sb.content_margin_bottom      = 2.0
	cell.add_theme_stylebox_override("panel", sb)
	return cell

func _make_race_cell(race: int) -> PanelContainer:
	var color: Color = RACE_MANA_COLORS.get(race, Color.WHITE)
	var cell := _make_cell_container(color)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 3)

	var swatch: Control
	if RACE_MANA_ICONS.has(race):
		var icon := TextureRect.new()
		icon.texture = RACE_MANA_ICONS[race]
		icon.custom_minimum_size = Vector2(22, 22)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = color
		swatch = icon
	else:
		var rect := ColorRect.new()
		rect.custom_minimum_size = Vector2(13, 13)
		rect.color = color
		swatch = rect
	hbox.add_child(swatch)

	var amount_label := _make_amount_label()
	amount_label.set_meta("amount_label", true)
	hbox.add_child(amount_label)

	cell.add_child(hbox)
	cell.set_meta("amount_label_ref", amount_label)
	return cell

func _make_placeholder_cell() -> Control:
	var cell := Control.new()
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return cell

## Point d'entrée principal : reçoit les pools de mana par race (`Battle.race_mana`
## / `race_max_mana` ou leurs équivalents adverses) et reconstruit la grille de cases.
func set_mana_pools(pool: Dictionary, max_pool: Dictionary) -> void:
	var total_current := 0
	var tooltip_lines: Array[String] = []
	var active: Array[int] = []

	for race in RACE_ORDER:
		var max_v: int = int(max_pool.get(race, 0))
		if max_v <= 0:
			continue
		var cur_v: int = int(pool.get(race, 0))
		total_current += cur_v
		active.append(race)
		var race_key: String = RACE_TRANSLATION_KEYS.get(race, "")
		var race_name: String = SettingsManager.t(race_key) if race_key != "" else Race.get_race_name(race)
		tooltip_lines.append("%s : %d / %d" % [race_name, cur_v, max_v])

	# Mana temporaire (Race.Type.NONE) : surplus hors-race gagné en combat
	# (ex: Vortex des Âmes), jamais rechargé, jamais comptabilisé dans la grille.
	var temp_mana: int = int(pool.get(Race.Type.NONE, 0))
	if temp_mana > 0:
		total_current += temp_mana
		tooltip_lines.append("%s : +%d" % [SettingsManager.t("MANA_TEMPORARY"), temp_mana])

	tooltip_text = "\n".join(tooltip_lines)

	_rebuild_grid(active, pool, max_pool)
	_update_temp_cell(temp_mana)

	if total_current > _last_total and _last_total >= 0:
		_pulse()
	_last_total = total_current

func _rebuild_grid(active: Array[int], pool: Dictionary, max_pool: Dictionary) -> void:
	for child in _grid.get_children():
		child.queue_free()

	var count: int = active.size()
	if count <= 0:
		return

	var single: bool = count <= 1
	_grid.columns = 1 if single else 2
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if single else Control.SIZE_EXPAND_FILL

	for race in active:
		var cur_v: int = int(pool.get(race, 0))
		var max_v: int = int(max_pool.get(race, 0))
		var cell := _make_race_cell(race)
		var amount_label: Label = cell.get_meta("amount_label_ref")
		amount_label.text = "%d/%d" % [cur_v, max_v]
		if not single:
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(cell)

	# 3 races actives : grille coupée en 4 (2x2), la 4e case reste vide.
	if count == 3:
		var placeholder := _make_placeholder_cell()
		placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(placeholder)

func _update_temp_cell(temp_mana: int) -> void:
	_temp_cell.visible = temp_mana > 0
	if temp_mana > 0:
		_temp_amount_label.text = "+%d" % temp_mana

func _pulse() -> void:
	pivot_offset = size / 2.0
	if _pulse_tween:
		_pulse_tween.kill()
	scale = Vector2.ONE
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.08)
	_pulse_tween.tween_property(self, "scale", Vector2.ONE, 0.15)

## Animation plus marquée lorsqu'une carte-ressource pose une nouvelle unité
## de mana max : le joueur repère l'info directement sur le terrain.
func pulse_max() -> void:
	pivot_offset = size / 2.0
	if _pulse_tween:
		_pulse_tween.kill()
	scale = Vector2.ONE
	_pulse_tween = create_tween()
	_pulse_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "scale", Vector2(1.28, 1.28), 0.18)
	_pulse_tween.tween_property(self, "scale", Vector2.ONE, 0.22)
