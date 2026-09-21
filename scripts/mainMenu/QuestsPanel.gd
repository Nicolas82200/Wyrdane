extends RefCounted
class_name QuestsPanel

# Panneau des quêtes du menu principal — extrait de MainMenu.gd.
# `menu._current_info_view`/`menu.InfoView` servent à ignorer une réponse
# backend arrivée après que le joueur a quitté la vue Quêtes.
#
# Deux onglets (menu.QuestTab, boutons QuestsRegularTabButton/
# QuestsUniqueTabButton dans MainMenu.tscn) : "Quêtes" regroupe quotidienne/
# hebdo/mensuelle (fréquentes, reset périodique), "Uniques" isole les jalons
# de carrière (jamais reset, liste potentiellement longue) — mélanger les
# deux dans une seule liste rendait la vue difficile à parcourir une fois les
# quêtes mensuelles ajoutées. Les quatre catégories sont toujours chargées
# ensemble (menu._quests_cache, une entrée par catégorie) : changer d'onglet
# ne fait que reconstruire l'affichage depuis ce cache, sans refetch — seul
# `open()` (ouverture de la vue, changement de langue) refetch réellement.

static func open(menu) -> void:
	if not BackendClient.is_authenticated():
		menu.quests_status_label.text = SettingsManager.t("QUESTS_UNAVAILABLE")
		menu.quests_status_label.visible = true
		return
	menu.quests_status_label.text = SettingsManager.t("PROFILE_LOADING")
	menu.quests_status_label.visible = true
	for child in menu.quests_list_vbox.get_children():
		child.queue_free()
	menu._quests_cache = {}
	BackendClient.get_daily_quests(func(success: bool, data: Dictionary):
		if menu._current_info_view != menu.InfoView.QUESTS:
			return
		if not success:
			menu.quests_status_label.text = SettingsManager.t("QUESTS_UNAVAILABLE")
			return
		_store_and_render(menu, "daily", data.get("quests", []))
	)
	# Les trois autres catégories sont chargées séparément (échec silencieux,
	# la quotidienne suffit à couvrir l'état d'erreur global de la vue).
	BackendClient.get_weekly_quests(func(success: bool, data: Dictionary):
		if menu._current_info_view != menu.InfoView.QUESTS or not success:
			return
		_store_and_render(menu, "weekly", data.get("quests", []))
	)
	BackendClient.get_monthly_quests(func(success: bool, data: Dictionary):
		if menu._current_info_view != menu.InfoView.QUESTS or not success:
			return
		_store_and_render(menu, "monthly", data.get("quests", []))
	)
	BackendClient.get_unique_quests(func(success: bool, data: Dictionary):
		if menu._current_info_view != menu.InfoView.QUESTS or not success:
			return
		_store_and_render(menu, "unique", data.get("quests", []))
	)

static func _store_and_render(menu, kind: String, quests: Array) -> void:
	menu._quests_cache[kind] = quests
	menu._update_quests_badge(quests, kind)
	render(menu)

# Reconstruit la liste affichée depuis le cache selon l'onglet actif — appelé
# après chaque réponse backend (open) et à chaque changement d'onglet
# (MainMenu._select_quest_tab), jamais de refetch pour ce second cas.
static func render(menu) -> void:
	for child in menu.quests_list_vbox.get_children():
		child.queue_free()
	var cache: Dictionary = menu._quests_cache
	if menu._quest_tab == menu.QuestTab.UNIQUE:
		_render_unique(menu, cache.get("unique", []))
	else:
		_render_regular(menu, cache.get("daily", []), cache.get("weekly", []), cache.get("monthly", []))

static func _render_regular(menu, daily: Array, weekly: Array, monthly: Array) -> void:
	var has_any := not daily.is_empty() or not weekly.is_empty() or not monthly.is_empty()
	menu.quests_status_label.visible = not has_any
	if not has_any:
		menu.quests_status_label.text = SettingsManager.t("QUESTS_UNAVAILABLE")
	for quest in daily:
		_add_item(menu, quest)
	if not weekly.is_empty():
		_add_section_header(menu, "QUESTS_WEEKLY_TITLE")
		for quest in weekly:
			_add_item(menu, quest, "weekly")
	if not monthly.is_empty():
		_add_section_header(menu, "QUESTS_MONTHLY_TITLE")
		for quest in monthly:
			_add_item(menu, quest, "monthly")

# Toujours le catalogue entier (pas de rotation/reset côté backend, voir
# uniqueQuestModel.ts), donc potentiellement une longue liste — pas d'en-tête
# de section ici, l'onglet lui-même sert de titre.
static func _render_unique(menu, quests: Array) -> void:
	menu.quests_status_label.visible = quests.is_empty()
	if quests.is_empty():
		menu.quests_status_label.text = SettingsManager.t("QUESTS_UNAVAILABLE")
	for quest in quests:
		_add_item(menu, quest, "unique")

static func _add_section_header(menu, translation_key: String) -> void:
	var header := Label.new()
	header.text = SettingsManager.t(translation_key)
	header.add_theme_font_size_override("font_size", Typography.BODY)
	header.add_theme_color_override("font_color", Color(0.85, 0.72, 0.5, 0.9))
	menu.quests_list_vbox.add_child(HSeparator.new())
	menu.quests_list_vbox.add_child(header)

# Style de carte à liseré coloré (façon MTGA), même petit helper que
# NewsPanel._make_accent_card_style (dupliqué plutôt qu'extrait dans un 3e
# fichier partagé — seulement deux appelants).
const ACCENT_EMBER := Color(0.72, 0.48, 0.19, 0.85)
const ACCENT_DIM := Color(0.42, 0.37, 0.3, 0.55)
const ACCENT_GOLD := Color(0.92, 0.72, 0.28, 0.95)

# Placeholder en attendant les vraies icônes de récompense (or/pack) — carré
# marron foncé à remplacer par une TextureRect une fois les images
# disponibles (voir _add_item).
const REWARD_ICON_COLOR := Color(0.22, 0.13, 0.07, 1)
const REWARD_ICON_SIZE := 36

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

# Le backend peut renvoyer une clé présente avec une valeur JSON `null`
# explicite (ex. champ optionnel non renseigné) plutôt que d'omettre la clé :
# Dictionary.get() ne retombe alors PAS sur son défaut dans ce cas, et
# int(null) plante ("Invalid call. Nonexistent 'int' constructor.").
static func _get_int(quest: Dictionary, key: String, default: int) -> int:
	var value = quest.get(key, default)
	return default if value == null else int(value)

# JSON.parse_string() désérialise TOUS les nombres JSON en float (jamais en
# int) : le constructeur String(float) n'existe pas en GDScript et plante
# ("Invalid call. Nonexistent 'String' constructor.") — contrairement à
# str(), qui accepte n'importe quel type. Utiliser str() ici, jamais String().
static func _get_str(quest: Dictionary, key: String, default: String) -> String:
	var value = quest.get(key, default)
	return default if value == null else str(value)

static func _add_item(menu, quest: Dictionary, kind: String = "daily") -> void:
	var progress := _get_int(quest, "progress", 0)
	var target := _get_int(quest, "target", 1)
	var claimed := bool(quest.get("claimed", false))
	var completed := progress >= target

	var row := PanelContainer.new()
	var quest_accent := ACCENT_DIM
	if completed and not claimed:
		quest_accent = ACCENT_GOLD
	elif not completed:
		quest_accent = ACCENT_EMBER
	row.add_theme_stylebox_override("panel", _make_accent_card_style(quest_accent))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	row.add_child(margin)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(REWARD_ICON_SIZE, REWARD_ICON_SIZE)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.color = REWARD_ICON_COLOR
	hbox.add_child(icon)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(text_col)

	var desc_label := Label.new()
	desc_label.text = SettingsManager.t(_get_str(quest, "description_key", ""))
	desc_label.add_theme_font_size_override("font_size", Typography.BODY)
	desc_label.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_col.add_child(desc_label)

	var progress_label := Label.new()
	match kind:
		"weekly":
			var reward_pack := _get_int(quest, "reward_pack", 0)
			progress_label.text = SettingsManager.t("QUESTS_WEEKLY_PROGRESS") % [progress, target, reward_pack]
		"monthly":
			var reward_currency_monthly := _get_int(quest, "reward_currency", 0)
			var reward_pack_monthly := _get_int(quest, "reward_pack", 0)
			progress_label.text = SettingsManager.t("QUESTS_MONTHLY_PROGRESS") % [progress, target, reward_currency_monthly, reward_pack_monthly]
		"unique":
			var reward_currency := _get_int(quest, "reward_currency", 0)
			var reward_pack_unique := _get_int(quest, "reward_pack", 0)
			progress_label.text = SettingsManager.t("QUESTS_UNIQUE_PROGRESS") % [progress, target, reward_currency, reward_pack_unique]
		_:
			var reward := _get_int(quest, "reward_currency", 0)
			progress_label.text = SettingsManager.t("QUESTS_PROGRESS") % [progress, target, reward]
	progress_label.add_theme_font_size_override("font_size", Typography.BODY)
	progress_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72, 0.85))
	text_col.add_child(progress_label)

	var action_button := Button.new()
	action_button.custom_minimum_size = Vector2(140, 40)
	action_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if claimed:
		action_button.text = SettingsManager.t("QUESTS_CLAIMED")
		action_button.disabled = true
	elif completed:
		action_button.text = SettingsManager.t("QUESTS_CLAIM")
		var quest_id := _get_int(quest, "id", 0)
		match kind:
			"weekly":
				action_button.pressed.connect(_on_claim_weekly_pressed.bind(menu, str(quest_id), action_button))
			"monthly":
				action_button.pressed.connect(_on_claim_monthly_pressed.bind(menu, quest_id, action_button))
			"unique":
				action_button.pressed.connect(_on_claim_unique_pressed.bind(menu, quest_id, action_button))
			_:
				action_button.pressed.connect(_on_claim_pressed.bind(menu, quest_id, action_button))
	else:
		action_button.text = SettingsManager.t("QUESTS_IN_PROGRESS")
		action_button.disabled = true
	hbox.add_child(action_button)

	menu.quests_list_vbox.add_child(row)

# Marque la quête réclamée dans le cache (menu._quests_cache), sans quoi un
# changement d'onglet après réclamation la réafficherait comme non réclamée
# (render() reconstruit toujours la liste depuis ce cache, jamais depuis le
# DOM affiché).
static func _mark_claimed_in_cache(menu, kind: String, quest_id) -> void:
	for quest in menu._quests_cache.get(kind, []):
		if str(quest.get("id", -1)) == str(quest_id):
			quest["claimed"] = true
			return

# Les quatre types de quête (quotidienne/hebdo/mensuelle/unique) partagent la
# même réaction de réclamation, seul l'appel réseau diffère (requester, un
# lambda qui appelle explicitement la bonne fonction BackendClient — on évite
# de faire transiter une référence de méthode nue en paramètre, peu fiable
# ici) — voir _on_claim_weekly/monthly/unique/_pressed.
static func _handle_claim_pressed(menu, button: Button, kind: String, quest_id, requester: Callable) -> void:
	button.disabled = true
	requester.call(func(success: bool, data: Dictionary):
		if not success:
			button.disabled = false
			return
		AudioManager.play(AudioManager.CONFIRM)
		CurrencyManager.sync_from_backend()
		button.text = SettingsManager.t("QUESTS_CLAIMED")
		_mark_claimed_in_cache(menu, kind, quest_id)
		menu._fetch_quests_badge()
	)

static func _on_claim_weekly_pressed(menu, quest_id: String, button: Button) -> void:
	_handle_claim_pressed(menu, button, "weekly", quest_id, func(on_data: Callable): BackendClient.claim_weekly_quest(quest_id, on_data))

static func _on_claim_monthly_pressed(menu, quest_id: int, button: Button) -> void:
	_handle_claim_pressed(menu, button, "monthly", quest_id, func(on_data: Callable): BackendClient.claim_monthly_quest(quest_id, on_data))

static func _on_claim_unique_pressed(menu, quest_id: int, button: Button) -> void:
	_handle_claim_pressed(menu, button, "unique", quest_id, func(on_data: Callable): BackendClient.claim_unique_quest(quest_id, on_data))

static func _on_claim_pressed(menu, quest_id: int, button: Button) -> void:
	_handle_claim_pressed(menu, button, "daily", quest_id, func(on_data: Callable): BackendClient.claim_quest(quest_id, on_data))
