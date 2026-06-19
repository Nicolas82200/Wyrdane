extends Control

const EffectManagerData  = preload("res://scripts/EffectManager/EffectManager.gd")
const BOARD_MINION_SCENE = preload("res://scenes/minion/BoardMinion.tscn")
const CARD_BACK          = preload("res://assets/card_back/card-back.png")
const MAX_STACK_VISUAL   := 8

@onready var hand                  = $Hand
@onready var mana_label            = $ManaLabel
@onready var end_turn_button       = $EndTurnButton
@onready var enemy_container       = $Board/EnemyMinionsContainer
@onready var player_container      = $Board/PlayerMinionsContainer
@onready var player_graveyard_btn  = $PlayerGraveyardButton
@onready var enemy_graveyard_btn   = $EnemyGraveyardButton
@onready var player_graveyard_preview = $PlayerGraveyardButton/CardPreview
@onready var enemy_graveyard_preview  = $EnemyGraveyardButton/CardPreview
@onready var graveyard_view: GraveyardView = $GraveyardView
@onready var deck_button           = $DeckButton
@onready var deck_count_label      = $DeckButton/CountLabel

var player_minions: Array[Minion] = []
var enemy_minions: Array[Minion]  = []

var player_graveyard := Graveyard.new()
var enemy_graveyard  := Graveyard.new()

var selected_attacker: Minion         = null
var selected_board_minion: BoardMinion = null
var pending_card: CardData            = null
var waiting_for_target := false

var deck: Array[CardData]       = []
var hand_cards: Array[CardData] = []

var mana      := 3
var max_mana  := 3
var player_hero: Hero
var enemy_hero: Hero
var game_over := false


func _ready() -> void:
	load_deck()
	var enemy_card = load("res://resources/cards/undead/minor-zombie.tres")
	enemy_minions.append(Minion.new(enemy_card, false))
	player_hero = Hero.new(30)
	enemy_hero  = Hero.new(30)
	hand.card_played.connect(_on_card_played)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	$EnemyHeroPanel.hero_clicked.connect(_on_enemy_hero_clicked)
	player_graveyard_preview.visible = false
	enemy_graveyard_preview.visible  = false
	player_graveyard_btn.visible     = false
	enemy_graveyard_btn.visible      = false
	player_graveyard.graveyard_changed.connect(
		func(): _update_graveyard_btn(
			player_graveyard,
			player_graveyard_preview,
			$PlayerGraveyardButton/CountLabel
		)
	)
	enemy_graveyard.graveyard_changed.connect(
		func(): _update_graveyard_btn(
			enemy_graveyard,
			enemy_graveyard_preview,
			$EnemyGraveyardButton/CountLabel
		)
	)
	var card_native_size := Vector2(200, 300)
	var btn_size         := Vector2(120, 180)
	var card_scale       := btn_size / card_native_size
	player_graveyard_preview.scale = card_scale
	enemy_graveyard_preview.scale  = card_scale
	player_graveyard_btn.pressed.connect(func(): graveyard_view.open(player_graveyard))
	enemy_graveyard_btn.pressed.connect(func():  graveyard_view.open(enemy_graveyard))
	if player_graveyard_preview.has_method("set_non_interactive"):
		player_graveyard_preview.set_non_interactive()
	if enemy_graveyard_preview.has_method("set_non_interactive"):
		enemy_graveyard_preview.set_non_interactive()
	update_mana_ui()
	update_hero_ui()
	update_deck_ui()
	refresh_board()
	start_game()

func load_deck() -> void:
	var card = load("res://resources/cards/undead/minor-horde.tres")
	deck = []
	for i in range(20):
		deck.append(card)

func start_game() -> void:
	deck.shuffle()
	for i in range(5):
		hand_cards.append(deck.pop_back())
	hand.set_hand(hand_cards, false)
	update_deck_ui()

func draw_card() -> void:
	if deck.is_empty():
		return
	hand_cards.append(deck.pop_back())
	var deck_pos :Vector2= deck_button.global_position + deck_button.size / 2.0
	hand.set_hand(hand_cards, true, deck_pos)
	update_deck_ui()

func discard_card(card_data: CardData) -> void:
	hand_cards.erase(card_data)
	player_graveyard.add_discard(card_data)

# ─── Mana ─────────────────────────────────────────────────────────────────────

func update_mana_ui() -> void:
	mana_label.text = "%d/%d" % [mana, max_mana]

# ─── Deck ─────────────────────────────────────────────────────────────────────

func update_deck_ui() -> void:
	deck_button.visible = not deck.is_empty()
	deck_count_label.text = str(deck.size())

	for child in deck_button.get_children():
		if child.name != "CountLabel":
			child.queue_free()

	if deck.is_empty():
		return

	var visible_count :float= clamp(
		int(float(deck.size()) / 10.0 * MAX_STACK_VISUAL) + 1,
		1,
		MAX_STACK_VISUAL
	)

	for i in range(visible_count, 0, -1):
		var card_back := TextureRect.new()
		card_back.texture             = CARD_BACK
		card_back.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card_back.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
		card_back.layout_mode         = 1
		card_back.anchors_preset      = 15
		card_back.anchor_right        = 1.0
		card_back.anchor_bottom       = 1.0
		card_back.offset_top          = -i * 1.5
		card_back.offset_left         = -i * 1.5
		card_back.offset_right        = -i * 1.5
		card_back.offset_bottom       = -i * 1.5
		card_back.mouse_filter        = Control.MOUSE_FILTER_IGNORE
		deck_button.add_child(card_back)

	deck_button.move_child(deck_count_label, deck_button.get_child_count() - 1)

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
	$EnemyHeroPanel/HealthLabel.text  = str(maxi(enemy_hero.health, 0))

# ─── Serviteurs ───────────────────────────────────────────────────────────────

func get_owner_minions(minion: Minion) -> Array[Minion]:
	if minion == null:
		return player_minions
	return player_minions if minion.owner_is_player else enemy_minions

func get_enemy_minions(minion: Minion) -> Array[Minion]:
	if minion == null:
		return enemy_minions
	return enemy_minions if minion.owner_is_player else player_minions

func summon_minion(card_data: CardData, is_player: bool = true) -> void:
	var minion = Minion.new(card_data, is_player)
	if is_player:
		player_minions.append(minion)
	else:
		enemy_minions.append(minion)
	trigger_effects(minion, "BATTLECRY")
	refresh_board()

func has_enemy_taunt() -> bool:
	for minion in enemy_minions:
		if minion.has_keyword(Keyword.Type.TAUNT):
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
	else:
		player_graveyard.add_spell(card_data)
		for effect in card_data.effects:
			EffectManagerData.execute_effect(self, null, effect)
			refresh_board()

func resolve_card_target(target: Minion) -> void:
	if pending_card == null:
		return
	mana -= pending_card.cost
	update_mana_ui()
	for effect in pending_card.effects:
		EffectManagerData.execute_targeted_effect(self, effect, target)
	hand_cards.erase(pending_card)
	player_graveyard.add_spell(pending_card)
	hand.set_hand(hand_cards)
	pending_card       = null
	waiting_for_target = false
	refresh_board()

# ─── Combat ───────────────────────────────────────────────────────────────────

func resolve_combat(attacker: Minion, defender: Minion) -> void:
	trigger_effects(attacker, "OnAttack")
	defender.take_damage(attacker.attack)
	if attacker.has_keyword(Keyword.Type.DEADLY_POISON) and defender.health > 0:
		defender.health = 0
	trigger_effects(defender, "OnDamaged")
	if attacker.has_keyword(Keyword.Type.LIFESTEAL):
		get_owner_hero(attacker).heal(attacker.attack)
	attacker.take_damage(defender.attack)
	if defender.has_keyword(Keyword.Type.DEADLY_POISON) and attacker.health > 0:
		attacker.health = 0
	attacker.attacks_remaining -= 1
	remove_dead_minions()
	update_hero_ui()
	refresh_board()
	check_game_end()

func remove_dead_minions() -> void:
	var dead_player := player_minions.filter(func(m): return m.is_dead())
	var dead_enemy  := enemy_minions.filter(func(m): return m.is_dead())
	for minion in dead_player:
		player_graveyard.add_minion(minion.card_data)
		trigger_effects(minion, "DEATHRATTLE")
	for minion in dead_enemy:
		enemy_graveyard.add_minion(minion.card_data)
		trigger_effects(minion, "DEATHRATTLE")
	player_minions = player_minions.filter(func(m): return not m.is_dead())
	enemy_minions  = enemy_minions.filter(func(m): return not m.is_dead())
	refresh_board()

func trigger_effects(minion: Minion, trigger_name: String) -> void:
	if minion == null:
		return
	if not trigger_name in minion.card_data.trigger_types:
		return
	for effect in minion.card_data.effects:
		EffectManagerData.execute_effect(self, minion, effect)

func _update_graveyard_btn(graveyard: Graveyard, preview: Card, label: Label) -> void:
	var last: CardData = graveyard.last_card_data()
	if last == null:
		preview.visible = false
		label.text = "0"
		return
	preview.visible = true
	preview.get_parent().visible = true
	preview.set_data(last)
	label.text = str(graveyard.size())

# ─── Sélection / Clicks ───────────────────────────────────────────────────────

func _on_player_minion_clicked(minion: Minion, board_minion: BoardMinion) -> void:
	if game_over or not minion.can_attack():
		return
	if selected_board_minion:
		selected_board_minion.set_selected(false)
	selected_attacker     = minion
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
	if has_enemy_taunt() and not target.has_keyword(Keyword.Type.TAUNT):
		return
	resolve_combat(selected_attacker, target)
	clear_selection()

func _on_enemy_hero_clicked() -> void:
	if game_over or selected_attacker == null or has_enemy_taunt():
		return
	damage_hero(enemy_hero, selected_attacker.attack)
	if selected_attacker.has_keyword(Keyword.Type.LIFESTEAL):
		get_owner_hero(selected_attacker).heal(selected_attacker.attack)
	selected_attacker.attacks_remaining -= 1
	clear_selection()
	check_game_end()
	refresh_board()

func clear_selection() -> void:
	if selected_board_minion:
		selected_board_minion.set_selected(false)
	selected_board_minion = null
	selected_attacker     = null

# ─── Tours ────────────────────────────────────────────────────────────────────

func _on_end_turn_pressed() -> void:
	if game_over:
		return
	end_turn()

func end_turn() -> void:
	for minion in player_minions:
		trigger_effects(minion, "ONTURNEND")
	start_new_turn()

func start_new_turn() -> void:
	max_mana = mini(max_mana + 1, 10)
	mana     = max_mana
	for minion in player_minions:
		minion.refresh_attacks()
		trigger_effects(minion, "ONTURNSTART")
	draw_card()
	update_mana_ui()
	refresh_board()

# ─── Board ────────────────────────────────────────────────────────────────────

var _known_minions: Array[Minion] = []

var _refreshing := false

func refresh_board() -> void:
	if _refreshing:
		return
	_refreshing = true

	var previous := _known_minions.duplicate()
	_known_minions = player_minions + enemy_minions

	await _rebuild_minion_visuals(player_container, player_minions, true, previous)
	await _rebuild_minion_visuals(enemy_container, enemy_minions, false, previous)

	if selected_attacker and selected_attacker not in player_minions:
		clear_selection()

	_refreshing = false

	_rebuild_minion_visuals(
		enemy_container,
		enemy_minions,
		false,
		previous
	)

	if selected_attacker and selected_attacker not in player_minions:
		clear_selection()

func _rebuild_minion_visuals(
	container: Node,
	minions: Array[Minion],
	is_player: bool,
	previously_existing: Array[Minion]
) -> void:
	# Anime la mort des serviteurs supprimés
	var dying_visuals: Array = []
	for child in container.get_children():
		if child is BoardMinion and child.minion not in minions:
			dying_visuals.append(child)
			_play_death_animation(child)

	# Attend la fin de l'animation de mort avant de continuer
	if not dying_visuals.is_empty():
		await get_tree().create_timer(0.4).timeout

	for child in container.get_children():
		if child not in dying_visuals:
			child.queue_free()
	for v in dying_visuals:
		if is_instance_valid(v):
			v.queue_free()

	await get_tree().process_frame

	for minion in minions:
		var visual: BoardMinion = BOARD_MINION_SCENE.instantiate()
		container.add_child(visual)
		visual.set_minion(minion)
		if is_player:
			visual.minion_clicked.connect(_on_player_minion_clicked)
		else:
			visual.minion_clicked.connect(_on_enemy_minion_clicked)
		if minion not in previously_existing:
			_play_summon_animation(visual)

func _play_death_animation(visual: BoardMinion) -> void:
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale",      Vector2.ZERO, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(visual, "modulate:a", 0.0,          0.25)

func _play_summon_animation(visual: BoardMinion) -> void:
	visual.scale = Vector2(0.2, 0.2)
	visual.modulate.a = 0.0

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		visual,
		"scale",
		Vector2.ONE,
		0.35
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		visual,
		"modulate:a",
		1.0,
		0.25
	)

# ─── Fin de partie ────────────────────────────────────────────────────────────

func check_game_end() -> void:
	if enemy_hero.is_dead() or player_hero.is_dead():
		game_over = true

# ─── Input ────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

func _find_zone_at(mouse: Vector2, group: String) -> Control:
	for zone in get_tree().get_nodes_in_group(group):
		if zone is Control and zone.get_global_rect().has_point(mouse):
			return zone
	return null
