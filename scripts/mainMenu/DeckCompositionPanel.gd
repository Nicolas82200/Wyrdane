extends RefCounted
class_name DeckCompositionPanel

# Vue "Composition du deck" du menu principal (liste des cartes, aperçu au
# survol, courbe de mana + répartition) — extrait de MainMenu.gd. Fonctions
# statiques prenant `menu` en paramètre, même pattern que NewsPanel/
# QuestsPanel/ProfilePanel. `menu._composition_deck_index` reste sur
# MainMenu (déjà lu/écrit à plusieurs autres endroits du fichier).
#
# _make_curve_chart/_make_chip ressemblent à DeckStatsPanel._make_curve_chart/
# _make_chip mais avec des réglages visuels délibérément différents (colonne
# étroite ici, pleine largeur dans DeckBuilder) — pas fusionnés.

const CURVE_BUCKETS := 8       # coûts 0..6, puis 7+ regroupés
const CURVE_BAR_HEIGHT := 60.0
const CURVE_BAR_COLOR := Color(0.78, 0.58, 0.10, 1)
const STATS_LABEL_COLOR := Color(0.7, 0.6, 0.4, 1)
const STATS_VALUE_COLOR := Color(0.91, 0.835, 0.639, 1)

static func show(menu, deck_index: int) -> void:
	menu._composition_deck_index = deck_index
	var deck: DeckData = DeckManager.decks[deck_index]
	menu.deck_comp_title_label.text = "%s : %s" % [SettingsManager.t("MENU_DECK_COMPOSITION_TITLE"), SettingsManager.t(deck.name)]
	menu.deck_comp_preview_card.hide()
	menu.deck_comp_preview_hint.show()
	for child in menu.deck_comp_list_vbox.get_children():
		child.queue_free()

	var counts: Dictionary = {}
	var order: Array[CardData] = []
	for card in deck.get_cards():
		if not counts.has(card.resource_path):
			order.append(card)
		counts[card.resource_path] = counts.get(card.resource_path, 0) + 1

	for card in order:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		line.mouse_entered.connect(_on_card_hover.bind(menu, card))
		line.mouse_exited.connect(_on_card_unhover.bind(menu))

		var count_lbl := Label.new()
		count_lbl.text = "x%d" % counts[card.resource_path]
		count_lbl.custom_minimum_size = Vector2(32, 0)
		count_lbl.add_theme_font_size_override("font_size", 14)
		count_lbl.add_theme_color_override("font_color", Color(0.94, 0.75, 0.25, 1))
		line.add_child(count_lbl)

		var name_lbl := Label.new()
		name_lbl.text = SettingsManager.t(card.card_name)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
		line.add_child(name_lbl)

		var cost_lbl := Label.new()
		cost_lbl.text = str(card.cost)
		cost_lbl.custom_minimum_size = Vector2(20, 0)
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.add_theme_font_size_override("font_size", 14)
		cost_lbl.add_theme_color_override("font_color", Color(0.6, 0.75, 0.95, 1))
		line.add_child(cost_lbl)

		menu.deck_comp_list_vbox.add_child(line)

	_update_stats(menu, deck.get_cards())
	menu._show_info_view(menu.InfoView.DECK_COMPOSITION)

## Aperçu de carte à droite au survol d'une ligne de la composition.
static func _on_card_hover(menu, card: CardData) -> void:
	menu.deck_comp_preview_hint.hide()
	menu.deck_comp_preview_card.set_data(card)
	menu.deck_comp_preview_card.show()

static func _on_card_unhover(menu) -> void:
	menu.deck_comp_preview_card.hide()
	menu.deck_comp_preview_hint.show()

## Courbe de mana + répartition types/races du deck affiché.
static func _update_stats(menu, cards: Array[CardData]) -> void:
	for child in menu.deck_comp_stats_panel.get_children():
		child.queue_free()
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
	menu.deck_comp_stats_panel.add_child(curve_title)

	menu.deck_comp_stats_panel.add_child(_make_curve_chart(curve))

	var avg_label := Label.new()
	avg_label.text = SettingsManager.t("deck.stats_avg_cost") % (float(total_cost) / cards.size())
	avg_label.add_theme_color_override("font_color", STATS_VALUE_COLOR)
	avg_label.add_theme_font_size_override("font_size", 12)
	avg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.deck_comp_stats_panel.add_child(avg_label)

	var breakdown_title := Label.new()
	breakdown_title.text = SettingsManager.t("deck.stats_types_title")
	breakdown_title.add_theme_color_override("font_color", STATS_LABEL_COLOR)
	breakdown_title.add_theme_font_size_override("font_size", 13)
	menu.deck_comp_stats_panel.add_child(breakdown_title)

	# Colonne étroite : un chip par ligne plutôt qu'une rangée horizontale
	# (contrairement à DeckBuilder, qui a toute la largeur de l'écran).
	for type_name in ["Minion", "Instant", "Ritual", "Enchantment", "Resource"]:
		if type_counts.has(type_name):
			menu.deck_comp_stats_panel.add_child(_make_chip(
				SettingsManager.t("cardtype." + type_name.to_lower()), type_counts[type_name]))

	for key in Race.Type.keys():
		var race_value: int = Race.Type[key]
		if race_counts.has(race_value):
			menu.deck_comp_stats_panel.add_child(_make_chip(SettingsManager.t("RACE_" + key), race_counts[race_value]))

static func _make_curve_chart(curve: Array) -> Control:
	var max_count: int = 1
	for c in curve:
		max_count = max(max_count, c)

	var chart := HBoxContainer.new()
	chart.alignment = BoxContainer.ALIGNMENT_CENTER
	chart.add_theme_constant_override("separation", 3)

	for i in range(CURVE_BUCKETS):
		var count: int = curve[i]
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_END
		col.custom_minimum_size = Vector2(22, 0)
		col.add_theme_constant_override("separation", 2)

		var count_lbl := Label.new()
		count_lbl.text = str(count) if count > 0 else ""
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_lbl.add_theme_font_size_override("font_size", 10)
		count_lbl.add_theme_color_override("font_color", STATS_VALUE_COLOR)
		col.add_child(count_lbl)

		var bar := ColorRect.new()
		var height: float = max(4.0, (float(count) / max_count) * CURVE_BAR_HEIGHT)
		bar.custom_minimum_size = Vector2(18, height)
		bar.color = CURVE_BAR_COLOR if count > 0 else Color(0.3, 0.24, 0.10, 0.4)
		col.add_child(bar)

		var cost_lbl := Label.new()
		cost_lbl.text = str(i) if i < CURVE_BUCKETS - 1 else "%d+" % i
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.add_theme_font_size_override("font_size", 10)
		cost_lbl.add_theme_color_override("font_color", STATS_LABEL_COLOR)
		col.add_child(cost_lbl)

		chart.add_child(col)

	return chart

static func _make_chip(label_text: String, count: int) -> Control:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.10, 0.08, 1)
	bg.border_color = Color(0.72, 0.55, 0.24, 0.55)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(4)
	bg.content_margin_left   = 8
	bg.content_margin_right  = 8
	bg.content_margin_top    = 2
	bg.content_margin_bottom = 2

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", bg)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var lbl := Label.new()
	lbl.text = "%s ×%d" % [label_text, count]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", STATS_VALUE_COLOR)
	panel.add_child(lbl)

	return panel

static func edit_deck(menu) -> void:
	if menu._composition_deck_index < 0 or menu._composition_deck_index >= DeckManager.decks.size():
		return
	var scene := load(menu.DECK_BUILDER_SCENE) as PackedScene
	if scene == null:
		return
	var builder = scene.instantiate()
	menu.get_tree().current_scene.add_child(builder)
	builder.load_deck(DeckManager.decks[menu._composition_deck_index])
	# DeckBuilder est plein écran, il recouvre déjà le panneau de nav en
	# dessous — pas besoin de le masquer, juste de rafraîchir au retour.
	builder.tree_exited.connect(func():
		if menu._play_selected_deck_index >= 0:
			menu._refresh_play_deck_list()
			show(menu, menu._composition_deck_index)
	)
