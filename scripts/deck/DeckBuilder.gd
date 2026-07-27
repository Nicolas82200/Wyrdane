# DeckBuilder.gd
extends Control

const ALL_CARDS_PATH := "res://resources/cards"
# Plus de plafond de taille de deck (voir README « Système de Ressources par
# Race ») : seuls des minimums sont imposés, cartes jouables et ressources
# comptées séparément bien que mélangées dans le même paquet.
const MIN_CARDS := 40
const MIN_RESOURCE_CARDS := 10
const MAX_COPIES := 4
# Nombre de cartes instanciées par frame — ajuste selon les perfs
const CARDS_PER_FRAME := 5

# Taille des cartes dans la grille de collection
const GRID_CARD_SCALE       := 0.9
const GRID_WRAPPER_SIZE     := Vector2(236, 354)
const CARD_BASE_SIZE        := Vector2(250, 375)  # taille native de Card.tscn

# Preview agrandie affichée au survol (façon board/main), à la place du léger
# zoom en place — évite le chevauchement des cartes voisines de la grille.
const PREVIEW_SCALE := Vector2(1.15, 1.15)

# Teinte des cartes de la grille dont le max de copies est atteint
const MAXED_TINT := Color(0.38, 0.38, 0.38, 1)

@onready var card_grid:        GridContainer = %CardGrid
@onready var deck_list:        VBoxContainer = %DeckList
@onready var deck_name_edit:   LineEdit      = %DeckNameEdit
@onready var card_count_label: Label         = %CardCountLabel
@onready var save_button:      Button        = %SaveButton
@onready var back_button:      Button        = %BackButton
@onready var search_edit:      LineEdit      = %SearchEdit
@onready var filter_bar:       HFlowContainer = %FilterBar
@onready var sort_bar:         HFlowContainer = %SortBar
@onready var stats_panel:      VBoxContainer = %StatsPanel
@onready var export_button:    Button        = %ExportButton
@onready var import_button:    Button        = %ImportButton
@onready var header_label:     Label         = $MainVBox/HeaderBar/HeaderMargin/HeaderHBox/HeaderLabel
@onready var card_preview:     Card          = $CardPreview

var current_deck: DeckData = null
var _all_cards: Array[CardData] = []
var _pending_cards: Array[CardData] = []
var _is_loading_grid: bool = false

# Tooltip state
var _keyword_tooltips: Array[Control] = []
var _race_tooltip:     Control        = null
var _tooltip_layer:    CanvasLayer    = null
var _hovering:         bool           = false
var _hovered_wrapper:  Control        = null

# Calque pour le tooltip « max de copies » (au-dessus de la grille)
var _overlay_layer: CanvasLayer = null
var _max_tooltip:   Control     = null

# resource_path -> Card (visuel dans la grille), pour griser au max de copies
var _grid_visuals: Dictionary = {}
# resource_path -> Button "Acheter (%d)", affiché uniquement sur les cartes
# non débloquées (voir _is_card_locked) et retiré une fois l'achat réussi.
var _buy_buttons: Dictionary = {}
# resource_path -> Label affichant le stock restant (possédé - déjà dans le deck)
var _stock_labels: Dictionary = {}

# ─── Filtres ──────────────────────────────────────────────────────────────────

var _filter_text:       String = ""
var _filter_race:       int = -1   # Race.Type, -1 = tous
var _filter_rarity:     String = ""
var _filter_type:       String = ""
var _filter_cost:       int    = -1
var _filter_keyword:    String = ""  # "" = tous, sinon "pool:value" (voir _card_has_keyword)
var _sort_mode:         String = ""  # "" = par défaut, "cost", "name", "rarity"
# Par défaut, la grille ne montre que les cartes débloquées (voir
# CollectionManager) — permet aux nouveaux joueurs de ne voir que ce qu'ils
# possèdent réellement (decks de départ), le reste restant accessible via ce filtre.
var _filter_hide_locked: bool = true

const RARITY_ORDER := ["Common", "Rare", "Epic", "Legendary"]

const CARD_SCENE = preload("res://scenes/card/Card.tscn")

func _ready() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 19
	add_child(_overlay_layer)
	card_preview.set_non_interactive()
	card_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_preview.z_index = 100
	card_preview.hide()
	save_button.pressed.connect(_on_save)
	back_button.pressed.connect(_on_back)
	deck_name_edit.text_changed.connect(_on_name_changed)
	search_edit.text_changed.connect(_on_search_changed)
	export_button.pressed.connect(_on_export)
	import_button.pressed.connect(_on_import)
	_load_all_cards()
	_refresh_deck_list()
	SettingsManager.language_changed.connect(func(_l): _retranslate())
	_retranslate()   # construit aussi la barre de filtres localisée

# Met à jour les libellés fixes et la barre de filtres dans la langue courante.
func _retranslate() -> void:
	header_label.text            = SettingsManager.t("deck.title")
	back_button.text             = SettingsManager.t("ui.back")
	save_button.text             = SettingsManager.t("deck.save")
	search_edit.placeholder_text = SettingsManager.t("deck.search")
	deck_name_edit.placeholder_text = SettingsManager.t("deck.name_placeholder")
	export_button.text = SettingsManager.t("deck.export")
	import_button.text = SettingsManager.t("deck.import")
	_build_filter_bar()   # relocalise les libellés de filtres (sélection préservée)
	_build_sort_bar()
	_update_count_label()
	_update_stats_panel()

# ─── Chargement cartes ────────────────────────────────────────────────────────

func _load_all_cards() -> void:
	_all_cards = CardLibrary.all_cards.duplicate()
	_refresh_card_grid()


# ─── Grille cartes disponibles ────────────────────────────────────────────────

var _load_generation: int = 0

func _refresh_card_grid() -> void:
	_load_generation += 1
	var my_generation: int = _load_generation
	for child in card_grid.get_children():
		child.queue_free()
	_grid_visuals.clear()
	_buy_buttons.clear()
	_stock_labels.clear()

	_pending_cards.clear()
	for card_data in _all_cards:
		if _match_filters(card_data):
			_pending_cards.append(card_data)

	_sort_cards(_pending_cards)
	_load_next_batch(my_generation)


func _match_filters(c: CardData) -> bool:
	if _filter_text != "":
		var needle := _filter_text.to_lower()
		if not c.display_name().to_lower().contains(needle) \
				and not c.description.to_lower().contains(needle):
			return false
	if _filter_race != -1 and c.race != _filter_race:
		return false
	if _filter_rarity != "" and c.rarity != _filter_rarity:
		return false
	if _filter_type != "" and c.card_type != _filter_type:
		return false
	if _filter_cost == 7 and c.cost < 7:
		return false
	elif _filter_cost >= 0 and _filter_cost < 7 and c.cost != _filter_cost:
		return false
	if _filter_keyword != "" and not _card_has_keyword(c, _filter_keyword):
		return false
	if _filter_hide_locked and _is_card_locked(c):
		return false
	return true

## Vérifie si une carte porte le mot-clé désigné par "pool:value"
## (pool = K générique, H humain, U mort-vivant, D démon).
func _card_has_keyword(c: CardData, keyword_id: String) -> bool:
	var parts := keyword_id.split(":")
	if parts.size() != 2:
		return false
	var value := int(parts[1])
	match parts[0]:
		"K": return value in c.get_keyword_values()
		"H": return value in c.get_human_keyword_values()
		"U": return value in c.get_undead_keyword_values()
		"D": return value in c.get_demon_keyword_values()
		"A": return value in c.get_abomination_keyword_values()
		_:   return false

func _sort_cards(cards: Array[CardData]) -> void:
	match _sort_mode:
		"cost":
			cards.sort_custom(func(a: CardData, b: CardData) -> bool:
				if a.cost != b.cost:
					return a.cost < b.cost
				return a.display_name() < b.display_name())
		"name":
			cards.sort_custom(func(a: CardData, b: CardData) -> bool:
				return a.display_name() < b.display_name())
		"rarity":
			cards.sort_custom(func(a: CardData, b: CardData) -> bool:
				var ra := RARITY_ORDER.find(a.rarity)
				var rb := RARITY_ORDER.find(b.rarity)
				if ra != rb:
					return ra < rb
				return a.display_name() < b.display_name())
		_:
			pass  # ordre par défaut (celui de _all_cards)

func _load_next_batch(generation: int) -> void:
	if generation != _load_generation or _pending_cards.is_empty():
		return
	for i in range(CARDS_PER_FRAME):
		if _pending_cards.is_empty():
			break
		_add_card_to_grid(_pending_cards.pop_front())
	await get_tree().process_frame
	_load_next_batch(generation)

func _add_card_to_grid(card_data: CardData) -> void:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = GRID_WRAPPER_SIZE
	wrapper.size                = GRID_WRAPPER_SIZE
	wrapper.clip_contents       = false
	wrapper.mouse_filter        = Control.MOUSE_FILTER_STOP
	card_grid.add_child(wrapper)

	var card_visual: Card = CARD_SCENE.instantiate() as Card
	card_visual.set_non_interactive()
	card_visual.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	card_visual.scale         = Vector2(GRID_CARD_SCALE, GRID_CARD_SCALE)
	# Pivot au centre : le zoom au survol s'étend uniformément autour de la carte
	card_visual.pivot_offset  = CARD_BASE_SIZE / 2.0
	card_visual.position      = Vector2(0, 0)
	wrapper.add_child(card_visual)
	card_visual.set_data(card_data)

	_grid_visuals[card_data.resource_path] = card_visual
	if _is_card_maxed(card_data):
		card_visual.modulate = MAXED_TINT

	wrapper.gui_input.connect(_on_card_wrapper_input.bind(card_data))
	wrapper.mouse_entered.connect(_on_card_wrapper_entered.bind(card_data, card_visual, wrapper))
	wrapper.mouse_exited.connect(_on_card_wrapper_exited.bind(card_visual))

	_add_buy_button_if_locked(card_data, wrapper)
	_add_stock_badge(card_data, wrapper)

## Badge en coin de la vignette indiquant le stock restant (possédé - déjà
## placé dans le deck en cours). Mis à jour à chaque ajout/retrait de carte
## (voir _update_grid_maxed_states) sans reconstruire toute la grille.
func _add_stock_badge(card_data: CardData, wrapper: Control) -> void:
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
	badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var badge_label := Label.new()
	badge_label.add_theme_font_size_override("font_size", 12)
	badge_label.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	badge_panel.add_child(badge_label)
	wrapper.add_child(badge_panel)

	_stock_labels[card_data.resource_path] = badge_label
	_update_stock_label(card_data, badge_label)

## Texte du badge de stock : quantité possédée (plafonnée à MAX_COPIES pour
## les cartes non-ressource, qui ne peuvent de toute façon pas être utilisées
## au-delà de ce nombre dans un deck) moins les copies déjà présentes dans le
## deck en cours (jamais négatif).
func _update_stock_label(card_data: CardData, label: Label) -> void:
	var owned := CollectionManager.owned_quantity(card_data)
	if card_data.card_type != "Resource":
		owned = mini(owned, MAX_COPIES)
	var remaining: int = maxi(owned - _count_in_deck(card_data.resource_path), 0)
	label.text = SettingsManager.t("deck.stock_format") % remaining

## Ajoute un bouton "Acheter (prix)" en bas de la vignette pour toute carte non
## encore possédée à MAX_COPIES (qu'elle soit à 0 ou partiellement possédée :
## on peut toujours compléter jusqu'au plafond utilisable en deck) — les
## cartes-ressource ne sont pas vendables à l'unité (voir
## CollectionManager.buy_card, qui reflète le même refus côté serveur).
func _add_buy_button_if_locked(card_data: CardData, wrapper: Control) -> void:
	if card_data.card_type == "Resource":
		return
	if CollectionManager.owned_quantity(card_data) >= MAX_COPIES:
		return
	var price := CurrencyManager.card_price(card_data.rarity)
	if price <= 0:
		return

	var buy_button := Button.new()
	buy_button.text = SettingsManager.t("deck.buy_button") % price
	buy_button.custom_minimum_size = Vector2(0, 26)
	buy_button.add_theme_font_size_override("font_size", 12)
	buy_button.anchor_left   = 0.0
	buy_button.anchor_right  = 1.0
	buy_button.anchor_top    = 1.0
	buy_button.anchor_bottom = 1.0
	buy_button.offset_top    = -30
	buy_button.offset_bottom = -4
	buy_button.mouse_filter  = Control.MOUSE_FILTER_STOP
	buy_button.pressed.connect(_on_buy_card.bind(card_data, buy_button))
	wrapper.add_child(buy_button)
	_buy_buttons[card_data.resource_path] = buy_button

func _on_buy_card(card_data: CardData, buy_button: Button) -> void:
	buy_button.disabled = true
	CollectionManager.buy_card(card_data, func(success: bool) -> void:
		if not is_instance_valid(buy_button):
			return
		if success:
			# Le plafond peut ne pas être encore atteint (achat partiel) : le
			# bouton reste alors disponible pour compléter la collection.
			if CollectionManager.owned_quantity(card_data) >= MAX_COPIES:
				_buy_buttons.erase(card_data.resource_path)
				buy_button.queue_free()
			else:
				buy_button.disabled = false
			_update_grid_maxed_states()
		else:
			buy_button.disabled = false
			_show_buy_error_tooltip(buy_button)
	)

## Petit tooltip d'erreur temporaire au-dessus du bouton d'achat (solde
## insuffisant ou requête réseau échouée) — se referme seul après 2s.
func _show_buy_error_tooltip(anchor: Control) -> void:
	var panel := TooltipData.make_race_tooltip("deck.buy_error")
	panel.position = Vector2(-9999, -9999)
	_overlay_layer.add_child(panel)
	await get_tree().process_frame
	if not is_instance_valid(panel):
		return
	if not is_instance_valid(anchor):
		panel.queue_free()
		return
	panel.global_position = anchor.global_position + Vector2((anchor.size.x - panel.size.x) / 2.0, -panel.size.y - 4.0)
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(panel):
		panel.queue_free()

func _on_card_wrapper_input(event: InputEvent, card_data: CardData) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		_on_add_card(card_data)

func _on_card_wrapper_entered(card_data: CardData, card_visual: Card, wrapper: Control) -> void:
	_hovered_wrapper = wrapper
	_hovering = true
	card_preview.set_data(card_data)
	card_preview.scale = PREVIEW_SCALE
	card_preview.show()
	_position_hover_tooltips()
	if _is_card_maxed(card_data):
		_show_max_copies_tooltip(wrapper, card_data)
	await _show_keyword_tooltips(card_data, wrapper)

func _on_card_wrapper_exited(card_visual: Card) -> void:
	_hovered_wrapper = null
	_hovering = false
	card_preview.hide()
	_clear_max_tooltip()
	_hide_keyword_tooltips()

# ─── Liste deck à droite ──────────────────────────────────────────────────────

func _refresh_deck_list() -> void:
	for child in deck_list.get_children():
		child.queue_free()
	_update_grid_maxed_states()
	_update_stats_panel()
	if current_deck == null:
		_update_count_label()
		return

	var counts: Dictionary = {}
	for path in current_deck.card_paths:
		counts[path] = counts.get(path, 0) + 1

	var seen: Array[String] = []
	for path in current_deck.card_paths:
		if path in seen:
			continue
		seen.append(path)
		var card := load(path) as CardData
		if card == null:
			continue
		deck_list.add_child(_make_deck_row(card, path, counts[path]))

	_update_count_label()

func _make_deck_row(card: CardData, path: String, count: int) -> Control:
	var bg := StyleBoxFlat.new()
	bg.bg_color                   = Color(0.12, 0.10, 0.08, 1)
	bg.corner_radius_top_left     = 3
	bg.corner_radius_top_right    = 3
	bg.corner_radius_bottom_left  = 3
	bg.corner_radius_bottom_right = 3

	var bg_hover := bg.duplicate() as StyleBoxFlat
	bg_hover.bg_color             = Color(0.20, 0.16, 0.10, 1)
	bg_hover.border_color         = Color(0.55, 0.41, 0.08, 0.6)
	bg_hover.border_width_left    = 1
	bg_hover.border_width_right   = 1
	bg_hover.border_width_top     = 1
	bg_hover.border_width_bottom  = 1

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", bg)
	panel.custom_minimum_size = Vector2(0, 34)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	panel.add_child(row)

	var cost_bg := StyleBoxFlat.new()
	cost_bg.bg_color                  = Color(0.55, 0.41, 0.08, 0.9)
	cost_bg.corner_radius_top_left    = 3
	cost_bg.corner_radius_bottom_left = 3
	var cost_panel := PanelContainer.new()
	cost_panel.add_theme_stylebox_override("panel", cost_bg)
	cost_panel.custom_minimum_size = Vector2(28, 0)
	var cost_lbl := Label.new()
	cost_lbl.text                 = str(card.cost)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_color_override("font_color", Color(0.05, 0.04, 0.02, 1))
	cost_lbl.add_theme_font_size_override("font_size", 13)
	cost_panel.add_child(cost_lbl)
	row.add_child(cost_panel)

	var name_lbl := Label.new()
	name_lbl.text                  = card.display_name()
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	name_lbl.add_theme_font_size_override("font_size", 14)
	var name_margin := MarginContainer.new()
	name_margin.add_theme_constant_override("margin_left", 8)
	name_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_margin.add_child(name_lbl)
	row.add_child(name_margin)

	var qty_lbl := Label.new()
	qty_lbl.text                 = str(count)
	qty_lbl.custom_minimum_size  = Vector2(22, 0)
	qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_lbl.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 0.8))
	qty_lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(qty_lbl)

	var del_btn := Button.new()
	del_btn.text                = "✕"
	del_btn.flat                = true
	del_btn.custom_minimum_size = Vector2(28, 0)
	del_btn.add_theme_color_override("font_color",       Color(0.6, 0.3, 0.3, 1))
	del_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.4, 0.4, 1))
	del_btn.add_theme_font_size_override("font_size", 12)
	del_btn.pressed.connect(_on_remove_one.bind(path))
	row.add_child(del_btn)

	panel.mouse_entered.connect(func(): panel.add_theme_stylebox_override("panel", bg_hover))
	panel.mouse_exited.connect(func():  panel.add_theme_stylebox_override("panel", bg))

	# Preview agrandie au survol d'une carte déjà dans le deck, même mécanisme
	# que pour la grille de collection (voir _on_card_wrapper_entered/_exited).
	panel.mouse_entered.connect(_on_card_wrapper_entered.bind(card, null, panel))
	panel.mouse_exited.connect(_on_card_wrapper_exited.bind(null))

	return panel

func _playable_count() -> int:
	if current_deck == null:
		return 0
	var n := 0
	for card in current_deck.get_cards():
		if card.card_type != "Resource":
			n += 1
	return n

func _resource_count() -> int:
	if current_deck == null:
		return 0
	var n := 0
	for card in current_deck.get_cards():
		if card.card_type == "Resource":
			n += 1
	return n

func _update_count_label() -> void:
	var playable := _playable_count()
	var resources := _resource_count()
	card_count_label.text = "%s\n%s" % [
		SettingsManager.t("deck.count_format") % [playable, MIN_CARDS],
		SettingsManager.t("deck.resource_count_format") % [resources, MIN_RESOURCE_CARDS],
	]
	var ok: bool = playable >= MIN_CARDS and resources >= MIN_RESOURCE_CARDS
	card_count_label.modulate = Color(0.5, 0.9, 0.5) if ok else Color(1, 0.4, 0.4)

# ─── Statistiques du deck (courbe de mana + répartition) ──────────────────────

const CURVE_BUCKETS := 8       # coûts 0..6, puis 7+ regroupés
const CURVE_BAR_HEIGHT := 60.0
const CURVE_BAR_COLOR := Color(0.78, 0.58, 0.10, 1)
const STATS_LABEL_COLOR := Color(0.7, 0.6, 0.4, 1)
const STATS_VALUE_COLOR := Color(0.91, 0.835, 0.639, 1)

func _update_stats_panel() -> void:
	for child in stats_panel.get_children():
		child.queue_free()

	if current_deck == null:
		return
	var cards := current_deck.get_cards()
	if cards.is_empty():
		return

	var curve := []
	curve.resize(CURVE_BUCKETS)
	curve.fill(0)
	var type_counts: Dictionary = {}
	var race_counts: Dictionary = {}
	var total_cost := 0

	for card in cards:
		var bucket: int = min(card.cost, CURVE_BUCKETS - 1)
		curve[bucket] += 1
		total_cost += card.cost
		type_counts[card.card_type] = type_counts.get(card.card_type, 0) + 1
		race_counts[card.race] = race_counts.get(card.race, 0) + 1

	var curve_title := Label.new()
	curve_title.text = SettingsManager.t("deck.stats_curve_title")
	curve_title.add_theme_color_override("font_color", STATS_LABEL_COLOR)
	curve_title.add_theme_font_size_override("font_size", 13)
	stats_panel.add_child(curve_title)

	stats_panel.add_child(_make_curve_chart(curve))

	var avg_label := Label.new()
	avg_label.text = SettingsManager.t("deck.stats_avg_cost") % (float(total_cost) / cards.size())
	avg_label.add_theme_color_override("font_color", STATS_VALUE_COLOR)
	avg_label.add_theme_font_size_override("font_size", 12)
	avg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_panel.add_child(avg_label)

	var breakdown_title := Label.new()
	breakdown_title.text = SettingsManager.t("deck.stats_types_title")
	breakdown_title.add_theme_color_override("font_color", STATS_LABEL_COLOR)
	breakdown_title.add_theme_font_size_override("font_size", 13)
	stats_panel.add_child(breakdown_title)

	var type_row := HBoxContainer.new()
	type_row.alignment = BoxContainer.ALIGNMENT_CENTER
	type_row.add_theme_constant_override("separation", 10)
	for type_name in ["Minion", "Instant", "Ritual", "Enchantment", "Resource"]:
		if type_counts.has(type_name):
			type_row.add_child(_make_chip(
				SettingsManager.t("cardtype." + type_name.to_lower()), type_counts[type_name]))
	stats_panel.add_child(type_row)

	var race_row := HBoxContainer.new()
	race_row.alignment = BoxContainer.ALIGNMENT_CENTER
	race_row.add_theme_constant_override("separation", 10)
	for key in Race.Type.keys():
		var race_value: int = Race.Type[key]
		if race_counts.has(race_value):
			race_row.add_child(_make_chip(SettingsManager.t("RACE_" + key), race_counts[race_value]))
	stats_panel.add_child(race_row)

func _make_curve_chart(curve: Array) -> Control:
	var max_count: int = 1
	for c in curve:
		max_count = max(max_count, c)

	var chart := HBoxContainer.new()
	chart.alignment = BoxContainer.ALIGNMENT_CENTER
	chart.add_theme_constant_override("separation", 4)

	for i in range(CURVE_BUCKETS):
		var count: int = curve[i]
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_END
		col.custom_minimum_size = Vector2(28, 0)
		col.add_theme_constant_override("separation", 2)

		var count_lbl := Label.new()
		count_lbl.text = str(count) if count > 0 else ""
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_lbl.add_theme_font_size_override("font_size", 11)
		count_lbl.add_theme_color_override("font_color", STATS_VALUE_COLOR)
		col.add_child(count_lbl)

		var bar := ColorRect.new()
		var height: float = max(4.0, (float(count) / max_count) * CURVE_BAR_HEIGHT)
		bar.custom_minimum_size = Vector2(22, height)
		bar.color = CURVE_BAR_COLOR if count > 0 else Color(0.3, 0.24, 0.10, 0.4)
		col.add_child(bar)

		var cost_lbl := Label.new()
		cost_lbl.text = str(i) if i < CURVE_BUCKETS - 1 else "%d+" % i
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.add_theme_font_size_override("font_size", 11)
		cost_lbl.add_theme_color_override("font_color", STATS_LABEL_COLOR)
		col.add_child(cost_lbl)

		chart.add_child(col)

	return chart

func _make_chip(label_text: String, count: int) -> Control:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.10, 0.08, 1)
	bg.border_color = Color(0.30, 0.24, 0.10, 0.6)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(4)
	bg.content_margin_left   = 8
	bg.content_margin_right  = 8
	bg.content_margin_top    = 2
	bg.content_margin_bottom = 2

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", bg)

	var lbl := Label.new()
	lbl.text = "%s: %d" % [label_text, count]
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", STATS_VALUE_COLOR)
	panel.add_child(lbl)

	return panel

# ─── Actions ──────────────────────────────────────────────────────────────────

func load_deck(deck: DeckData) -> void:
	current_deck = deck
	deck_name_edit.text = deck.name
	_refresh_deck_list()

func _on_add_card(card_data: CardData) -> void:
	if current_deck == null:
		return
	if not DeckManager.can_add_card(current_deck, card_data):
		return
	current_deck.add_card(card_data)
	_refresh_deck_list()
	# Si on vient d'atteindre le max de copies, feedback immédiat sous le curseur
	if _is_card_maxed(card_data) and _hovered_wrapper != null and is_instance_valid(_hovered_wrapper):
		_show_max_copies_tooltip(_hovered_wrapper, card_data)

func _on_remove_one(path: String) -> void:
	if current_deck == null:
		return
	var idx := current_deck.card_paths.rfind(path)
	if idx >= 0:
		current_deck.remove_card_at(idx)
	_refresh_deck_list()

func _on_name_changed(new_name: String) -> void:
	if current_deck:
		current_deck.name = new_name

func _on_search_changed(text: String) -> void:
	_filter_text = text
	_refresh_card_grid()

func _on_save() -> void:
	if current_deck == null or _playable_count() < MIN_CARDS or _resource_count() < MIN_RESOURCE_CARDS:
		return
	DeckManager.save_decks()

func _on_back() -> void:
	DeckManager.save_decks()
	queue_free()

# ─── Import / Export ───────────────────────────────────────────────────────────

func _on_export() -> void:
	if current_deck == null:
		return
	var code := current_deck.to_code()
	DisplayServer.clipboard_set(code)

	var dialog := AcceptDialog.new()
	dialog.title = SettingsManager.t("deck.export_title")
	dialog.min_size = Vector2(480, 220)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var hint := Label.new()
	hint.text = SettingsManager.t("deck.export_hint")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(hint)

	var text_edit := TextEdit.new()
	text_edit.text = code
	text_edit.editable = false
	text_edit.custom_minimum_size = Vector2(0, 110)
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	vbox.add_child(text_edit)

	dialog.add_child(vbox)
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)

func _on_import() -> void:
	if current_deck == null:
		return
	var dialog := AcceptDialog.new()
	dialog.title = SettingsManager.t("deck.import_title")
	dialog.min_size = Vector2(480, 220)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var hint := Label.new()
	hint.text = SettingsManager.t("deck.import_hint")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(hint)

	var text_edit := TextEdit.new()
	text_edit.custom_minimum_size = Vector2(0, 110)
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	vbox.add_child(text_edit)

	dialog.add_child(vbox)
	add_child(dialog)
	dialog.popup_centered()

	dialog.confirmed.connect(func():
		var imported := DeckData.from_code(text_edit.text)
		if imported == null:
			var err := AcceptDialog.new()
			err.dialog_text = SettingsManager.t("deck.import_error")
			add_child(err)
			err.popup_centered()
			err.confirmed.connect(err.queue_free)
		else:
			current_deck.name = imported.name
			current_deck.card_paths = imported.card_paths
			deck_name_edit.text = current_deck.name
			_refresh_deck_list()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)

# ─── Limite de copies ─────────────────────────────────────────────────────────

func _count_in_deck(path: String) -> int:
	if current_deck == null:
		return 0
	var count := 0
	for p in current_deck.card_paths:
		if p == path:
			count += 1
	return count

func _is_card_maxed(card_data: CardData) -> bool:
	var owned := CollectionManager.owned_quantity(card_data)
	if card_data.card_type == "Resource":
		return _count_in_deck(card_data.resource_path) >= owned
	return _count_in_deck(card_data.resource_path) >= min(MAX_COPIES, owned)

## true si le joueur ne possède aucun exemplaire de cette carte (distinct de
## "maxed" : une carte à 0 possédée est verrouillée, pas juste complète dans
## ce deck — sert à choisir le bon message de tooltip, voir _show_max_copies_tooltip.
func _is_card_locked(card_data: CardData) -> bool:
	if card_data == null:
		return true
	if card_data.card_type == "Resource":
		return false
	return CollectionManager.owned_quantity(card_data) <= 0

## Grise les cartes de la grille dont le deck contient déjà le max de copies
## possédées (voir _is_card_maxed — inclut désormais les cartes-ressource,
## bornées par la quantité réellement débloquée plutôt que par MAX_COPIES).
func _update_grid_maxed_states() -> void:
	for path in _grid_visuals.keys():
		var visual: Card = _grid_visuals[path]
		if not is_instance_valid(visual):
			continue
		var card_data: CardData = visual.data
		var maxed: bool = card_data != null and _is_card_maxed(card_data)
		visual.modulate = MAXED_TINT if maxed else Color.WHITE
		if card_data != null and _stock_labels.has(path):
			var stock_label: Label = _stock_labels[path]
			if is_instance_valid(stock_label):
				_update_stock_label(card_data, stock_label)

## Tooltip centré sur la carte grisée : max de copies possédées atteint, ou
## carte pas encore débloquée du tout (message distinct, voir _is_card_locked).
func _show_max_copies_tooltip(anchor: Control, card_data: CardData = null) -> void:
	_clear_max_tooltip()
	var text_key := "deck.card_locked" if (card_data != null and _is_card_locked(card_data)) \
		else "deck.max_copies_reached"
	var panel := TooltipData.make_race_tooltip(text_key)
	panel.position = Vector2(-9999, -9999)
	_overlay_layer.add_child(panel)
	_max_tooltip = panel
	await get_tree().process_frame
	if not is_instance_valid(panel):
		return
	if not _hovering or not is_instance_valid(anchor):
		_clear_max_tooltip()
		return
	panel.global_position = anchor.global_position + (anchor.size - panel.size) / 2.0

func _clear_max_tooltip() -> void:
	if _max_tooltip != null and is_instance_valid(_max_tooltip):
		_max_tooltip.queue_free()
	_max_tooltip = null

# ─── Tooltips — délégués à TooltipData ───────────────────────────────────────

## Panneaux de mots-clés à côté de la carte survolée, tooltip de race centré dessous.
func _show_keyword_tooltips(card_data: CardData, wrapper: Control) -> void:
	_hide_keyword_tooltips()
	if card_data == null or wrapper == null:
		return
	_tooltip_layer = CanvasLayer.new()
	_tooltip_layer.layer = 20
	add_child(_tooltip_layer)
	var panels: Array[Control] = TooltipData.build_panels_for_card(card_data, _tooltip_layer)

	var race_panel: Control = null
	if TooltipData.RACE_DESCRIPTIONS.has(card_data.race):
		race_panel = TooltipData.make_race_tooltip(TooltipData.RACE_DESCRIPTIONS[card_data.race])
		race_panel.position = Vector2(-9999, -9999)
		_tooltip_layer.add_child(race_panel)

	await get_tree().process_frame
	if not _hovering or not is_instance_valid(wrapper):
		_hide_keyword_tooltips()
		return

	for panel in panels:
		if is_instance_valid(panel):
			_keyword_tooltips.append(panel)
	_race_tooltip = race_panel
	_position_hover_tooltips()

## Repositionne la preview agrandie et les tooltips par rapport à la carte
## survolée. Appelé à chaque frame tant que le survol dure, pour que tout
## suive le scroll de la grille.
func _position_hover_tooltips() -> void:
	var wrapper := _hovered_wrapper
	if wrapper == null or not is_instance_valid(wrapper):
		return
	var vp := get_viewport_rect().size
	var preview_size := CARD_BASE_SIZE * PREVIEW_SCALE.x
	var wrapper_center := wrapper.global_position + wrapper.size / 2.0

	# Preview centrée verticalement sur la carte survolée, à droite si la
	# place le permet (sinon à gauche), pour ne jamais masquer le curseur.
	var preview_y: float = clampf(
		wrapper_center.y - preview_size.y / 2.0, 4.0, vp.y - preview_size.y - 4.0)
	var preview_x: float = wrapper.global_position.x + wrapper.size.x + 12.0
	if preview_x + preview_size.x > vp.x - 4.0:
		preview_x = wrapper.global_position.x - preview_size.x - 12.0
	preview_x = clampf(preview_x, 4.0, vp.x - preview_size.x - 4.0)

	card_preview.global_position = Vector2(preview_x, preview_y)
	var card_center := card_preview.global_position + preview_size / 2.0
	var base_y       := card_preview.global_position.y

	for panel in _keyword_tooltips:
		if not is_instance_valid(panel):
			continue
		var px := card_preview.global_position.x + preview_size.x + 12.0
		if px + panel.size.x > vp.x:
			px = card_preview.global_position.x - panel.size.x - 12.0
		panel.global_position = Vector2(px, base_y)
		base_y += panel.size.y + 6
	if _race_tooltip != null and is_instance_valid(_race_tooltip):
		var rx: float = clampf(
			card_center.x - _race_tooltip.size.x / 2.0,
			4.0, vp.x - _race_tooltip.size.x - 4.0)
		var ry: float = card_preview.global_position.y + preview_size.y + 4.0
		if ry + _race_tooltip.size.y > vp.y:
			ry = card_preview.global_position.y - _race_tooltip.size.y - 4.0
		_race_tooltip.global_position = Vector2(rx, ry)
	if _max_tooltip != null and is_instance_valid(_max_tooltip):
		_max_tooltip.global_position = \
			wrapper.global_position + (wrapper.size - _max_tooltip.size) / 2.0

func _process(_delta: float) -> void:
	if _hovering:
		_position_hover_tooltips()

func _hide_keyword_tooltips() -> void:
	for tooltip in _keyword_tooltips:
		if is_instance_valid(tooltip):
			tooltip.queue_free()
	_keyword_tooltips.clear()
	if _race_tooltip != null and is_instance_valid(_race_tooltip):
		_race_tooltip.queue_free()
	_race_tooltip = null
	if _tooltip_layer and is_instance_valid(_tooltip_layer):
		_tooltip_layer.queue_free()
		_tooltip_layer = null
		
# ─── Filtres ──────────────────────────────────────────────────────────────────

## Crée la barre de filtres directement en code sous la SearchEdit.
## Appelle cette fonction dans _ready(), après _load_all_cards().
func _build_filter_bar() -> void:
	# Reconstruit à chaque appel (notamment au changement de langue) : on vide
	# d'abord les libellés/groupes existants. La sélection active est préservée
	# car chaque groupe s'initialise depuis les variables _filter_*.
	for child in filter_bar.get_children():
		child.queue_free()

	var all_label := SettingsManager.t("deck.filter_all")

	# Race (seules les races dotées de cartes sont proposées comme filtre)
	var race_values: Array = [-1]
	var race_labels: Array[String] = [all_label]
	var race_keys := Race.Type.keys()
	for race_value in Race.get_implemented_races():
		race_values.append(race_value)
		race_labels.append(SettingsManager.t("RACE_" + race_keys[race_value]))
	filter_bar.add_child(_make_filter_label(SettingsManager.t("deck.filter_race")))
	_add_filter_group(filter_bar, race_values,
		func(v: int) -> void: _filter_race = v; _refresh_card_grid(),
		func() -> int: return _filter_race,
		race_labels)

	# Type de carte
	filter_bar.add_child(_make_filter_label(SettingsManager.t("deck.filter_type")))
	_add_filter_group(filter_bar, ["", "Minion", "Instant", "Ritual", "Enchantment", "Resource"],
		func(v: String) -> void: _filter_type = v; _refresh_card_grid(),
		func() -> String: return _filter_type,
		[all_label, SettingsManager.t("cardtype.minion"), SettingsManager.t("cardtype.instant"),
			SettingsManager.t("cardtype.ritual"), SettingsManager.t("cardtype.enchantment"),
			SettingsManager.t("cardtype.resource")])

	# Rareté
	filter_bar.add_child(_make_filter_label(SettingsManager.t("deck.filter_rarity")))
	_add_filter_group(filter_bar, ["", "Common", "Rare", "Epic", "Legendary"],
		func(v: String) -> void: _filter_rarity = v; _refresh_card_grid(),
		func() -> String: return _filter_rarity,
		[all_label, "Common", "Rare", "Epic", "Legendary"])

	# Coût
	filter_bar.add_child(_make_filter_label(SettingsManager.t("deck.filter_cost")))
	_add_filter_group(filter_bar, [-1, 0, 1, 2, 3, 4, 5, 6, 7],
		func(v: int) -> void: _filter_cost = v; _refresh_card_grid(),
		func() -> int: return _filter_cost,
		[all_label, "0", "1", "2", "3", "4", "5", "6", "7+"])

	# Cacher/montrer les cartes non débloquées (bouton à bascule seul, pas un groupe radio)
	var lock_btn := Button.new()
	lock_btn.text            = SettingsManager.t("deck.filter_hide_locked")
	lock_btn.toggle_mode     = true
	lock_btn.button_pressed  = _filter_hide_locked
	lock_btn.custom_minimum_size = Vector2(0, 26)
	lock_btn.add_theme_font_size_override("font_size", 12)
	_style_filter_button(lock_btn, _filter_hide_locked)
	lock_btn.toggled.connect(func(pressed: bool) -> void:
		_filter_hide_locked = pressed
		_style_filter_button(lock_btn, pressed)
		_refresh_card_grid())
	filter_bar.add_child(lock_btn)


## Barre secondaire : filtre par mot-clé (dropdown, trop de valeurs pour des
## boutons radio) et tri de la grille de cartes.
func _build_sort_bar() -> void:
	for child in sort_bar.get_children():
		child.queue_free()

	var all_label := SettingsManager.t("deck.filter_all")

	sort_bar.add_child(_make_filter_label(SettingsManager.t("deck.filter_keyword")))
	var kw_values: Array[String] = [""]
	var kw_labels: Array[String] = [all_label]
	for entry in _all_keyword_entries():
		kw_values.append(entry["id"])
		kw_labels.append(entry["label"])
	sort_bar.add_child(_make_keyword_dropdown(kw_values, kw_labels))

	var sort_spacer := Control.new()
	sort_spacer.custom_minimum_size = Vector2(20, 0)
	sort_bar.add_child(sort_spacer)

	sort_bar.add_child(_make_filter_label(SettingsManager.t("deck.sort_label")))
	_add_filter_group(sort_bar, ["", "cost", "name", "rarity"],
		func(v: String) -> void: _sort_mode = v; _refresh_card_grid(),
		func() -> String: return _sort_mode,
		[SettingsManager.t("deck.sort_default"), SettingsManager.t("deck.sort_cost"),
			SettingsManager.t("deck.sort_name"), SettingsManager.t("deck.sort_rarity")])

## Rassemble tous les mots-clés (générique + 3 races) sous forme d'ids "pool:value".
func _all_keyword_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for key in Keyword.Type.keys():
		var v: int = Keyword.Type[key]
		entries.append({"id": "K:%d" % v, "label": Keyword.get_keyword_name(v)})
	for key in KeywordHuman.Type.keys():
		var v: int = KeywordHuman.Type[key]
		entries.append({"id": "H:%d" % v, "label": KeywordHuman.get_keyword_name(v)})
	for key in KeywordUndead.Type.keys():
		var v: int = KeywordUndead.Type[key]
		entries.append({"id": "U:%d" % v, "label": KeywordUndead.get_keyword_name(v)})
	for key in KeywordDemon.Type.keys():
		var v: int = KeywordDemon.Type[key]
		entries.append({"id": "D:%d" % v, "label": KeywordDemon.get_keyword_name(v)})
	for key in KeywordAbomination.Type.keys():
		var v: int = KeywordAbomination.Type[key]
		entries.append({"id": "A:%d" % v, "label": KeywordAbomination.get_keyword_name(v)})
	return entries

func _make_keyword_dropdown(values: Array[String], labels: Array[String]) -> OptionButton:
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(170, 26)
	opt.add_theme_font_size_override("font_size", 12)
	for i in range(labels.size()):
		opt.add_item(labels[i])
	var current_idx := values.find(_filter_keyword)
	opt.selected = max(current_idx, 0)
	opt.item_selected.connect(func(idx: int) -> void:
		_filter_keyword = values[idx]
		_refresh_card_grid())
	return opt

func _make_filter_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4, 1))
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl


## Crée un groupe de boutons radio pour un filtre donné.
## values      : tableau de valeurs (String ou int)
## on_select   : callable(value) appelé au clic
## get_current : callable() → valeur active
## labels      : libellés affichés (même taille que values)
func _add_filter_group(parent: Control, values: Array, on_select: Callable,
		get_current: Callable, labels: Array) -> void:
	var group_box := HBoxContainer.new()
	group_box.add_theme_constant_override("separation", 2)
	parent.add_child(group_box)

	var buttons: Array[Button] = []
	for i in range(values.size()):
		var val   = values[i]
		var label = labels[i] if i < labels.size() else str(val)
		var btn   := Button.new()
		btn.text               = label
		btn.toggle_mode        = true
		btn.button_pressed     = (val == get_current.call())
		btn.custom_minimum_size = Vector2(0, 26)
		btn.add_theme_font_size_override("font_size", 12)
		_style_filter_button(btn, btn.button_pressed)
		buttons.append(btn)
		group_box.add_child(btn)

		btn.pressed.connect(func() -> void:
			# Déselectionne les autres du groupe
			for b in buttons:
				b.button_pressed = false
				_style_filter_button(b, false)
			btn.button_pressed = true
			_style_filter_button(btn, true)
			on_select.call(val)
		)


func _style_filter_button(btn: Button, active: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color                   = Color(0.35, 0.26, 0.06, 0.9) if active else Color(0.12, 0.10, 0.08, 0.85)
	sb.border_color               = Color(0.78, 0.58, 0.10, 1) if active else Color(0.30, 0.24, 0.10, 0.6)
	sb.border_width_left          = 1
	sb.border_width_right         = 1
	sb.border_width_top           = 1
	sb.border_width_bottom        = 1
	sb.corner_radius_top_left     = 4
	sb.corner_radius_top_right    = 4
	sb.corner_radius_bottom_left  = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left        = 7
	sb.content_margin_right       = 7
	sb.content_margin_top         = 3
	sb.content_margin_bottom      = 3
	btn.add_theme_stylebox_override("normal",   sb)
	btn.add_theme_stylebox_override("pressed",  sb)
	btn.add_theme_stylebox_override("hover",    sb)
	var font_color := Color(0.98, 0.85, 0.40, 1) if active else Color(0.72, 0.64, 0.48, 1)
	btn.add_theme_color_override("font_color",         font_color)
	btn.add_theme_color_override("font_pressed_color", font_color)
	btn.add_theme_color_override("font_hover_color",   Color(1, 0.92, 0.60, 1))
