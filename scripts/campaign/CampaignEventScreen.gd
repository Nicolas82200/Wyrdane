extends Control

const CAMPAIGN_MAP_SCENE := "res://scenes/campaign/CampaignMapScreen.tscn"
const MAIN_MENU_SCENE := "res://scenes/mainMenu/MainMenu.tscn"

var _event: Dictionary
var _resolved := false

@onready var _feedback_label: Label = null

func _ready() -> void:
	if not CampaignContext.active or CampaignContext.run == null:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		return

	add_child(CampaignUI.make_background())
	var run := CampaignContext.run
	_event = CampaignEvents.random_event(run.rng)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	CampaignUI.style_panel(panel)
	panel.custom_minimum_size = Vector2(500, 0)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	vbox.add_child(CampaignUI.make_title_label(SettingsManager.t(_event["title_key"])))
	vbox.add_child(CampaignUI.make_body_label(SettingsManager.t(_event["body_key"])))

	_feedback_label = CampaignUI.make_body_label("")
	_feedback_label.add_theme_color_override("font_color", Color("f0c040"))
	_feedback_label.hide()
	vbox.add_child(_feedback_label)

	var choices_box := VBoxContainer.new()
	choices_box.add_theme_constant_override("separation", 8)
	vbox.add_child(choices_box)

	for choice in _event["choices"]:
		var btn := Button.new()
		btn.text = SettingsManager.t(choice["label_key"])
		CampaignUI.style_button(btn)
		var effect: String = choice["effect"]
		btn.pressed.connect(func(): _on_choice_pressed(btn, choices_box, effect))
		choices_box.add_child(btn)

func _on_choice_pressed(pressed_button: Button, choices_box: VBoxContainer, effect: String) -> void:
	if _resolved:
		return
	_resolved = true
	CampaignEvents.apply_effect(effect, CampaignContext.run)
	CampaignContext.run.mark_node_cleared(CampaignContext.run.current_node_id)
	for child in choices_box.get_children():
		child.disabled = true
	AudioManager.play(AudioManager.CONFIRM)
	_feedback_label.text = SettingsManager.t("CAMPAIGN_EVENT_RESOLVED")
	_feedback_label.show()

	var continue_button := Button.new()
	continue_button.text = SettingsManager.t("CAMPAIGN_CONTINUE")
	CampaignUI.style_button(continue_button)
	continue_button.pressed.connect(func(): get_tree().change_scene_to_file(CAMPAIGN_MAP_SCENE))
	choices_box.get_parent().add_child(continue_button)
