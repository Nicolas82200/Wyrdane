extends RefCounted
class_name AccountDataPanel

# Section « Mes données » ajoutée en bas de l'onglet Communauté de la vue Profil
# (même pattern statique que ReferralPanel/RecentOpponentsPanel : aucune vue ni
# bouton de nav supplémentaire). Donne accès aux deux droits que le RGPD rend
# obligatoires, et que Steam impose de traiter pour tout jeu distribué sur sa
# plateforme :
#   - récupérer une copie de ses données (article 15) ;
#   - faire effacer son compte (article 17).
#
# Les routes backend correspondantes existent (voir « Données personnelles &
# RGPD » dans le CLAUDE.md de wyrdane-backend), mais un droit qu'aucune UI
# n'atteint n'est pas un droit : c'est cette section qui le rend réel.
#
# Côté serveur, la suppression ANONYMISE le compte (le SteamID est libéré, la
# ligne survit pour ne pas amputer l'historique des adversaires ni les écritures
# comptables) ; côté joueur, l'effet est bien une perte définitive : collection,
# decks, progression, amis. D'où la double barrière ci-dessous — un bouton qui
# révèle un champ, puis un mot à saisir exactement.

# Mot à saisir pour confirmer, traduit (SUPPRIMER / DELETE) : faire taper un mot
# français à un joueur anglophone transformerait un garde-fou en énigme. Le
# backend accepte les deux orthographes (voir accountController.deleteMyAccount).
static func _confirm_word() -> String:
	return SettingsManager.t("ACCOUNT_DATA_DELETE_WORD")

static func open(menu) -> void:
	var existing: Node = menu.profile_body.get_node_or_null("AccountDataSection")
	if existing:
		existing.queue_free()
	if not BackendClient.is_authenticated():
		return

	var section := VBoxContainer.new()
	section.name = "AccountDataSection"
	section.add_theme_constant_override("separation", 6)
	menu.profile_body.add_child(section)

	section.add_child(HSeparator.new())

	var title := Label.new()
	title.text = SettingsManager.t("ACCOUNT_DATA_TITLE")
	title.add_theme_font_size_override("font_size", Typography.SECTION)
	title.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	section.add_child(title)

	var status_label := Label.new()
	status_label.text = SettingsManager.t("ACCOUNT_DATA_HINT")
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_label.add_theme_font_size_override("font_size", Typography.MICRO)
	section.add_child(status_label)

	# ─── Export ──────────────────────────────────────────────────────────────
	var export_row := HBoxContainer.new()
	export_row.add_theme_constant_override("separation", 8)
	section.add_child(export_row)

	var export_button := Button.new()
	export_button.text = SettingsManager.t("ACCOUNT_DATA_EXPORT")
	export_row.add_child(export_button)

	export_button.pressed.connect(func() -> void:
		export_button.disabled = true
		status_label.text = SettingsManager.t("ACCOUNT_DATA_EXPORTING")
		BackendClient.export_my_data(func(success: bool, data: Dictionary) -> void:
			if not is_instance_valid(section):
				return
			export_button.disabled = false
			if not success:
				status_label.text = SettingsManager.t("ACCOUNT_DATA_EXPORT_FAILED")
				return
			# Écrit dans le dossier utilisateur du jeu plutôt que téléchargé : le
			# client n'a pas de navigateur, et ce dossier est celui que le joueur
			# peut ouvrir depuis Steam (Parcourir les fichiers locaux).
			var path := "user://wyrdane-mes-donnees.json"
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				status_label.text = SettingsManager.t("ACCOUNT_DATA_EXPORT_FAILED")
				return
			file.store_string(JSON.stringify(data, "\t"))
			file.close()
			status_label.text = "%s\n%s" % [
				SettingsManager.t("ACCOUNT_DATA_EXPORT_DONE"),
				ProjectSettings.globalize_path(path),
			]
		)
	)

	# ─── Suppression ─────────────────────────────────────────────────────────
	var delete_button := Button.new()
	delete_button.text = SettingsManager.t("ACCOUNT_DATA_DELETE")
	export_row.add_child(delete_button)

	# Deuxième barrière, masquée jusqu'à ce que le joueur demande explicitement
	# la suppression : le mot à taper évite qu'un clic de curiosité efface un
	# compte, sans pour autant multiplier les popups.
	var confirm_row := HBoxContainer.new()
	confirm_row.add_theme_constant_override("separation", 8)
	confirm_row.visible = false
	section.add_child(confirm_row)

	var confirm_field := LineEdit.new()
	confirm_field.placeholder_text = _confirm_word()
	confirm_field.custom_minimum_size = Vector2(180, 0)
	confirm_row.add_child(confirm_field)

	var confirm_button := Button.new()
	confirm_button.text = SettingsManager.t("ACCOUNT_DATA_DELETE_CONFIRM")
	confirm_button.disabled = true
	confirm_row.add_child(confirm_button)

	var cancel_button := Button.new()
	cancel_button.text = SettingsManager.t("ACCOUNT_DATA_DELETE_CANCEL")
	confirm_row.add_child(cancel_button)

	delete_button.pressed.connect(func() -> void:
		confirm_row.visible = true
		status_label.text = SettingsManager.t("ACCOUNT_DATA_DELETE_WARNING")
		confirm_field.grab_focus()
	)

	cancel_button.pressed.connect(func() -> void:
		confirm_row.visible = false
		confirm_field.text = ""
		confirm_button.disabled = true
		status_label.text = SettingsManager.t("ACCOUNT_DATA_HINT")
	)

	confirm_field.text_changed.connect(func(new_text: String) -> void:
		confirm_button.disabled = new_text.strip_edges() != _confirm_word()
	)

	confirm_button.pressed.connect(func() -> void:
		if confirm_field.text.strip_edges() != _confirm_word():
			return
		confirm_button.disabled = true
		cancel_button.disabled = true
		status_label.text = SettingsManager.t("ACCOUNT_DATA_DELETING")
		BackendClient.delete_my_account(_confirm_word(), func(success: bool) -> void:
			if not is_instance_valid(section):
				return
			if not success:
				cancel_button.disabled = false
				confirm_button.disabled = false
				status_label.text = SettingsManager.t("ACCOUNT_DATA_DELETE_FAILED")
				return
			# La session locale ne vaut plus rien (voir
			# BackendClient.delete_my_account) : on retourne à l'écran de
			# chargement, qui relancera une authentification propre — et créera
			# donc un compte neuf, le SteamID ayant été libéré côté serveur.
			confirm_row.visible = false
			status_label.text = SettingsManager.t("ACCOUNT_DATA_DELETE_DONE")
			SceneTransition.change_scene("res://scenes/loading/LoadingScreen.tscn")
		)
	)
