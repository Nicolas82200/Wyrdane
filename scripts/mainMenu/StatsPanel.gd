extends RefCounted
class_name StatsPanel

# Panneau "Statistiques" du menu principal — cartes les plus jouées (taux de
# jeu + winrate, calculés côté backend sur les matchs classés uniquement, voir
# docs/backend-contracts/card-stats-and-leaderboard.md) et classement des
# joueurs par MMR. Lecture seule, même pattern statique que QuestsPanel/
# ProfilePanel. `menu._current_info_view` sert à ignorer une réponse backend
# arrivée après que le joueur a quitté la vue.

static func open(menu) -> void:
	if not BackendClient.is_authenticated():
		menu.stats_status_label.text = SettingsManager.t("STATS_UNAVAILABLE")
		menu.stats_status_label.visible = true
		return
	menu.stats_status_label.text = SettingsManager.t("PROFILE_LOADING")
	menu.stats_status_label.visible = true
	for child in menu.stats_list_vbox.get_children():
		child.queue_free()
	BackendClient.get_card_stats(func(success: bool, cards: Array):
		if menu._current_info_view != menu.InfoView.STATS:
			return
		_populate_cards(menu, cards)
	)
	BackendClient.get_leaderboard(func(success: bool, players: Array):
		if menu._current_info_view != menu.InfoView.STATS:
			return
		_populate_leaderboard(menu, players)
	)

static func _populate_cards(menu, cards: Array) -> void:
	menu.stats_status_label.visible = cards.is_empty()
	if cards.is_empty():
		menu.stats_status_label.text = SettingsManager.t("STATS_UNAVAILABLE")
	var header := Label.new()
	header.text = SettingsManager.t("STATS_TOP_CARDS_TITLE")
	header.add_theme_font_size_override("font_size", Typography.BODY)
	header.add_theme_color_override("font_color", Color(0.85, 0.72, 0.5, 0.9))
	menu.stats_list_vbox.add_child(header)
	for card in cards:
		_add_card_row(menu, card)

static func _populate_leaderboard(menu, players: Array) -> void:
	if players.is_empty():
		return
	menu.stats_list_vbox.add_child(HSeparator.new())
	var header := Label.new()
	header.text = SettingsManager.t("STATS_LEADERBOARD_TITLE")
	header.add_theme_font_size_override("font_size", Typography.BODY)
	header.add_theme_color_override("font_color", Color(0.85, 0.72, 0.5, 0.9))
	menu.stats_list_vbox.add_child(header)
	var local_name := SteamService.local_persona_name()
	for i in players.size():
		_add_leaderboard_row(menu, players[i], i + 1, local_name)

# Style à liseré coloré (façon MTGA), même petit helper que
# NewsPanel/QuestsPanel._make_accent_card_style — dupliqué plutôt qu'extrait
# dans un fichier partagé, cohérent avec la convention déjà en place ici.
const ACCENT_DIM := Color(0.42, 0.37, 0.3, 0.55)
const ACCENT_GOLD := Color(0.92, 0.72, 0.28, 0.95)

static func _make_accent_card_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.075, 0.06, 0.55)
	style.border_width_left = 3
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = accent
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	return style

static func _get_float(data: Dictionary, key: String, default: float) -> float:
	var value = data.get(key, default)
	return default if value == null else float(value)

static func _get_int(data: Dictionary, key: String, default: int) -> int:
	var value = data.get(key, default)
	return default if value == null else int(value)

static func _get_str(data: Dictionary, key: String, default: String) -> String:
	var value = data.get(key, default)
	return default if value == null else str(value)

static func _add_card_row(menu, card: Dictionary) -> void:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _make_accent_card_style(ACCENT_DIM))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 8)
	row.add_child(margin)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	var name_label := Label.new()
	name_label.text = _get_str(card, "card_name", "?")
	name_label.add_theme_font_size_override("font_size", Typography.BODY)
	name_label.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)

	var play_rate := _get_float(card, "play_rate", 0.0)
	var winrate := _get_float(card, "winrate", 0.0)
	var stats_label := Label.new()
	stats_label.text = SettingsManager.t("STATS_CARD_ROW") % [play_rate * 100.0, winrate * 100.0]
	stats_label.add_theme_font_size_override("font_size", Typography.BODY)
	stats_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72, 0.85))
	hbox.add_child(stats_label)

	menu.stats_list_vbox.add_child(row)

static func _add_leaderboard_row(menu, player: Dictionary, rank: int, local_name: String) -> void:
	var display_name := _get_str(player, "username", "?")
	var is_local := local_name != "" and display_name == local_name

	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _make_accent_card_style(ACCENT_GOLD if is_local else ACCENT_DIM))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 8)
	row.add_child(margin)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	var rank_label := Label.new()
	rank_label.text = "#%d" % rank
	rank_label.custom_minimum_size = Vector2(48, 0)
	rank_label.add_theme_font_size_override("font_size", Typography.BODY)
	rank_label.add_theme_color_override("font_color", Color(0.85, 0.72, 0.5, 0.9))
	hbox.add_child(rank_label)

	var name_label := Label.new()
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", Typography.BODY)
	name_label.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)

	var mmr_label := Label.new()
	mmr_label.text = str(_get_int(player, "mmr", 0))
	mmr_label.add_theme_font_size_override("font_size", Typography.BODY)
	mmr_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72, 0.85))
	hbox.add_child(mmr_label)

	menu.stats_list_vbox.add_child(row)
