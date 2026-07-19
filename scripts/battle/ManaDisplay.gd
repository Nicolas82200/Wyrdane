extends PanelContainer
class_name ManaDisplay

## Affichage du mana utilisable : une rangée de cristaux par race active
## (chaque race a son propre pool, voir README « Système de Ressources par Race »),
## avec un compteur "X / Y" par rangée.

const FONT_BOLD := preload("res://assets/fonts/MedievalSharp-Bold.ttf")

# Au-delà de cette limite, seuls les cristaux affichés se remplissent,
# le compteur texte reste la source exacte
const ROW_MAX_CRYSTALS: int = 6

const COLOR_TEXT := Color("cfe6ff")

# Teinte de cristal par race, réutilisée pour le swatch identifiant la rangée.
const RACE_MANA_COLORS := {
	Race.Type.HUMAN:      Color("e8c04a"),
	Race.Type.ELF:        Color("4fc2b0"),
	Race.Type.DWARF:      Color("c98a4a"),
	Race.Type.UNDEAD:     Color("9fd0d6"),
	Race.Type.DEMON:      Color("e0574a"),
	Race.Type.ABOMINATION: Color("7ee23a"),
}

const RACE_TRANSLATION_KEYS := {
	Race.Type.HUMAN:      "RACE_HUMAN",
	Race.Type.ELF:        "RACE_ELF",
	Race.Type.DWARF:      "RACE_DWARF",
	Race.Type.UNDEAD:     "RACE_UNDEAD",
	Race.Type.DEMON:      "RACE_DEMON",
	Race.Type.ABOMINATION: "RACE_ABOMINATION",
}

# Ordre d'affichage des rangées (correspond à l'ordre de l'enum Race.Type).
const RACE_ORDER: Array[int] = [
	Race.Type.HUMAN,
	Race.Type.ELF,
	Race.Type.DWARF,
	Race.Type.UNDEAD,
	Race.Type.DEMON,
	Race.Type.ABOMINATION,
]

var _vbox: VBoxContainer
var _rows: Dictionary = {} # Race.Type -> {hbox, swatch, crystals: Array[Label], amount_label}
var _last_total: int = -1
var _pulse_tween: Tween

func _ready() -> void:
	_build_style()
	_vbox = VBoxContainer.new()
	_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox.add_theme_constant_override("separation", 2)
	add_child(_vbox)

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

func _ensure_row(race: int) -> Dictionary:
	if _rows.has(race):
		return _rows[race]

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 3)

	var color: Color = RACE_MANA_COLORS.get(race, Color.WHITE)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(10, 10)
	swatch.color = color
	hbox.add_child(swatch)

	var crystals: Array[Label] = []
	for i in range(ROW_MAX_CRYSTALS):
		var crystal := Label.new()
		crystal.text = "◆"
		crystal.visible = false
		crystal.add_theme_font_size_override("font_size", 12)
		crystal.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		crystal.add_theme_constant_override("shadow_offset_x", 1)
		crystal.add_theme_constant_override("shadow_offset_y", 1)
		hbox.add_child(crystal)
		crystals.append(crystal)

	var amount_label := Label.new()
	amount_label.add_theme_font_override("font", FONT_BOLD)
	amount_label.add_theme_font_size_override("font_size", 14)
	amount_label.add_theme_color_override("font_color", COLOR_TEXT)
	amount_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	amount_label.add_theme_constant_override("shadow_offset_x", 1)
	amount_label.add_theme_constant_override("shadow_offset_y", 1)
	hbox.add_child(amount_label)

	_vbox.add_child(hbox)

	var row := {"hbox": hbox, "swatch": swatch, "crystals": crystals, "amount_label": amount_label}
	_rows[race] = row
	return row

func _update_row(race: int, current: int, maximum: int) -> void:
	var row: Dictionary = _rows[race]
	var color: Color = RACE_MANA_COLORS.get(race, Color.WHITE)
	var color_empty: Color = color.darkened(0.7)

	var amount_label: Label = row["amount_label"]
	amount_label.text = "%d/%d" % [current, maximum]

	var crystals: Array = row["crystals"]
	var shown: int = mini(maximum, ROW_MAX_CRYSTALS)
	for i in range(ROW_MAX_CRYSTALS):
		var crystal: Label = crystals[i]
		crystal.visible = i < shown
		var filled: bool = i < mini(current, shown)
		crystal.add_theme_color_override("font_color", color if filled else color_empty)

## Point d'entrée principal : reçoit les pools de mana par race (`Battle.race_mana`
## / `race_max_mana` ou leurs équivalents adverses) et construit une rangée par
## race active (max_pool[race] > 0).
func set_mana_pools(pool: Dictionary, max_pool: Dictionary) -> void:
	var total_current := 0
	var tooltip_lines: Array[String] = []
	var active: Dictionary = {}

	for race in RACE_ORDER:
		var max_v: int = int(max_pool.get(race, 0))
		if max_v <= 0:
			continue
		var cur_v: int = int(pool.get(race, 0))
		total_current += cur_v
		active[race] = true
		_ensure_row(race)
		_update_row(race, cur_v, max_v)
		var race_key: String = RACE_TRANSLATION_KEYS.get(race, "")
		var race_name: String = SettingsManager.t(race_key) if race_key != "" else Race.get_race_name(race)
		tooltip_lines.append("%s : %d / %d" % [race_name, cur_v, max_v])

	for race in _rows.keys().duplicate():
		if not active.has(race):
			_rows[race]["hbox"].queue_free()
			_rows.erase(race)

	tooltip_text = "\n".join(tooltip_lines)

	if total_current > _last_total and _last_total >= 0:
		_pulse()
	_last_total = total_current

## Point d'ancrage global de la rangée d'une race (centre du swatch coloré),
## utilisé par les animations qui doivent converger vers le pool de mana
## correspondant (ex. absorption d'une carte-ressource jouée). Si la rangée
## n'existe pas encore, retombe sur le centre du panneau entier.
func get_race_anchor_global_position(race: int) -> Vector2:
	if _rows.has(race):
		var swatch: ColorRect = _rows[race]["swatch"]
		return swatch.global_position + swatch.size / 2.0
	return global_position + size / 2.0

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
