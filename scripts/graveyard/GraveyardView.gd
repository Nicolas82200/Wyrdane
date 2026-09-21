extends Control
class_name GraveyardView

const CARD_SCENE = preload("res://scenes/card/Card.tscn")

# Émis quand la vue est ouverte en mode sélection (voir open_for_selection) et
# que le joueur a choisi une carte, ou null si la fenêtre a été fermée sans
# choisir (clic sur le fond / bouton Fermer).
signal card_picked(card_data: CardData)

const GRID_CARD_SCALE       := 0.85
const GRID_CARD_HOVER_SCALE := 0.95
const GRID_WRAPPER_SIZE     := Vector2(215, 320)
const CARD_BASE_SIZE        := Vector2(250, 375)  # taille native de Card.tscn
const TOOLTIP_WIDTH         := 220.0

@onready var container   = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/GridMargin/GridContainer
@onready var count_label = $PanelContainer/MarginContainer/VBoxContainer/Header/CountLabel
@onready var close_btn   = $PanelContainer/MarginContainer/VBoxContainer/Header/CloseButton
@onready var color_rect  = $ColorRect

var _keyword_tooltips: Array[Control] = []
var _tooltip_layer:    CanvasLayer    = null
var _hovering:         bool           = false
var _hovered_wrapper:  Control        = null
var _selection_mode:   bool           = false
# Bulle "Clic droit pour afficher/cacher les informations" au-dessus de la
# carte survolée — voir TooltipData.tooltips_expanded.
var _hint_panel:       PanelContainer = null

# Aperçus des jetons invoqués par la carte survolée (voir
# CardData.get_summon_preview_cards / Hand._show_summon_previews, même
# principe) — au-dessus de la carte agrandie si la place le permet, sinon en
# dessous.
var _token_previews:      Array[Card]              = []
var _token_preview_links: Array[PreviewLinkOverlay] = []
const TOKEN_PREVIEW_SCALE_RATIO := 0.75

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
	_hide_hint_panel()
	_clear_summon_previews()
	hide()
	if _selection_mode:
		_selection_mode = false
		card_picked.emit(null)

func open(graveyard: Graveyard) -> void:
	count_label.text = SettingsManager.t("graveyard.count_format") % graveyard.size()
	var entries: Array = []
	# Pile LIFO : la mort la plus récente est affichée en premier
	for i in range(graveyard.entries.size() - 1, -1, -1):
		var entry = graveyard.entries[i]
		entries.append({"card_data": entry["card_data"], "face_down": graveyard.is_face_down(entry)})
	_open_entries(entries)

# Mode sélection : le joueur doit choisir une carte parmi `candidates` (déjà
# filtrées par l'appelant — ex: Mort-Vivants du cimetière allié). Le signal
# card_picked émet la carte choisie, ou null si la fenêtre est fermée sans
# choix. Les cartes ne faisant pas partie de `candidates` ne sont pas
# affichées : contrairement à `open()`, cette vue ne montre que les cibles
# valides pour éviter de laisser cliquer sur une carte non éligible.
func open_for_selection(candidates: Array[CardData]) -> void:
	_selection_mode = true
	count_label.text = SettingsManager.t("graveyard.choose_target_format") % candidates.size()
	var entries: Array = []
	for card_data in candidates:
		entries.append({"card_data": card_data, "face_down": false})
	_open_entries(entries)

func _pick(card_data: CardData) -> void:
	if not _selection_mode:
		return
	_selection_mode = false
	AudioManager.play(AudioManager.CLOSE_MENU)
	_hide_keyword_tooltips()
	_clear_summon_previews()
	hide()
	card_picked.emit(card_data)

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

## Regroupe les cartes identiques (même resource_path) en une seule vignette
## avec un badge "xN" au lieu d'en afficher une par copie (ex: 20 cartes-
## ressource identiques) — les cartes face cachée ne sont jamais regroupées
## (chacune reste une carte individuelle, sans donnée exploitable pour grouper
## visuellement sans révéler d'information).
func _open_entries(entries: Array) -> void:
	AudioManager.play(AudioManager.OPEN_MENU)
	_hide_keyword_tooltips()
	_clear_summon_previews()
	for child in container.get_children():
		child.queue_free()
	var grouped: Array = []
	var index_by_path: Dictionary = {}
	for entry in entries:
		if entry["face_down"]:
			grouped.append({"card_data": entry["card_data"], "face_down": true, "count": 1})
			continue
		var path: String = entry["card_data"].resource_path
		if index_by_path.has(path):
			grouped[index_by_path[path]]["count"] += 1
		else:
			index_by_path[path] = grouped.size()
			grouped.append({"card_data": entry["card_data"], "face_down": false, "count": 1})
	for group in grouped:
		_add_card(group["card_data"], group["face_down"], group["count"])
	show()

func _add_card(card_data: CardData, face_down: bool, count: int = 1) -> void:
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
	if count > 1:
		_add_count_badge(wrapper, count)
	wrapper.mouse_entered.connect(_on_card_wrapper_entered.bind(card_data, card_visual, wrapper))
	wrapper.mouse_exited.connect(_on_card_wrapper_exited.bind(card_visual, wrapper))
	wrapper.gui_input.connect(_on_card_wrapper_right_click.bind(card_data, wrapper))
	if _selection_mode:
		wrapper.gui_input.connect(_on_card_wrapper_clicked.bind(card_data))

func _on_card_wrapper_clicked(event: InputEvent, card_data: CardData) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		_pick(card_data)

## Badge "xN" en haut à gauche de la vignette, même gabarit visuel que le badge
## de stock du deck builder (voir DeckBuilder._add_stock_badge).
func _add_count_badge(wrapper: Control, count: int) -> void:
	var badge_bg := StyleBoxFlat.new()
	badge_bg.bg_color = Color(0.05, 0.04, 0.02, 0.85)
	badge_bg.set_corner_radius_all(3)
	badge_bg.content_margin_left   = 5
	badge_bg.content_margin_right  = 5
	badge_bg.content_margin_top    = 1
	badge_bg.content_margin_bottom = 1

	var badge_panel := PanelContainer.new()
	badge_panel.add_theme_stylebox_override("panel", badge_bg)
	badge_panel.position     = Vector2(4, 4)
	badge_panel.z_index      = 3
	badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var badge_label := Label.new()
	badge_label.add_theme_font_size_override("font_size", Typography.MICRO)
	badge_label.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	badge_label.text = SettingsManager.t("deck_view.card_count_badge") % count
	badge_panel.add_child(badge_label)
	wrapper.add_child(badge_panel)

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
	_show_hint_panel(wrapper)
	_show_summon_previews(card_data, wrapper)
	if TooltipData.tooltips_expanded:
		await _show_keyword_tooltips(card_data, tooltip_x, tooltip_y, wrapper)

## Bascule TooltipData.tooltips_expanded pour toute la session et rafraîchit
## l'affichage courant si cette carte est actuellement survolée.
func _on_card_wrapper_right_click(event: InputEvent, card_data: CardData, wrapper: Control) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT
			and event.pressed):
		return
	TooltipData.toggle_tooltips_expanded()
	get_viewport().set_input_as_handled()
	if wrapper != _hovered_wrapper or not _hovering:
		return
	var tooltip_x: float = wrapper.global_position.x + CARD_BASE_SIZE.x * GRID_CARD_HOVER_SCALE + 12
	if tooltip_x + TOOLTIP_WIDTH > get_viewport_rect().size.x:
		tooltip_x = wrapper.global_position.x - TOOLTIP_WIDTH - 12
	var tooltip_y: float = wrapper.global_position.y
	_show_hint_panel(wrapper)
	if TooltipData.tooltips_expanded:
		await _show_keyword_tooltips(card_data, tooltip_x, tooltip_y, wrapper)
	else:
		_hide_keyword_tooltips()

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
	_hide_hint_panel()
	_clear_summon_previews()

## Aperçu supplémentaire par jeton fixe invoqué par la carte survolée (voir
## CardData.get_summon_preview_cards) — repose sur CardEffect.summon_card,
## donc rien pour SummonRandom (cible aléatoire, pas de jeton précis à
## montrer). Centré horizontalement sur la carte agrandie, au-dessus si la
## place le permet, sinon en dessous.
func _show_summon_previews(card_data: CardData, wrapper: Control) -> void:
	_clear_summon_previews()
	if card_data == null or not is_instance_valid(wrapper):
		return
	var tokens := card_data.get_summon_preview_cards()
	if tokens.is_empty():
		return
	var token_scale := Vector2(GRID_CARD_HOVER_SCALE, GRID_CARD_HOVER_SCALE) * TOKEN_PREVIEW_SCALE_RATIO
	const TOKEN_SPACING := 12.0
	var card_size := CARD_BASE_SIZE * GRID_CARD_HOVER_SCALE
	var token_size := CARD_BASE_SIZE * token_scale.x

	var new_tokens: Array[Card] = []
	for token_data in tokens:
		var token_card: Card = CARD_SCENE.instantiate()
		if token_card == null:
			continue
		add_child(token_card)
		token_card.set_non_interactive()
		# PASS (pas IGNORE) : le clic droit sur un jeton invoqué doit aussi
		# basculer les tooltips détaillés de la carte survolée.
		token_card.mouse_filter = Control.MOUSE_FILTER_PASS
		token_card.gui_input.connect(_on_token_preview_right_click.bind(card_data, wrapper))
		token_card.z_index = 5
		token_card.set_data(token_data)
		token_card.scale = token_scale
		new_tokens.append(token_card)
	if new_tokens.is_empty():
		return

	var strip_width: float = float(new_tokens.size()) * token_size.x \
		+ float(new_tokens.size() - 1) * TOKEN_SPACING
	var vp := get_viewport_rect().size
	var strip_x: float = clampf(
		wrapper.global_position.x + card_size.x / 2.0 - strip_width / 2.0,
		4.0, vp.x - strip_width - 4.0)

	var above_y: float = wrapper.global_position.y - token_size.y - 12.0
	var place_above: bool = above_y >= 4.0
	var strip_y: float = above_y if place_above else wrapper.global_position.y + card_size.y + 12.0
	strip_y = clampf(strip_y, 4.0, vp.y - token_size.y - 4.0)

	var link_from_y: float = wrapper.global_position.y if place_above \
		else wrapper.global_position.y + card_size.y

	for i in range(new_tokens.size()):
		var token_card: Card = new_tokens[i]
		var tx: float = strip_x + float(i) * (token_size.x + TOKEN_SPACING)
		token_card.global_position = Vector2(tx, strip_y)
		token_card.visible = true
		_token_previews.append(token_card)

		var link := PreviewLinkOverlay.new()
		link.z_index = 4
		add_child(link)
		var link_from := Vector2(wrapper.global_position.x + card_size.x / 2.0, link_from_y)
		var link_to_y: float = strip_y + token_size.y if place_above else strip_y
		var link_to := Vector2(tx + token_size.x / 2.0, link_to_y)
		link.show_link(link_from, link_to)
		_token_preview_links.append(link)

func _clear_summon_previews() -> void:
	for token_card in _token_previews:
		if is_instance_valid(token_card):
			token_card.queue_free()
	_token_previews.clear()
	for link in _token_preview_links:
		if is_instance_valid(link):
			link.queue_free()
	_token_preview_links.clear()

## Même bascule que _on_card_wrapper_right_click, depuis un clic droit sur un
## aperçu de jeton invoqué (voir _show_summon_previews) — ces cartes n'ont
## pas leur propre pile de tooltips, seule celle de la carte survolée compte.
func _on_token_preview_right_click(event: InputEvent, card_data: CardData, wrapper: Control) -> void:
	_on_card_wrapper_right_click(event, card_data, wrapper)

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

## Positionnée au-dessus de la carte agrandie (dans `wrapper`) — voir
## Hand._show_hint_panel (même principe).
func _show_hint_panel(wrapper: Control) -> void:
	_hide_hint_panel()
	if not is_instance_valid(wrapper):
		return
	_hint_panel = TooltipData.make_hint_panel()
	_hint_panel.z_index = 1000
	add_child(_hint_panel)
	await get_tree().process_frame
	if not _hovering or wrapper != _hovered_wrapper or not is_instance_valid(_hint_panel):
		return
	var center_x: float = wrapper.global_position.x + CARD_BASE_SIZE.x * GRID_CARD_HOVER_SCALE * 0.5
	_hint_panel.global_position = Vector2(
		center_x - _hint_panel.size.x * 0.5, wrapper.global_position.y - _hint_panel.size.y - 6)

func _hide_hint_panel() -> void:
	if _hint_panel and is_instance_valid(_hint_panel):
		_hint_panel.queue_free()
	_hint_panel = null
