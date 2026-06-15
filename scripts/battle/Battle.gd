extends Control

const EffectManagerData = preload("res://scripts/EffectManager/EffectManager.gd")
const BOARD_MINION_SCENE = preload("res://scenes/minion/BoardMinion.tscn")

@onready var hand = $Hand
@onready var mana_label = $ManaLabel
@onready var end_turn_button = $EndTurnButton
@onready var enemy_container = $Board/EnemyMinionsContainer
@onready var player_container = $Board/PlayerMinionsContainer

var player_minions: Array[Minion] = []
var enemy_minions: Array[Minion] = []

var selected_attacker: Minion = null
var selected_board_minion: BoardMinion = null
var pending_card: CardData = null
var waiting_for_target := false

var deck: Array[CardData] = []
var hand_cards: Array[CardData] = []

var mana := 3
var max_mana := 3
var player_hero: Hero
var enemy_hero: Hero
var game_over := false


func _ready() -> void:
	load_deck()
	var enemy_card = load("res://resources/cards/undead/decaying-crawler.tres")
	enemy_minions.append(Minion.new(enemy_card, false))

	player_hero = Hero.new(30)
	enemy_hero = Hero.new(30)

	hand.card_played.connect(_on_card_played)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	$EnemyHeroPanel.hero_clicked.connect(_on_enemy_hero_clicked)

	update_mana_ui()
	update_hero_ui()
	refresh_board()
	start_game()


func load_deck() -> void:
	var card = load("res://resources/cards/undead/zombie-banshe.tres")
	deck = []
	for i in range(10):
		deck.append(card)


func start_game() -> void:
	deck.shuffle()
	for i in range(5):
		draw_card()
	hand.set_hand(hand_cards)


func draw_card() -> void:
	if deck.is_empty():
		# TODO: fatigue damage au héros
		return
	hand_cards.append(deck.pop_back())


# ─── Mana ─────────────────────────────────────────────────────────────────────

func update_mana_ui() -> void:
	mana_label.text = "%d/%d" % [mana, max_mana]


# ─── Héros ────────────────────────────────────────────────────────────────────

func get_owner_hero(minion: Minion) -> Hero:
	if minion == null:
		return player_hero
	return player_hero if minion.owner_is_player else enemy_hero

func get_enemy_hero(minion: Minion) -> Hero:
	if minion == null:
		return enemy_hero
	return enemy_hero if minion.owner_is_player else player_hero

func damage_hero(hero: Hero, damage: int) -> void:
	hero.take_damage(damage)
	update_hero_ui()
	check_game_end()

func update_hero_ui() -> void:
	$PlayerHeroPanel/HealthLabel.text = str(maxi(player_hero.health, 0))
	$EnemyHeroPanel/HealthLabel.text = str(maxi(enemy_hero.health, 0))


# ─── Serviteurs ───────────────────────────────────────────────────────────────

func get_owner_minions(minion: Minion) -> Array[Minion]:
	return player_minions if minion.owner_is_player else enemy_minions

func get_enemy_minions(minion: Minion) -> Array[Minion]:
	return enemy_minions if minion.owner_is_player else player_minions

func summon_minion(card_data: CardData, is_player: bool = true) -> void:
	var minion = Minion.new(card_data, is_player)
	if is_player:
		player_minions.append(minion)
	else:
		enemy_minions.append(minion)
	trigger_effects(minion, "Battlecry")
	refresh_board()

func has_enemy_taunt() -> bool:
	for minion in enemy_minions:
		if minion.has_keyword(
			Keyword.Type.TAUNT
		):
			return true
	return false

func destroy_minion(target: Minion) -> void:
	target.health = 0
	remove_dead_minions()


# ─── Carte jouée ──────────────────────────────────────────────────────────────

func _on_card_played(card_data: CardData) -> void:
	if game_over or card_data.cost > mana:
		return
	if card_data.requires_target:
		pending_card = card_data
		waiting_for_target = true
		return
	play_card(card_data)

func play_card(card_data: CardData) -> void:
	mana -= card_data.cost
	update_mana_ui()
	hand_cards.erase(card_data)
	hand.set_hand(hand_cards)
	if card_data.card_type == "Minion":
		summon_minion(card_data)

func resolve_card_target(target: Minion) -> void:
	if pending_card == null:
		return
	mana -= pending_card.cost
	update_mana_ui()
	for effect in pending_card.effects:
		EffectManagerData.execute_targeted_effect(self, effect, target)
	hand_cards.erase(pending_card)
	hand.set_hand(hand_cards)
	pending_card = null
	waiting_for_target = false
	refresh_board()


# ─── Combat ───────────────────────────────────────────────────────────────────

func resolve_combat(attacker: Minion, defender: Minion) -> void:
	trigger_effects(attacker, "OnAttack")
	defender.take_damage(attacker.attack)
	trigger_effects(defender, "OnDamaged")
	if attacker.has_keyword(
	Keyword.Type.LIFESTEAL):
		get_owner_hero(attacker).heal(attacker.attack)
	attacker.take_damage(defender.attack)
	attacker.attacks_remaining -= 1
	remove_dead_minions()
	update_hero_ui()
	refresh_board()
	check_game_end()

func remove_dead_minions() -> void:
	# Collecter les morts
	var dead_player := player_minions.filter(func(m): return m.is_dead())
	var dead_enemy := enemy_minions.filter(func(m): return m.is_dead())

	# Retirer avant les deathrattles pour éviter des doubles triggers
	player_minions = player_minions.filter(func(m): return not m.is_dead())
	enemy_minions = enemy_minions.filter(func(m): return not m.is_dead())

	# Résoudre tous les deathrattles, puis un seul refresh
	for minion in dead_player:
		trigger_effects(minion, "Deathrattle")
	for minion in dead_enemy:
		trigger_effects(minion, "Deathrattle")

	refresh_board()

func trigger_effects(minion: Minion, trigger_name: String) -> void:
	if minion == null:
		return
	## Support multi-triggers : on vérifie le tableau trigger_types
	if not trigger_name in minion.card_data.trigger_types:
		return
	for effect in minion.card_data.effects:
		EffectManagerData.execute_effect(self, minion, effect)


# ─── Sélection / Clicks ───────────────────────────────────────────────────────

func _on_player_minion_clicked(minion: Minion, board_minion: BoardMinion) -> void:
	if game_over or not minion.can_attack():
		return
	if selected_board_minion:
		selected_board_minion.set_selected(false)
	selected_attacker = minion
	selected_board_minion = board_minion
	selected_board_minion.set_selected(true)

func _on_enemy_minion_clicked(target: Minion, _board_minion: BoardMinion) -> void:
	if game_over:
		return
	if waiting_for_target:
		resolve_card_target(target)
		return
	if selected_attacker == null:
		return
	if has_enemy_taunt() and not target.has_keyword(
	Keyword.Type.TAUNT):
		return
	resolve_combat(selected_attacker, target)
	clear_selection()

func _on_enemy_hero_clicked() -> void:
	if game_over or selected_attacker == null or has_enemy_taunt():
		return
	damage_hero(enemy_hero, selected_attacker.attack)
	if selected_attacker.has_keyword(
	Keyword.Type.LIFESTEAL):
		get_owner_hero(selected_attacker).heal(
		selected_attacker.attack
	)
	selected_attacker.attacks_remaining -= 1
	clear_selection()
	check_game_end()
	refresh_board()

func clear_selection() -> void:
	if selected_board_minion:
		selected_board_minion.set_selected(false)
	selected_board_minion = null
	selected_attacker = null


# ─── Tours ────────────────────────────────────────────────────────────────────

func _on_end_turn_pressed() -> void:
	if game_over:
		return
	end_turn()

func end_turn() -> void:
	for minion in player_minions:
		trigger_effects(minion, "OnTurnEnd")
	start_new_turn()

func start_new_turn() -> void:
	max_mana = mini(max_mana + 1, 10)
	mana = max_mana
	for minion in player_minions:
		minion.refresh_attacks()
		trigger_effects(minion, "OnTurnStart")
	draw_card()
	hand.set_hand(hand_cards)
	update_mana_ui()
	refresh_board()


# ─── Board ────────────────────────────────────────────────────────────────────

func refresh_board() -> void:
	_rebuild_minion_visuals(player_container, player_minions, true)
	_rebuild_minion_visuals(enemy_container, enemy_minions, false)
	if selected_attacker and selected_attacker not in player_minions:
		clear_selection()

func _rebuild_minion_visuals(container: Node, minions: Array[Minion], is_player: bool) -> void:
	for child in container.get_children():
		child.queue_free()
	for minion in minions:
		var visual: BoardMinion = BOARD_MINION_SCENE.instantiate()
		container.add_child(visual)
		visual.set_minion(minion)
		if is_player:
			visual.minion_clicked.connect(_on_player_minion_clicked)
		else:
			visual.minion_clicked.connect(_on_enemy_minion_clicked)


# ─── Fin de partie ────────────────────────────────────────────────────────────

func check_game_end() -> void:
	if enemy_hero.is_dead() or player_hero.is_dead():
		game_over = true


# ─── Input ────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
