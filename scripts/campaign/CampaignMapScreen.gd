extends Control

# Carte de run : un palier par rangée (haut = départ, bas = boss), seuls les
# nœuds accessibles depuis la position actuelle sont cliquables. Re-render
# entièrement à chaque _ready() depuis CampaignContext.run (pas d'état local
# perdu entre deux passages, ni pour un combat gagné, ni pour un nœud repos/
# événement/boutique).

const BATTLE_SCENE       := "res://scenes/campaign/CampaignBattle.tscn"
const CAMPAIGN_REST_SCENE  := "res://scenes/campaign/CampaignRestScreen.tscn"
const CAMPAIGN_EVENT_SCENE := "res://scenes/campaign/CampaignEventScreen.tscn"
const CAMPAIGN_REWARD_SCENE := "res://scenes/campaign/CampaignRewardScreen.tscn"
const CAMPAIGN_SHOP_SCENE := "res://scenes/campaign/CampaignShopScreen.tscn"
const CAMPAIGN_RELIC_SCENE := "res://scenes/campaign/CampaignRelicScreen.tscn"
const MAIN_MENU_SCENE     := "res://scenes/mainMenu/MainMenu.tscn"

const NODE_TYPE_KEYS := {
	CampaignMapNode.NodeType.COMBAT: "CAMPAIGN_NODE_COMBAT",
	CampaignMapNode.NodeType.ELITE:  "CAMPAIGN_NODE_ELITE",
	CampaignMapNode.NodeType.EVENT:  "CAMPAIGN_NODE_EVENT",
	CampaignMapNode.NodeType.SHOP:   "CAMPAIGN_NODE_SHOP",
	CampaignMapNode.NodeType.REST:   "CAMPAIGN_NODE_REST",
	CampaignMapNode.NodeType.BOSS:   "CAMPAIGN_NODE_BOSS",
	CampaignMapNode.NodeType.RELIC:  "CAMPAIGN_NODE_RELIC",
}

# Carte générée par fenêtre glissante (CampaignMapGenerator) : étend la carte
# automatiquement quand le joueur s'approche du bord déjà généré, pour
# préserver l'illusion d'une run sans fin sans jamais stocker un graphe infini.
const EXTEND_LOOKAHEAD_THRESHOLD := 5

func _ready() -> void:
	if not CampaignContext.active or CampaignContext.run == null:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		return

	add_child(CampaignUI.make_background())
	var run := CampaignContext.run
	_ensure_map_lookahead(run)

	var root_margin := MarginContainer.new()
	root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 40)
	root_margin.add_theme_constant_override("margin_right", 40)
	root_margin.add_theme_constant_override("margin_top", 24)
	root_margin.add_theme_constant_override("margin_bottom", 24)
	add_child(root_margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 16)
	root_margin.add_child(main_vbox)

	var header := HBoxContainer.new()
	main_vbox.add_child(header)
	var title := CampaignUI.make_title_label(SettingsManager.t("CAMPAIGN_MAP_TITLE"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var hp_label := CampaignUI.make_body_label("%s : %d / %d    %s : %d" % [
		SettingsManager.t("CAMPAIGN_HP_LABEL"), run.hero_health, run.hero_max_health,
		SettingsManager.t("CAMPAIGN_GOLD_LABEL"), run.gold])
	header.add_child(hp_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	var layers_vbox := VBoxContainer.new()
	layers_vbox.add_theme_constant_override("separation", 24)
	layers_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(layers_vbox)

	var accessible: Array = run.accessible_node_ids()
	var by_depth: Dictionary = {}
	var max_depth := 0
	for node in run.map:
		if not by_depth.has(node.depth):
			by_depth[node.depth] = []
		by_depth[node.depth].append(node)
		max_depth = max(max_depth, node.depth)

	for depth in range(1, max_depth + 1):
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 16)
		layers_vbox.add_child(row)
		for node in by_depth.get(depth, []):
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(140, 56)
			btn.text = SettingsManager.t(NODE_TYPE_KEYS.get(node.type, ""))
			CampaignUI.style_button(btn)
			var is_accessible: bool = node.id in accessible
			btn.disabled = not is_accessible
			if node.cleared:
				btn.modulate = Color(0.5, 0.5, 0.5, 1.0)
				btn.disabled = true
			elif is_accessible:
				btn.add_theme_color_override("font_color", Color("f0c040"))
			var node_id: int = node.id
			btn.pressed.connect(func(): _select_node(node_id))
			row.add_child(btn)

	var abandon_button := Button.new()
	abandon_button.text = SettingsManager.t("CAMPAIGN_ABANDON")
	CampaignUI.style_button(abandon_button)
	abandon_button.pressed.connect(func():
		CampaignSaveService.clear()
		CampaignContext.clear()
		get_tree().change_scene_to_file(MAIN_MENU_SCENE))
	main_vbox.add_child(abandon_button)

func _select_node(node_id: int) -> void:
	var run := CampaignContext.run
	run.current_node_id = node_id
	var node := run.current_node()
	AudioManager.play(AudioManager.OPEN_MENU)
	match node.type:
		CampaignMapNode.NodeType.COMBAT, CampaignMapNode.NodeType.ELITE, CampaignMapNode.NodeType.BOSS:
			# Adversaire figé + sauvegarde AVANT d'engager le combat
			# (CAMPAIGN.md « Sauvegarde de run ») : une relance après
			# fermeture du jeu retrouve exactement le même adversaire.
			run.pending_enemy_board = CampaignOpponentFactory.generate_board(run, node)
			CampaignSaveService.save(run)
			get_tree().change_scene_to_file(BATTLE_SCENE)
		CampaignMapNode.NodeType.REST:
			get_tree().change_scene_to_file(CAMPAIGN_REST_SCENE)
		CampaignMapNode.NodeType.SHOP:
			get_tree().change_scene_to_file(CAMPAIGN_SHOP_SCENE)
		CampaignMapNode.NodeType.EVENT:
			get_tree().change_scene_to_file(CAMPAIGN_EVENT_SCENE)
		CampaignMapNode.NodeType.RELIC:
			get_tree().change_scene_to_file(CAMPAIGN_RELIC_SCENE)

func _ensure_map_lookahead(run: CampaignRun) -> void:
	var max_depth := 0
	for node in run.map:
		max_depth = max(max_depth, node.depth)
	if max_depth - run.depth < EXTEND_LOOKAHEAD_THRESHOLD:
		CampaignMapGenerator.extend(run)
