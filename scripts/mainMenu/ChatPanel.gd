extends RefCounted
class_name ChatPanel

# Chat privé entre amis (voir CLAUDE.md côté wyrdane-backend « Système d'amis
# Wyrdane + chat ») — vue du panneau principal comme Profil/Boutique/Quêtes
# (voir MainMenu.tscn ChatView, InfoView.CHAT), pas un popup flottant : le
# bouton Retour repasse par _show_info_view comme les autres vues. Polling HTTP
# (décision utilisateur, pas de WebSocket) : POLL_INTERVAL_SECONDS tant que
# cette vue est affichée (voir _poll, qui se coupe de lui-même sinon).

const POLL_INTERVAL_SECONDS := 4.0

static func open_inbox(menu) -> void:
	_ensure_poll_timer(menu)
	menu.chat_thread_friend_id = 0
	menu.chat_thread_friend_name = ""
	menu.chat_thread_messages = []
	menu.chat_conversations_cache = []
	_update_send_button(menu)
	_refresh_conversations(menu)
	_render_thread(menu)

static func open_for_friend(menu, friend_id: int, friend_username: String) -> void:
	_ensure_poll_timer(menu)
	menu.chat_thread_friend_id = friend_id
	menu.chat_thread_friend_name = friend_username
	menu.chat_thread_messages = []
	_refresh_conversations(menu)
	_open_thread(menu, friend_id, friend_username)

static func send(menu) -> void:
	var body: String = menu.chat_input_line_edit.text.strip_edges()
	var friend_id: int = menu.chat_thread_friend_id
	if body == "" or friend_id <= 0:
		return
	menu.chat_input_line_edit.editable = false
	BackendClient.send_message(friend_id, body, func(success: bool, message: Dictionary):
		menu.chat_input_line_edit.editable = true
		if not success:
			return
		menu.chat_input_line_edit.text = ""
		# chat_thread_messages suit la convention backend (le plus récent en
		# tête, voir _render_thread) : insérer en tête, pas append, sinon le
		# message tout juste envoyé se retrouve traité comme le plus ancien et
		# s'affiche en haut du fil au lieu du bas.
		menu.chat_thread_messages.insert(0, message)
		_render_thread(menu)
		_refresh_conversations(menu)
	)

static func refresh_unread_badge(menu) -> void:
	BackendClient.get_unread_message_total(func(total: int):
		menu.chat_badge.visible = total > 0
		menu.chat_badge_label.text = str(min(total, 99))
	)

# --- Interne ------------------------------------------------------------

static func _ensure_poll_timer(menu) -> void:
	if menu.has_meta("chat_poll_timer"):
		var existing: Timer = menu.get_meta("chat_poll_timer")
		if is_instance_valid(existing):
			existing.start()
			return
	var timer := Timer.new()
	timer.wait_time = POLL_INTERVAL_SECONDS
	timer.autostart = true
	timer.timeout.connect(func(): _poll(menu))
	menu.add_child(timer)
	menu.set_meta("chat_poll_timer", timer)

static func _poll(menu) -> void:
	if menu._current_info_view != menu.InfoView.CHAT:
		return
	refresh_unread_badge(menu)
	_refresh_conversations(menu)
	var friend_id: int = menu.chat_thread_friend_id
	if friend_id > 0:
		BackendClient.get_conversation(friend_id, 50, 0, func(success: bool, messages: Array):
			if not success or menu.get("chat_thread_friend_id") != friend_id:
				return
			# Le backend renvoie le plus récent en tête (voir messageModel.
			# getConversation) : comparer la taille suffit à détecter une
			# nouveauté sans reconstruire un diff message par message.
			if messages.size() != menu.chat_thread_messages.size():
				menu.chat_thread_messages = messages
				_render_thread(menu)
				BackendClient.mark_conversation_read(friend_id)
		)

static func _open_thread(menu, friend_id: int, friend_username: String) -> void:
	menu.chat_thread_friend_id = friend_id
	menu.chat_thread_friend_name = friend_username
	_update_send_button(menu)
	BackendClient.get_conversation(friend_id, 50, 0, func(success: bool, messages: Array):
		if menu.chat_thread_friend_id != friend_id:
			return
		menu.chat_thread_messages = messages if success else []
		_render_thread(menu)
		BackendClient.mark_conversation_read(friend_id)
		refresh_unread_badge(menu)
	)

# Grisé tant qu'aucune conversation n'est sélectionnée (ouverture via le
# bouton Chat général sans conversation existante, voir _render_conversations)
# — send() est déjà protégé (friend_id <= 0), mais un bouton actif sans rien
# à faire est trompeur pour le joueur.
static func _update_send_button(menu) -> void:
	menu.chat_send_button.disabled = menu.chat_thread_friend_id <= 0

static func _refresh_conversations(menu) -> void:
	BackendClient.get_conversations(func(success: bool, conversations: Array):
		menu.chat_conversations_cache = conversations if success else []
		_render_conversations(menu)
	)

static func _render_conversations(menu) -> void:
	for child in menu.chat_conversations_list.get_children():
		child.queue_free()
	if menu.chat_conversations_cache.is_empty():
		var empty_label := Label.new()
		empty_label.text = SettingsManager.t("CHAT_NO_CONVERSATIONS")
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		empty_label.add_theme_font_size_override("font_size", Typography.MICRO)
		empty_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.58, 0.85))
		menu.chat_conversations_list.add_child(empty_label)
		return
	for convo in menu.chat_conversations_cache:
		if not (convo is Dictionary):
			continue
		menu.chat_conversations_list.add_child(_make_conversation_row(menu, convo))
	# Aucune conversation encore sélectionnée (ouverture via le bouton Chat
	# général, pas via le clic sur un ami précis) : ouvrir la plus récente par
	# défaut plutôt que de laisser le volet de droite vide.
	if menu.chat_thread_friend_id == 0 and not menu.chat_conversations_cache.is_empty():
		var first: Dictionary = menu.chat_conversations_cache[0]
		_open_thread(menu, int(first.get("partner_id", 0)), str(first.get("username", "?")))

static func _make_conversation_row(menu, convo: Dictionary) -> Button:
	var partner_id := int(convo.get("partner_id", 0))
	var username := str(convo.get("username", "?"))
	var unread := int(convo.get("unread_count", 0))

	var is_selected: bool = partner_id == menu.chat_thread_friend_id

	var row := Button.new()
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_theme_font_size_override("font_size", Typography.MICRO)
	row.add_theme_constant_override("h_separation", 0)
	row.text = "%s  (%d)" % [username, unread] if unread > 0 else username
	if is_selected:
		row.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	else:
		row.add_theme_color_override("font_color", Color(0.72, 0.66, 0.56, 0.85))

	# Bandeau doré/sombre transparent (demande utilisateur), même traitement
	# que les lignes d'amis (FriendsPanel._make_friend_row) : rend visible la
	# zone cliquable de chaque conversation sans attendre le survol. La
	# conversation sélectionnée ressort avec un fond plus clair, en plus de la
	# couleur de texte dorée déjà utilisée ci-dessus.
	var normal_style := StyleBoxFlat.new()
	# La conversation ouverte garde l'habillage doré habituel ; les autres sont
	# nettement assombries (demande utilisateur) pour qu'on repère d'un coup
	# d'œil avec qui on discute — c'est désormais le seul endroit qui porte le
	# nom de l'interlocuteur, l'en-tête du fil ne l'affiche plus.
	normal_style.bg_color = Color(0.30, 0.24, 0.10, 0.65) if is_selected else Color(0.07, 0.055, 0.02, 0.55)
	normal_style.border_color = Color(0.55, 0.44, 0.2, 0.4) if is_selected else Color(0.3, 0.24, 0.11, 0.35)
	normal_style.border_width_left = 1
	normal_style.border_width_top = 1
	normal_style.border_width_right = 1
	normal_style.border_width_bottom = 1
	normal_style.corner_radius_top_left = 4
	normal_style.corner_radius_top_right = 4
	normal_style.corner_radius_bottom_right = 4
	normal_style.corner_radius_bottom_left = 4
	normal_style.content_margin_left = 8
	normal_style.content_margin_right = 8
	normal_style.content_margin_top = 5
	normal_style.content_margin_bottom = 5
	var hover_style: StyleBoxFlat = normal_style.duplicate()
	hover_style.bg_color = Color(0.36, 0.29, 0.13, 0.7) if is_selected else Color(0.14, 0.11, 0.04, 0.6)
	row.add_theme_stylebox_override("normal", normal_style)
	row.add_theme_stylebox_override("hover", hover_style)
	row.add_theme_stylebox_override("pressed", hover_style)
	row.add_theme_stylebox_override("focus", normal_style)

	row.pressed.connect(func(): _open_thread(menu, partner_id, username))
	return row

static func _render_thread(menu) -> void:
	for child in menu.chat_thread_list.get_children():
		child.queue_free()
	if menu.chat_thread_friend_id == 0:
		return
	# Le backend renvoie le plus récent en tête (voir messageModel.getConversation) —
	# on réaffiche dans l'ordre chronologique.
	var ordered: Array = menu.chat_thread_messages.duplicate()
	ordered.reverse()
	# Les messages sont regroupés par jour : dès que la date locale change, un
	# séparateur en italique (« 26 septembre ») est inséré avant la bulle
	# suivante, pour situer un fil étalé sur plusieurs jours.
	var last_day := ""
	for message in ordered:
		if not (message is Dictionary):
			continue
		var stamp: Dictionary = _local_datetime(str(message.get("created_at", "")))
		if not stamp.is_empty():
			var day_key := "%04d-%02d-%02d" % [int(stamp["year"]), int(stamp["month"]), int(stamp["day"])]
			if day_key != last_day:
				last_day = day_key
				menu.chat_thread_list.add_child(_make_day_separator(stamp))
		menu.chat_thread_list.add_child(_make_message_bubble(message, stamp))
	_scroll_to_latest(menu)


# Ouvre toujours le fil sur le message le plus récent (demande utilisateur).
# Un simple call_deferred("set", "scroll_vertical", ...) ne suffisait pas : à ce
# moment-là les bulles tout juste ajoutées n'ont pas encore de taille, donc la
# barre de défilement a toujours son ancien max_value et la valeur demandée est
# clampée dessus — le fil s'ouvrait au milieu. On attend donc deux frames (la
# première pour le recalcul de layout des conteneurs, la seconde pour que la
# barre ait pris sa nouvelle étendue) avant de descendre tout en bas.
static func _scroll_to_latest(menu) -> void:
	var scroll: ScrollContainer = menu.chat_thread_scroll
	if not is_instance_valid(scroll):
		return
	var tree: SceneTree = scroll.get_tree()
	if tree == null:
		return
	await tree.process_frame
	await tree.process_frame
	if not is_instance_valid(scroll):
		return
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


# created_at arrive en UTC ISO 8601 depuis le backend (colonne DATETIME MySQL
# sérialisée en JSON par mysql2, ex. "2026-09-26T14:32:11.000Z") : on le ramène
# à l'heure locale du joueur avant tout affichage. Dictionnaire vide si la date
# est absente ou illisible — l'appelant n'affiche alors ni heure ni séparateur
# de jour plutôt qu'une date inventée.
static func _local_datetime(raw: String) -> Dictionary:
	var normalized := raw.strip_edges()
	if normalized == "":
		return {}
	normalized = normalized.replace(" ", "T")
	if normalized.ends_with("Z"):
		normalized = normalized.left(normalized.length() - 1)
	var dot := normalized.find(".")
	if dot != -1:
		normalized = normalized.left(dot)
	# Contrôle de forme avant de parser : Time.get_unix_time_from_datetime_string
	# pousse une erreur moteur dans le log sur une chaîne qui n'est pas une date,
	# alors qu'ici un champ vide ou abîmé est un cas normal à ignorer.
	var date_part := normalized.get_slice("T", 0)
	var pieces := date_part.split("-")
	if pieces.size() != 3:
		return {}
	for piece in pieces:
		if not piece.is_valid_int():
			return {}
	var unix := int(Time.get_unix_time_from_datetime_string(normalized))
	if unix <= 0:
		return {}
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return Time.get_datetime_dict_from_unix_time(unix + bias)


static func _format_time(stamp: Dictionary) -> String:
	if stamp.is_empty():
		return ""
	return "%02d:%02d" % [int(stamp["hour"]), int(stamp["minute"])]


static func _format_day(stamp: Dictionary) -> String:
	var month: String = SettingsManager.t("MONTH_%d" % int(stamp["month"]))
	var day := str(int(stamp["day"]))
	var year := int(stamp["year"])
	# L'année n'est affichée que si elle diffère de l'année en cours — inutile
	# de la répéter sur chaque séparateur d'une conversation récente.
	if year == int(Time.get_datetime_dict_from_system().get("year", year)):
		return SettingsManager.t("CHAT_DAY_FORMAT").format({"day": day, "month": month})
	return SettingsManager.t("CHAT_DAY_FORMAT_YEAR").format({
		"day": day, "month": month, "year": str(year)
	})


static func _make_day_separator(stamp: Dictionary) -> Label:
	var label := Label.new()
	label.text = _format_day(stamp)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", Typography.MICRO)
	label.add_theme_color_override("font_color", Color(0.72, 0.66, 0.56, 0.8))
	# Italique synthétique : le projet n'embarque pas de fonte italique, donc on
	# incline la fonte de base via FontVariation (skew positif = penché vers la
	# droite, cf. Transform2D(rotation, échelle, skew, position)).
	var italic := FontVariation.new()
	italic.base_font = ThemeDB.fallback_font
	italic.variation_transform = Transform2D(0.0, Vector2.ONE, deg_to_rad(12.0), Vector2.ZERO)
	label.add_theme_font_override("font", italic)
	return label

# Largeur max d'une bulle — un Label en AUTOWRAP_WORD renvoie une largeur
# minimale de 0 par conception Godot (le wrap est censé être contraint par le
# rect reçu du parent, pas déduit du texte) : placé dans un conteneur qui se
# resserre sur son contenu (SIZE_SHRINK_BEGIN/END, pour aligner la bulle à
# gauche/droite selon l'expéditeur), il s'effondrait donc à une largeur quasi
# nulle — texte replié caractère par caractère et dessiné hors des bornes du
# panneau (Label ne s'auto-clippe pas). Fix : mesurer la largeur naturelle du
# texte sur une seule ligne et la donner explicitement comme largeur minimale
# du Label (chose que AUTOWRAP ne fait jamais tout seul), plafonnée à ceci
# pour que les messages longs retombent correctement à la ligne.
const BUBBLE_MAX_WIDTH := 260.0

static func _make_message_bubble(message: Dictionary, stamp: Dictionary = {}) -> PanelContainer:
	var is_mine: bool = int(message.get("sender_id", -1)) == BackendClient.local_user_id()
	var body: String = str(message.get("body", ""))

	var wrapper := PanelContainer.new()
	var style := StyleBoxFlat.new()
	# Bulle dorée plus sombre pour l'interlocuteur, pour rester dans la charte
	# dorée du jeu plutôt qu'un gris/noir neutre (demande utilisateur).
	style.bg_color = Color(0.35, 0.28, 0.14, 0.6) if is_mine else Color(0.16, 0.12, 0.04, 0.75)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	wrapper.add_theme_stylebox_override("panel", style)
	wrapper.size_flags_horizontal = Control.SIZE_SHRINK_END if is_mine else Control.SIZE_SHRINK_BEGIN

	var label := Label.new()
	label.text = body
	var font: Font = ThemeDB.fallback_font
	var font_size: int = Typography.SECTION
	var natural_width: float = font.get_string_size(body, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	label.custom_minimum_size = Vector2(min(natural_width + 4.0, BUBBLE_MAX_WIDTH), 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.9, 0.87, 0.78, 1))

	# L'heure se place du côté extérieur de la bulle (demande utilisateur) :
	# « hh:mm message » pour un message reçu, « message hh:mm » pour un envoyé.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var time_text := _format_time(stamp)
	if time_text != "" and not is_mine:
		row.add_child(_make_time_label(time_text))
	row.add_child(label)
	if time_text != "" and is_mine:
		row.add_child(_make_time_label(time_text))
	wrapper.add_child(row)

	return wrapper


static func _make_time_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.add_theme_font_size_override("font_size", Typography.MICRO)
	label.add_theme_color_override("font_color", Color(0.78, 0.73, 0.63, 0.7))
	return label
