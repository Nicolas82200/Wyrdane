extends Control

# 5 choix successifs de carte (3 candidates Commune de la race choisie à
# chaque fois) qui constituent le plateau de départ du joueur — pas de deck
# ni de pioche en Campagne (CAMPAIGN.md « Constitution du plateau »).

const CARD_SCENE := preload("res://scenes/card/Card.tscn")
const CARD_BASE_SIZE := Vector2(250, 375)
const CARD_DISPLAY_SCALE := 0.8
const CAMPAIGN_MAP_SCENE := "res://scenes/campaign/CampaignMapScreen.tscn"
const MAIN_MENU_SCENE := "res://scenes/mainMenu/MainMenu.tscn"

var _choice_index := 0
var _picked := false
var _title_label: Label
var _cards_box: HBoxContainer

func _ready() -> void:
	if not CampaignContext.active or CampaignContext.run == null:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		return

	add_child(CampaignUI.make_background())

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	CampaignUI.style_panel(panel)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	_title_label = CampaignUI.make_title_label("")
	vbox.add_child(_title_label)
	vbox.add_child(CampaignUI.make_body_label(SettingsManager.t("CAMPAIGN_BOARD_BUILD_BODY")))

	_cards_box = HBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 20)
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_cards_box)

	_show_next_choice()

func _show_next_choice() -> void:
	_picked = false
	for child in _cards_box.get_children():
		child.queue_free()
	_title_label.text = SettingsManager.t("CAMPAIGN_BOARD_BUILD_TITLE") % [_choice_index + 1, CampaignBoardBuild.CHOICE_COUNT]

	var run := CampaignContext.run
	var candidates := CampaignBoardBuild.pick_candidates(run.race, run.rng, run.board)
	for card_data in candidates:
		_add_card_option(card_data)

func _add_card_option(card_data: CardData) -> void:
	var option_vbox := VBoxContainer.new()
	option_vbox.add_theme_constant_override("separation", 8)
	_cards_box.add_child(option_vbox)

	var wrapper := Control.new()
	wrapper.custom_minimum_size = CARD_BASE_SIZE * CARD_DISPLAY_SCALE
	wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
	wrapper.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	option_vbox.add_child(wrapper)

	var card_visual: Card = CARD_SCENE.instantiate()
	wrapper.add_child(card_visual)
	card_visual.set_non_interactive()
	card_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_visual.scale = Vector2(CARD_DISPLAY_SCALE, CARD_DISPLAY_SCALE)
	card_visual.set_data(card_data)

	var choose_button := Button.new()
	choose_button.text = SettingsManager.t("CAMPAIGN_REWARD_CHOOSE")
	CampaignUI.style_button(choose_button)
	choose_button.pressed.connect(func(): _on_card_chosen(card_data))
	option_vbox.add_child(choose_button)

	wrapper.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_card_chosen(card_data))

func _on_card_chosen(card_data: CardData) -> void:
	if _picked:
		return
	_picked = true
	AudioManager.play(AudioManager.CONFIRM)
	CampaignContext.run.add_card_to_board(card_data)
	_choice_index += 1
	if _choice_index >= CampaignBoardBuild.CHOICE_COUNT:
		get_tree().change_scene_to_file(CAMPAIGN_MAP_SCENE)
	else:
		_show_next_choice()
