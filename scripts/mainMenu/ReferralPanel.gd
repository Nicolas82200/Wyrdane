extends RefCounted
class_name ReferralPanel

# Section Parrainage, ajoutée dynamiquement en bas de la vue Profil (pas de
# nouveau bouton de nav / vue dédiée — même esprit que les rangées construites
# à la volée par QuestsPanel/NewsPanel). Un joueur ne peut parrainer qu'un
# seul ami (contrainte côté serveur, voir
# docs/backend-contracts/weekly-quests-and-referral.md) : la récompense
# (3 packs + 500 or) est créditée au parrain quand le filleul termine le
# tutoriel.

const INVITE_LINK_PREFIX := "https://wyrdane.com/invite/"

static func open(menu) -> void:
	# Section reconstruite à chaque ouverture de la vue Profil — supprime
	# l'ancienne avant d'en ajouter une nouvelle (évite l'empilement si
	# ProfilePanel.open est rappelé plusieurs fois sans quitter la vue).
	var existing: Node = menu.profile_view.get_node_or_null("ReferralSection")
	if existing:
		existing.queue_free()
	if not BackendClient.is_authenticated():
		return

	var section := VBoxContainer.new()
	section.name = "ReferralSection"
	section.add_theme_constant_override("separation", 6)
	menu.profile_view.add_child(section)

	section.add_child(HSeparator.new())

	var title := Label.new()
	title.text = SettingsManager.t("REFERRAL_TITLE")
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	section.add_child(title)

	var status_label := Label.new()
	status_label.text = SettingsManager.t("PROFILE_LOADING")
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	section.add_child(status_label)

	var link_row := HBoxContainer.new()
	link_row.add_theme_constant_override("separation", 8)
	section.add_child(link_row)
	var copy_button := Button.new()
	copy_button.text = SettingsManager.t("REFERRAL_COPY_LINK")
	copy_button.disabled = true
	link_row.add_child(copy_button)

	var redeem_row := HBoxContainer.new()
	redeem_row.add_theme_constant_override("separation", 8)
	section.add_child(redeem_row)
	var redeem_field := LineEdit.new()
	redeem_field.placeholder_text = SettingsManager.t("REFERRAL_REDEEM_PLACEHOLDER")
	redeem_field.custom_minimum_size = Vector2(180, 0)
	redeem_row.add_child(redeem_field)
	var redeem_button := Button.new()
	redeem_button.text = SettingsManager.t("REFERRAL_REDEEM_BUTTON")
	redeem_row.add_child(redeem_button)

	BackendClient.get_referral_code(func(code_success: bool, code_data: Dictionary):
		if not is_instance_valid(section) or menu._current_info_view != menu.InfoView.PROFILE:
			return
		if not code_success:
			status_label.text = SettingsManager.t("REFERRAL_UNAVAILABLE")
			return
		var code := String(code_data.get("code", ""))
		copy_button.disabled = code.is_empty()
		copy_button.pressed.connect(func():
			DisplayServer.clipboard_set(INVITE_LINK_PREFIX + code)
			AudioManager.play(AudioManager.CONFIRM)
			copy_button.text = SettingsManager.t("REFERRAL_LINK_COPIED")
		)
		_fetch_status(menu, section, status_label, code)
	)

	redeem_button.pressed.connect(func():
		var code := redeem_field.text.strip_edges().to_upper()
		if code.is_empty():
			return
		redeem_button.disabled = true
		BackendClient.redeem_referral_code(code, func(success: bool, error_code: String):
			if not is_instance_valid(redeem_button):
				return
			redeem_button.disabled = false
			if success:
				AudioManager.play(AudioManager.CONFIRM)
				redeem_field.editable = false
				redeem_button.text = SettingsManager.t("REFERRAL_REDEEM_DONE")
			else:
				var message_key := error_code if not error_code.is_empty() else "REFERRAL_UNAVAILABLE"
				status_label.text = SettingsManager.t(message_key)
		)
	)

static func _fetch_status(menu, section: VBoxContainer, status_label: Label, code: String) -> void:
	BackendClient.get_referral_status(func(success: bool, data: Dictionary):
		if not is_instance_valid(section) or menu._current_info_view != menu.InfoView.PROFILE:
			return
		if not success:
			status_label.text = SettingsManager.t("REFERRAL_UNAVAILABLE")
			return
		var status := String(data.get("status", "none"))
		match status:
			"pending":
				status_label.text = SettingsManager.t("REFERRAL_STATUS_PENDING") % String(data.get("referred_username", ""))
			"completed":
				status_label.text = SettingsManager.t("REFERRAL_STATUS_COMPLETED") % String(data.get("referred_username", ""))
			_:
				status_label.text = SettingsManager.t("REFERRAL_STATUS_NONE") % code
	)

# --- Popup de premier lancement --------------------------------------------
# Affiché une seule fois (SettingsManager.referral_prompt_seen), juste après
# la fin du tutoriel — moment naturel pour un nouveau joueur d'entrer un code
# reçu d'un ami, plutôt que de compter sur lui pour aller le chercher dans la
# vue Profil. Construit entièrement en code (aucune édition de MainMenu.tscn,
# scène volumineuse gérée par un outil externe — même prudence que la section
# Profil ci-dessus) et ajouté comme dernier enfant de `menu` pour s'afficher
# au-dessus du reste. Appelé depuis MainMenu._launch_backend_syncs() : le
# check `status == "none"` côté backend sert aussi de garde-fou si le joueur a
# déjà été parrainé depuis un autre appareil/session avant que le flag local
# ne soit posé.
static func maybe_show_first_launch_prompt(menu) -> void:
	if not SettingsManager.tutorial_completed or SettingsManager.referral_prompt_seen:
		return
	if not BackendClient.is_authenticated():
		return
	BackendClient.get_referral_status(func(success: bool, data: Dictionary):
		if not success:
			return
		if String(data.get("status", "none")) != "none":
			SettingsManager.mark_referral_prompt_seen()
			return
		_show_first_launch_popup(menu)
	)

const PROMPT_ACCENT := Color(0.85, 0.7, 0.25, 1.0)

static func _show_first_launch_popup(menu) -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "ReferralFirstLaunchPopup"
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.z_index = 4000
	menu.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.075, 0.06, 0.97)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = PROMPT_ACCENT
	style.set_corner_radius_all(8)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(380, 0)
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = SettingsManager.t("REFERRAL_FIRST_LAUNCH_TITLE")
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = SettingsManager.t("REFERRAL_FIRST_LAUNCH_DESC")
	desc.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72, 1))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc)

	var status_label := Label.new()
	status_label.visible = false
	status_label.add_theme_color_override("font_color", Color(0.85, 0.25, 0.2, 1))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(status_label)

	var field := LineEdit.new()
	field.placeholder_text = SettingsManager.t("REFERRAL_REDEEM_PLACEHOLDER")
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(field)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 12)
	vbox.add_child(button_row)

	var skip_button := Button.new()
	skip_button.text = SettingsManager.t("REFERRAL_SKIP_BUTTON")
	button_row.add_child(skip_button)

	var submit_button := Button.new()
	submit_button.custom_minimum_size = Vector2(140, 0)
	submit_button.text = SettingsManager.t("REFERRAL_REDEEM_BUTTON")
	button_row.add_child(submit_button)

	var close_popup := func():
		SettingsManager.mark_referral_prompt_seen()
		AudioManager.play(AudioManager.CLOSE_MENU)
		backdrop.queue_free()

	skip_button.pressed.connect(close_popup)

	submit_button.pressed.connect(func():
		var code := field.text.strip_edges().to_upper()
		if code.is_empty():
			return
		submit_button.disabled = true
		BackendClient.redeem_referral_code(code, func(success: bool, error_code: String):
			if not is_instance_valid(submit_button):
				return
			submit_button.disabled = false
			if success:
				AudioManager.play(AudioManager.CONFIRM)
				close_popup.call()
			else:
				var message_key := error_code if not error_code.is_empty() else "REFERRAL_UNAVAILABLE"
				status_label.text = SettingsManager.t(message_key)
				status_label.visible = true
		)
	)
