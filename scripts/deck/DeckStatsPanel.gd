extends RefCounted
class_name DeckStatsPanel

# Panneau de statistiques du deck (courbe de mana + répartition types/races) —
# extrait de DeckBuilder.gd, pure lecture de `builder.current_deck` et
# construction de nœuds dans `builder.stats_panel`.

const CURVE_BUCKETS := 8       # coûts 0..6, puis 7+ regroupés
const CURVE_BAR_HEIGHT := 60.0
const CURVE_BAR_COLOR := Color(0.78, 0.58, 0.10, 1)
const STATS_LABEL_COLOR := Color(0.7, 0.6, 0.4, 1)
const STATS_VALUE_COLOR := Color(0.91, 0.835, 0.639, 1)

static func refresh(builder) -> void:
	for child in builder.stats_panel.get_children():
		child.queue_free()

	if builder.current_deck == null:
		return
	var cards := builder.current_deck.get_cards()
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
	builder.stats_panel.add_child(curve_title)

	builder.stats_panel.add_child(_make_curve_chart(curve))

	var avg_label := Label.new()
	avg_label.text = SettingsManager.t("deck.stats_avg_cost") % (float(total_cost) / cards.size())
	avg_label.add_theme_color_override("font_color", STATS_VALUE_COLOR)
	avg_label.add_theme_font_size_override("font_size", 12)
	avg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	builder.stats_panel.add_child(avg_label)

	var breakdown_title := Label.new()
	breakdown_title.text = SettingsManager.t("deck.stats_types_title")
	breakdown_title.add_theme_color_override("font_color", STATS_LABEL_COLOR)
	breakdown_title.add_theme_font_size_override("font_size", 13)
	builder.stats_panel.add_child(breakdown_title)

	var type_row := HBoxContainer.new()
	type_row.alignment = BoxContainer.ALIGNMENT_CENTER
	type_row.add_theme_constant_override("separation", 10)
	for type_name in ["Minion", "Instant", "Ritual", "Enchantment", "Resource"]:
		if type_counts.has(type_name):
			type_row.add_child(_make_chip(
				SettingsManager.t("cardtype." + type_name.to_lower()), type_counts[type_name]))
	builder.stats_panel.add_child(type_row)

	var race_row := HBoxContainer.new()
	race_row.alignment = BoxContainer.ALIGNMENT_CENTER
	race_row.add_theme_constant_override("separation", 10)
	for key in Race.Type.keys():
		var race_value: int = Race.Type[key]
		if race_counts.has(race_value):
			race_row.add_child(_make_chip(SettingsManager.t("RACE_" + key), race_counts[race_value]))
	builder.stats_panel.add_child(race_row)

static func _make_curve_chart(curve: Array) -> Control:
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

static func _make_chip(label_text: String, count: int) -> Control:
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
