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

func _make_deck_row(deck: DeckData, index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	# Indicateur deck actif
	var active_indicator := Label.new()
	active_indicator.text = "★" if index == DeckManager.active_deck_index else "☆"
	active_indicator.custom_minimum_size = Vector2(24, 0)
	active_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Nom + compte
	var name_lbl := Label.new()
	name_lbl.text = "%s  (%d/40)" % [deck.name, deck.size()]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Bouton choisir
	var select_btn := Button.new()
	select_btn.text = "Choisir"
	select_btn.pressed.connect(_on_select_deck.bind(index))

	# Bouton éditer
	var edit_btn := Button.new()
	edit_btn.text = "Editer"
	edit_btn.pressed.connect(_on_edit_deck.bind(index))

	# Bouton supprimer
	var del_btn := Button.new()
	del_btn.text = "X"
	del_btn.pressed.connect(_on_delete_deck.bind(index))

	row.add_child(active_indicator)
	row.add_child(name_lbl)
	row.add_child(select_btn)
	row.add_child(edit_btn)
	row.add_child(del_btn)
	return row

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
