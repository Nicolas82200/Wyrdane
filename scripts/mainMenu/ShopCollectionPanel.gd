extends RefCounted
class_name ShopCollectionPanel

# Grille de collection de l'onglet "Collection" de la Boutique (voir
# MainMenu.gd, _select_shop_tab) — affiche TOUTES les cartes jouables du jeu
# (hors jetons, déjà exclus par CardLibrary, et hors cartes-ressource, sans
# intérêt collectionnable), possédées en clair avec leur nombre d'exemplaires,
# non possédées grisées (même teinte que DeckBuilder.MAXED_TINT) — la
# quantité est toujours affichée en texte, jamais seulement par la couleur
# (voir "Indicateurs non basés sur la seule couleur" dans CLAUDE.md).

const CARD_SCENE := preload("res://scenes/card/Card.tscn")
const GRID_CARD_SCALE := 0.72
const GRID_WRAPPER_SIZE := Vector2(189, 283)
const LOCKED_TINT := Color(0.38, 0.38, 0.38, 1)
const CARDS_PER_FRAME := 8

static var _filter_race: int = -1
# Incrémenté à chaque (re)population : invalide toute chaîne _load_batch en
# cours (filtre changé avant la fin du chargement précédent) pour éviter
# qu'un batch obsolète continue à écrire dans une grille déjà reconstruite,
# et pour que deux `bind()` successifs ne soient jamais des Callable égaux
# (Godot compare les arguments par valeur : deux appels avec un même
# contenu de `cards` et un même `end_index` sur la même grille produisaient
# sinon un "Signal already connected").
static var _load_token: int = 0

## Construit la grille dans `parent` (VBoxContainer, vidé puis reconstruit) :
## une barre de filtre par race suivie d'une grille en HFlowContainer.
static func build_into(parent: Control) -> void:
	for child in parent.get_children():
		child.queue_free()

	var filter_bar := HBoxContainer.new()
	filter_bar.name = "CollectionFilterBar"
	filter_bar.add_theme_constant_override("separation", 6)
	parent.add_child(filter_bar)

	var count_label := Label.new()
	count_label.name = "CollectionCountLabel"
	count_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72, 0.9))
	parent.add_child(count_label)

	var grid := HFlowContainer.new()
	grid.name = "CollectionGrid"
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)

	_build_filter_bar(filter_bar, grid, count_label)
	_populate_grid(grid, count_label)

static func _build_filter_bar(filter_bar: HBoxContainer, grid: HFlowContainer, count_label: Label) -> void:
	var label := Label.new()
	label.text = SettingsManager.t("deck.filter_race")
	filter_bar.add_child(label)

	var group := ButtonGroup.new()
	var all_button := _make_filter_button(SettingsManager.t("deck.filter_all"), -1, group, grid, count_label)
	filter_bar.add_child(all_button)

	var race_keys := Race.Type.keys()
	for race_value in Race.get_implemented_races():
		var race_button := _make_filter_button(SettingsManager.t("RACE_" + race_keys[race_value]), race_value, group, grid, count_label)
		filter_bar.add_child(race_button)

static func _make_filter_button(label_text: String, race_value: int, group: ButtonGroup, grid: HFlowContainer, count_label: Label) -> Button:
	var button := Button.new()
	button.text = label_text
	button.toggle_mode = true
	button.button_group = group
	button.button_pressed = _filter_race == race_value
	button.pressed.connect(func():
		_filter_race = race_value
		_populate_grid(grid, count_label)
	)
	return button

static func _populate_grid(grid: HFlowContainer, count_label: Label) -> void:
	for child in grid.get_children():
		child.queue_free()

	var cards: Array[CardData] = []
	for c in CardLibrary.all_cards:
		if c.card_type == "Resource":
			continue
		if _filter_race != -1 and c.race != _filter_race:
			continue
		cards.append(c)
	cards.sort_custom(func(a, b): return a.cost < b.cost)

	var owned_count := 0
	for c in cards:
		if CollectionManager.is_owned(c):
			owned_count += 1
	count_label.text = SettingsManager.t("collection.owned_count") % [owned_count, cards.size()]

	_load_token += 1
	_load_batch(cards, 0, grid, _load_token)

static func _load_batch(cards: Array[CardData], start_index: int, grid: HFlowContainer, token: int) -> void:
	if not is_instance_valid(grid) or token != _load_token:
		return
	var end_index: int = mini(start_index + CARDS_PER_FRAME, cards.size())
	for i in range(start_index, end_index):
		var wrapper := Control.new()
		wrapper.custom_minimum_size = GRID_WRAPPER_SIZE
		# Le wrapper doit déjà être dans l'arbre avant d'y ajouter la carte :
		# Card.gd initialise ses @onready au moment où il entre l'arbre, et
		# set_data() y écrit directement — l'appeler avant laisse ces
		# références à null (voir DeckBuilder._add_card_to_grid, même ordre).
		grid.add_child(wrapper)
		_fill_card_wrapper(wrapper, cards[i])
	if end_index < cards.size():
		grid.get_tree().process_frame.connect(_load_batch.bind(cards, end_index, grid, token), CONNECT_ONE_SHOT)

static func _fill_card_wrapper(wrapper: Control, card_data: CardData) -> void:
	var card_visual: Card = CARD_SCENE.instantiate()
	wrapper.add_child(card_visual)
	card_visual.scale = Vector2(GRID_CARD_SCALE, GRID_CARD_SCALE)
	card_visual.set_data(card_data)
	card_visual.set_non_interactive()

	var owned: int = CollectionManager.owned_quantity(card_data)
	if owned <= 0:
		card_visual.modulate = LOCKED_TINT

	var badge := PanelContainer.new()
	badge.position = Vector2(4, 4)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0, 0, 0, 0.75)
	badge_style.corner_radius_top_left = 6
	badge_style.corner_radius_top_right = 6
	badge_style.corner_radius_bottom_left = 6
	badge_style.corner_radius_bottom_right = 6
	badge_style.content_margin_left = 6
	badge_style.content_margin_right = 6
	badge_style.content_margin_top = 2
	badge_style.content_margin_bottom = 2
	badge.add_theme_stylebox_override("panel", badge_style)

	var badge_label := Label.new()
	badge_label.text = SettingsManager.t("collection.owned_format") % owned
	badge_label.add_theme_font_size_override("font_size", 13)
	badge_label.add_theme_color_override("font_color", Color.WHITE if owned > 0 else Color(0.8, 0.8, 0.8, 1))
	badge.add_child(badge_label)
	wrapper.add_child(badge)
