extends RefCounted
class_name ProfileCosmeticsPanel

# Section "Titre & cadre", ajoutée dynamiquement en bas de la vue Profil —
# même esprit que ReferralPanel. Sélection parmi les titres/cadres débloqués
# par le niveau de compte local (voir ProfileCosmetics). Purement cosmétique.

static func open(menu) -> void:
	var existing: Node = menu.profile_body.get_node_or_null("ProfileCosmeticsSection")
	if existing:
		existing.queue_free()

	var section := VBoxContainer.new()
	section.name = "ProfileCosmeticsSection"
	section.add_theme_constant_override("separation", 6)
	menu.profile_body.add_child(section)

	section.add_child(HSeparator.new())

	var title := Label.new()
	title.text = SettingsManager.t("PROFILE_COSMETICS_TITLE")
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	section.add_child(title)

	var titles_row := HBoxContainer.new()
	titles_row.add_theme_constant_override("separation", 8)
	section.add_child(titles_row)
	for i in ProfileCosmetics.TITLES.size():
		titles_row.add_child(_make_choice_button(menu, ProfileCosmetics.TITLES[i]["key"],
			ProfileCosmetics.TITLES[i]["level"], ProfileCosmetics.title_unlocked(i),
			SettingsManager.selected_title == i,
			func(): ProfileCosmetics.select_title(i); open(menu)))

	var frames_row := HBoxContainer.new()
	frames_row.add_theme_constant_override("separation", 8)
	section.add_child(frames_row)
	for i in ProfileCosmetics.FRAMES.size():
		frames_row.add_child(_make_choice_button(menu, ProfileCosmetics.FRAMES[i]["key"],
			ProfileCosmetics.FRAMES[i]["level"], ProfileCosmetics.frame_unlocked(i),
			SettingsManager.selected_frame == i,
			func(): ProfileCosmetics.select_frame(i); open(menu)))

static func _make_choice_button(_menu, key: String, level: int, unlocked: bool, is_selected: bool, on_pick: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(100, 36)
	if not unlocked:
		btn.text = "%s (%s)" % [SettingsManager.t(key), SettingsManager.t("PROFILE_COSMETICS_LOCKED") % level]
		btn.disabled = true
	elif is_selected:
		btn.text = "%s ✓" % SettingsManager.t(key)
		btn.disabled = true
	else:
		btn.text = SettingsManager.t(key)
		btn.pressed.connect(on_pick)
	return btn
