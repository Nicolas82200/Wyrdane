extends RefCounted
class_name FriendsPanel

# Panneau "Amis" (voir MainMenu.NavMode) : prend la place des boutons de
# navigation habituels dans NavStack plutôt que d'ouvrir une nouvelle vue dans
# InfoPanel — demande utilisateur explicite (le panneau Amis doit rester
# accessible sans perdre le contexte de ce qu'on regardait). Système d'amis
# propre à Wyrdane, distinct de la liste d'amis Steam (overlay natif, voir
# SteamService.open_friends_overlay) — le badge Steam d'un ami est calculé ici
# en croisant son steam_id avec SteamService.is_steam_friend, aucune requête
# réseau supplémentaire.

const MIN_SEARCH_LENGTH = 2

const PRESENCE_COLOR := {
	"online": Color(0.45, 0.78, 0.42, 1),
	"in_game": Color(0.85, 0.68, 0.30, 1),
	"offline": Color(0.5, 0.47, 0.42, 0.7),
}

static func open(menu) -> void:
	AudioManager.play(AudioManager.OPEN_MENU)
	menu.show_nav(menu.NavMode.FRIENDS)
	menu.friends_search_line_edit.text = ""
	menu.friends_search_results = []
	fetch(menu)

static func close(menu) -> void:
	menu.show_nav(menu.NavMode.MAIN)

static func fetch(menu) -> void:
	# Synchronise d'abord les amis Steam (le backend les ajoute directement en
	# amis Wyrdane "acceptés", voir BackendClient.resolve_steam_friends —
	# demande utilisateur explicite : "je ne veux pas qu'on ait à les rajouter
	# en jeu") AVANT de charger la liste d'amis, pour qu'ils y apparaissent
	# déjà au premier rendu plutôt qu'un instant plus tard.
	_sync_steam_friends(menu, func():
		BackendClient.get_friends(func(success: bool, friends: Array):
			if menu._nav_mode != menu.NavMode.FRIENDS:
				return
			menu.friends_cache = friends if success else []
			BackendClient.get_incoming_friend_requests(func(req_success: bool, requests: Array):
				if menu._nav_mode != menu.NavMode.FRIENDS:
					return
				menu.friend_requests_cache = requests if req_success else []
				render(menu)
			)
		)
	)

# Appel réseau évité si le joueur n'a aucun ami Steam local ou si Steam est
# indisponible (get_steam_friend_ids() renvoie [] dans les deux cas).
static func _sync_steam_friends(menu, on_done: Callable) -> void:
	var steam_ids: Array = SteamService.get_steam_friend_ids()
	if steam_ids.is_empty():
		on_done.call()
		return
	BackendClient.resolve_steam_friends(steam_ids, func(_success: bool, _results: Array):
		if menu._nav_mode != menu.NavMode.FRIENDS:
			return
		on_done.call()
	)

static func search(menu) -> void:
	var query: String = menu.friends_search_line_edit.text.strip_edges()
	if query.length() < MIN_SEARCH_LENGTH:
		menu.friends_search_results = []
		render(menu)
		return
	BackendClient.search_friends(query, func(success: bool, results: Array):
		if menu._nav_mode != menu.NavMode.FRIENDS:
			return
		menu.friends_search_results = results if success else []
		render(menu)
	)

static func render(menu) -> void:
	for child in menu.friends_body.get_children():
		child.queue_free()

	if not menu.friends_search_results.is_empty():
		_add_section_title(menu, SettingsManager.t("FRIENDS_SEARCH_RESULTS_TITLE"))
		for result in menu.friends_search_results:
			if result is Dictionary:
				menu.friends_body.add_child(_make_search_result_row(menu, result))

	if not menu.friend_requests_cache.is_empty():
		_add_section_title(menu, SettingsManager.t("FRIENDS_REQUESTS_TITLE"))
		for req in menu.friend_requests_cache:
			if req is Dictionary:
				menu.friends_body.add_child(_make_request_row(menu, req))

	_add_section_title(menu, SettingsManager.t("FRIENDS_LIST_TITLE"))
	if menu.friends_cache.is_empty():
		var empty_label := Label.new()
		empty_label.text = SettingsManager.t("FRIENDS_LIST_EMPTY")
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		empty_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.58, 0.85))
		menu.friends_body.add_child(empty_label)
	else:
		for friend in menu.friends_cache:
			if friend is Dictionary:
				menu.friends_body.add_child(_make_friend_row(menu, friend))

static func _add_section_title(menu, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", Typography.MICRO)
	label.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 0.85))
	menu.friends_body.add_child(label)

static func _make_search_result_row(menu, result: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var name_label := Label.new()
	name_label.text = str(result.get("username", "?"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", Typography.BODY)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.87, 0.78, 1))
	row.add_child(name_label)

	var add_button := Button.new()
	add_button.text = SettingsManager.t("FRIENDS_ADD_BUTTON")
	add_button.add_theme_font_size_override("font_size", Typography.MICRO)
	var target_id := int(result.get("id", 0))
	add_button.pressed.connect(func(): _send_request(menu, target_id))
	row.add_child(add_button)

	return row

static func _make_request_row(menu, req: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var name_label := Label.new()
	name_label.text = str(req.get("username", "?"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", Typography.BODY)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.87, 0.78, 1))
	row.add_child(name_label)

	var friendship_id := int(req.get("friendship_id", 0))

	var accept_button := Button.new()
	accept_button.text = SettingsManager.t("FRIENDS_ACCEPT_BUTTON")
	accept_button.add_theme_font_size_override("font_size", Typography.MICRO)
	accept_button.pressed.connect(func(): _accept_request(menu, friendship_id))
	row.add_child(accept_button)

	var decline_button := Button.new()
	decline_button.text = SettingsManager.t("FRIENDS_DECLINE_BUTTON")
	decline_button.add_theme_font_size_override("font_size", Typography.MICRO)
	decline_button.pressed.connect(func(): _remove_friendship(menu, friendship_id))
	row.add_child(decline_button)

	return row

static func _make_friend_row(menu, friend: Dictionary) -> PanelContainer:
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	# Bandeau doré/sombre transparent (demande utilisateur) : rend visible la
	# zone cliquable (ouvre le chat) sans attendre le survol.
	style.bg_color = Color(0.18, 0.14, 0.05, 0.5)
	style.border_color = Color(0.55, 0.44, 0.2, 0.4)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	row.add_theme_stylebox_override("panel", style)

	# Bouton invisible plein cadre : clic gauche = ouvrir le chat, clic droit
	# (via gui_input, les boutons ne déclenchent .pressed que sur clic gauche
	# par défaut) = menu contextuel.
	var click_area := Button.new()
	click_area.flat = true
	click_area.focus_mode = Control.FOCUS_NONE
	row.add_child(click_area)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 6)
	row.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	# Chaque Label ci-dessous doit aussi ignorer la souris : un Control
	# (Label compris) intercepte les clics par défaut (MOUSE_FILTER_STOP), donc
	# sans ceci, cliquer précisément SUR le pseudo (ou la pastille de présence,
	# l'étiquette Steam...) n'atteignait jamais click_area en dessous — seule la
	# zone "vide" de la ligne réagissait. Demande utilisateur explicite
	# (2026-09-25) : toute la zone où se trouve le pseudo doit être cliquable.
	var presence: String = str(friend.get("presence", "offline"))
	var dot := Label.new()
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.text = "●"
	dot.add_theme_color_override("font_color", PRESENCE_COLOR.get(presence, PRESENCE_COLOR["offline"]))
	hbox.add_child(dot)

	var name_col := VBoxContainer.new()
	name_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.add_theme_constant_override("separation", 0)
	hbox.add_child(name_col)

	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = str(friend.get("username", "?"))
	name_label.clip_text = true
	# Demande utilisateur explicite (2026-09-25) : agrandir les noms d'amis —
	# SECTION plutôt que BODY, seule taille de l'échelle Typography au-dessus
	# qui reste lisible sur une ligne sans écraser le reste (pastille de
	# présence, étiquette Steam) en dessous.
	name_label.add_theme_font_size_override("font_size", Typography.SECTION)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.87, 0.78, 1))
	name_col.add_child(name_label)

	var tags_row := HBoxContainer.new()
	tags_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tags_row.add_theme_constant_override("separation", 4)
	name_col.add_child(tags_row)

	var presence_key := "FRIENDS_PRESENCE_" + presence.to_upper()
	var presence_label := Label.new()
	presence_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	presence_label.text = SettingsManager.t(presence_key)
	presence_label.add_theme_font_size_override("font_size", Typography.MICRO)
	presence_label.add_theme_color_override("font_color", PRESENCE_COLOR.get(presence, PRESENCE_COLOR["offline"]))
	tags_row.add_child(presence_label)

	var steam_id: String = str(friend.get("steam_id", ""))
	if steam_id != "" and SteamService.is_steam_friend(steam_id):
		var steam_tag := Label.new()
		steam_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		steam_tag.text = SettingsManager.t("FRIENDS_TAG_STEAM")
		steam_tag.add_theme_font_size_override("font_size", Typography.MICRO)
		steam_tag.add_theme_color_override("font_color", Color(0.35, 0.62, 0.85, 1))
		tags_row.add_child(steam_tag)

	var friendship_id := int(friend.get("friendship_id", 0))
	var user_id := int(friend.get("id", 0))
	var username := str(friend.get("username", "?"))

	click_area.pressed.connect(func():
		menu._show_info_view(menu.InfoView.CHAT)
		ChatPanel.open_for_friend(menu, user_id, username))
	click_area.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_show_context_menu(menu, friendship_id, user_id, username, click_area.get_global_mouse_position())
	)

	return row

static func _show_context_menu(menu, friendship_id: int, user_id: int, username: String, global_pos: Vector2) -> void:
	var popup := PopupMenu.new()
	menu.add_child(popup)
	popup.add_item(SettingsManager.t("FRIENDS_MENU_INVITE"), 0)
	popup.add_item(SettingsManager.t("FRIENDS_MENU_PROFILE"), 1)
	popup.add_item(SettingsManager.t("FRIENDS_MENU_REPORT"), 2)
	popup.add_item(SettingsManager.t("FRIENDS_MENU_REMOVE"), 3)
	popup.id_pressed.connect(func(id: int):
		match id:
			0:
				close(menu)
				menu._show_info_view(menu.InfoView.MODE_SELECT)
			1:
				close(menu)
				menu._show_info_view(menu.InfoView.STATS)
				menu.leaderboard_search_field.text = username
				StatsPanel.search_player(menu)
			2:
				BackendClient.report_issue("cheating", SettingsManager.t("FRIENDS_REPORT_DEFAULT_DESCRIPTION") % username, user_id)
			3:
				_remove_friendship(menu, friendship_id)
		popup.queue_free()
	)
	popup.popup_hide.connect(popup.queue_free)
	popup.position = Vector2i(global_pos)
	popup.popup()

static func _send_request(menu, target_user_id: int) -> void:
	BackendClient.send_friend_request(target_user_id, func(_success: bool, _status: String):
		menu.friends_search_line_edit.text = ""
		menu.friends_search_results = []
		fetch(menu)
	)

static func _accept_request(menu, friendship_id: int) -> void:
	BackendClient.accept_friend_request(friendship_id, func(_code: int, _parsed):
		fetch(menu)
	)

static func _remove_friendship(menu, friendship_id: int) -> void:
	BackendClient.remove_friendship(friendship_id, func(_code: int, _parsed):
		fetch(menu)
	)
