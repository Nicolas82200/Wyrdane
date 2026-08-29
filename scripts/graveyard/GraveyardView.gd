extends Control
class_name GraveyardView

const CARD_SCENE = preload("res://scenes/card/Card.tscn")

const GRID_CARD_SCALE       := 0.85
const GRID_CARD_HOVER_SCALE := 0.95
const GRID_WRAPPER_SIZE     := Vector2(215, 320)
const CARD_BASE_SIZE        := Vector2(250, 375)  # taille native de Card.tscn
const TOOLTIP_WIDTH         := 220.0

@onready var container   = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var count_label = $PanelContainer/MarginContainer/VBoxContainer/Header/CountLabel
@onready var close_btn   = $PanelContainer/MarginContainer/VBoxContainer/Header/CloseButton
@onready var color_rect  = $ColorRect

var _keyword_tooltips: Array[Control] = []
var _tooltip_layer:    CanvasLayer    = null
var _hovering:         bool           = false
var _hovered_wrapper:  Control        = null

func _ready() -> void:
	# Le son de fermeture est joué dans close(), pas le clic générique
	close_btn.set_meta("no_click_sound", true)
	close_btn.pressed.connect(close)
	color_rect.gui_input.connect(_on_background_clicked)
	hide()

func _on_background_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		close()

func close() -> void:
	AudioManager.play(AudioManager.CLOSE_MENU)
	_hide_keyword_tooltips()
	hide()

func open(graveyard: Graveyard) -> void:
	count_label.text = SettingsManager.t("graveyard.count_format") % graveyard.size()
	var entries: Array = []
	# Pile LIFO : la mort la plus récente est affichée en premier
	for i in range(graveyard.entries.size() - 1, -1, -1):
		var entry = graveyard.entries[i]
		entries.append({"card_data": entry["card_data"], "face_down": graveyard.is_face_down(entry)})
	_open_entries(entries)

# Cartes restantes dans la pioche du joueur, triées par coût de mana (pas
# l'ordre du deck, qui est mélangé et sans intérêt pour le joueur ici).
func open_deck(cards: Array) -> void:
	count_label.text = SettingsManager.t("deck_view.count_format") % cards.size()
	var sorted_cards := cards.duplicate()
	sorted_cards.sort_custom(func(a: CardData, b: CardData): return a.cost < b.cost)
	var entries: Array = []
	for card in sorted_cards:
		entries.append({"card_data": card, "face_down": false})
	_open_entries(entries)

func _open_entries(entries: Array) -> void:
	AudioManager.play(AudioManager.OPEN_MENU)
	_hide_keyword_tooltips()
	for child in container.get_children():
		child.queue_free()
	for entry in entries:
		_add_card(entry["card_data"], entry["face_down"])
	show()

func _add_card(card_data: CardData, face_down: bool) -> void:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = GRID_WRAPPER_SIZE
	wrapper.size                = GRID_WRAPPER_SIZE
	wrapper.clip_contents       = false
	wrapper.mouse_filter        = Control.MOUSE_FILTER_STOP
	container.add_child(wrapper)

	var card_visual: Card = CARD_SCENE.instantiate() as Card
	card_visual.set_non_interactive()
	card_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_visual.scale        = Vector2(GRID_CARD_SCALE, GRID_CARD_SCALE)
	card_visual.pivot_offset = Vector2.ZERO
	card_visual.position     = Vector2.ZERO
	wrapper.add_child(card_visual)

	if face_down:
		card_visual.show_back(true)
		return

	card_visual.set_data(card_data)
	wrapper.mouse_entered.connect(_on_card_wrapper_entered.bind(card_data, card_visual, wrapper))
	wrapper.mouse_exited.connect(_on_card_wrapper_exited.bind(card_visual, wrapper))

func _on_card_wrapper_entered(card_data: CardData, card_visual: Card, wrapper: Control) -> void:
	_hovered_wrapper = wrapper
	_hovering = true
	wrapper.z_index = 2  # passe au-dessus des cartes voisines pendant le zoom
	var tween := create_tween()
	tween.tween_property(card_visual, "scale",
		Vector2(GRID_CARD_HOVER_SCALE, GRID_CARD_HOVER_SCALE), 0.12)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var tooltip_x: float = wrapper.global_position.x + CARD_BASE_SIZE.x * GRID_CARD_HOVER_SCALE + 12
	# Bascule les tooltips à gauche de la carte s'ils déborderaient de l'écran
	if tooltip_x + TOOLTIP_WIDTH > get_viewport_rect().size.x:
		tooltip_x = wrapper.global_position.x - TOOLTIP_WIDTH - 12
	var tooltip_y: float = wrapper.global_position.y
	await get_tree().process_frame
	await get_tree().process_frame
	if _hovered_wrapper != wrapper or not is_instance_valid(wrapper):
		return
	await _show_keyword_tooltips(card_data, tooltip_x, tooltip_y, wrapper)

## `wrapper` : mouse_entered/mouse_exited entre deux cartes adjacentes n'arrivent
## pas toujours dans un ordre garanti par Godot — un exited périmé (celui de
## l'ancienne carte survolée, arrivant après l'entered de la nouvelle) doit être
## ignoré plutôt que d'effacer à tort le survol/tooltip de la carte actuelle
## (voir le même garde-fou dans _show_keyword_tooltips).
func _on_card_wrapper_exited(card_visual: Card, wrapper: Control) -> void:
	if wrapper != _hovered_wrapper:
		return
	_hovered_wrapper = null
	_hovering = false
	if wrapper:
		wrapper.z_index = 0
	var tween := create_tween()
	tween.tween_property(card_visual, "scale",
		Vector2(GRID_CARD_SCALE, GRID_CARD_SCALE), 0.12)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hide_keyword_tooltips()

# ─── Tooltips — délégués à TooltipData ───────────────────────────────────────

func _show_keyword_tooltips(card_data: CardData, base_x: float, base_y: float,
		wrapper: Control = null) -> void:
	_hide_keyword_tooltips()
	if card_data == null:
		return
	_tooltip_layer = CanvasLayer.new()
	_tooltip_layer.layer = 20
	add_child(_tooltip_layer)
	var panels: Array[Control] = TooltipData.build_panels_for_card(card_data, _tooltip_layer)

	# Tooltip de race — centré sous la carte
	var race_panel: Control = null
	if wrapper != null and TooltipData.RACE_DESCRIPTIONS.has(card_data.race):
		race_panel = TooltipData.make_race_tooltip(TooltipData.RACE_DESCRIPTIONS[card_data.race])
		race_panel.position = Vector2(-9999, -9999)
		_tooltip_layer.add_child(race_panel)

	await get_tree().process_frame
	if not _hovering or wrapper != _hovered_wrapper:
		_hide_keyword_tooltips()
		return

	# Remonte le point de départ si la pile déborde en bas de l'écran.
	var vp := get_viewport_rect().size
	var stack_height := 0.0
	for panel in panels:
		if is_instance_valid(panel):
			stack_height += panel.size.y + 6.0
	if stack_height > 0.0:
		stack_height -= 6.0
		base_y = clampf(base_y, 4.0, maxf(4.0, vp.y - stack_height - 4.0))

	for panel in panels:
		if not is_instance_valid(panel):
			continue
		panel.global_position = Vector2(base_x, base_y)
		base_y += panel.size.y + 6
		_keyword_tooltips.append(panel)

	if race_panel != null and is_instance_valid(race_panel) and is_instance_valid(wrapper):
		# Calé sous le bord visuel de la carte agrandie (pivot en haut-gauche)
		var card_size := CARD_BASE_SIZE * GRID_CARD_HOVER_SCALE
		var rx: float = clampf(
			wrapper.global_position.x + card_size.x / 2.0 - race_panel.size.x / 2.0,
			4.0, vp.x - race_panel.size.x - 4.0)
		var ry := wrapper.global_position.y + card_size.y + 4
		if ry + race_panel.size.y > vp.y - 4.0:
			ry = wrapper.global_position.y - race_panel.size.y - 4
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
