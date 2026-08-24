extends Control
class_name KeywordGlossaryPanel

## Glossaire consultable à tout moment pendant un match (bouton "?" du HUD) :
## liste tous les mots-clés (communs + par race) et déclencheurs déjà décrits
## dans TooltipData (même source que les tooltips de carte), regroupés par
## section. Simple overlay centré, ne met pas la partie en pause — juste une
## fenêtre de référence que le joueur ouvre/ferme librement.
## Créé entièrement en code (aucun nœud dans Battle.tscn), même pattern que
## CombatLogPanel.

const FONT_BOLD    := preload("res://assets/fonts/MedievalSharp-Bold.ttf")
const FONT_REGULAR := preload("res://assets/fonts/MedievalSharp-Book.ttf")
const PANEL_SIZE := Vector2(560, 620)
# Marge gardée entre le panneau et les bords de l'écran : le nombre de
# sections (5 races + déclencheurs) a fini par rendre PANEL_SIZE.y trop
# grand pour tenir sur les résolutions/fenêtres plus basses que 1080p,
# poussant le bouton Fermer hors écran. La taille réelle du panneau est donc
# recalculée par rapport à la fenêtre plutôt que figée à PANEL_SIZE.
const SCREEN_MARGIN := 60.0

var _wrapper: PanelContainer
var _scroll: ScrollContainer
var _list: VBoxContainer
var _title_label: Label
var _close_button: Button

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Fond semi-transparent : bloque les clics sur le plateau tant que le
	# glossaire est ouvert, comme un modal classique.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_wrapper = PanelContainer.new()
	# Position en pixels absolus via get_viewport_rect() (voir _update_layout),
	# pas via ancres fractionnaires : celles-ci se résolvent contre la taille de
	# `self` (ce Control), qui hérite du PRESET_FULL_RECT posé juste au-dessus —
	# pas garanti résolu dès ce frame puisque `self` vient d'entrer dans l'arbre.
	# Un ancrage à 0.5 contre une taille encore à 0x0 centre le panneau sur (0,0)
	# plutôt que sur l'écran : seul son coin bas-droit (le quart qui déborde vers
	# les coordonnées positives) reste visible. Même piège et même parade que
	# ReconnectOverlay._center_panel (position absolue recalculée à chaque frame
	# nécessaire, jamais figée dans des ancres).
	var style := StyleBoxFlat.new()
	style.bg_color              = Color("1a0e0ef2")
	style.border_width_top      = 2
	style.border_width_bottom   = 2
	style.border_width_left     = 2
	style.border_width_right    = 2
	style.border_color          = Color("c9a227")
	style.content_margin_left   = 16
	style.content_margin_right  = 16
	style.content_margin_top    = 12
	style.content_margin_bottom = 12
	_wrapper.add_theme_stylebox_override("panel", style)
	add_child(_wrapper)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_wrapper.add_child(vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_override("font", FONT_BOLD)
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color("e8d5a3"))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)

	_close_button = Button.new()
	_close_button.custom_minimum_size = Vector2(140, 40)
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close_button.pressed.connect(func():
		AudioManager.play(AudioManager.CLOSE_MENU)
		close()
	)
	vbox.add_child(_close_button)

	_populate()
	_retranslate()
	_update_layout()
	SettingsManager.language_changed.connect(func(_l): _retranslate())
	get_viewport().size_changed.connect(_update_layout)

func _update_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var panel_size := Vector2(
		min(PANEL_SIZE.x, viewport_size.x - SCREEN_MARGIN),
		min(PANEL_SIZE.y, viewport_size.y - SCREEN_MARGIN)
	)
	_wrapper.custom_minimum_size = panel_size
	_scroll.custom_minimum_size = Vector2(panel_size.x - 32, panel_size.y - 90)
	_wrapper.reset_size()
	_wrapper.position = (viewport_size - _wrapper.size) / 2.0

func open() -> void:
	_update_layout()
	visible = true
	AudioManager.play(AudioManager.OPEN_MENU)

func close() -> void:
	visible = false

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func _populate() -> void:
	for child in _list.get_children():
		child.queue_free()
	_add_section("GLOSSARY_SECTION_COMMON", TooltipData.KEYWORD_DESCRIPTIONS, TooltipData.COLOR_KEYWORD)
	_add_section("RACE_HUMAN", TooltipData.KEYWORD_HUMAN_DESCRIPTIONS, TooltipData.COLOR_KEYWORD_HUMAN)
	_add_section("RACE_UNDEAD", TooltipData.KEYWORD_UNDEAD_DESCRIPTIONS, TooltipData.COLOR_KEYWORD_UNDEAD)
	_add_section("RACE_DEMON", TooltipData.KEYWORD_DEMON_DESCRIPTIONS, TooltipData.COLOR_KEYWORD_DEMON)
	_add_section("RACE_ABOMINATION", TooltipData.KEYWORD_ABOMINATION_DESCRIPTIONS, TooltipData.COLOR_KEYWORD_ABOMINATION)
	_add_section("GLOSSARY_SECTION_TRIGGERS", TooltipData.TRIGGER_DESCRIPTIONS, TooltipData.COLOR_TRIGGER)

func _add_section(header_key: String, entries: Dictionary, color: Color) -> void:
	var header := Label.new()
	header.add_theme_font_override("font", FONT_BOLD)
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", color.lightened(0.55))
	header.set_meta("i18n_key", header_key)
	_list.add_child(header)

	for info in entries.values():
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 0)

		var name_label := Label.new()
		name_label.add_theme_font_override("font", FONT_BOLD)
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", Color("e8d5a3"))
		name_label.set_meta("i18n_key", info["title"])
		row.add_child(name_label)

		var desc_label := Label.new()
		desc_label.add_theme_font_override("font", FONT_REGULAR)
		desc_label.add_theme_font_size_override("font_size", 13)
		desc_label.add_theme_color_override("font_color", Color("c9beac"))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.set_meta("i18n_key", info["desc"])
		row.add_child(desc_label)

		_list.add_child(row)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	_list.add_child(spacer)

func _retranslate() -> void:
	_title_label.text = SettingsManager.t("GLOSSARY_TITLE")
	_close_button.text = SettingsManager.t("MENU_CLOSE")
	for node in _list.get_children():
		if node.has_meta("i18n_key"):
			node.text = SettingsManager.t(node.get_meta("i18n_key"))
		for child in node.get_children():
			if child.has_meta("i18n_key"):
				child.text = SettingsManager.t(child.get_meta("i18n_key"))
