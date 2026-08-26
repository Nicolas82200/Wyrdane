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
