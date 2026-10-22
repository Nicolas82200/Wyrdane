extends RefCounted
class_name FriendsPanel

# Panneau "Amis" : popup qui s'ouvre au survol de FriendsStrip (dernier enfant
# de la racine de MainMenu.tscn, donc toujours au-dessus du reste, avec un
# fond assombrissant qui bloque les clics en dessous — voir
# MainMenu._position_friends_hover_panel/_process) plutôt qu'une vue cliquable
# classique, pour rester accessible sans perdre le contexte de ce qu'on
# regardait. Système d'amis propre à Wyrdane, distinct de la liste d'amis
# Steam (overlay natif, voir SteamService.open_friends_overlay) — le badge
# Steam d'un ami est calculé ici en croisant son steam_id avec
# SteamService.is_steam_friend, aucune requête réseau supplémentaire. Les amis
# Steam ayant déjà un compte Wyrdane sont auto-ajoutés en amis acceptés avant
# même d'ouvrir ce popup (voir _sync_steam_friends) : ils apparaissent donc
# directement dans la liste ci-dessous, avatar Steam compris.

const MIN_SEARCH_LENGTH = 2

const PRESENCE_COLOR := {
	"online": Color(0.45, 0.78, 0.42, 1),
	"in_game": Color(0.85, 0.68, 0.30, 1),
	"offline": Color(0.5, 0.47, 0.42, 0.7),
}

static func open(menu) -> void:
	if menu.friends_hover_open:
		return
	AudioManager.play(AudioManager.OPEN_MENU)
	menu.friends_hover_open = true
	menu.friends_hover_overlay.visible = true
	menu._position_friends_hover_panel()
	menu.friends_search_line_edit.text = ""
	menu.friends_search_results = []
	fetch(menu)

static func close(menu) -> void:
	menu.friends_hover_open = false
	menu.friends_hover_overlay.visible = false

static func fetch(menu) -> void:
	# Synchronise d'abord les amis Steam (le backend les ajoute directement en
	# amis Wyrdane "acceptés", voir BackendClient.resolve_steam_friends —
	# demande utilisateur explicite : "je ne veux pas qu'on ait à les rajouter
	# en jeu") AVANT de charger la liste d'amis, pour qu'ils y apparaissent
	# déjà au premier rendu plutôt qu'un instant plus tard.
	# Pas de garde sur friends_hover_open ici : fetch() est aussi appelé au
	# chargement du menu (popup fermée) pour préremplir la bande d'avatars
	# collapsée (voir MainMenu._ready/render_collapsed) — seule la validité de
	# menu lui-même (scène encore en vie) importe.
	_sync_steam_friends(menu, func():
		BackendClient.get_friends(func(success: bool, friends: Array):
			if not is_instance_valid(menu):
				return
			menu.friends_cache = friends if success else []
			BackendClient.get_incoming_friend_requests(func(req_success: bool, requests: Array):
				if not is_instance_valid(menu):
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
		if not is_instance_valid(menu):
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
		if not menu.friends_hover_open:
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

	render_collapsed(menu)

# Taille d'avatar collapsée : 3x la taille d'origine (26px) — demande
# utilisateur explicite 2026-10-13.
const COLLAPSED_AVATAR_SIZE := 78.0

# Bande d'amis permanente du rail (voir MainMenu.tscn/FriendsStrip), sans
# aucun pseudo — demande utilisateur explicite : "pas les pseudo, juste les
# avatars tant qu'on n'a pas hover", et TOUS les amis visibles (pas de
# plafond, la bande défile verticalement — FriendsStripScroll). Les noms
# n'apparaissent que dans le popup déplié au survol (_make_friend_row).
static func render_collapsed(menu) -> void:
	for child in menu.friends_collapsed_avatars.get_children():
		child.queue_free()

	var shown := 0
	for friend in menu.friends_cache:
		if not friend is Dictionary:
			continue
		var steam_id: String = str(friend.get("steam_id", ""))
		if steam_id == "" or steam_id == "0":
			continue
		var avatar_rect := TextureRect.new()
		avatar_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar_rect.custom_minimum_size = Vector2(COLLAPSED_AVATAR_SIZE, COLLAPSED_AVATAR_SIZE)
		avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		menu.friends_collapsed_avatars.add_child(avatar_rect)
		SteamService.request_avatar_async(steam_id, func(tex: ImageTexture):
			if is_instance_valid(avatar_rect):
				avatar_rect.texture = tex
		)
		shown += 1

	if shown == 0:
		var placeholder := Label.new()
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		placeholder.text = "👥"
		placeholder.add_theme_font_size_override("font_size", Typography.SECTION)
		placeholder.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 0.7))
		menu.friends_collapsed_avatars.add_child(placeholder)

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
	name_label.tooltip_text = name_label.text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Sans clip_text, un pseudo long impose sa largeur au HBox et pousse les
	# boutons hors du panneau (FriendsScroll n'a pas de défilement horizontal).
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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

# Le rail de navigation ne fait qu'environ 210 px utiles : un pseudo et les
# deux boutons Accepter/Refuser sur une seule ligne débordaient du panneau
# (FriendsScroll n'a pas de défilement horizontal, le contenu trop large sort
# simplement du cadre). La ligne est donc empilée sur deux niveaux — pseudo
# au-dessus (replié sur plusieurs lignes si besoin), boutons en dessous.
static func _make_request_row(menu, req: Dictionary) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var name_label := Label.new()
	name_label.text = str(req.get("username", "?"))
	name_label.tooltip_text = name_label.text
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", Typography.BODY)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.87, 0.78, 1))
	row.add_child(name_label)

	var friendship_id := int(req.get("friendship_id", 0))

	var buttons_row := HBoxContainer.new()
	buttons_row.add_theme_constant_override("separation", 6)
	buttons_row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(buttons_row)

	var accept_button := Button.new()
	accept_button.text = SettingsManager.t("FRIENDS_ACCEPT_BUTTON")
	accept_button.add_theme_font_size_override("font_size", Typography.MICRO)
	accept_button.pressed.connect(func(): _accept_request(menu, friendship_id))
	buttons_row.add_child(accept_button)

	var decline_button := Button.new()
	decline_button.text = SettingsManager.t("FRIENDS_DECLINE_BUTTON")
	decline_button.add_theme_font_size_override("font_size", Typography.MICRO)
	decline_button.pressed.connect(func(): _remove_friendship(menu, friendship_id))
	buttons_row.add_child(decline_button)

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

	# Avatar Steam (même pattern que StatsPanel._make_leaderboard_row) : vaut
	# aussi bien pour un ami ajouté dans le jeu que pour un ami Steam auto-
	# synchronisé (voir _sync_steam_friends) — les deux ont un steam_id dans ce
	# dictionnaire, Steam ne garantissant l'avatar en cache que best-effort.
	var steam_id: String = str(friend.get("steam_id", ""))
	if steam_id != "" and steam_id != "0":
		var avatar_rect := TextureRect.new()
		avatar_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar_rect.custom_minimum_size = Vector2(36, 36)
		avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		hbox.add_child(avatar_rect)
		SteamService.request_avatar_async(steam_id, func(tex: ImageTexture):
			if is_instance_valid(avatar_rect):
				avatar_rect.texture = tex
		)

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
	name_label.tooltip_text = name_label.text
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
			_show_context_menu(menu, friendship_id, user_id, username, presence, click_area.get_global_mouse_position())
	)

	return row

# presence : voir _make_friend_row — "Inviter" est désactivé (grisé, pas juste
# ignoré au clic) si l'ami est déjà en jeu, demande utilisateur explicite
# (2026-09-25) : "qu'on puisse pas l'inviter" s'il est déjà en partie.
static func _show_context_menu(menu, friendship_id: int, user_id: int, username: String, presence: String, global_pos: Vector2) -> void:
	var popup := PopupMenu.new()
	menu.add_child(popup)
	popup.add_item(SettingsManager.t("FRIENDS_MENU_INVITE"), 0)
	popup.set_item_disabled(0, presence == "in_game")
	popup.add_item(SettingsManager.t("FRIENDS_MENU_PROFILE"), 1)
	popup.add_item(SettingsManager.t("FRIENDS_MENU_REPORT"), 2)
	popup.add_item(SettingsManager.t("FRIENDS_MENU_REMOVE"), 3)
	popup.id_pressed.connect(func(id: int):
		match id:
			0:
				close(menu)
				menu._start_friend_invite_flow(user_id, username)
			1:
				close(menu)
				menu._profile_pending_user_id = user_id
				menu._profile_pending_username = username
				menu._show_info_view(menu.InfoView.PROFILE)
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
