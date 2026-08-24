extends RefCounted
class_name QuestsPanel

# Panneau des quêtes quotidiennes du menu principal — extrait de MainMenu.gd.
# `menu._current_info_view`/`menu.InfoView` servent à ignorer une réponse
# backend arrivée après que le joueur a quitté la vue Quêtes.

static func open(menu) -> void:
	if not BackendClient.is_authenticated():
		menu.quests_status_label.text = SettingsManager.t("QUESTS_UNAVAILABLE")
		menu.quests_status_label.visible = true
		return
	menu.quests_status_label.text = SettingsManager.t("PROFILE_LOADING")
	menu.quests_status_label.visible = true
	BackendClient.get_daily_quests(func(success: bool, data: Dictionary):
		if menu._current_info_view != menu.InfoView.QUESTS:
			return
		if not success:
			menu.quests_status_label.text = SettingsManager.t("QUESTS_UNAVAILABLE")
			return
		_populate(menu, data.get("quests", []))
	)

static func _populate(menu, quests: Array) -> void:
	menu.quests_status_label.visible = quests.is_empty()
	if quests.is_empty():
		menu.quests_status_label.text = SettingsManager.t("QUESTS_UNAVAILABLE")
	for child in menu.quests_list_vbox.get_children():
		child.queue_free()
	for quest in quests:
		_add_item(menu, quest)
	menu._update_quests_badge(quests)

# Style de carte à liseré coloré (façon MTGA), même petit helper que
# NewsPanel._make_accent_card_style (dupliqué plutôt qu'extrait dans un 3e
# fichier partagé — seulement deux appelants).
const ACCENT_EMBER := Color(0.72, 0.48, 0.19, 0.85)
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

static func _add_item(menu, quest: Dictionary) -> void:
	var quest_id := int(quest.get("id", 0))
	var progress := int(quest.get("progress", 0))
	var target := int(quest.get("target", 1))
	var reward := int(quest.get("reward_currency", 0))
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

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(text_col)

	var desc_label := Label.new()
	desc_label.text = SettingsManager.t(String(quest.get("description_key", "")))
	desc_label.add_theme_font_size_override("font_size", 17)
	desc_label.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_col.add_child(desc_label)

	var progress_label := Label.new()
	progress_label.text = SettingsManager.t("QUESTS_PROGRESS") % [progress, target, reward]
	progress_label.add_theme_font_size_override("font_size", 14)
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
		action_button.pressed.connect(_on_claim_pressed.bind(menu, quest_id, action_button))
	else:
		action_button.text = SettingsManager.t("QUESTS_IN_PROGRESS")
		action_button.disabled = true
	hbox.add_child(action_button)

	menu.quests_list_vbox.add_child(row)

static func _on_claim_pressed(menu, quest_id: int, button: Button) -> void:
	button.disabled = true
	BackendClient.claim_quest(quest_id, func(success: bool, data: Dictionary):
		if not success:
			button.disabled = false
			return
		AudioManager.play(AudioManager.CONFIRM)
		CurrencyManager.sync_from_backend()
		button.text = SettingsManager.t("QUESTS_CLAIMED")
		menu._fetch_quests_badge()
	)
