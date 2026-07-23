extends Control
class_name DeckList

@onready var decks_container: VBoxContainer = %DecksContainer
@onready var create_button: Button          = %CreateButton
@onready var import_button: Button          = %ImportButton
@onready var back_button: Button            = %BackButton
@onready var title_label: Label             = $CenterContainer/Panel/Margin/VBox/Title
@onready var subtitle_label: Label          = $CenterContainer/Panel/Margin/VBox/Subtitle

const DECK_BUILDER_SCENE := "res://scenes/deck/DeckBuilder.tscn"

# Couleur d'accent affichée en bandeau à gauche de chaque ligne, selon la race
# dominante du deck (repère visuel rapide dans la liste).
const RACE_ACCENTS := {
	Race.Type.UNDEAD: Color(0.35, 0.62, 0.32, 1),
	Race.Type.HUMAN:  Color(0.85, 0.68, 0.30, 1),
	Race.Type.DEMON:  Color(0.78, 0.22, 0.25, 1),
	Race.Type.ELF:    Color(0.30, 0.65, 0.55, 1),
	Race.Type.DWARF:  Color(0.62, 0.42, 0.24, 1),
}
const NEUTRAL_ACCENT := Color(0.4, 0.35, 0.25, 1)

func _ready() -> void:
	create_button.pressed.connect(_on_create_deck)
	import_button.pressed.connect(_on_import_deck)
	back_button.pressed.connect(_on_back)
	SettingsManager.language_changed.connect(func(_l): _retranslate())
	# Les decks arrivent de façon asynchrone (sync backend lancée par MainMenu) :
	# si elle n'a pas encore fini, on se met simplement à jour quand elle finit.
	DeckManager.decks_loaded.connect(_refresh)
	_retranslate()   # appelle aussi _refresh()

# Met à jour les libellés fixes dans la langue courante (les lignes de deck sont
# régénérées par _refresh, appelé ici aussi pour relocaliser leurs boutons).
func _retranslate() -> void:
	title_label.text    = SettingsManager.t("decklist.title")
	subtitle_label.text = SettingsManager.t("decklist.subtitle")
	create_button.text  = SettingsManager.t("decklist.create")
	import_button.text  = SettingsManager.t("decklist.import")
	back_button.text    = SettingsManager.t("ui.back")
	_refresh()

func _refresh() -> void:
	for child in decks_container.get_children():
		child.queue_free()
	if DeckManager.decks.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = SettingsManager.t("decklist.empty")
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_lbl.custom_minimum_size = Vector2(0, 120)
		empty_lbl.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 0.5))
		empty_lbl.add_theme_font_size_override("font_size", 18)
		decks_container.add_child(empty_lbl)
		return
	for i in range(DeckManager.decks.size()):
		var deck: DeckData = DeckManager.decks[i]
		var row := _make_deck_row(deck, i)
		decks_container.add_child(row)

## Couleur de la race la plus représentée dans le deck.
func _dominant_race_color(deck: DeckData) -> Color:
	var counts: Dictionary = {}
	for card in deck.get_cards():
		counts[card.race] = counts.get(card.race, 0) + 1
	var best_race := -1
	var best_count := 0
	for race in counts:
		if counts[race] > best_count:
			best_race = race
			best_count = counts[race]
	return RACE_ACCENTS.get(best_race, NEUTRAL_ACCENT)

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

	# Bandeau coloré : race dominante du deck
	var race_strip := ColorRect.new()
	race_strip.color = _dominant_race_color(deck)
	race_strip.custom_minimum_size = Vector2(5, 0)
	row.add_child(race_strip)

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
	select_btn.text = SettingsManager.t("decklist.active") if is_active else SettingsManager.t("decklist.select")
	select_btn.disabled = is_active
	select_btn.custom_minimum_size = Vector2(96, 0)
	select_btn.add_theme_font_size_override("font_size", 15)
	select_btn.pressed.connect(_on_select_deck.bind(index))
	row.add_child(select_btn)

	# Bouton éditer
	var edit_btn := Button.new()
	edit_btn.text = SettingsManager.t("decklist.edit")
	edit_btn.custom_minimum_size = Vector2(84, 0)
	edit_btn.add_theme_font_size_override("font_size", 15)
	edit_btn.pressed.connect(_on_edit_deck.bind(index))
	row.add_child(edit_btn)

	# Bouton dupliquer
	var dup_btn := Button.new()
	dup_btn.text = SettingsManager.t("decklist.duplicate")
	dup_btn.custom_minimum_size = Vector2(96, 0)
	dup_btn.add_theme_font_size_override("font_size", 15)
	dup_btn.pressed.connect(_on_duplicate_deck.bind(index))
	row.add_child(dup_btn)

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

func _on_duplicate_deck(index: int) -> void:
	DeckManager.duplicate_deck(index)
	_refresh()

func _on_import_deck() -> void:
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
		var deck := DeckData.from_code(text_edit.text)
		if deck == null:
			var err := AcceptDialog.new()
			err.dialog_text = SettingsManager.t("deck.import_error")
			add_child(err)
			err.popup_centered()
			err.confirmed.connect(err.queue_free)
		else:
			DeckManager.add_deck(deck)
			_refresh()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)

func _on_back() -> void:
	hide()
