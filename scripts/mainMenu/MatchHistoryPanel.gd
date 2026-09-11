extends RefCounted
class_name MatchHistoryPanel

# Section "Historique des parties", ajoutée dynamiquement en bas de la vue
# Profil — même esprit que ReferralPanel/QuestsPanel (pas de nouveau bouton de
# nav/vue dédiée). Purement local (SettingsManager.match_history) : aucune
# route backend, aucune notion d'historique côté serveur.

const ACCENT_VICTORY := Color(0.42, 0.62, 0.32, 0.85)
const ACCENT_DEFEAT := Color(0.62, 0.28, 0.24, 0.85)

static func open(menu) -> void:
	# Reconstruite à chaque ouverture de la vue Profil, même logique que
	# ReferralPanel.open (évite l'empilement si Profil est rouvert plusieurs fois).
	var existing: Node = menu.profile_view.get_node_or_null("MatchHistorySection")
	if existing:
		existing.queue_free()

	var section := VBoxContainer.new()
	section.name = "MatchHistorySection"
	section.add_theme_constant_override("separation", 6)
	menu.profile_view.add_child(section)

	section.add_child(HSeparator.new())

	var title := Label.new()
	title.text = SettingsManager.t("MATCH_HISTORY_TITLE")
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	section.add_child(title)

	var history: Array = SettingsManager.match_history
	if history.is_empty():
		var empty_label := Label.new()
		empty_label.text = SettingsManager.t("MATCH_HISTORY_EMPTY")
		empty_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.58, 0.85))
		section.add_child(empty_label)
		return

	for entry in history:
		if entry is Dictionary:
			section.add_child(_make_row(entry))

static func _make_row(entry: Dictionary) -> PanelContainer:
	var is_victory: bool = entry.get("result", "") == "victory"
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.075, 0.06, 0.55)
	style.border_width_left = 3
	style.border_color = ACCENT_VICTORY if is_victory else ACCENT_DEFEAT
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	row.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 6)
	row.add_child(margin)

	var label := Label.new()
	var result_text: String = SettingsManager.t("MATCH_HISTORY_VICTORY" if is_victory else "MATCH_HISTORY_DEFEAT")
	var opponent_name: String = str(entry.get("opponent_name", "?"))
	var opponent_race: String = str(entry.get("opponent_race", ""))
	var race_suffix := " (%s)" % opponent_race if opponent_race != "" else ""
	var duration_sec: int = int(entry.get("duration_sec", 0))
	label.text = "%s — %s%s — %d:%02d" % [result_text, opponent_name, race_suffix, duration_sec / 60, duration_sec % 60]
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.9, 0.87, 0.78, 1))
	margin.add_child(label)

	return row
