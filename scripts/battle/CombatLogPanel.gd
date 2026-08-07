extends Control
class_name CombatLogPanel

## Panneau repliable affichant l'historique du CombatLogSystem, créé
## entièrement en code par Battle (aucun nœud dans Battle.tscn).
##
## Positionnement en pixels ABSOLUS (position/size), pas via anchors : les
## enfants ancrés hérités de la taille du parent au moment de leur création
## se sont révélés placés hors écran (taille du parent pas encore propagée
## au tout premier frame) — même piège documenté sur TurnBanner.show_banner,
## qui contourne le problème de la même façon (get_viewport_rect().size après
## un await process_frame plutôt que des anchors).

const FONT_BOLD    := preload("res://assets/fonts/MedievalSharp-Bold.ttf")
const FONT_REGULAR := preload("res://assets/fonts/MedievalSharp-Book.ttf")
const TOGGLE_SIZE   := Vector2(40, 40)
const PANEL_WIDTH   := 260.0
const VERTICAL_GAP  := 16.0  # marge par rapport au mana adverse (haut) et à la main (bas)
const ANIM_TIME     := 0.25
const THUMB_SIZE    := Vector2(58, 80)
const COLOR_PLAYER  := Color("4CE071")
const COLOR_ENEMY   := Color("FF4D4D")
const COLOR_NEUTRAL := Color("d8c9a3")
const COLOR_DEAD_TINT := Color(0.32, 0.32, 0.32, 1.0)

var battle
var combat_log: CombatLogSystem

var _toggle_button: Button
var _badge: Label
var _wrapper: Control
var _panel: PanelContainer
var _title_label: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _panel_top_left: Vector2 = Vector2.ZERO
var _panel_height: float = 0.0
var _is_open: bool = false
var _tween: Tween

func init(_battle, _combat_log: CombatLogSystem) -> void:
	battle = _battle
	combat_log = _combat_log
	combat_log.entry_added.connect(_on_entry_added)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# La taille du viewport et la position des autres panneaux (mana adverse,
	# main) ne sont pas fiables au tout premier frame (layout pas encore propagé).
	await get_tree().process_frame

	_build_panel()

	_toggle_button = Button.new()
	_toggle_button.text = "≡"
	_toggle_button.custom_minimum_size = TOGGLE_SIZE
	_toggle_button.size = TOGGLE_SIZE
	_toggle_button.position = Vector2(0.0, _panel_top_left.y + _panel_height / 2.0 - TOGGLE_SIZE.y / 2.0)
	_toggle_button.pressed.connect(_on_toggle_pressed)
	_toggle_button.z_index = 1  # par-dessus le bord gauche du panneau
	add_child(_toggle_button)

	_badge = Label.new()
	_badge.text = "!"
	_badge.add_theme_color_override("font_color", Color("ff4444"))
	_badge.add_theme_font_size_override("font_size", 20)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.position = Vector2(TOGGLE_SIZE.x - 14, -6)
	_badge.visible = false
	_toggle_button.add_child(_badge)

	_retranslate()
	SettingsManager.language_changed.connect(func(_l): _retranslate())

func _build_panel() -> void:
	var top: float = VERTICAL_GAP
	var bottom: float = get_viewport_rect().size.y - VERTICAL_GAP
	if battle and battle.enemy_mana_display:
		top = battle.enemy_mana_display.get_global_rect().end.y + VERTICAL_GAP
	# battle.hand (le Control racine) est délibérément étiré sur toute la hauteur
	# de l'écran (voir Hand.gd/_compute_layout, hand_bottom = size.y - 30) pour
	# laisser les cartes survoler/pivoter sans être coupées : son rect global ne
	# reflète donc pas la position visuelle de la main. ManaDisplay (joueur), lui,
	# est ancré correctement juste au-dessus de la main et sert de repère fiable.
	if battle and battle.mana_display:
		bottom = battle.mana_display.get_global_rect().position.y - VERTICAL_GAP
	_panel_height = max(bottom - top, TOGGLE_SIZE.y)
	_panel_top_left = Vector2(0.0, top)

	# PanelContainer est un Container : il se redimensionne tout seul à chaque
	# frame pour épouser la taille minimale de son contenu, écrasant toute
	# tentative de forcer sa largeur à 0 pour l'animation. On l'enferme donc
	# dans un simple Control (pas un Container) qu'on anime/clippe ; le
	# PanelContainer à l'intérieur garde toujours sa taille finale.
	_wrapper = Control.new()
	_wrapper.clip_contents = true
	_wrapper.position = _panel_top_left
	_wrapper.size = Vector2(0.0, _panel_height)  # replié au départ (largeur 0)
	add_child(_wrapper)

	_panel = PanelContainer.new()
	_panel.position = Vector2.ZERO
	_panel.size = Vector2(PANEL_WIDTH, _panel_height)
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, _panel_height)
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

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(PANEL_WIDTH - 20, 0)
	_panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_override("font", FONT_BOLD)
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", Color("e8d5a3"))
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_title_label)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(PANEL_WIDTH - 20, _panel_height - 50)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)

	_wrapper.add_child(_panel)

func _on_toggle_pressed() -> void:
	if _is_open:
		close()
	else:
		open()

func open() -> void:
	if _is_open:
		return
	_is_open = true
	_badge.visible = false
	_animate_width(PANEL_WIDTH)

func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_animate_width(0.0)

func _animate_width(target_width: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_wrapper, "size:x", target_width, ANIM_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _is_open:
		_tween.tween_callback(_scroll_to_bottom)

func _on_entry_added(entry: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)

	var icon_label := Label.new()
	icon_label.text = entry["icon"]
	icon_label.add_theme_font_size_override("font_size", 22)
	row.add_child(icon_label)

	for segment in entry["segments"]:
		if segment["type"] == "card":
			row.add_child(_make_card_thumb(segment))
		else:
			var seg_label := Label.new()
			seg_label.text = segment["text"]
			seg_label.add_theme_font_override("font", FONT_REGULAR)
			seg_label.add_theme_font_size_override("font_size", 18)
			seg_label.add_theme_color_override("font_color", _segment_color(segment.get("is_player")))
			row.add_child(seg_label)

	_list.add_child(row)
	while _list.get_child_count() > CombatLogSystem.MAX_ENTRIES:
		_list.get_child(0).queue_free()

	if _is_open:
		await get_tree().process_frame
		_scroll_to_bottom()
	else:
		_badge.visible = true

# Miniature de l'illustration de la carte, encadrée d'une bordure colorée par
# camp (verte = vous, rouge = adversaire) — le nom reste accessible en tooltip.
# content_margin = border_width : sans cette marge, l'image (enfant du
# PanelContainer) recouvre entièrement la bordure et la rend invisible.
func _make_card_thumb(segment: Dictionary) -> Control:
	var frame := PanelContainer.new()
	frame.tooltip_text = segment.get("name", "")
	var color := _segment_color(segment.get("is_player"))
	var style := StyleBoxFlat.new()
	style.bg_color              = Color(color, 0.18)
	style.border_width_top      = 3
	style.border_width_bottom   = 3
	style.border_width_left     = 3
	style.border_width_right    = 3
	style.border_color          = color
	style.content_margin_left   = 3
	style.content_margin_right  = 3
	style.content_margin_top    = 3
	style.content_margin_bottom = 3
	frame.add_theme_stylebox_override("panel", style)

	# Un serviteur mort de cette attaque : portrait dans un Control (non-Container)
	# pour pouvoir superposer une tête de mort par-dessus, ce que PanelContainer
	# seul (un enfant, redimensionné à sa taille) ne permet pas.
	var stack := Control.new()
	stack.custom_minimum_size = THUMB_SIZE

	var tex := TextureRect.new()
	tex.texture = segment.get("texture")
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	var is_dead: bool = segment.get("dead", false)
	if is_dead:
		tex.modulate = COLOR_DEAD_TINT
	stack.add_child(tex)

	if is_dead:
		var skull := Label.new()
		skull.text = "X"
		skull.add_theme_font_size_override("font_size", int(THUMB_SIZE.y * 0.65))
		skull.set_anchors_preset(Control.PRESET_FULL_RECT)
		skull.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skull.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		skull.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(skull)

	frame.add_child(stack)
	return frame

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
