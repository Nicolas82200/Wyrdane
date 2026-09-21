extends RefCounted
class_name StatsPanel

# Panneau "Classement" du menu principal (STATS_TITLE/MENU_STATS = "Classement"
# en jeu malgré le nom de fichier/vue) — deux sections dans la même vue :
# « Cartes les plus jouées » (taux de jeu + winrate) en haut, dans une petite
# zone de défilement bornée, et le classement des joueurs par MMR en dessous,
# qui occupe le reste de l'espace. Lecture seule, même pattern statique que
# QuestsPanel/ProfilePanel. `menu._current_info_view` sert à ignorer une
# réponse backend arrivée après que le joueur a quitté la vue.
#
# ── Classement ──────────────────────────────────────────────────────────────
# Les 4 paliers (RankTier.Type) sont des bornes de MMR contiguës : un onglet
# sélectionné demande au backend une page filtrée par ces bornes
# (BackendClient.get_leaderboard min_mmr/max_mmr). Le palier du joueur local
# est ouvert par défaut, centré sur sa propre position (route dédiée
# /leaderboard/around-me, offset calculé côté serveur) — les autres paliers
# s'ouvrent sur leur sommet (offset 0). Une recherche par pseudo peut cibler
# un joueur de n'importe quel palier : son rang global déjà renvoyé par la
# recherche sert à recalculer un offset local au palier (voir
# _load_tier_centered_on_rank) en une requête supplémentaire bon marché
# (limit=1 pour connaître le rang du sommet du palier).
# Défilement infini vers le bas uniquement (voir on_leaderboard_scrolled) :
# remonter au-delà de la page initialement chargée n'est pas supporté, c'est
# une limitation assumée (voir CLAUDE.md style de scope réduit) — rouvrir
# l'onglet ou re-rechercher/« Mon rang » recharge une page centrée fraîche.

const PAGE_SIZE := 24
const SCROLL_LOAD_THRESHOLD := 240.0

const ACCENT_DIM := Color(0.42, 0.37, 0.3, 0.55)
const ACCENT_GOLD := Color(0.92, 0.72, 0.28, 0.95)
const ROW_DIM_BG := Color(0.09, 0.075, 0.06, 0.55)
const MEDAL_TEXT_COLOR := Color(0.05, 0.05, 0.05, 1)

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
	_init_leaderboard(menu)

static func _populate_cards(menu, cards: Array) -> void:
	menu.stats_status_label.visible = cards.is_empty()
	if cards.is_empty():
		menu.stats_status_label.text = SettingsManager.t("STATS_UNAVAILABLE")
	var header := Label.new()
	header.text = SettingsManager.t("STATS_TOP_CARDS_TITLE")
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.85, 0.72, 0.5, 0.9))
	menu.stats_list_vbox.add_child(header)
	for card in cards:
		_add_card_row(menu, card)

# ── Classement : chargement ─────────────────────────────────────────────────

static func _tier_bounds(tier: int) -> Vector2i:
	match tier:
		RankTier.Type.LEGEND:
			return Vector2i(RankTier.THRESHOLDS[RankTier.Type.LEGEND], -1)
		RankTier.Type.GOLD:
			return Vector2i(RankTier.THRESHOLDS[RankTier.Type.GOLD], RankTier.THRESHOLDS[RankTier.Type.LEGEND])
		RankTier.Type.SILVER:
			return Vector2i(RankTier.THRESHOLDS[RankTier.Type.SILVER], RankTier.THRESHOLDS[RankTier.Type.GOLD])
		_:
			return Vector2i(-1, RankTier.THRESHOLDS[RankTier.Type.SILVER])

static func _set_tier_buttons_state(menu) -> void:
	menu.leaderboard_tier_bronze_button.button_pressed = menu.leaderboard_tier == RankTier.Type.BRONZE
	menu.leaderboard_tier_silver_button.button_pressed = menu.leaderboard_tier == RankTier.Type.SILVER
	menu.leaderboard_tier_gold_button.button_pressed = menu.leaderboard_tier == RankTier.Type.GOLD
	menu.leaderboard_tier_legend_button.button_pressed = menu.leaderboard_tier == RankTier.Type.LEGEND

static func _clear_leaderboard(menu) -> void:
	for c in menu.leaderboard_list_vbox.get_children():
		c.queue_free()

static func _show_leaderboard_status(menu, text: String) -> void:
	menu.leaderboard_status_label.text = text
	menu.leaderboard_status_label.visible = true

static func _init_leaderboard(menu) -> void:
	_show_leaderboard_status(menu, SettingsManager.t("PROFILE_LOADING"))
	_clear_leaderboard(menu)
	BackendClient.get_my_leaderboard_position(func(success: bool, row: Dictionary):
		if menu._current_info_view != menu.InfoView.STATS:
			return
		if success:
			menu.leaderboard_own_user_id = int(row.get("user_id", -1))
			menu.leaderboard_own_tier = RankTier.from_mmr(int(row.get("mmr", 0)))
			menu.leaderboard_tier = menu.leaderboard_own_tier
			menu.leaderboard_highlight_user_id = menu.leaderboard_own_user_id
		else:
			menu.leaderboard_own_user_id = -1
			menu.leaderboard_own_tier = -1
			menu.leaderboard_tier = RankTier.Type.BRONZE
			menu.leaderboard_highlight_user_id = -1
		_set_tier_buttons_state(menu)
		_load_current_tier(menu, success)
	)

static func _load_current_tier(menu, center_on_self: bool) -> void:
	if center_on_self:
		var bounds := _tier_bounds(menu.leaderboard_tier)
		BackendClient.get_leaderboard_around_me(PAGE_SIZE, bounds.x, bounds.y, func(success: bool, total: int, offset: int, players: Array):
			if menu._current_info_view != menu.InfoView.STATS:
				return
			if success:
				_render_leaderboard_page(menu, players, offset, total, true)
			else:
				_load_tier_top(menu, menu.leaderboard_tier)
		)
	else:
		_load_tier_top(menu, menu.leaderboard_tier)

static func _load_tier_top(menu, tier: int) -> void:
	var bounds := _tier_bounds(tier)
	BackendClient.get_leaderboard(PAGE_SIZE, 0, bounds.x, bounds.y, func(success: bool, total: int, players: Array):
		if menu._current_info_view != menu.InfoView.STATS:
			return
		if success:
			_render_leaderboard_page(menu, players, 0, total, false)
		else:
			_show_leaderboard_status(menu, SettingsManager.t("STATS_UNAVAILABLE"))
	)

static func _load_tier_centered_on_rank(menu, tier: int, target_rank: int) -> void:
	var bounds := _tier_bounds(tier)
	BackendClient.get_leaderboard(1, 0, bounds.x, bounds.y, func(success: bool, _total: int, top_players: Array):
		if menu._current_info_view != menu.InfoView.STATS:
			return
		if not success or top_players.is_empty():
			_show_leaderboard_status(menu, SettingsManager.t("STATS_UNAVAILABLE"))
			return
		var tier_top_rank := int(top_players[0].get("rank", target_rank))
		var target_offset: int = max(0, (target_rank - tier_top_rank) - int(PAGE_SIZE / 2))
		BackendClient.get_leaderboard(PAGE_SIZE, target_offset, bounds.x, bounds.y, func(success2: bool, total2: int, players: Array):
			if menu._current_info_view != menu.InfoView.STATS:
				return
			if success2:
				_render_leaderboard_page(menu, players, target_offset, total2, true)
			else:
				_show_leaderboard_status(menu, SettingsManager.t("STATS_UNAVAILABLE"))
		)
	)

# ── Classement : actions déclenchées par l'UI (onglets, recherche, "Mon rang") ──

static func select_tier(menu, tier: int) -> void:
	menu.leaderboard_tier = tier
	menu.leaderboard_highlight_user_id = menu.leaderboard_own_user_id if (tier == menu.leaderboard_own_tier and menu.leaderboard_own_user_id != -1) else -1
	_set_tier_buttons_state(menu)
	_show_leaderboard_status(menu, SettingsManager.t("PROFILE_LOADING"))
	_clear_leaderboard(menu)
	_load_current_tier(menu, menu.leaderboard_highlight_user_id == menu.leaderboard_own_user_id and menu.leaderboard_own_user_id != -1)

static func jump_to_me(menu) -> void:
	if menu.leaderboard_own_user_id == -1:
		_show_leaderboard_status(menu, SettingsManager.t("LEADERBOARD_NOT_RANKED"))
		return
	menu.leaderboard_tier = menu.leaderboard_own_tier
	menu.leaderboard_highlight_user_id = menu.leaderboard_own_user_id
	_set_tier_buttons_state(menu)
	_show_leaderboard_status(menu, SettingsManager.t("PROFILE_LOADING"))
	_clear_leaderboard(menu)
	_load_current_tier(menu, true)

static func search_player(menu) -> void:
	var query: String = menu.leaderboard_search_field.text.strip_edges()
	if query.is_empty():
		return
	_show_leaderboard_status(menu, SettingsManager.t("PROFILE_LOADING"))
	BackendClient.search_leaderboard(query, func(success: bool, results: Array):
		if menu._current_info_view != menu.InfoView.STATS:
			return
		if not success or results.is_empty():
			_show_leaderboard_status(menu, SettingsManager.t("LEADERBOARD_PLAYER_NOT_FOUND"))
			return
		var found: Dictionary = results[0]
		for r in results:
			if String(r.get("username", "")).to_lower() == query.to_lower():
				found = r
				break
		menu.leaderboard_tier = RankTier.from_mmr(int(found.get("mmr", 0)))
		menu.leaderboard_highlight_user_id = int(found.get("user_id", -1))
		var target_rank := int(found.get("rank", -1))
		_set_tier_buttons_state(menu)
		_clear_leaderboard(menu)
		if menu.leaderboard_highlight_user_id == menu.leaderboard_own_user_id and menu.leaderboard_own_user_id != -1:
			_load_current_tier(menu, true)
		else:
			_load_tier_centered_on_rank(menu, menu.leaderboard_tier, target_rank)
	)

# ── Classement : défilement infini (vers le bas uniquement) ────────────────

static func on_leaderboard_scrolled(menu) -> void:
	if menu.leaderboard_loading_more or not menu.stats_view.visible:
		return
	var bar: VScrollBar = menu.leaderboard_scroll.get_v_scroll_bar()
	if bar == null or bar.max_value <= bar.page:
		return
	var near_bottom: bool = bar.value >= bar.max_value - bar.page - SCROLL_LOAD_THRESHOLD
	if near_bottom and int(menu.leaderboard_end_offset) < int(menu.leaderboard_total):
		_load_more(menu)

static func _load_more(menu) -> void:
	menu.leaderboard_loading_more = true
	var bounds := _tier_bounds(menu.leaderboard_tier)
	var offset: int = menu.leaderboard_end_offset
	BackendClient.get_leaderboard(PAGE_SIZE, offset, bounds.x, bounds.y, func(success: bool, total: int, players: Array):
		menu.leaderboard_loading_more = false
		if menu._current_info_view != menu.InfoView.STATS or menu.leaderboard_end_offset != offset:
			return
		if not success or players.is_empty():
			return
		menu.leaderboard_total = total
		menu.leaderboard_end_offset = offset + players.size()
		for i in players.size():
			var medal_rank: int = (offset + i + 1) if offset == 0 else -1
			var row := _build_leaderboard_row(menu, players[i], medal_rank)
			menu.leaderboard_list_vbox.add_child(row)
	)

# ── Classement : rendu ───────────────────────────────────────────────────────

static func _render_leaderboard_page(menu, players: Array, offset: int, total: int, center_highlight: bool) -> void:
	_clear_leaderboard(menu)
	menu.leaderboard_total = total
	menu.leaderboard_start_offset = offset
	menu.leaderboard_end_offset = offset + players.size()
	if players.is_empty():
		_show_leaderboard_status(menu, SettingsManager.t("STATS_NO_DATA"))
		return
	_show_leaderboard_status(menu, SettingsManager.t("LEADERBOARD_TOTAL_COUNT") % total)
	var highlighted_row: Control = null
	for i in players.size():
		var medal_rank := (offset + i + 1) if offset == 0 else -1
		var row := _build_leaderboard_row(menu, players[i], medal_rank)
		menu.leaderboard_list_vbox.add_child(row)
		if int(players[i].get("user_id", -1)) == menu.leaderboard_highlight_user_id:
			highlighted_row = row
	if center_highlight and highlighted_row != null:
		_scroll_to_center(menu, highlighted_row)
	else:
		menu.leaderboard_scroll.scroll_vertical = 0

static func _scroll_to_center(menu, row: Control) -> void:
	# Le layout n'a pas encore de position/taille valides tant qu'une frame de
	# rendu ne s'est pas écoulée après l'ajout des lignes.
	await menu.get_tree().process_frame
	await menu.get_tree().process_frame
	if not is_instance_valid(row) or not is_instance_valid(menu.leaderboard_scroll):
		return
	var viewport_height: float = menu.leaderboard_scroll.size.y
	var target: float = row.position.y - viewport_height / 2.0 + row.size.y / 2.0
	menu.leaderboard_scroll.scroll_vertical = int(max(0.0, target))

static func _make_leaderboard_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style

static func _build_leaderboard_row(menu, player: Dictionary, medal_rank: int) -> Control:
	var user_id := int(player.get("user_id", -1))
	var is_highlight: bool = user_id != -1 and user_id == int(menu.leaderboard_highlight_user_id)
	var medal := medal_rank if medal_rank >= 1 and medal_rank <= 3 else 0

	var bg_color: Color
	var border_color: Color
	var border_width := 1
	var text_color := Color(0.91, 0.835, 0.639, 1)
	var stats_color := Color(0.85, 0.8, 0.72, 0.85)
	match medal:
		1:
			bg_color = RankTier.color(RankTier.Type.GOLD)
			border_color = bg_color
		2:
			bg_color = RankTier.color(RankTier.Type.SILVER)
			border_color = bg_color
		3:
			bg_color = RankTier.color(RankTier.Type.BRONZE)
			border_color = bg_color
		_:
			bg_color = ROW_DIM_BG
			border_color = ACCENT_GOLD if is_highlight else ACCENT_DIM
	if medal > 0:
		text_color = MEDAL_TEXT_COLOR
		stats_color = MEDAL_TEXT_COLOR
		if is_highlight:
			border_width = 3
	elif is_highlight:
		border_width = 3

	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _make_leaderboard_style(bg_color, border_color, border_width))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	row.add_child(margin)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	margin.add_child(hbox)

	var rank_label := Label.new()
	rank_label.text = "#%d" % int(player.get("rank", 0))
	rank_label.custom_minimum_size = Vector2(56, 0)
	rank_label.add_theme_font_size_override("font_size", 20)
	rank_label.add_theme_color_override("font_color", text_color if medal > 0 else Color(0.85, 0.72, 0.5, 0.9))
	hbox.add_child(rank_label)

	var avatar_rect := TextureRect.new()
	avatar_rect.custom_minimum_size = Vector2(48, 48)
	avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hbox.add_child(avatar_rect)
	var steam_id := str(player.get("steam_id", ""))
	if steam_id != "" and steam_id != "0":
		SteamService.request_avatar_async(steam_id, func(tex: ImageTexture):
			if is_instance_valid(avatar_rect):
				avatar_rect.texture = tex
		)

	var name_label := Label.new()
	name_label.text = str(player.get("username", "?"))
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", text_color)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)

	var stats_label := Label.new()
	stats_label.text = SettingsManager.t("LEADERBOARD_ROW_STATS") % [
		int(player.get("mmr", 0)), int(player.get("wins", 0)), int(player.get("losses", 0))
	]
	stats_label.add_theme_font_size_override("font_size", 17)
	stats_label.add_theme_color_override("font_color", stats_color)
	hbox.add_child(stats_label)

	return row

# ── Cartes les plus jouées (inchangé) ───────────────────────────────────────

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
	name_label.text = str(card.get("card_name", "?"))
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)

	var play_rate := _get_float(card, "play_rate", 0.0)
	var winrate := _get_float(card, "winrate", 0.0)
	var stats_label := Label.new()
	stats_label.text = SettingsManager.t("STATS_CARD_ROW") % [play_rate * 100.0, winrate * 100.0]
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72, 0.85))
	hbox.add_child(stats_label)

	menu.stats_list_vbox.add_child(row)
