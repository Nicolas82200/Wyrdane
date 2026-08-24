extends RefCounted
class_name NewsPanel

# Panneau d'actualités du menu principal — extrait de MainMenu.gd. Charge les
# devlogs/actus créées sur le site (wyrdane.com) via NEWS_FEED_URL (généré par
# le site à chaque déploiement depuis src/content/news + src/content/devlog —
# voir son scripts/generate-feed.mjs). Les ressources locales
# (res://resources/news/*.tres) ne servent plus que de repli si le site est
# injoignable (même logique de dégradation que CollectionManager/CurrencyManager).

static func load_news(menu) -> void:
	_load_local_news(menu)
	_fetch_remote_news(menu)

static func _load_local_news(menu) -> void:
	menu._local_news_entries.clear()
	var dir := DirAccess.open(menu.NEWS_DIR)
	if dir == null:
		push_warning("Dossier d'actualités introuvable : %s" % menu.NEWS_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var entry := load(menu.NEWS_DIR + file_name) as NewsEntry
			if entry:
				menu._local_news_entries.append(entry)
		file_name = dir.get_next()
	dir.list_dir_end()
	menu._local_news_entries.sort_custom(func(a: NewsEntry, b: NewsEntry): return a.date > b.date)
	_populate_news(menu)

static func _fetch_remote_news(menu) -> void:
	var http := HTTPRequest.new()
	menu.add_child(http)
	http.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
			push_warning("Impossible de récupérer les actualités du site (résultat %d, code %d)" % [result, response_code])
			return
		var parsed = JSON.parse_string(body.get_string_from_utf8())
		if typeof(parsed) != TYPE_ARRAY:
			push_warning("Format de flux d'actualités invalide")
			return
		menu._remote_news_entries = parsed
		menu._use_remote_news = true
		_populate_news(menu)
	)
	var err := http.request(menu.NEWS_FEED_URL)
	if err != OK:
		push_warning("Échec de la requête d'actualités : %d" % err)
		http.queue_free()

static func _populate_news(menu) -> void:
	for child in menu.news_list_vbox.get_children():
		child.queue_free()
	if menu._use_remote_news:
		for i in menu._remote_news_entries.size():
			var entry: Dictionary = menu._remote_news_entries[i]
			var title: String = entry.get("title", {}).get(SettingsManager.language, entry.get("title", {}).get("fr", ""))
			var body: String = entry.get("body", {}).get(SettingsManager.language, entry.get("body", {}).get("fr", ""))
			_add_news_item(menu, entry.get("date", ""), title, body, entry.get("kind", "news"), i == 0)
	else:
		for i in menu._local_news_entries.size():
			var entry: NewsEntry = menu._local_news_entries[i]
			_add_news_item(menu, entry.date, entry.display_title(), entry.display_body(), "news", i == 0)

# Style de carte à liseré coloré (façon MTGA), partagé avec QuestsPanel (même
# petit helper dupliqué là-bas plutôt qu'extrait dans un 3e fichier — les deux
# seuls appelants, pas de raison de fusionner davantage).
const ACCENT_EMBER := Color(0.72, 0.48, 0.19, 0.85)
const ACCENT_ARCANE := Color(0.47, 0.56, 0.84, 0.85)

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

# Le corps d'une entrée est tronqué côté site (voir generate-feed.mjs,
# MAX_BODY_LENGTH) : le lien "voir les détails" renvoie vers la page dédiée
# du site (actus ou devlog selon "kind") pour lire le texte complet.
# `is_featured` marque la toute première entrée (la plus récente) d'un liseré
# arcane distinct, pour qu'elle ressorte visuellement du reste de la liste.
static func _add_news_item(menu, date: String, title: String, body: String, kind: String, is_featured: bool = false) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _make_accent_card_style(ACCENT_ARCANE if is_featured else ACCENT_EMBER))
	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 14)
	card_margin.add_theme_constant_override("margin_top", 10)
	card_margin.add_theme_constant_override("margin_right", 14)
	card_margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(card_margin)

	var item := VBoxContainer.new()
	item.add_theme_constant_override("separation", 4)
	card_margin.add_child(item)

	var date_label := Label.new()
	date_label.text = date
	date_label.add_theme_font_size_override("font_size", 13)
	date_label.add_theme_color_override("font_color", ACCENT_ARCANE if is_featured else Color(0.91, 0.835, 0.639, 0.55))
	item.add_child(date_label)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	item.add_child(title_label)

	var body_label := Label.new()
	body_label.text = body
	body_label.add_theme_font_size_override("font_size", 15)
	body_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72, 0.9))
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	item.add_child(body_label)

	var read_more := LinkButton.new()
	read_more.text = SettingsManager.t("MENU_NEWS_READ_MORE")
	read_more.add_theme_font_size_override("font_size", 13)
	read_more.add_theme_color_override("font_color", Color(0.85, 0.65, 0.25, 1))
	var path: String = menu.WEBSITE_DEVLOG_PATH if kind == "devlog" else menu.WEBSITE_NEWS_PATH
	read_more.pressed.connect(func(): OS.shell_open(menu.WEBSITE_URL + path))
	item.add_child(read_more)

	menu.news_list_vbox.add_child(card)
