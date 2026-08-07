extends Control

# Choix d'une carte parmi 3 après un combat gagné (Serviteurs uniquement — les
# Enchantements/Rituels sont des Reliques, obtenues via le nœud Relique ou la
# Boutique, jamais ce choix classique, voir CampaignRewardPicker).
# Inspiré de PackShop.gd pour la présentation (réutilise le composant Card),
# mais interaction plus simple : 3 cartes déjà visibles, cliquables, un seul
# choix retenu (comme Slay the Spire), pas d'animation d'ouverture de pack.

const CARD_SCENE := preload("res://scenes/card/Card.tscn")
const CARD_BASE_SIZE := Vector2(250, 375)
const CARD_DISPLAY_SCALE := 0.8
const CAMPAIGN_MAP_SCENE := "res://scenes/campaign/CampaignMapScreen.tscn"
const MAIN_MENU_SCENE := "res://scenes/mainMenu/MainMenu.tscn"

var _picked := false

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

	vbox.add_child(CampaignUI.make_title_label(SettingsManager.t("CAMPAIGN_REWARD_TITLE")))
	vbox.add_child(CampaignUI.make_body_label(SettingsManager.t("CAMPAIGN_REWARD_BODY")))

	# Réutilise le choix déjà tiré/sauvegardé par CampaignBattle._finish_combat
	# si présent (reprise après fermeture du jeu sur cet écran) — sinon (accès
	# direct hors du flux normal) tire un nouveau choix.
	var candidates: Array[CardData] = run.pending_reward_cards if not run.pending_reward_cards.is_empty() \
		else CampaignRewardPicker.pick_three(run.race, run.rng)

	var cards_box := HBoxContainer.new()
	cards_box.add_theme_constant_override("separation", 20)
	cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(cards_box)

	for card_data in candidates:
		_add_card_option(cards_box, card_data)

	var skip_button := Button.new()
	skip_button.text = SettingsManager.t("CAMPAIGN_REWARD_SKIP")
	CampaignUI.style_button(skip_button)
	skip_button.pressed.connect(func(): _finish())
	vbox.add_child(skip_button)

# Chaque conteneur est attaché à l'arbre AVANT d'y ajouter l'enfant suivant :
# Card.gd s'appuie sur des @onready résolus dans son _ready(), qui ne se
# déclenche qu'une fois le nœud effectivement dans l'arbre — set_data() sur
# une carte encore détachée plante sur des labels @onready à null (voir
# DeckBuilder._create_card_visual, même pattern add_child-avant-set_data).
func _add_card_option(cards_box: HBoxContainer, card_data: CardData) -> void:
	var option_vbox := VBoxContainer.new()
	option_vbox.add_theme_constant_override("separation", 8)
	cards_box.add_child(option_vbox)

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
	CampaignContext.run.add_card_to_board(card_data)
	_finish()

func _finish() -> void:
	if _picked:
		AudioManager.play(AudioManager.CONFIRM)
	var run := CampaignContext.run
	if run.current_node_id != -1:
		run.mark_node_cleared(run.current_node_id)
	run.pending_reward_cards = []
	get_tree().change_scene_to_file(CAMPAIGN_MAP_SCENE)
