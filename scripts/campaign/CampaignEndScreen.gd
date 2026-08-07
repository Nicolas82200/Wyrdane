extends Control

# Fin de run : uniquement la défaite (mort du héros) — la run n'a pas de
# "victoire" au sens classique (CAMPAIGN.md : run sans fin, le Boss récurrent
# n'est plus une fin de run). Style visuel calqué sur GameOverScreen (pas
# d'héritage : GameOverScreen est trop couplé à Battle/réseau).

const MAIN_MENU_SCENE := "res://scenes/mainMenu/MainMenu.tscn"
const TITLE_DEFEAT_COLOR := Color(0.85, 0.25, 0.2)

func _ready() -> void:
	add_child(CampaignUI.make_background())
	var run: CampaignRun = CampaignContext.run

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	CampaignUI.style_panel(panel)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title := CampaignUI.make_title_label(SettingsManager.t("CAMPAIGN_END_DEFEAT_TITLE"))
	title.add_theme_color_override("font_color", TITLE_DEFEAT_COLOR)
	vbox.add_child(title)

	var reward_amount := 0
	if run != null:
		vbox.add_child(CampaignUI.make_body_label(SettingsManager.t("CAMPAIGN_END_DEPTH_REACHED") % run.depth))
		reward_amount = CampaignConsolationReward.compute(run)

	if reward_amount > 0:
		vbox.add_child(CampaignUI.make_body_label(SettingsManager.t("CAMPAIGN_END_CONSOLATION_REWARD") % reward_amount))

	var menu_button := Button.new()
	menu_button.text = SettingsManager.t("battle.gameover.menu")
	CampaignUI.style_button(menu_button)
	menu_button.pressed.connect(_on_menu_pressed)
	vbox.add_child(menu_button)

	AudioManager.play(AudioManager.OPEN_MENU)
	# Une seule récompense de fin de run (consolation de défaite) — jamais par
	# combat individuel (voir CampaignBattle.gd).
	CurrencyManager.report_solo_match_result(false, func(_credited: bool): pass)

func _on_menu_pressed() -> void:
	CampaignSaveService.clear()
	CampaignContext.clear()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
