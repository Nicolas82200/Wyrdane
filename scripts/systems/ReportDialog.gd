# ReportDialog.gd
# Popup de signalement (bug ou joueur pour triche), utilisable depuis le menu
# principal (MainMenu) et l'écran de bataille (Battle). Pas de suivi côté
# client : le signalement est envoyé par mail à l'équipe via
# BackendClient.report_issue (voir reportsController côté backend).
class_name ReportDialog
extends AcceptDialog

const TYPE_BUG := "bug"
const TYPE_CHEATING := "cheating"

var _category_select: OptionButton
var _text_edit: TextEdit
var _reported_user_id: int
var _match_id: String

# allow_cheating n'a d'effet que si reported_user_id > 0 (aucun sens de
# signaler un adversaire hors partie réseau, ou sans identité backend connue).
static func open_on(parent: Node, allow_cheating: bool, reported_user_id: int = 0, match_id: String = "") -> void:
	var dialog := ReportDialog.new()
	var can_report_player := allow_cheating and reported_user_id > 0
	dialog._reported_user_id = reported_user_id if can_report_player else 0
	dialog._match_id = match_id if can_report_player else ""
	dialog.title = SettingsManager.t("REPORT_TITLE")
	dialog.ok_button_text = SettingsManager.t("REPORT_SUBMIT")
	dialog.min_size = Vector2(480, 320)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var category_label := Label.new()
	category_label.text = SettingsManager.t("REPORT_CATEGORY_LABEL")
	vbox.add_child(category_label)

	dialog._category_select = OptionButton.new()
	dialog._category_select.add_item(SettingsManager.t("REPORT_CATEGORY_BUG"))
	dialog._category_select.set_item_metadata(0, TYPE_BUG)
	if can_report_player:
		dialog._category_select.add_item(SettingsManager.t("REPORT_CATEGORY_CHEATING"))
		dialog._category_select.set_item_metadata(1, TYPE_CHEATING)
	vbox.add_child(dialog._category_select)

	var desc_label := Label.new()
	desc_label.text = SettingsManager.t("REPORT_DESCRIPTION_LABEL")
	vbox.add_child(desc_label)

	dialog._text_edit = TextEdit.new()
	dialog._text_edit.placeholder_text = SettingsManager.t("REPORT_DESCRIPTION_PLACEHOLDER")
	dialog._text_edit.custom_minimum_size = Vector2(0, 160)
	dialog._text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	vbox.add_child(dialog._text_edit)

	dialog.add_child(vbox)
	parent.add_child(dialog)
	dialog.popup_centered()

	dialog.confirmed.connect(dialog._on_confirmed)
	dialog.canceled.connect(dialog.queue_free)

func _on_confirmed() -> void:
	var parent := get_parent()
	var description := _text_edit.text.strip_edges()
	var type_id: String = _category_select.get_item_metadata(_category_select.selected)
	var reported_user_id := _reported_user_id
	var match_id := _match_id
	queue_free()

	if description.is_empty():
		_show_message(parent, SettingsManager.t("REPORT_EMPTY_ERROR"))
		return

	BackendClient.report_issue(type_id, description, reported_user_id, match_id, func(code: int, _parsed):
		if code == 200:
			_show_message(parent, SettingsManager.t("REPORT_SUCCESS_TEXT"))
		else:
			_show_message(parent, SettingsManager.t("REPORT_ERROR_TEXT"))
	)

static func _show_message(parent: Node, text: String) -> void:
	var msg := AcceptDialog.new()
	msg.dialog_text = text
	parent.add_child(msg)
	msg.popup_centered()
	msg.confirmed.connect(msg.queue_free)
	msg.canceled.connect(msg.queue_free)
