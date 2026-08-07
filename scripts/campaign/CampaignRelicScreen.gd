extends Control

# Nœud Relique : une carte Enchantement/Rituel aléatoire imposée, sans choix
# (CAMPAIGN.md « Reliques » : « toujours aléatoire/imposée »).

const CARD_SCENE := preload("res://scenes/card/Card.tscn")
const CARD_BASE_SIZE := Vector2(250, 375)
const CARD_DISPLAY_SCALE := 0.9
const CAMPAIGN_MAP_SCENE := "res://scenes/campaign/CampaignMapScreen.tscn"
const MAIN_MENU_SCENE := "res://scenes/mainMenu/MainMenu.tscn"

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

	vbox.add_child(CampaignUI.make_title_label(SettingsManager.t("CAMPAIGN_RELIC_TITLE")))
	vbox.add_child(CampaignUI.make_body_label(SettingsManager.t("CAMPAIGN_RELIC_BODY")))

	var card := CampaignRewardPicker.pick_relic(run.race, run.rng)

	var wrapper := Control.new()
	wrapper.custom_minimum_size = CARD_BASE_SIZE * CARD_DISPLAY_SCALE
	vbox.add_child(wrapper)

	if card != null:
		var card_visual: Card = CARD_SCENE.instantiate()
		wrapper.add_child(card_visual)
		card_visual.set_non_interactive()
		card_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_visual.scale = Vector2(CARD_DISPLAY_SCALE, CARD_DISPLAY_SCALE)
		card_visual.set_data(card)
	else:
		vbox.add_child(CampaignUI.make_body_label(SettingsManager.t("CAMPAIGN_RELIC_NONE")))

	var continue_button := Button.new()
	continue_button.text = SettingsManager.t("CAMPAIGN_CONTINUE")
	CampaignUI.style_button(continue_button)
	continue_button.pressed.connect(func(): _on_continue(card))
	vbox.add_child(continue_button)

func _on_continue(card: CardData) -> void:
	var run := CampaignContext.run
	if card != null:
		run.add_card_to_board(card)
	run.mark_node_cleared(run.current_node_id)
	AudioManager.play(AudioManager.CONFIRM)
	get_tree().change_scene_to_file(CAMPAIGN_MAP_SCENE)
