extends Control

const CAMPAIGN_MAP_SCENE := "res://scenes/campaign/CampaignMapScreen.tscn"
const MAIN_MENU_SCENE := "res://scenes/mainMenu/MainMenu.tscn"
const REST_HEAL_PERCENT := 0.3

func _ready() -> void:
	if not CampaignContext.active or CampaignContext.run == null:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		return

	add_child(CampaignUI.make_background())
	var run := CampaignContext.run

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	CampaignUI.style_panel(panel)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	vbox.add_child(CampaignUI.make_title_label(SettingsManager.t("CAMPAIGN_REST_TITLE")))
	vbox.add_child(CampaignUI.make_body_label(SettingsManager.t("CAMPAIGN_REST_BODY")))
	vbox.add_child(CampaignUI.make_body_label("%s : %d / %d" % [SettingsManager.t("CAMPAIGN_HP_LABEL"), run.hero_health, run.hero_max_health]))

	var rest_button := Button.new()
	rest_button.text = SettingsManager.t("CAMPAIGN_REST_BUTTON")
	CampaignUI.style_button(rest_button)
	rest_button.disabled = run.hero_health >= run.hero_max_health
	rest_button.pressed.connect(_on_rest_pressed)
	vbox.add_child(rest_button)

func _on_rest_pressed() -> void:
	var run := CampaignContext.run
	var missing := run.hero_max_health - run.hero_health
	run.heal(int(ceil(missing * REST_HEAL_PERCENT)))
	run.mark_node_cleared(run.current_node_id)
	AudioManager.play(AudioManager.OPEN_MENU)
	get_tree().change_scene_to_file(CAMPAIGN_MAP_SCENE)
