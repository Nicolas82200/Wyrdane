extends RefCounted
class_name CosmeticsPanel

# Section "Cosmétiques", ajoutée dynamiquement en bas de la vue Profil — même
# esprit que ReferralPanel. Sélection du dos de carte parmi ceux débloqués par
# le niveau de compte local (voir CosmeticsManager/SettingsManager.account_level).
# Purement cosmétique, aucun impact gameplay (voir CLAUDE.md, "éviter le
# Pay-to-Win").

const SWATCH_SIZE := Vector2(56, 84)

static func open(menu) -> void:
	var existing: Node = menu.profile_body.get_node_or_null("CosmeticsSection")
	if existing:
		existing.queue_free()

	var section := VBoxContainer.new()
	section.name = "CosmeticsSection"
	section.add_theme_constant_override("separation", 6)
	menu.profile_body.add_child(section)

	section.add_child(HSeparator.new())

	var title := Label.new()
	title.text = SettingsManager.t("COSMETICS_TITLE")
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	section.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	section.add_child(row)

	var card_back_tex: Texture2D = load("res://assets/card_back/card-back.png")
	for i in CosmeticsManager.CARD_BACKS.size():
		row.add_child(_make_swatch(menu, i, card_back_tex))

static func _make_swatch(menu, index: int, card_back_tex: Texture2D) -> VBoxContainer:
	var cb: Dictionary = CosmeticsManager.CARD_BACKS[index]
	var unlocked: bool = CosmeticsManager.is_unlocked(index)
	var is_selected: bool = SettingsManager.selected_card_back == index

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)

	var swatch := TextureRect.new()
	swatch.texture = card_back_tex
	swatch.custom_minimum_size = SWATCH_SIZE
	swatch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	swatch.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	swatch.modulate = cb["tint"] if unlocked else Color(0.3, 0.3, 0.3, 0.6)
	col.add_child(swatch)

	var name_label := Label.new()
	name_label.text = SettingsManager.t(cb["key"])
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.custom_minimum_size = Vector2(SWATCH_SIZE.x, 0)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.87, 0.78, 1))
	col.add_child(name_label)

	var action_button := Button.new()
	action_button.custom_minimum_size = Vector2(SWATCH_SIZE.x, 30)
	if not unlocked:
		action_button.text = SettingsManager.t("COSMETICS_LOCKED") % int(cb["level"])
		action_button.disabled = true
	elif is_selected:
		action_button.text = SettingsManager.t("COSMETICS_SELECTED")
		action_button.disabled = true
	else:
		action_button.text = SettingsManager.t("COSMETICS_SELECT")
		action_button.pressed.connect(func():
			CosmeticsManager.select_card_back(index)
			open(menu)
		)
	col.add_child(action_button)

	return col
