extends RefCounted
class_name LevelRewardsPanel

# Popup de récompenses de niveau du menu principal — extrait de MainMenu.gd,
# même pattern que QuestsPanel/ReferralPanel. Ouverte en cliquant sur le
# niveau de compte sous le pseudo (voir MainMenu._on_player_status_gui_input).
#
# Les récompenses de niveau sont créditées automatiquement dès qu'un palier
# est franchi (voir levelModel.grantLevelReward côté wyrdane-backend) : cette
# popup ne fait que les lister et laisser le joueur les marquer comme "vues"
# (level_rewards.claimed_at) — cliquer sur une récompense ne crédite rien de
# nouveau, c'est un simple accusé de réception.

# Même mapping que GameOverScreen.LEVEL_REWARD_RARITY_KEY — dupliqué plutôt
# qu'extrait dans un 3e fichier partagé, un seul autre appelant.
const LEVEL_REWARD_RARITY_KEY := {
	"Commune": "rarity.common",
	"Rare": "rarity.rare",
	"Épique": "rarity.epic",
	"Légendaire": "rarity.legendary",
}

const ACCENT_CLAIMABLE := Color(0.92, 0.72, 0.28, 0.95)
const ACCENT_LOCKED := Color(0.42, 0.37, 0.3, 0.4)
const ACCENT_DONE := Color(0.42, 0.37, 0.3, 0.55)

static func open(menu) -> void:
	menu.level_rewards_popup.visible = true
	_load(menu)

static func close(menu) -> void:
	menu.level_rewards_popup.visible = false

static func _load(menu) -> void:
	menu.level_rewards_status_label.text = SettingsManager.t("PROFILE_LOADING")
	menu.level_rewards_status_label.visible = true
	menu.level_rewards_claim_all_button.disabled = true
	for child in menu.level_rewards_list_vbox.get_children():
		child.queue_free()

	if not BackendClient.is_authenticated():
		menu.level_rewards_status_label.text = SettingsManager.t("LEVEL_REWARDS_UNAVAILABLE")
		return

	LevelManager.fetch_rewards(func(success: bool, data: Dictionary):
		if not menu.level_rewards_popup.visible:
			return
		if not success:
			menu.level_rewards_status_label.text = SettingsManager.t("LEVEL_REWARDS_UNAVAILABLE")
			return
		_populate(menu, data)
	)

static func _populate(menu, data: Dictionary) -> void:
	menu.level_rewards_status_label.visible = false
	var current_level := int(data.get("level", 1))
	var catalog: Array = data.get("catalog", [])
	var granted_by_level := {}
	for reward in data.get("rewards", []):
		if reward is Dictionary:
			granted_by_level[int(reward.get("level", 0))] = reward

	var claimable_levels: Array[int] = []
	var current_row: Control = null
	for entry in catalog:
		if not (entry is Dictionary):
			continue
		var row := _make_row(menu, entry, current_level, granted_by_level)
		if bool(row.get_meta("claimable", false)):
			claimable_levels.append(int(row.get_meta("level")))
		if int(row.get_meta("level")) == current_level:
			current_row = row
		menu.level_rewards_list_vbox.add_child(row)

	menu.level_rewards_claim_all_button.disabled = claimable_levels.is_empty()
	menu.level_rewards_claim_all_button.set_meta("claimable_levels", claimable_levels)
	menu.level_rewards_list_vbox.set_meta("current_level", current_level)

	if current_row:
		menu.level_rewards_scroll.call_deferred("ensure_control_visible", current_row)

static func _make_row(menu, entry: Dictionary, current_level: int, granted_by_level: Dictionary) -> PanelContainer:
	var level := int(entry.get("level", 0))
	var granted: Variant = granted_by_level.get(level)
	var reached := level <= current_level
	# Un niveau atteint sans ligne journalisée est un niveau franchi avant
	# l'introduction de cette popup (voir CLAUDE.md wyrdane-backend, section
	# « Popup de récompenses de niveau ») : traité comme déjà réclamé.
	var claimed := true if not (granted is Dictionary) else bool(granted.get("claimed", false))
	var claimable := reached and not claimed

	var row := PanelContainer.new()
	row.set_meta("level", level)
	row.set_meta("claimable", claimable)
	var accent := ACCENT_DONE
	if not reached:
		accent = ACCENT_LOCKED
	elif claimable:
		accent = ACCENT_CLAIMABLE
	row.add_theme_stylebox_override("panel", _make_accent_card_style(accent))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 8)
	row.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(text_col)

	var level_label := Label.new()
	level_label.text = SettingsManager.t("ACCOUNT_LEVEL_LABEL") % level
	level_label.add_theme_font_size_override("font_size", 16)
	level_label.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	if not reached:
		level_label.modulate.a = 0.6
	text_col.add_child(level_label)

	var reward_label := Label.new()
	reward_label.text = _reward_description(entry)
	reward_label.add_theme_font_size_override("font_size", 14)
	reward_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72, 0.85))
	if not reached:
		reward_label.modulate.a = 0.6
	text_col.add_child(reward_label)

	var action_button := Button.new()
	action_button.custom_minimum_size = Vector2(120, 40)
	action_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not reached:
		action_button.text = SettingsManager.t("LEVEL_REWARDS_LOCKED")
		action_button.disabled = true
	elif claimed:
		action_button.text = SettingsManager.t("QUESTS_CLAIMED")
		action_button.disabled = true
	else:
		action_button.text = SettingsManager.t("QUESTS_CLAIM")
		action_button.pressed.connect(_on_claim_pressed.bind(menu, level, action_button))
	hbox.add_child(action_button)

	return row

static func _reward_description(entry: Dictionary) -> String:
	match String(entry.get("kind", "")):
		"card":
			var rarity_key: String = LEVEL_REWARD_RARITY_KEY.get(String(entry.get("rarity", "")), "")
			var rarity_text := SettingsManager.t(rarity_key) if rarity_key != "" else ""
			return SettingsManager.t("LEVEL_REWARDS_REWARD_CARD") % rarity_text
		"pack":
			return SettingsManager.t("LEVEL_REWARDS_REWARD_PACK")
		"gold":
			return SettingsManager.t("LEVEL_REWARDS_REWARD_GOLD") % int(entry.get("gold", 0))
		_:
			return ""

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

static func _on_claim_pressed(menu, level: int, button: Button) -> void:
	button.disabled = true
	LevelManager.claim_rewards([level], func(success: bool, _data: Dictionary):
		if not success:
			button.disabled = false
			return
		AudioManager.play(AudioManager.CONFIRM)
		if menu.level_rewards_popup.visible:
			_load(menu)
	)

static func claim_all(menu) -> void:
	var levels: Array = menu.level_rewards_claim_all_button.get_meta("claimable_levels", [])
	if levels.is_empty():
		return
	menu.level_rewards_claim_all_button.disabled = true
	LevelManager.claim_rewards(levels, func(success: bool, _data: Dictionary):
		if not success:
			menu.level_rewards_claim_all_button.disabled = false
			return
		AudioManager.play(AudioManager.CONFIRM)
		if menu.level_rewards_popup.visible:
			_load(menu)
	)

static func go_to_current_level(menu) -> void:
	if not menu.level_rewards_list_vbox.has_meta("current_level"):
		return
	var current_level := int(menu.level_rewards_list_vbox.get_meta("current_level"))
	for row in menu.level_rewards_list_vbox.get_children():
		if row.has_meta("level") and int(row.get_meta("level")) == current_level:
			menu.level_rewards_scroll.ensure_control_visible(row)
			return
