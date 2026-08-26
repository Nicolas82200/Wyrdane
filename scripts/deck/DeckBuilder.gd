# DeckBuilder.gd
extends Control

const ALL_CARDS_PATH := "res://resources/cards"
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
@onready var warning_label:    Label         = %WarningLabel
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

# Instantané du deck au dernier chargement/sauvegarde — current_deck est la
# MÊME instance que celle rangée dans DeckManager.decks, donc chaque
# ajout/retrait de carte la modifie déjà en mémoire avant tout clic sur
# Sauvegarder. "Ne pas sauvegarder" restaure ces valeurs sur l'objet partagé
# pour que l'édition abandonnée ne soit pas silencieusement repoussée au
# backend par un DeckManager.save_decks() ultérieur et sans rapport (ex.
# création d'un autre deck) — voir _snapshot_original_state/_discard_changes.
var _original_name: String = ""
var _original_card_paths: Array[String] = []

# true dès que le deck en cours d'édition a été modifié depuis le dernier
# chargement/sauvegarde — commande l'activation du bouton Sauvegarder et
# l'avertissement de sortie sans sauvegarde (voir _mark_dirty/_on_back).
var _dirty: bool = false

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
	DeckFilterBar.build_filter_bar(self)   # relocalise les libellés de filtres (sélection préservée)
	DeckFilterBar.build_sort_bar(self)
	_update_count_label()
	DeckStatsPanel.refresh(self)

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

## Texte du badge de stock : "cartes encore ajoutables au deck / cartes
## possédées au total" — le numérateur est plafonné à DeckManager.MAX_COPIES_PER_CARD
## (au-delà, la carte ne peut de toute façon plus être ajoutée) moins les
## copies déjà présentes dans le deck en cours (jamais négatif) ; le
## dénominateur est la quantité réellement possédée, non plafonnée, pour que
## le joueur voie sa collection réelle. Les cartes-ressource sont illimitées :
## le badge affiche l'infini plutôt qu'un stock borné à ce qui est possédé.
func _update_stock_label(card_data: CardData, label: Label) -> void:
	if card_data.card_type == "Resource":
		label.text = "∞"
		return
	var owned: int = CollectionManager.owned_quantity(card_data)
	var addable: int = maxi(mini(owned, DeckManager.MAX_COPIES_PER_CARD) - _count_in_deck(card_data.resource_path), 0)
	label.text = SettingsManager.t("deck.stock_format") % [addable, owned]

## Ajoute un bouton "Acheter (prix)" en bas de la vignette pour toute carte non
## encore possédée à DeckManager.MAX_COPIES_PER_CARD (qu'elle soit à 0 ou partiellement possédée :
## on peut toujours compléter jusqu'au plafond utilisable en deck) — les
## cartes-ressource ne sont pas vendables à l'unité (voir
## CollectionManager.buy_card, qui reflète le même refus côté serveur).
func _add_buy_button_if_locked(card_data: CardData, wrapper: Control) -> void:
	if card_data.card_type == "Resource":
		return
	if CollectionManager.owned_quantity(card_data) >= DeckManager.MAX_COPIES_PER_CARD:
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
			if CollectionManager.owned_quantity(card_data) >= DeckManager.MAX_COPIES_PER_CARD:
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
	DeckStatsPanel.refresh(self)
	if current_deck == null:
		_update_count_label()
		return

	var counts: Dictionary = {}
	for path in current_deck.card_paths:
		counts[path] = counts.get(path, 0) + 1

	# Une ligne par carte distincte, triée par coût croissant (puis par nom à
	# coût égal) — reconstruite à chaque modification du deck, donc une carte
	# ajoutée/retirée se replace immédiatement à la bonne position.
	var seen: Array[String] = []
	for path in current_deck.card_paths:
		if path not in seen:
			seen.append(path)
	seen.sort_custom(func(a: String, b: String) -> bool:
		var ca := load(a) as CardData
		var cb := load(b) as CardData
		if ca.cost != cb.cost:
			return ca.cost < cb.cost
		return ca.display_name() < cb.display_name())

	for path in seen:
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
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	# Couleur du badge = race de la carte (mêmes teintes que les icônes de
	# type/rangée sur la carte elle-même, voir Card.RACE_ICON_COLORS) : repère
	# visuel rapide pour identifier la race sans survoler chaque ligne.
	var cost_bg := StyleBoxFlat.new()
	cost_bg.bg_color                  = Card.RACE_ICON_COLORS.get(card.race, Color(0.55, 0.41, 0.08, 0.9))
	cost_bg.corner_radius_top_left    = 3
	cost_bg.corner_radius_bottom_left = 3
	var cost_panel := PanelContainer.new()
	cost_panel.add_theme_stylebox_override("panel", cost_bg)
	cost_panel.custom_minimum_size = Vector2(28, 0)
	cost_panel.mouse_filter        = Control.MOUSE_FILTER_IGNORE
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
	name_margin.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	name_margin.add_child(name_lbl)
	row.add_child(name_margin)

	var qty_lbl := Label.new()
	qty_lbl.text                 = "x%d" % count
	qty_lbl.custom_minimum_size  = Vector2(28, 0)
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
	del_btn.pressed.connect(_on_remove_all.bind(path))
	row.add_child(del_btn)

	panel.mouse_entered.connect(func(): panel.add_theme_stylebox_override("panel", bg_hover))
	panel.mouse_exited.connect(func():  panel.add_theme_stylebox_override("panel", bg))

	# Clic sur la ligne (hors croix rouge) : retire une seule copie. La croix
	# rouge (del_btn, filtre souris par défaut STOP) consomme son propre clic
	# et ne déclenche donc jamais ce gui_input.
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_deck_row_input.bind(path))

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
		SettingsManager.t("deck.count_format") % [playable, DeckManager.MIN_PLAYABLE_CARDS],
		SettingsManager.t("deck.resource_count_format") % [resources, DeckManager.MIN_RESOURCE_CARDS],
	]
	var ok: bool = playable >= DeckManager.MIN_PLAYABLE_CARDS and resources >= DeckManager.MIN_RESOURCE_CARDS
	card_count_label.modulate = Color(0.5, 0.9, 0.5) if ok else Color(1, 0.4, 0.4)
	_update_warnings()
	_update_save_button()

# ─── Warnings ressources de race ───────────────────────────────────────────────

func _update_warnings() -> void:
	var warnings := DeckManager.race_warnings(current_deck)
	warning_label.visible = not warnings.is_empty()
	warning_label.text = "\n".join(warnings)

# ─── État du bouton Sauvegarder ────────────────────────────────────────────────

func _can_save() -> bool:
	return current_deck != null and _dirty and DeckManager.validation_warnings(current_deck).is_empty()

func _update_save_button() -> void:
	save_button.disabled = not _can_save()

## Toute modification du deck en cours (ajout/retrait de carte, renommage,
## import) passe par ici pour réactiver le bouton Sauvegarder.
func _mark_dirty() -> void:
	_dirty = true
	_update_save_button()

# ─── Actions ──────────────────────────────────────────────────────────────────

func load_deck(deck: DeckData) -> void:
	current_deck = deck
	deck_name_edit.text = deck.name
	_dirty = false
	_snapshot_original_state()
	_refresh_deck_list()

## Mémorise l'état actuel de current_deck comme point de retour pour un futur
## "Ne pas sauvegarder" — appelé au chargement puis après chaque sauvegarde
## réussie (voir load_deck/_on_save), jamais pendant l'édition elle-même.
func _snapshot_original_state() -> void:
	if current_deck == null:
		return
	_original_name = current_deck.name
	_original_card_paths = current_deck.card_paths.duplicate()

## Restaure current_deck (même instance que dans DeckManager.decks) à son
## dernier état sauvegardé — voir _original_name/_original_card_paths.
func _discard_changes() -> void:
	if current_deck == null:
		return
	current_deck.name = _original_name
	current_deck.card_paths = _original_card_paths.duplicate()

func _on_add_card(card_data: CardData) -> void:
	if current_deck == null:
		return
	if not DeckManager.can_add_card(current_deck, card_data):
		return
	current_deck.add_card(card_data)
	_mark_dirty()
	_refresh_deck_list()
	# Si on vient d'atteindre le max de copies, feedback immédiat sous le curseur
	if _is_card_maxed(card_data) and _hovered_wrapper != null and is_instance_valid(_hovered_wrapper):
		_show_max_copies_tooltip(_hovered_wrapper, card_data)

func _on_deck_row_input(event: InputEvent, path: String) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		_on_remove_one(path)

func _on_remove_one(path: String) -> void:
	if current_deck == null:
		return
	var idx := current_deck.card_paths.rfind(path)
	if idx >= 0:
		current_deck.remove_card_at(idx)
		_mark_dirty()
	_refresh_deck_list()

func _on_remove_all(path: String) -> void:
	if current_deck == null:
		return
	current_deck.remove_all_copies(path)
	_mark_dirty()
	_refresh_deck_list()

func _on_name_changed(new_name: String) -> void:
	if current_deck and current_deck.name != new_name:
		current_deck.name = new_name
		_mark_dirty()

func _on_search_changed(text: String) -> void:
	_filter_text = text
	_refresh_card_grid()

func _on_save() -> void:
	if not _can_save():
		return
	current_deck.name = DeckManager.make_unique_name(current_deck.name, current_deck)
	deck_name_edit.text = current_deck.name
	DeckManager.save_decks()
	_dirty = false
	_snapshot_original_state()
	_update_save_button()

func _on_back() -> void:
	if _dirty:
		_show_unsaved_changes_dialog()
	else:
		queue_free()

## Popup affichée en quittant le deck builder avec des modifications non
## sauvegardées (voir _dirty) : proposer de sauvegarder plutôt que de perdre
## les changements silencieusement (comportement précédent). Panneau custom
## (pas de ConfirmationDialog natif, dont le chrome de fenêtre système
## tranche avec le reste de l'UI parchemin/or du deck builder) construit
## dans le même style que les autres panneaux de cet écran.
func _show_unsaved_changes_dialog() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 30
	add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var bg := StyleBoxFlat.new()
	bg.bg_color              = Color(0.09, 0.075, 0.055, 0.98)
	bg.border_color          = Color(0.78, 0.58, 0.10, 0.9)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(8)
	bg.content_margin_left   = 26
	bg.content_margin_right  = 26
	bg.content_margin_top    = 22
	bg.content_margin_bottom = 22

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", bg)
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	var text_lbl := Label.new()
	text_lbl.text = SettingsManager.t("deck.unsaved_changes_text")
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_lbl.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	text_lbl.add_theme_font_size_override("font_size", 15)
	vbox.add_child(text_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var discard_btn := Button.new()
	discard_btn.text = SettingsManager.t("deck.unsaved_changes_discard")
	discard_btn.custom_minimum_size = Vector2(150, 34)
	btn_row.add_child(discard_btn)

	var save_btn := Button.new()
	save_btn.text = SettingsManager.t("deck.unsaved_changes_save")
	save_btn.custom_minimum_size = Vector2(150, 34)
	btn_row.add_child(save_btn)

	save_btn.pressed.connect(func():
		overlay.queue_free()
		# Deck invalide (min de cartes non atteint, warning de ressource de race...) :
		# on ne peut pas sauvegarder — on referme juste la popup et on laisse le
		# joueur corriger le deck plutôt que de fermer le builder sans sauver.
		if _can_save():
			_on_save()
			queue_free()
	)
	discard_btn.pressed.connect(func():
		overlay.queue_free()
		_discard_changes()
		queue_free()
	)

# ─── Import / Export ───────────────────────────────────────────────────────────

func _on_export() -> void:
	DeckImportExport.export(self)

func _on_import() -> void:
	DeckImportExport.import(self)

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
	# Cartes-ressource : jamais au maximum, quantité illimitée dans le deck.
	if card_data.card_type == "Resource":
		return false
	var owned := CollectionManager.owned_quantity(card_data)
	return _count_in_deck(card_data.resource_path) >= min(DeckManager.MAX_COPIES_PER_CARD, owned)

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
## bornées par la quantité réellement débloquée plutôt que par DeckManager.MAX_COPIES_PER_CARD).
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

## Trouve le ScrollContainer ancêtre le plus proche du nœud survolé (grille de
## collection = ScrollCards, liste du deck = ScrollDeck) : sert de référence
## pour ne jamais faire déborder la preview/les tooltips sur les panneaux
## voisins (barre de filtres au-dessus, liste du deck à côté). À défaut,
## replie sur tout l'écran.
func _hover_panel_bounds(wrapper: Control) -> Rect2:
	var n: Node = wrapper
	while n != null and not (n is ScrollContainer):
		n = n.get_parent()
	if n == null:
		return Rect2(Vector2.ZERO, get_viewport_rect().size)
	var ctrl := n as Control
	return Rect2(ctrl.global_position, ctrl.size)

## Repositionne la preview agrandie et les tooltips par rapport à la carte
## survolée. Appelé à chaque frame tant que le survol dure, pour que tout
## suive le scroll de la grille.
func _position_hover_tooltips() -> void:
	var wrapper := _hovered_wrapper
	if wrapper == null or not is_instance_valid(wrapper):
		return
	var vp := get_viewport_rect().size
	var panel_bounds := _hover_panel_bounds(wrapper)
	var preview_size := CARD_BASE_SIZE * PREVIEW_SCALE.x

	# Preview alignée sur le haut de la carte survolée quand la place le
	# permet (sinon ajustée comme en bas d'écran, pour ne jamais chevaucher
	# la barre de filtres si la carte est coupée en haut de la grille).
	var preview_y: float = clampf(
		wrapper.global_position.y, panel_bounds.position.y, vp.y - preview_size.y - 4.0)

	# À droite de la carte par défaut (place généralement disponible dans la
	# grille), replié à gauche seulement si ça déborderait du panneau courant
	# (empêche d'empiéter sur la liste du deck voisine).
	var preview_on_left := false
	var preview_x: float = wrapper.global_position.x + wrapper.size.x + 12.0
	if preview_x + preview_size.x > panel_bounds.position.x + panel_bounds.size.x - 4.0:
		preview_x = wrapper.global_position.x - preview_size.x - 12.0
		preview_on_left = true
	preview_x = clampf(preview_x, 4.0, vp.x - preview_size.x - 4.0)

	card_preview.global_position = Vector2(preview_x, preview_y)
	var card_center := card_preview.global_position + preview_size / 2.0
	var base_y       := card_preview.global_position.y

	# Hauteur totale de la pile de panneaux : si elle dépasse le bas de l'écran,
	# on remonte le point de départ (ou on le limite en haut) pour que la pile
	# entière reste visible plutôt que de déborder sous la fenêtre.
	var stack_height := 0.0
	for panel in _keyword_tooltips:
		if is_instance_valid(panel):
			stack_height += panel.size.y + 6.0
	if stack_height > 0.0:
		stack_height -= 6.0
		base_y = clampf(base_y, 4.0, maxf(4.0, vp.y - stack_height - 4.0))

	# Toujours du même côté que la preview, en s'en éloignant davantage —
	# jamais entre la preview et la carte survolée (sinon ils la recouvrent).
	for panel in _keyword_tooltips:
		if not is_instance_valid(panel):
			continue
		var px: float
		if preview_on_left:
			px = card_preview.global_position.x - panel.size.x - 12.0
		else:
			px = card_preview.global_position.x + preview_size.x + 12.0
		px = clampf(px, 4.0, vp.x - panel.size.x - 4.0)
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
		
