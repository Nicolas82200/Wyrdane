extends RefCounted
class_name DeckImportExport

# Popups d'export/import de deck (code presse-papiers, voir DeckData.to_code/
# from_code) — extrait de DeckBuilder.gd, pure construction de dialogue +
# lecture/écriture de `builder.current_deck`.

static func export(builder) -> void:
	if builder.current_deck == null:
		return
	var code: String = builder.current_deck.to_code()
	DisplayServer.clipboard_set(code)

	var dialog := AcceptDialog.new()
	dialog.title = SettingsManager.t("deck.export_title")
	dialog.min_size = Vector2(480, 220)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var hint := Label.new()
	hint.text = SettingsManager.t("deck.export_hint")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(hint)

	var text_edit := TextEdit.new()
	text_edit.text = code
	text_edit.editable = false
	text_edit.custom_minimum_size = Vector2(0, 110)
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	vbox.add_child(text_edit)

	dialog.add_child(vbox)
	builder.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)

static func import(builder) -> void:
	if builder.current_deck == null:
		return
	var dialog := AcceptDialog.new()
	dialog.title = SettingsManager.t("deck.import_title")
	dialog.min_size = Vector2(480, 220)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var hint := Label.new()
	hint.text = SettingsManager.t("deck.import_hint")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(hint)

	var text_edit := TextEdit.new()
	text_edit.custom_minimum_size = Vector2(0, 110)
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	vbox.add_child(text_edit)

	dialog.add_child(vbox)
	builder.add_child(dialog)
	dialog.popup_centered()

	dialog.confirmed.connect(func():
		var imported := DeckData.from_code(text_edit.text)
		if imported == null:
			var err := AcceptDialog.new()
			err.dialog_text = SettingsManager.t("deck.import_error")
			builder.add_child(err)
			err.popup_centered()
			err.confirmed.connect(err.queue_free)
		else:
			builder.current_deck.name = imported.name
			builder.current_deck.card_paths = imported.card_paths
			builder.deck_name_edit.text = builder.current_deck.name
			builder._mark_dirty()
			builder._refresh_deck_list()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
