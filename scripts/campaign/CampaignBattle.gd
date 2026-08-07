extends Control

# Combat auto-battler de campagne (CAMPAIGN.md « Système de combat ») : pas de
# main/mana/pioche, les deux plateaux sont posés avant le combat, puis
# alternance stricte joueur/adversaire, 1 tour = 1 attaque (+ bonus CHARGE).
# Scène volontairement légère par rapport à Battle.gd (~950 lignes, main/mana/
# deck/coût) : réutilise directement CombatSystem/DeathSystem/TriggerSystem/
# EnchantmentSystem/SelectionSystem (déjà indépendants de la main, confirmés
# par exploration), sans jamais instancier DeckSystem/CardSystem/CostSystem/
# DropSystem/Hand.
#
# Simplifications assumées pour ce combat auto-battler (voir CAMPAIGN.md,
# aucune ne bloque la jouabilité) :
# - Pas de ciblage interactif pour les effets déclenchés d'Enchantement/Rituel
#   sans cible déjà résolue par le trigger (comportement déjà celui du moteur
#   partagé : EffectManager._get_targets avertit et ignore l'effet si
#   selected_target est null pour un effet à cible unique non pré-résolue).
# - "1 tour = 1 attaque obligatoire" n'est pas strictement forcé : le joueur
#   peut terminer son tour sans avoir attaqué (évite un soft-lock si aucun
#   attaquant n'est valide, plus simple qu'une détection au cas par cas).
# - Un plateau vide rend le héros directement attaquable (get_attackable_enemy_
#   minions déjà réutilisé tel quel) sans vérifier la présence d'un
#   enchantement/rituel capable d'invoquer (CAMPAIGN.md l'évoque ; complexité
#   non justifiée pour la fréquence attendue des Reliques d'invocation en v1).

const ROW_FRONT := "Front"
const ROW_BACK := "Back"
const MAX_MINIONS_PER_ROW := 10
const CAMPAIGN_REWARD_SCENE := "res://scenes/campaign/CampaignRewardScreen.tscn"
const CAMPAIGN_END_SCENE := "res://scenes/campaign/CampaignEndScreen.tscn"
const MAIN_MENU_SCENE := "res://scenes/mainMenu/MainMenu.tscn"

# ─── État de combat (mêmes noms que Battle.gd pour que les systèmes partagés
# fonctionnent sans modification — voir CombatSystem/DeathSystem/AuraSystem...) ─
var player_hero: Hero
var enemy_hero: Hero
var player_minions: Array[Minion] = []
var enemy_minions: Array[Minion] = []
var player_graveyard := Graveyard.new()
var enemy_graveyard := Graveyard.new()
var game_over: bool = false
var reconnecting: bool = false
var enemy_turn_active: bool = false
var waiting_for_target: bool = false
var counter_offensive: Dictionary = {true: false, false: false}
var undead_ally_deaths_this_turn: Dictionary = {true: 0, false: 0}
var net_emitter = null
var net_registry := NetRegistry.new()
var network_manager = null
var tutorial_manager = null
var game_rng := RandomNumberGenerator.new()

# ─── Systèmes réutilisés du moteur de combat classique ────────────────────────
var combat_system := CombatSystem.new()
var death_system := DeathSystem.new()
var targeting_system := TargetingSystem.new()
var selection_system := SelectionSystem.new()
var trigger_system: TriggerSystem
var enchantment_system = load("res://scripts/systems/EnchantmentSystem.gd").new()
var aura_system := AuraSystem.new()
var board_visual_system := BoardVisualSystem.new()
var animation_system := AnimationSystem.new()
var hero_system := HeroSystem.new()
var board_system := BoardSystem.new()
var combat_log := CombatLogSystem.new()
var card_popup_system: CardPopupSystem
var sacrifice_system := SacrificeSystem.new()
var fusion_system := FusionSystem.new()
var temp_effect_system := TempEffectSystem.new()
var effect_manager := EffectManager.new()
# Instance IA réutilisée uniquement pour ses méthodes pures de décision
# d'attaque (_pick_attack_target, _attack_phase...) — jamais setup()/_build_deck().
var ai_system: AISystem

# ─── Conteneurs de plateau (construits en code, voir _build_ui) ───────────────
var player_front_container: HBoxContainer
var player_back_container: HBoxContainer
var enemy_front_container: HBoxContainer
var enemy_back_container: HBoxContainer
var player_enchantment_zone: HBoxContainer
var enemy_enchantment_zone: HBoxContainer
var player_ritual_zone: HBoxContainer
var enemy_ritual_zone: HBoxContainer
var player_resource_zone: HBoxContainer
var enemy_resource_zone: HBoxContainer
var _end_turn_button: Button
var _status_label: Label

var _run: CampaignRun
var _node: CampaignMapNode
var _player_turn_active := false
var _player_has_attacked := false
var _end_turn_requested := false

func _ready() -> void:
	if not CampaignContext.active or CampaignContext.run == null:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		return
	_run = CampaignContext.run
	_node = _run.current_node()
	AudioManager.play_battle_music()
	_init_data()
	_init_systems()
	_build_ui()
	await _start_game()

func _init_data() -> void:
	player_hero = Hero.new(_run.hero_max_health)
	player_hero.health = _run.hero_health
	enemy_hero = Hero.new(CampaignOpponentFactory.hero_health_for(_run, _node))
	game_rng.randomize()

func _init_systems() -> void:
	trigger_system = TriggerSystem.new()
	trigger_system.init(self)
	combat_system.init(self)
	death_system.init(self)
	targeting_system.init(self)
	selection_system.init(self)
	enchantment_system.init(self)
	aura_system.init(self)
	board_visual_system.init(self)
	animation_system.init(self)
	hero_system.init(self)
	board_system.init(self)
	combat_log.init(self)
	sacrifice_system.init(self)
	fusion_system.init(self)
	temp_effect_system.init(self)
	card_popup_system = CardPopupSystem.new()
	card_popup_system.init(self)
	# Même sous-ensemble que Battle.gd::_init_systems() : seuls ces systèmes
	# sont réellement ajoutés à l'arbre (les autres, Node ou RefCounted, ne
	# font jamais appel à self.get_tree()/self._ready(), juste battle.get_tree()).
	add_child(trigger_system)
	add_child(enchantment_system)
	add_child(targeting_system)
	add_child(sacrifice_system)
	add_child(fusion_system)
	ai_system = AISystem.new()
	add_child(ai_system)
	ai_system.init(self)

func _start_game() -> void:
	# Adversaire déjà figé par CampaignMapScreen avant d'entrer en combat
	# (sauvegarde de run) — sinon (lancement direct hors du flux normal, ex.
	# tests) on le génère à la volée.
	var enemy_board: Array[CardData] = _run.pending_enemy_board if not _run.pending_enemy_board.is_empty() \
		else CampaignOpponentFactory.generate_board(_run, _node)
	_run.pending_enemy_board = []
	var stat_multiplier := CampaignOpponentFactory.stat_multiplier_for(_run, _node)

	for entry in _run.board_with_rows():
		await board_system.summon_minion(entry["card"], true, entry["row"], -1, true)

	for card in enemy_board:
		var allowed := get_allowed_rows_for_card(card)
		var row: String = allowed[game_rng.randi_range(0, allowed.size() - 1)]
		await board_system.summon_minion(card, false, row, -1, true)
	for minion in enemy_minions:
		minion.base_attack = int(ceil(minion.base_attack * stat_multiplier))
		minion.base_max_health = int(ceil(minion.base_max_health * stat_multiplier))
	board_visual_system.refresh_board()
	hero_system.update_ui()

	check_game_end()
	if not game_over:
		await _run_combat_loop()

# ─── Boucle de combat : alternance stricte, 1 tour = 1 attaque (+ CHARGE) ─────
func _run_combat_loop() -> void:
	var is_player_turn := true
	while not game_over:
		await _run_half_turn(is_player_turn)
		if game_over:
			break
		is_player_turn = not is_player_turn

func _run_half_turn(is_player: bool) -> void:
	var acting_minions := player_minions if is_player else enemy_minions
	for minion in acting_minions.duplicate():
		minion.refresh_attacks()
		# CHARGE (règle Campagne, voir en-tête de fichier) : une attaque bonus
		# en plus de l'attaque normale, répétable tant que le serviteur est
		# vivant — logique locale à ce script, ne touche pas Minion.gd/
		# CombatSystem partagés avec la partie rapide/le multijoueur.
		if minion.has_keyword(Keyword.Type.CHARGE):
			minion.attacks_remaining += 1
	aura_system.recompute_all()
	await death_system.process_deaths()
	trigger_system.reset_once_per_turn(is_player)
	await trigger_system.fire("OnAwaken", null, is_player)
	if game_over:
		return
	await trigger_system.fire("OnDecline", null, not is_player)
	if game_over:
		return
	board_visual_system.refresh_board()
	_update_status(is_player)

	if is_player:
		await _run_player_turn()
	else:
		enemy_turn_active = true
		await ai_system._attack_phase(false)
		enemy_turn_active = false

	if game_over:
		return
	await _run_end_of_turn(is_player)

func _run_player_turn() -> void:
	_player_turn_active = true
	_player_has_attacked = false
	_end_turn_requested = false
	enemy_turn_active = false
	_end_turn_button.disabled = false
	_end_turn_button.show()
	while not _end_turn_requested and not game_over:
		await get_tree().process_frame
	_end_turn_button.hide()
	_player_turn_active = false

func _on_end_turn_pressed() -> void:
	_end_turn_requested = true

func _run_end_of_turn(is_player: bool) -> void:
	var turn_hero: Hero = player_hero if is_player else enemy_hero
	turn_hero.heal_block_turns = max(turn_hero.heal_block_turns - 1, 0)
	var any_infected := false
	for minion in (player_minions + enemy_minions).duplicate():
		if minion.infected:
			any_infected = true
			var dealt: int = minion.take_damage(1)
			if dealt > 0:
				combat_log.infection_tick(minion)
				var visual: BoardMinion = board_visual_system.get_visual(minion)
				if visual:
					animation_system.play_infection_tick(visual, dealt)
				await effect_manager.notify_damaged(self, minion)
	await death_system.process_deaths()
	board_visual_system.refresh_board()
	if any_infected:
		await pace_actions()
	check_game_end()

# ─── Fin de combat ────────────────────────────────────────────────────────────

func check_game_end() -> void:
	if game_over:
		return
	if enemy_hero.is_dead() or player_hero.is_dead():
		game_over = true
		_finish_combat("defeat" if player_hero.is_dead() else "victory")

func _finish_combat(result: String) -> void:
	# Synchronise le plateau de la run avec les survivants : les morts en
	# combat de campagne sont définitives (CAMPAIGN.md « Mort en combat »).
	var surviving_board: Array[CardData] = []
	for minion in player_minions:
		surviving_board.append(minion.card_data)
	_run.board = surviving_board
	if result == "victory":
		_run.hero_health = max(1, player_hero.health)
		_run.gold += CampaignGold.reward_for_node(_node)
		match _node.type:
			CampaignMapNode.NodeType.ELITE:
				_run.elite_wins += 1
			CampaignMapNode.NodeType.BOSS:
				_run.boss_wins += 1
		_run.mark_node_cleared(_run.current_node_id)
		# Récompense proposée générée ET sauvegardée dès la victoire
		# (CAMPAIGN.md « Sauvegarde de run ») : le joueur retrouve le même
		# choix de 3 cartes s'il ferme le jeu avant d'avoir choisi.
		_run.pending_reward_cards = CampaignRewardPicker.pick_three(_run.race, _run.rng)
		CampaignSaveService.save(_run)
		AudioManager.play(AudioManager.OPEN_MENU)
		get_tree().change_scene_to_file(CAMPAIGN_REWARD_SCENE)
	else:
		AudioManager.play(AudioManager.OPEN_MENU)
		get_tree().change_scene_to_file(CAMPAIGN_END_SCENE)

func pace_actions(delay: float = 0.5) -> void:
	await get_tree().create_timer(delay).timeout

func destroy_minion(target: Minion) -> void:
	await death_system.destroy(target)

# Délégation attendue par EffectManager (SummonMinion/SummonRandom/SummonSelf...).
func summon_minion(card_data: CardData, is_player: bool, row := "Front", insert_index := -1, skip_onplay := false) -> void:
	await board_system.summon_minion(card_data, is_player, row, insert_index, skip_onplay)

# Pas de bouton "Fin du tour" avec indicateur "prêt" façon partie rapide : le
# bouton Terminer le tour de la Campagne est toujours cliquable (voir
# _run_player_turn). No-op attendu par BoardVisualSystem.spawn_minion_visual.
func update_end_turn_hint() -> void:
	pass

# ─── Règles de plateau/attaque (copiées de Battle.gd, logique pure) ───────────

func get_owner_minions(minion: Minion) -> Array[Minion]:
	if minion == null:
		return player_minions
	return player_minions if minion.owner_is_player else enemy_minions

func get_enemy_minions(minion: Minion) -> Array[Minion]:
	if minion == null:
		return enemy_minions
	return enemy_minions if minion.owner_is_player else player_minions

func get_row_minions(is_player: bool, row: String) -> Array[Minion]:
	var source: Array[Minion] = player_minions if is_player else enemy_minions
	return source.filter(func(m: Minion): return m.board_row == row)

func get_front_minions(is_player: bool) -> Array[Minion]:
	return get_row_minions(is_player, ROW_FRONT)

func get_back_minions(is_player: bool) -> Array[Minion]:
	return get_row_minions(is_player, ROW_BACK)

func can_summon_to_row(is_player: bool, row: String) -> bool:
	return get_row_minions(is_player, row).size() < MAX_MINIONS_PER_ROW

func get_allowed_rows_for_card(card_data: CardData) -> Array[String]:
	if card_data == null or card_data.card_type != "Minion":
		return [ROW_FRONT, ROW_BACK]
	match card_data.board_position:
		ROW_FRONT: return [ROW_FRONT]
		ROW_BACK:  return [ROW_BACK]
		_:         return [ROW_FRONT, ROW_BACK]

func has_enemy_taunt(attacker: Minion) -> bool:
	var attackable: Array[Minion] = get_attackable_enemy_minions(attacker)
	for minion in attackable:
		if minion.has_keyword(Keyword.Type.TAUNT):
			return true
	return false

func get_attackable_enemy_minions(attacker: Minion) -> Array[Minion]:
	var defending_is_player: bool = attacker != null and not attacker.owner_is_player
	var defenders: Array[Minion] = player_minions if defending_is_player else enemy_minions
	if attacker and attacker.has_keyword(Keyword.Type.BLACK_WINGS):
		return defenders
	var front: Array[Minion] = get_front_minions(defending_is_player)
	if not front.is_empty():
		return front
	return defenders

func _can_attack_minion_target(attacker: Minion, target: Minion) -> bool:
	if target not in get_attackable_enemy_minions(attacker):
		return false
	if has_enemy_taunt(attacker) and not target.has_keyword(Keyword.Type.TAUNT):
		return false
	return true

func _can_attack_hero(attacker: Minion) -> bool:
	if attacker.card_data != null and attacker.card_data.cannot_attack_hero:
		return false
	if has_enemy_taunt(attacker):
		return false
	var defending_is_player: bool = not attacker.owner_is_player
	return attacker.has_keyword(Keyword.Type.BLACK_WINGS) or get_front_minions(defending_is_player).is_empty()

# ─── Construction de l'UI (procédurale, pas de .tscn détaillé — voir plan) ────

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("14141fdd")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root_margin := MarginContainer.new()
	root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 30)
	root_margin.add_theme_constant_override("margin_right", 30)
	root_margin.add_theme_constant_override("margin_top", 20)
	root_margin.add_theme_constant_override("margin_bottom", 20)
	add_child(root_margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	root_margin.add_child(vbox)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 22)
	_status_label.add_theme_color_override("font_color", Color("f0c040"))
	vbox.add_child(_status_label)

	var enemy_hero_panel := _make_hero_panel("EnemyHeroPanel", true)
	add_child(enemy_hero_panel)
	enemy_hero_panel.hero_clicked.connect(selection_system.on_enemy_hero_clicked)
	enemy_hero_panel.hero_clicked.connect(func(): targeting_system.on_enemy_hero_clicked())

	enemy_back_container = _make_row("EnemyBack")
	vbox.add_child(enemy_back_container)
	enemy_front_container = _make_row("EnemyFront")
	vbox.add_child(enemy_front_container)

	var enemy_zones := HBoxContainer.new()
	enemy_zones.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_enchantment_zone = _make_zone("EnemyEnchantmentZone")
	enemy_ritual_zone = _make_zone("EnemyRitualZone")
	enemy_resource_zone = _make_zone("EnemyResourceZone")
	enemy_zones.add_child(enemy_enchantment_zone)
	enemy_zones.add_child(enemy_ritual_zone)
	vbox.add_child(enemy_zones)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	player_front_container = _make_row("PlayerFront")
	vbox.add_child(player_front_container)
	player_back_container = _make_row("PlayerBack")
	vbox.add_child(player_back_container)

	var player_zones := HBoxContainer.new()
	player_zones.alignment = BoxContainer.ALIGNMENT_CENTER
	player_enchantment_zone = _make_zone("PlayerEnchantmentZone")
	player_ritual_zone = _make_zone("PlayerRitualZone")
	player_resource_zone = _make_zone("PlayerResourceZone")
	player_zones.add_child(player_enchantment_zone)
	player_zones.add_child(player_ritual_zone)
	vbox.add_child(player_zones)

	var player_hero_panel := _make_hero_panel("PlayerHeroPanel", false)
	add_child(player_hero_panel)

	_end_turn_button = Button.new()
	_end_turn_button.text = SettingsManager.t("CAMPAIGN_BATTLE_END_TURN")
	_end_turn_button.custom_minimum_size = Vector2(180, 44)
	_end_turn_button.hide()
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	vbox.add_child(_end_turn_button)

func _make_hero_panel(node_name: String, is_top: bool) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	panel.set_script(load("res://scripts/hero/HeroPanel.gd"))
	panel.custom_minimum_size = Vector2(90, 90)
	panel.size = Vector2(90, 90)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -45
	panel.offset_right = 45
	if is_top:
		panel.offset_top = 8
		panel.offset_bottom = 98
	else:
		panel.anchor_top = 1.0
		panel.anchor_bottom = 1.0
		panel.offset_top = -98
		panel.offset_bottom = -8
	var label := Label.new()
	label.name = "HealthLabel"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	panel.add_child(label)
	return panel

func _make_row(node_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = node_name
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 150)
	return row

func _make_zone(node_name: String) -> HBoxContainer:
	var zone := HBoxContainer.new()
	zone.name = node_name
	zone.custom_minimum_size = Vector2(400, 90)
	zone.alignment = BoxContainer.ALIGNMENT_CENTER
	return zone

func _update_status(is_player: bool) -> void:
	_status_label.text = SettingsManager.t("CAMPAIGN_BATTLE_YOUR_TURN" if is_player else "CAMPAIGN_BATTLE_ENEMY_TURN")
