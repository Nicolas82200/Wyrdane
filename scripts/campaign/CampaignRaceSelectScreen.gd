extends Control

# Écran d'entrée du mode Campagne : choix de la race, génère la carte de run
# (sans fin, voir CampaignMapGenerator) et la race adverse de la première
# tranche de 10 paliers, active CampaignContext, puis va vers l'écran de
# constitution du plateau (5 choix de carte, pas de deck/pioche en Campagne).

const CAMPAIGN_BOARD_BUILD_SCENE := "res://scenes/campaign/CampaignBoardBuildScreen.tscn"
const CAMPAIGN_MAP_SCENE := "res://scenes/campaign/CampaignMapScreen.tscn"
const MAIN_MENU_SCENE := "res://scenes/mainMenu/MainMenu.tscn"

var _selected_race: int = Race.Type.NONE
var _race_buttons: Dictionary = {}
var _launch_button: Button

func _ready() -> void:
	CardLibrary.load_all_cards()
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

	if CampaignSaveService.has_save():
		_build_resume_ui(vbox)
		return
	_build_race_select_ui(vbox)

func _build_resume_ui(vbox: VBoxContainer) -> void:
	vbox.add_child(CampaignUI.make_title_label(SettingsManager.t("CAMPAIGN_RESUME_TITLE")))
	vbox.add_child(CampaignUI.make_body_label(SettingsManager.t("CAMPAIGN_RESUME_BODY")))

	var buttons_box := HBoxContainer.new()
	buttons_box.add_theme_constant_override("separation", 12)
	buttons_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(buttons_box)

	var resume_button := Button.new()
	resume_button.text = SettingsManager.t("CAMPAIGN_RESUME_CONTINUE")
	CampaignUI.style_button(resume_button)
	resume_button.pressed.connect(func():
		CampaignContext.run = CampaignSaveService.load_run()
		CampaignContext.active = true
		AudioManager.play(AudioManager.OPEN_MENU)
		get_tree().change_scene_to_file(CAMPAIGN_MAP_SCENE))
	buttons_box.add_child(resume_button)

	var new_run_button := Button.new()
	new_run_button.text = SettingsManager.t("CAMPAIGN_RESUME_NEW_RUN")
	CampaignUI.style_button(new_run_button)
	new_run_button.pressed.connect(func():
		CampaignSaveService.clear()
		for child in vbox.get_children():
			child.queue_free()
		_build_race_select_ui(vbox))
	buttons_box.add_child(new_run_button)

func _build_race_select_ui(vbox: VBoxContainer) -> void:
	vbox.add_child(CampaignUI.make_title_label(SettingsManager.t("CAMPAIGN_RACE_SELECT_TITLE")))
	vbox.add_child(CampaignUI.make_body_label(SettingsManager.t("CAMPAIGN_RACE_SELECT_BODY")))

	var race_box := HBoxContainer.new()
	race_box.add_theme_constant_override("separation", 12)
	race_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(race_box)

	for race in Race.get_implemented_races():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 60)
		btn.text = SettingsManager.t(ManaDisplay.RACE_TRANSLATION_KEYS.get(race, ""))
		btn.toggle_mode = true
		CampaignUI.style_button(btn)
		btn.add_theme_color_override("font_color", ManaDisplay.RACE_MANA_COLORS.get(race, CampaignUI.TITLE_COLOR))
		btn.pressed.connect(func(): _select_race(race))
		race_box.add_child(btn)
		_race_buttons[race] = btn

	var buttons_box := HBoxContainer.new()
	buttons_box.add_theme_constant_override("separation", 12)
	buttons_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(buttons_box)

	var back_button := Button.new()
	back_button.text = SettingsManager.t("CAMPAIGN_BACK")
	CampaignUI.style_button(back_button)
	back_button.pressed.connect(func():
		AudioManager.play(AudioManager.OPEN_MENU)
		get_tree().change_scene_to_file(MAIN_MENU_SCENE))
	buttons_box.add_child(back_button)

	_launch_button = Button.new()
	_launch_button.text = SettingsManager.t("CAMPAIGN_RACE_SELECT_LAUNCH")
	_launch_button.disabled = true
	CampaignUI.style_button(_launch_button)
	_launch_button.pressed.connect(_launch_run)
	buttons_box.add_child(_launch_button)

func _select_race(race: int) -> void:
	_selected_race = race
	for r in _race_buttons:
		_race_buttons[r].button_pressed = (r == race)
	_launch_button.disabled = false
	AudioManager.play(AudioManager.BUTTON)

func _launch_run() -> void:
	if _selected_race == Race.Type.NONE:
		return
	var run := CampaignRun.new()
	run.race = _selected_race
	run.rng_seed = randi()
	run.rng.seed = run.rng_seed
	run.hero_max_health = 30
	run.hero_health = 30
	# run.tier_race est tiré à la volée par CampaignOpponentFactory.ensure_tier_race
	# au premier combat (tier_index = -1 par défaut).
	var generated := CampaignMapGenerator.generate(run.rng)
	run.map = generated["nodes"]
	run.start_node_ids = generated["start_ids"]
	CampaignContext.run = run
	CampaignContext.active = true
	AudioManager.play(AudioManager.OPEN_MENU)
	get_tree().change_scene_to_file(CAMPAIGN_BOARD_BUILD_SCENE)
