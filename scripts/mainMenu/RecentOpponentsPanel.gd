extends RefCounted
class_name RecentOpponentsPanel

# Section "Social" minimale, ajoutée dynamiquement en bas de la vue Profil
# (même esprit que ReferralPanel) : liste des derniers adversaires réseau
# affrontés (purement local, voir SettingsManager.recent_opponents) + accès à
# l'overlay natif Steam pour la liste d'amis/demandes/blocage — pas de système
# d'amis dédié côté jeu, Steam gère déjà tout cela nativement.
# "Ajouter en ami" pour un adversaire précis n'est proposé qu'immédiatement
# après la partie (voir GameOverScreen), jamais depuis cette liste
# rétrospective : on n'y connaît que son pseudo, jamais son SteamID64 (voir
# NetTransport.remote_display_name).

static func open(menu) -> void:
	var existing: Node = menu.profile_view.get_node_or_null("SocialSection")
	if existing:
		existing.queue_free()

	var section := VBoxContainer.new()
	section.name = "SocialSection"
	section.add_theme_constant_override("separation", 6)
	menu.profile_view.add_child(section)

	section.add_child(HSeparator.new())

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	section.add_child(header_row)

	var title := Label.new()
	title.text = SettingsManager.t("RECENT_OPPONENTS_TITLE")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	header_row.add_child(title)

	var friends_button := Button.new()
	friends_button.text = SettingsManager.t("MENU_FRIENDS_BUTTON")
	friends_button.pressed.connect(SteamService.open_friends_overlay)
	header_row.add_child(friends_button)

	var opponents: Array = SettingsManager.recent_opponents
	if opponents.is_empty():
		var empty_label := Label.new()
		empty_label.text = SettingsManager.t("RECENT_OPPONENTS_EMPTY")
		empty_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.58, 0.85))
		section.add_child(empty_label)
		return

	var list_label := Label.new()
	list_label.text = ", ".join(opponents)
	list_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	list_label.add_theme_color_override("font_color", Color(0.9, 0.87, 0.78, 1))
	section.add_child(list_label)
