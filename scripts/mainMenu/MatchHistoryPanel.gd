extends RefCounted
class_name MatchHistoryPanel

# Onglet "Historique" de la vue Profil (voir ProfilePanel.render) : les 20
# dernières parties RÉSEAU (ranked + partie rapide, aucune distinction
# backend, voir « Ranked / paliers » dans CLAUDE.md) du joueur, adversaire
# le plus récent en tête — GET /api/ranked/matches/history
# (rankedModel.getMatchHistory côté backend). Solo/IA non couverts (pas de
# second rapporteur pour confirmer un match côté serveur).

const MATCH_HISTORY_LIMIT := 20
const ACCENT_VICTORY := Color(0.42, 0.62, 0.32, 0.85)
const ACCENT_DEFEAT := Color(0.62, 0.28, 0.24, 0.85)
const COLOR_MMR_GAIN := Color(0.55, 0.78, 0.42, 1)
const COLOR_MMR_LOSS := Color(0.82, 0.42, 0.38, 1)

static func open(menu) -> void:
	# Reconstruite à chaque ouverture de l'onglet (voir ProfilePanel.render,
	# qui queue_free déjà la section précédente) : on repart d'un état
	# "chargement" pendant la requête backend.
	var section := VBoxContainer.new()
	section.name = "MatchHistorySection"
	section.add_theme_constant_override("separation", 6)
	menu.profile_body.add_child(section)

	section.add_child(HSeparator.new())

	var title := Label.new()
	title.text = SettingsManager.t("MATCH_HISTORY_TITLE")
	title.add_theme_font_size_override("font_size", Typography.SECTION)
	title.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	section.add_child(title)

	var status_label := Label.new()
	status_label.name = "StatusLabel"
	status_label.text = SettingsManager.t("MATCH_HISTORY_LOADING")
	status_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.58, 0.85))
	section.add_child(status_label)

	if not BackendClient.is_authenticated():
		status_label.text = SettingsManager.t("MATCH_HISTORY_UNAVAILABLE")
		return

	# Profil d'un ami (voir ProfilePanel.open_for_user) : historique de CET
	# autre joueur (restreint aux amis acceptés côté backend), "victoire" doit
	# alors être jugée de son point de vue à lui, pas du joueur local.
	var target_user_id: int = menu._profile_target_user_id
	var on_result := func(success: bool, entries: Array):
		# La vue/l'onglet a pu changer pendant l'aller-retour réseau — la
		# section elle-même a alors déjà été libérée par un futur render().
		if not is_instance_valid(section):
			return
		_populate(section, status_label, success, entries, target_user_id)
	if target_user_id >= 0:
		BackendClient.get_friend_match_history(target_user_id, MATCH_HISTORY_LIMIT, on_result)
	else:
		BackendClient.get_match_history(MATCH_HISTORY_LIMIT, on_result)

static func _populate(section: VBoxContainer, status_label: Label, success: bool, entries: Array, viewed_user_id: int) -> void:
	if not success:
		status_label.text = SettingsManager.t("MATCH_HISTORY_UNAVAILABLE")
		return
	if entries.is_empty():
		status_label.text = SettingsManager.t("MATCH_HISTORY_EMPTY")
		return
	status_label.queue_free()

	for entry in entries:
		if entry is Dictionary:
			section.add_child(_make_row(entry, viewed_user_id))

static func _make_row(entry: Dictionary, viewed_user_id: int) -> PanelContainer:
	var is_victory: bool = _is_winner(entry, viewed_user_id)
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

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)

	var opponent_name: String = str(entry.get("opponent_username", ""))
	if opponent_name == "":
		opponent_name = SettingsManager.t("MATCH_HISTORY_UNKNOWN_OPPONENT")
	var deck_races: Array = entry.get("opponent_deck_races", []) if entry.get("opponent_deck_races") is Array else []
	var race_label := Race.race_names_label(deck_races)

	var top_label := Label.new()
	var result_text: String = SettingsManager.t("MATCH_HISTORY_VICTORY" if is_victory else "MATCH_HISTORY_DEFEAT")
	top_label.text = "%s — %s (%s)" % [result_text, opponent_name, race_label]
	top_label.add_theme_font_size_override("font_size", Typography.BODY)
	top_label.add_theme_color_override("font_color", Color(0.9, 0.87, 0.78, 1))
	vbox.add_child(top_label)

	var duration_sec: int = int(entry.get("duration_sec", 0))
	var mmr_change: int = int(entry.get("mmr_change", 0))
	var mmr_text := SettingsManager.t("MATCH_HISTORY_MMR_GAIN" if mmr_change >= 0 else "MATCH_HISTORY_MMR_LOSS") % mmr_change
	var played_at: String = str(entry.get("played_at", ""))
	var date_str := played_at.substr(0, 10) if played_at.length() >= 10 else ""

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 10)
	vbox.add_child(bottom_row)

	var duration_label := Label.new()
	duration_label.text = "%d:%02d" % [duration_sec / 60, duration_sec % 60]
	duration_label.add_theme_font_size_override("font_size", Typography.MICRO)
	duration_label.add_theme_color_override("font_color", Color(0.75, 0.71, 0.63, 0.9))
	bottom_row.add_child(duration_label)

	var mmr_label := Label.new()
	mmr_label.text = mmr_text
	mmr_label.add_theme_font_size_override("font_size", Typography.MICRO)
	mmr_label.add_theme_color_override("font_color", COLOR_MMR_GAIN if mmr_change >= 0 else COLOR_MMR_LOSS)
	bottom_row.add_child(mmr_label)

	var date_label := Label.new()
	date_label.text = date_str
	date_label.add_theme_font_size_override("font_size", Typography.MICRO)
	date_label.add_theme_color_override("font_color", Color(0.75, 0.71, 0.63, 0.9))
	bottom_row.add_child(date_label)

	return row

# winner_id est l'id backend brut (voir rankedModel.getMatchHistory) : victoire
# du joueur dont on affiche l'historique (le joueur local, ou l'ami consulté
# via ProfilePanel.open_for_user) si et seulement si winner_id == son id.
static func _is_winner(entry: Dictionary, viewed_user_id: int) -> bool:
	var reference_id := viewed_user_id if viewed_user_id >= 0 else BackendClient.local_user_id()
	return int(entry.get("winner_id", -1)) == reference_id
