extends Control
class_name DeckList

@onready var decks_container: VBoxContainer = %DecksContainer
@onready var create_button: Button          = %CreateButton
@onready var back_button: Button            = %BackButton

const DECK_BUILDER_SCENE := "res://scenes/deck/DeckBuilder.tscn"

func _ready() -> void:
	create_button.pressed.connect(_on_create_deck)
	back_button.pressed.connect(_on_back)
	_refresh()

func _refresh() -> void:
	for child in decks_container.get_children():
		child.queue_free()
	for i in range(DeckManager.decks.size()):
		var deck: DeckData = DeckManager.decks[i]
		var row := _make_deck_row(deck, i)
		decks_container.add_child(row)

func _make_deck_row(deck: DeckData, index: int) -> Control:
	var is_active := index == DeckManager.active_deck_index

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.10, 0.08, 1)
	bg.border_color = Color(0.78, 0.58, 0.10, 0.9) if is_active else Color(0.30, 0.24, 0.10, 0.5)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(5)
	bg.content_margin_left   = 12
	bg.content_margin_right  = 8
	bg.content_margin_top    = 8
	bg.content_margin_bottom = 8

	var bg_hover := bg.duplicate() as StyleBoxFlat
	bg_hover.bg_color     = Color(0.18, 0.15, 0.10, 1)
	bg_hover.border_color = Color(0.78, 0.58, 0.10, 1)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", bg)
	panel.custom_minimum_size = Vector2(0, 52)
	panel.mouse_entered.connect(func(): panel.add_theme_stylebox_override("panel", bg_hover))
	panel.mouse_exited.connect(func():  panel.add_theme_stylebox_override("panel", bg))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	# Indicateur deck actif
	var active_indicator := Label.new()
	active_indicator.text = "★" if is_active else "☆"
	active_indicator.custom_minimum_size = Vector2(28, 0)
	active_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_indicator.add_theme_font_size_override("font_size", 20)
	active_indicator.add_theme_color_override("font_color",
		Color(0.94, 0.75, 0.25, 1) if is_active else Color(0.91, 0.835, 0.639, 0.35))
	row.add_child(active_indicator)

	# Nom
	var name_lbl := Label.new()
	name_lbl.text = deck.name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	row.add_child(name_lbl)

	# Compte de cartes — rouge si deck incomplet
	var count_lbl := Label.new()
	count_lbl.text = "%d/40" % deck.size()
	count_lbl.custom_minimum_size = Vector2(56, 0)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.add_theme_font_size_override("font_size", 14)
	count_lbl.add_theme_color_override("font_color",
		Color(0.5, 0.9, 0.5, 1) if deck.size() >= 40 else Color(1, 0.4, 0.4, 1))
	row.add_child(count_lbl)

	# Bouton choisir — désactivé si déjà actif
	var select_btn := Button.new()
	select_btn.text = "Actif" if is_active else "Choisir"
	select_btn.disabled = is_active
	select_btn.custom_minimum_size = Vector2(96, 0)
	select_btn.add_theme_font_size_override("font_size", 15)
	select_btn.pressed.connect(_on_select_deck.bind(index))
	row.add_child(select_btn)

	# Bouton éditer
	var edit_btn := Button.new()
	edit_btn.text = "Éditer"
	edit_btn.custom_minimum_size = Vector2(84, 0)
	edit_btn.add_theme_font_size_override("font_size", 15)
	edit_btn.pressed.connect(_on_edit_deck.bind(index))
	row.add_child(edit_btn)

	# Bouton supprimer
	var del_btn := Button.new()
	del_btn.text = "✕"
	del_btn.flat = true
	del_btn.custom_minimum_size = Vector2(36, 0)
	del_btn.add_theme_color_override("font_color",       Color(0.6, 0.3, 0.3, 1))
	del_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.4, 0.4, 1))
	del_btn.pressed.connect(_on_delete_deck.bind(index))
	row.add_child(del_btn)

	return panel

func _on_select_deck(index: int) -> void:
	DeckManager.set_active_deck(index)
	_refresh()

func _on_edit_deck(index: int) -> void:
	var scene := load(DECK_BUILDER_SCENE) as PackedScene
	if scene == null:
		return
	var builder = scene.instantiate()
	get_tree().current_scene.add_child(builder)
	builder.load_deck(DeckManager.decks[index])
	hide()
	builder.tree_exited.connect(func():
		show()
		_refresh()
	)

func _on_create_deck() -> void:
	var deck := DeckManager.create_deck()
	var scene := load(DECK_BUILDER_SCENE) as PackedScene
	if scene == null:
		return
	var builder = scene.instantiate()
	get_tree().current_scene.add_child(builder)
	builder.load_deck(deck)
	hide()
	builder.tree_exited.connect(func():
		show()
		_refresh()
	)

func _on_delete_deck(index: int) -> void:
	DeckManager.delete_deck(index)
	_refresh()

func _on_back() -> void:
	hide()
