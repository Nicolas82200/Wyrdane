extends Control
class_name CombatLogPanel

## Panneau repliable affichant l'historique du CombatLogSystem : le joueur peut
## le consulter à tout moment pour comprendre un enchaînement d'effets ou
## rattraper ce qui s'est passé pendant le tour adverse. Chaque ligne = une
## icône + de courts segments colorés par camp (pas de phrase). Créé
## entièrement en code par Battle (aucun nœud dans Battle.tscn), sur le
## modèle de TurnBanner.

const FONT_BOLD    := preload("res://assets/fonts/MedievalSharp-Bold.ttf")
const FONT_REGULAR := preload("res://assets/fonts/MedievalSharp-Book.ttf")
const PANEL_SIZE   := Vector2(300, 420)
const TOGGLE_SIZE  := Vector2(40, 40)
const COLOR_PLAYER  := Color("9fd3ff")
const COLOR_ENEMY   := Color("ffb199")
const COLOR_NEUTRAL := Color("d8c9a3")

var battle
var combat_log: CombatLogSystem

var _toggle_button: Button
var _badge: Label
var _panel: PanelContainer
var _title_label: Label
var _scroll: ScrollContainer
var _list: VBoxContainer

func init(_battle, _combat_log: CombatLogSystem) -> void:
	battle = _battle
	combat_log = _combat_log
	combat_log.entry_added.connect(_on_entry_added)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_toggle_button = Button.new()
	_toggle_button.text = "📜"
	_toggle_button.custom_minimum_size = TOGGLE_SIZE
	_toggle_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toggle_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toggle_button.position = Vector2(-TOGGLE_SIZE.x - 8, 8)
	_toggle_button.pressed.connect(_on_toggle_pressed)
	add_child(_toggle_button)

	_badge = Label.new()
	_badge.text = "!"
	_badge.add_theme_color_override("font_color", Color("ff4444"))
	_badge.add_theme_font_size_override("font_size", 20)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.position = Vector2(-10, -6)
	_badge.visible = false
	_toggle_button.add_child(_badge)

	_build_panel()
	_retranslate()
	SettingsManager.language_changed.connect(func(_l): _retranslate())

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.position = Vector2(-PANEL_SIZE.x - 8, 8 + TOGGLE_SIZE.y + 6)
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.size = PANEL_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color              = Color("1a0e0ee6")
	style.border_width_top      = 2
	style.border_width_bottom   = 2
	style.border_width_left     = 2
	style.border_width_right    = 2
	style.border_color          = Color("c9a227")
	style.content_margin_left   = 10
	style.content_margin_right  = 10
	style.content_margin_top    = 8
	style.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", style)
	_panel.visible = false

	var vbox := VBoxContainer.new()
	_panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_override("font", FONT_BOLD)
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color("e8d5a3"))
	vbox.add_child(_title_label)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(PANEL_SIZE.x - 20, PANEL_SIZE.y - 50)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)

	add_child(_panel)

func _on_toggle_pressed() -> void:
	if _panel.visible:
		close()
	else:
		open()

func open() -> void:
	_panel.visible = true
	_badge.visible = false
	await get_tree().process_frame
	_scroll_to_bottom()

func close() -> void:
	_panel.visible = false

func _on_entry_added(entry: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)

	var icon_label := Label.new()
	icon_label.text = entry["icon"]
	icon_label.add_theme_font_size_override("font_size", 15)
	row.add_child(icon_label)

	for segment in entry["segments"]:
		var seg_label := Label.new()
		seg_label.text = segment["text"]
		seg_label.add_theme_font_override("font", FONT_REGULAR)
		seg_label.add_theme_font_size_override("font_size", 14)
		seg_label.add_theme_color_override("font_color", _segment_color(segment.get("is_player")))
		row.add_child(seg_label)

	_list.add_child(row)
	while _list.get_child_count() > CombatLogSystem.MAX_ENTRIES:
		_list.get_child(0).queue_free()

	if _panel.visible:
		await get_tree().process_frame
		_scroll_to_bottom()
	else:
		_badge.visible = true

func _segment_color(is_player) -> Color:
	if is_player == true:
		return COLOR_PLAYER
	if is_player == false:
		return COLOR_ENEMY
	return COLOR_NEUTRAL

func _scroll_to_bottom() -> void:
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

func _retranslate() -> void:
	_title_label.text = SettingsManager.t("battle.log.title")
	_toggle_button.tooltip_text = SettingsManager.t("battle.log.title")
