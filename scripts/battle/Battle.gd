extends Control

const EffectManagerData  = preload("res://scripts/EffectManager/EffectManager.gd")
const BOARD_MINION_SCENE = preload("res://scenes/minion/BoardMinion.tscn")
const CARD_BACK          = preload("res://assets/card_back/card-back.png")
const MAX_STACK_VISUAL   := 8
const ROW_FRONT          := "Front"
const ROW_BACK           := "Back"
const MAX_MINIONS_PER_ROW := 10
const BOARD_MINION_SIZE := Vector2(100, 150)
const DROP_HIGHLIGHT_COLOR := Color(1.0, 0.45, 0.05, 0.28)
const DROP_HIGHLIGHT_BORDER_COLOR := Color(1.0, 0.58, 0.12, 0.9)

@onready var hand: Hand                  = $Hand
@onready var mana_label: Label           = $ManaLabel
@onready var end_turn_button: Button     = $EndTurnButton
@onready var enemy_container: Control    = get_node_or_null("Board/EnemyMinionsContainer") as Control
@onready var player_container: Control   = get_node_or_null("Board/PlayerMinionsContainer") as Control
@onready var player_front_container: Control = get_node_or_null("Board/PlayerFrontLine") as Control
@onready var player_back_container: Control  = get_node_or_null("Board/PlayerBackLine") as Control
@onready var enemy_front_container: Control  = get_node_or_null("Board/EnemyFrontLine") as Control
@onready var enemy_back_container: Control   = get_node_or_null("Board/EnemyBackLine") as Control
@onready var player_graveyard_btn: Button = $PlayerGraveyardButton
@onready var enemy_graveyard_btn: Button  = $EnemyGraveyardButton
@onready var player_graveyard_preview: Card = $PlayerGraveyardButton/CardPreview
@onready var enemy_graveyard_preview: Card  = $EnemyGraveyardButton/CardPreview
@onready var graveyard_view: GraveyardView = $GraveyardView
@onready var deck_button           = $DeckButton
@onready var deck_count_label      = $DeckButton/CountLabel
@onready var settings_menu = get_node_or_null("AudioSettingsMenu") as AudioSettingsMenu
@onready var settings_button: Button = $SettingsButton
@onready var turn_choice_panel = $TurnChoicePanel

var combat_system := CombatSystem.new()
var board_system := BoardSystem.new()
var card_system := CardSystem.new()
var turn_system := TurnSystem.new()
var selection_system := SelectionSystem.new()
var drop_system := DropSystem.new()
var effect_manager := EffectManager.new()

var player_minions: Array[Minion] = []
var enemy_minions: Array[Minion]  = []

var player_graveyard: Graveyard = Graveyard.new()
var enemy_graveyard: Graveyard  = Graveyard.new()


var pending_card: CardData            = null
var pending_row: String = ROW_FRONT
var pending_insert_index: int = -1
var waiting_for_target: bool = false

var deck: Array[CardData]       = []
var hand_cards: Array[CardData] = []

var mana      := 3
var max_mana  := 3
var player_hero: Hero
var enemy_hero: Hero
var game_over: bool = false


var minion_to_visual: Dictionary = {} # Minion -> BoardMinion

var _is_dragging_card: bool = false

var _refreshing: bool = false
var _refresh_again: bool = false
var _processing_deaths: bool = false

# ─── Setup ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	AudioManager.play_battle_music()
	load_deck()
	hand.can_play_check = can_afford_card
	hand.create_drag_preview = _create_card_drag_preview
	var enemy_card: CardData = load("res://resources/cards/undead/infected-berserker.tres") as CardData
	enemy_minions.append(Minion.new(enemy_card, false, ROW_FRONT))
	player_hero = Hero.new(30)
	enemy_hero  = Hero.new(30)
	hand.card_played.connect(_on_card_played)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	$EnemyHeroPanel.hero_clicked.connect(selection_system.on_enemy_hero_clicked)
	var preview_scale: Vector2 = Vector2(120, 180) / Vector2(200, 300)
	_setup_graveyard_ui(player_graveyard, player_graveyard_btn, player_graveyard_preview, $PlayerGraveyardButton/CountLabel, preview_scale)
	_setup_graveyard_ui(enemy_graveyard, enemy_graveyard_btn, enemy_graveyard_preview, $EnemyGraveyardButton/CountLabel, preview_scale)

	hand.drag_started.connect(_on_hand_drag_started)
	hand.drag_ended.connect(_on_hand_drag_ended)
	update_mana_ui()
	update_hero_ui()
	update_deck_ui()
	refresh_board()
	refresh_board()
	for m in player_minions:
		_spawn_minion_visual(m, true)
	for m in enemy_minions:
		_spawn_minion_visual(m, false)
	start_game()
	combat_system.init(self)
	board_system.init(self)
	card_system.init(self)
	turn_system.init(self)
	selection_system.init(self)
	drop_system.init(self)
	turn_choice_panel.draw_selected.connect(_on_draw_selected)
	turn_choice_panel.mana_selected.connect(_on_mana_selected)
	if settings_menu:
		settings_button.pressed.connect(settings_menu.open)
	else:
		push_error("AudioSettingsMenu introuvable !")

func _setup_graveyard_ui(graveyard: Graveyard, button: Button, preview: Card, count_label: Label, preview_scale: Vector2) -> void:
	preview.visible = false
	button.visible  = false
	preview.scale   = preview_scale
	graveyard.graveyard_changed.connect(func(): _update_graveyard_btn(graveyard, preview, count_label))
	button.pressed.connect(func(): graveyard_view.open(graveyard))
	if preview.has_method("set_non_interactive"):
		preview.set_non_interactive()

func load_deck() -> void:
	var active := DeckManager.get_active_deck()
	if active:
		deck = active.get_cards()
	else:
		# Fallback si aucun deck créé
		var card := load("res://resources/cards/undead/gaunt-servant.tres") as CardData
		deck = []
		for i in range(20):
			deck.append(card)

func start_game() -> void:
	deck.shuffle()
	for i in range(5):
		hand_cards.append(deck.pop_back())
	hand.set_hand(hand_cards, false)
	update_deck_ui()

func _on_draw_selected() -> void:
	turn_system.choose_draw()

func _on_mana_selected() -> void:
	turn_system.choose_mana()

func discard_card(card_data: CardData) -> void:
	hand_cards.erase(card_data)
	player_graveyard.add_discard(card_data)

# ─── Mana ─────────────────────────────────────────────────────────────────────

func update_mana_ui() -> void:
	mana_label.text = "%d/%d" % [mana, max_mana]

func _pay_mana(cost: int) -> void:
	mana -= cost
	update_mana_ui()

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

func get_row_minions(is_player: bool, row: String) -> Array[Minion]:
	var source: Array[Minion] = player_minions if is_player else enemy_minions
	return source.filter(func(m): return m.board_row == row)

func get_front_minions(is_player: bool) -> Array[Minion]:
	return get_row_minions(is_player, ROW_FRONT)

func get_back_minions(is_player: bool) -> Array[Minion]:
	return get_row_minions(is_player, ROW_BACK)

func can_summon_to_row(is_player: bool, row: String) -> bool:
	return get_row_minions(is_player, row).size() < MAX_MINIONS_PER_ROW



func _spawn_minion_visual(minion: Minion, is_player: bool) -> void:
	var container: Control
	if is_player:
		container = player_front_container if minion.board_row == ROW_FRONT else player_back_container
	else:
		container = enemy_front_container if minion.board_row == ROW_FRONT else enemy_back_container
	if container == null:
		push_error("Container null pour spawn minion !")
		return
	var visual: BoardMinion = BOARD_MINION_SCENE.instantiate()
	container.add_child(visual)
	visual.set_minion(minion)
	minion_to_visual[minion] = visual
	if is_player:
		visual.minion_clicked.connect(selection_system.on_player_minion_clicked)
	else:
		visual.minion_clicked.connect(selection_system.on_enemy_minion_clicked)
	_play_summon_animation(visual)

func _normalized_row(row: String) -> String:
	return ROW_BACK if row == ROW_BACK else ROW_FRONT

func _insert_minion_in_row(minions: Array[Minion], minion: Minion, row: String, insert_index: int) -> void:
	var row_count: int = get_row_count_in(minions, row)
	insert_index = clamp(insert_index, 0, row_count) if insert_index >= 0 else row_count
	var seen_in_row: int = 0
	for i in range(minions.size()):
		if minions[i].board_row != row:
			continue
		if seen_in_row == insert_index:
			minions.insert(i, minion)
			return
		seen_in_row += 1
	minions.append(minion)

func get_row_count_in(minions: Array[Minion], row: String) -> int:
	var count: int = 0
	for minion in minions:
		if minion.board_row == row:
			count += 1
	return count

func get_allowed_rows_for_card(card_data: CardData) -> Array[String]:
	if card_data == null or card_data.card_type != "Minion":
		return [ROW_FRONT, ROW_BACK]
	match card_data.board_position:
		ROW_FRONT:
			return [ROW_FRONT]
		ROW_BACK:
			return [ROW_BACK]
		_:
			return [ROW_FRONT, ROW_BACK]

func can_play_card_on_row(card_data: CardData, row: String) -> bool:
	return row in get_allowed_rows_for_card(card_data)

func has_enemy_taunt(attacker: Minion) -> bool:
	for minion in get_attackable_enemy_minions(attacker):
		if minion.has_keyword(Keyword.Type.TAUNT):
			return true
	return false

func get_attackable_enemy_minions(attacker: Minion) -> Array[Minion]:
	if attacker and attacker.has_keyword(Keyword.Type.BLACK_WINGS):
		return enemy_minions
	var front: Array[Minion] = get_front_minions(false)
	if not front.is_empty():
		return front
	return enemy_minions

func destroy_minion(target: Minion) -> void:
	target.health = 0
	remove_dead_minions()

# ─── Carte jouée ──────────────────────────────────────────────────────────────

func _on_card_played(card_data: CardData, row: String = ROW_FRONT, insert_index: int = -1) -> void:
	if game_over or card_data.cost > mana:
		return
	row = _normalized_row(row)
	if card_data.card_type == "Minion" and not can_play_card_on_row(card_data, row):
		return
	if card_data.card_type == "Minion" and not can_summon_to_row(true, row):
		push_warning("Rangée %s pleine : impossible de jouer %s." % [row, card_data.card_name])
		return
	if card_data.requires_target:
		pending_card = card_data
		pending_row = row
		pending_insert_index = insert_index
		waiting_for_target = true
		return
	card_system.play_card(card_data, row, insert_index)

func summon_minion(card_data: CardData, is_player: bool, row := "Front", insert_index := -1) -> void:
	await board_system.summon_minion(card_data, is_player, row, insert_index)

func resolve_card_target(target: Minion) -> void:
	if pending_card == null:
		return
	_pay_mana(pending_card.cost)
	for effect in pending_card.effects:
		effect_manager.execute_targeted_effect(self, effect, target)
	hand_cards.erase(pending_card)
	if pending_card.card_type == "Minion":
		board_system.summon_minion(pending_card, true, pending_row, pending_insert_index)
	else:
		player_graveyard.add_spell(pending_card)
	hand.set_hand(hand_cards)
	pending_card       = null
	pending_row        = ROW_FRONT
	pending_insert_index = -1
	waiting_for_target = false
	refresh_board()
	
# ─── Combat ───────────────────────────────────────────────────────────────────


func remove_dead_minions() -> void:
	if _processing_deaths:
		return
	_processing_deaths = true
	var dead_player := player_minions.filter(func(m): return m.is_dead())
	var dead_enemy  := enemy_minions.filter(func(m): return m.is_dead())
	var dead_all: Array[Minion] = []
	dead_all.append_array(dead_player)
	dead_all.append_array(dead_enemy)
	# récup visuals
	var visuals: Array[BoardMinion] = []
	for m in dead_all:
		var v: BoardMinion = minion_to_visual.get(m)
		if v:
			visuals.append(v)
	# animation mort
	for v in visuals:
		_play_death_animation(v)
	if visuals.size() > 0:
		await get_tree().create_timer(0.1).timeout
	# cleanup visuel + mapping
	for m in dead_all:
		var v: BoardMinion = minion_to_visual.get(m)
		if v:
			v.queue_free()
			minion_to_visual.erase(m)
	# deathrattles + graveyard
	for m in dead_player:
		player_graveyard.add_minion(m.card_data)
		trigger_effects(m, "DEATHRATTLE")
	for m in dead_enemy:
		enemy_graveyard.add_minion(m.card_data)
		trigger_effects(m, "DEATHRATTLE")
	# cleanup logique
	player_minions = player_minions.filter(func(m): return not m.is_dead())
	enemy_minions = enemy_minions.filter(func(m): return not m.is_dead())
	_processing_deaths = false
	refresh_board()

func trigger_effects(minion: Minion, trigger_name: String) -> void:
	if minion == null:
		return
	var trigger_found := false
	for trigger in minion.card_data.trigger_types:
		if trigger.type == trigger_name:
			trigger_found = true
			break
	if not trigger_found:
		return
	for effect in minion.card_data.effects:
		effect_manager.execute_effect(self, minion, effect)

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

# ─── Règles d'attaque ─────────────────────────────────────────────────────────
# Centralise les conditions "peut attaquer" pour éviter de les dupliquer entre
# le mode simple et le mode multi-sélection.

func _can_attack_minion_target(attacker: Minion, target: Minion) -> bool:
	if target not in get_attackable_enemy_minions(attacker):
		return false
	if has_enemy_taunt(attacker) and not target.has_keyword(Keyword.Type.TAUNT):
		return false
	return true

func _can_attack_hero(attacker: Minion) -> bool:
	if has_enemy_taunt(attacker):
		return false
	return attacker.has_keyword(Keyword.Type.BLACK_WINGS) or get_front_minions(false).is_empty()


# ─── Tours ────────────────────────────────────────────────────────────────────

func _on_end_turn_pressed() -> void:
	if game_over:
		return
	turn_system.end_turn()

func draw_card() -> void:
	turn_system.draw_card()

# ─── Board ────────────────────────────────────────────────────────────────────

func refresh_board() -> void:
	if _refreshing:
		_refresh_again = true
		return
	_refreshing = true
	# Update uniquement les visuals existants
	for minion in player_minions + enemy_minions:
		var visual: BoardMinion = minion_to_visual.get(minion)
		if visual and is_instance_valid(visual):
			visual.update_display()
	# cleanup si sélection invalide
	if selection_system.selected_attacker and selection_system.selected_attacker not in player_minions:
		selection_system.clear_selection()
	_refreshing = false
	if _refresh_again:
		_refresh_again = false
		refresh_board()

func _get_all_minion_containers() -> Array[Control]:
	var containers: Array[Control] = []
	for c in [player_front_container, player_back_container, player_container, enemy_front_container, enemy_back_container, enemy_container]:
		if c != null:
			containers.append(c)
	return containers

func _find_board_minion_visual(target_minion: Minion) -> BoardMinion:
	if target_minion == null:
		return null
	for container in _get_all_minion_containers():
		for child in container.get_children():
			if child is BoardMinion and child.minion == target_minion:
				return child
	return null

func _animate_attack_lunge(
	attacker_visual: BoardMinion,
	target: Control
) -> void:
	if attacker_visual == null \
			or target == null \
			or not is_instance_valid(attacker_visual) \
			or not is_instance_valid(target):
		return
	var start_position := attacker_visual.position
	var attacker_center := attacker_visual.global_position + attacker_visual.size * 0.5
	var target_center := target.global_position + target.size * 0.5
	var direction := target_center - attacker_center
	if direction.length() < 1.0:
		return
	# Va presque jusqu'au centre de la cible
	var impact_offset := direction * 0.95
	attacker_visual.z_index = 50
	var attack_tween := create_tween()
	# Préparation
	attack_tween.tween_property(
		attacker_visual,
		"position",
		start_position + Vector2(0, -15),
		0.05
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Charge
	attack_tween.tween_property(
		attacker_visual,
		"position",
		start_position + impact_offset,
		0.05
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Impact + secousse de la cible
	attack_tween.tween_callback(func():
		if not is_instance_valid(target):
			return
		var hit_pos := target.position
		var shake := create_tween()
		shake.tween_property(
			target,
			"position",
			hit_pos + Vector2(10, 0),
			0.03
		)
		shake.tween_property(
			target,
			"position",
			hit_pos - Vector2(10, 0),
			0.03
		)
		shake.tween_property(
			target,
			"position",
			hit_pos,
			0.03
		)
	)
	# Retour
	attack_tween.tween_property(
		attacker_visual,
		"position",
		start_position,
		0.1
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await attack_tween.finished
	if is_instance_valid(attacker_visual):
		attacker_visual.z_index = 0

func _has_split_row_containers(is_player: bool) -> bool:
	if is_player:
		return player_front_container != null and player_back_container != null
	return enemy_front_container != null and enemy_back_container != null

func _rebuild_minion_visuals(container, minions, is_player, _previously_existing) -> void:
	if container == null:
		return
	for minion in minions:
		if minion_to_visual.has(minion):
			var existing: BoardMinion = minion_to_visual[minion]
			if is_instance_valid(existing):
				existing.update_display()
				_move_visual_if_needed(minion, existing, container)
			continue
		var visual: BoardMinion = BOARD_MINION_SCENE.instantiate()
		container.add_child(visual)
		visual.set_minion(minion)
		minion_to_visual[minion] = visual
		if is_player:
			visual.minion_clicked.connect(selection_system.on_player_minion_clicked)
		else:
			visual.minion_clicked.connect(selection_system.on_enemy_minion_clicked)
		_play_summon_animation(visual)

func _move_visual_if_needed(_minion: Minion, visual: BoardMinion, container: Control) -> void:
	if visual.get_parent() != container:
		visual.reparent(container)

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

func _unhandled_input(event: InputEvent) -> void:
	# Clic gauche sans Ctrl sur une zone non gérée par la GUI = vide la multi-sélection
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed \
			and not Input.is_key_pressed(KEY_CTRL):
		if selection_system.is_multi_selecting:
			selection_system.clear_multi_selection()


func _on_hand_drag_started() -> void:
	_is_dragging_card = true
	hand.set_compact(true)

func _on_hand_drag_ended() -> void:
	_is_dragging_card = false
	hand.set_compact(false)

func can_afford_card(card_data: CardData) -> bool:
	return card_data != null and mana >= card_data.cost

func _create_card_drag_preview(card_data: CardData) -> Control:
	var preview: BoardMinion = BOARD_MINION_SCENE.instantiate() as BoardMinion
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.z_index = 200
	add_child(preview)
	preview.set_minion(Minion.new(card_data, true, ROW_FRONT))
	preview.scale = Vector2.ONE
	preview.modulate = Color(1, 1, 1, 0.85)  # après set_minion pour ne pas être écrasé
	return preview

func is_dragging_card() -> bool:
	return _is_dragging_card

func _get_visuals_for_dead_minions(dead_minions: Array[Minion]) -> Array[BoardMinion]:
	var visuals: Array[BoardMinion] = []
	for minion in dead_minions:
		var visual := _find_board_minion_visual(minion)
		if visual != null:
			visuals.append(visual)
	return visuals
