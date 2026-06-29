extends Control

const _BoardSystemScript     = preload("res://scripts/systems/BoardSystem.gd")
const _CombatSystemScript    = preload("res://scripts/systems/CombatSystem.gd")
const _CardSystemScript      = preload("res://scripts/systems/CardSystem.gd")
const _TurnSystemScript      = preload("res://scripts/systems/TurnSystem.gd")
const _SelectionSystemScript = preload("res://scripts/systems/SelectionSystem.gd")
const _DropSystemScript      = preload("res://scripts/systems/DropSystem.gd")
const _BoardVisualSystemScript = preload("res://scripts/systems/BoardVisualSystem.gd")
const _DeathSystemScript     = preload("res://scripts/systems/DeathSystem.gd")
const _DeckSystemScript      = preload("res://scripts/systems/DeckSystem.gd")
const _GraveyardSystemScript = preload("res://scripts/systems/GraveyardSystem.gd")
const _AnimationSystemScript = preload("res://scripts/systems/AnimationSystem.gd")
const _HeroSystemScript      = preload("res://scripts/systems/HeroSystem.gd")
const _TargetingSystemScript = preload("res://scripts/systems/TargetingSystem.gd")

const BOARD_MINION_SCENE = preload("res://scenes/minion/BoardMinion.tscn")
const CARD_BACK          = preload("res://assets/card_back/card-back.png")
const MAX_STACK_VISUAL   := 8
const ROW_FRONT          := "Front"
const ROW_BACK           := "Back"
const MAX_MINIONS_PER_ROW := 10
const BOARD_MINION_SIZE  := Vector2(100, 150)
const DROP_HIGHLIGHT_COLOR        := Color(1.0, 0.45, 0.05, 0.28)
const DROP_HIGHLIGHT_BORDER_COLOR := Color(1.0, 0.58, 0.12, 0.9)

@onready var hand                            = $Hand
@onready var mana_label: Label               = $ManaLabel
@onready var end_turn_button: Button         = $EndTurnButton
@onready var enemy_container: Control        = get_node_or_null("Board/EnemyMinionsContainer") as Control
@onready var player_container: Control       = get_node_or_null("Board/PlayerMinionsContainer") as Control
@onready var player_front_container: Control = get_node_or_null("Board/PlayerFrontLine") as Control
@onready var player_back_container: Control  = get_node_or_null("Board/PlayerBackLine") as Control
@onready var enemy_front_container: Control  = get_node_or_null("Board/EnemyFrontLine") as Control
@onready var enemy_back_container: Control   = get_node_or_null("Board/EnemyBackLine") as Control
@onready var player_graveyard_btn: Button    = $PlayerGraveyardButton
@onready var enemy_graveyard_btn: Button     = $EnemyGraveyardButton
@onready var player_graveyard_preview: Card  = $PlayerGraveyardButton/CardPreview
@onready var enemy_graveyard_preview: Card   = $EnemyGraveyardButton/CardPreview
@onready var graveyard_view: GraveyardView   = $GraveyardView
@onready var deck_button                     = $DeckButton
@onready var deck_count_label                = $DeckButton/CountLabel
@onready var settings_menu                   = get_node_or_null("AudioSettingsMenu") as AudioSettingsMenu
@onready var settings_button: Button         = $SettingsButton
@onready var turn_choice_panel               = $TurnChoicePanel

var combat_system       := _CombatSystemScript.new()
var board_system        := _BoardSystemScript.new()
var card_system         := _CardSystemScript.new()
var turn_system         := _TurnSystemScript.new()
var selection_system    := _SelectionSystemScript.new()
var drop_system         := _DropSystemScript.new()
var board_visual_system := _BoardVisualSystemScript.new()
var death_system        := _DeathSystemScript.new()
var deck_system         := _DeckSystemScript.new()
var graveyard_system    := _GraveyardSystemScript.new()
var animation_system    := _AnimationSystemScript.new()
var hero_system         := _HeroSystemScript.new()
var targeting_system    := _TargetingSystemScript.new()
var enchantment_system  = load("res://scripts/systems/EnchantmentSystem.gd").new()
var card_popup_system: CardPopupSystem

var effect_manager := EffectManager.new()

var player_minions: Array[Minion] = []
var enemy_minions: Array[Minion]  = []
var player_graveyard: Graveyard   = Graveyard.new()
var enemy_graveyard: Graveyard    = Graveyard.new()

var pending_card: CardData       = null
var pending_row: String          = ROW_FRONT
var pending_insert_index: int    = -1
var waiting_for_target: bool     = false
var deck: Array[CardData]        = []
var hand_cards: Array[CardData]  = []
var mana: int                    = 1
var max_mana: int                = 1
var player_hero: Hero
var enemy_hero: Hero
var game_over: bool              = false
var _is_dragging_card: bool      = false

# ─── Setup ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	AudioManager.play_battle_music()
	player_hero = Hero.new(30)
	enemy_hero  = Hero.new(30)
	var enemy_card: CardData = load("res://resources/cards/undead/putrefied-leviathan.tres") as CardData
	enemy_minions.append(Minion.new(enemy_card, false, ROW_FRONT))
	hand.can_play_check      = can_afford_card
	hand.create_drag_preview = _create_card_drag_preview
	hand.card_played.connect(_on_card_played)

	deck_system.init(self)
	graveyard_system.init(self)  
	animation_system.init(self)
	hero_system.init(self)
	combat_system.init(self)
	board_system.init(self)
	card_system.init(self)
	turn_system.init(self)
	selection_system.init(self)
	drop_system.init(self)
	board_visual_system.init(self)
	death_system.init(self)
	targeting_system.init(self)
	enchantment_system.init(self)
	card_popup_system = CardPopupSystem.new()
	card_popup_system.init(self)
	add_child(enchantment_system)
	add_child(targeting_system)

	hand.drag_started.connect(_on_hand_drag_started)
	hand.drag_ended.connect(_on_hand_drag_ended)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	$EnemyHeroPanel.hero_clicked.connect(selection_system.on_enemy_hero_clicked)
	$EnemyHeroPanel.hero_clicked.connect(targeting_system.on_enemy_hero_clicked)
	turn_choice_panel.draw_selected.connect(_on_draw_selected)
	turn_choice_panel.mana_selected.connect(_on_mana_selected)
	targeting_system.targeting_cancelled.connect(_on_targeting_cancelled)
	if settings_menu:
		settings_button.pressed.connect(settings_menu.open)
	else:
		push_error("AudioSettingsMenu introuvable !")

	update_mana_ui()
	hero_system.update_ui()
	deck_system.load_deck()
	deck_system.update_deck_ui()

	board_visual_system.refresh_board()
	for minion in player_minions:
		board_visual_system.spawn_minion_visual(minion, true)
	for minion in enemy_minions:
		board_visual_system.spawn_minion_visual(minion, false)
	deck_system.start_game()

# ─── Process (flèche de ciblage) ──────────────────────────────────────────────

func _process(_delta: float) -> void:
	if targeting_system.is_targeting():
		targeting_system.update_arrow()

# ─── Input ────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if targeting_system.is_targeting():
		if event is InputEventMouseButton \
				and event.button_index == MOUSE_BUTTON_RIGHT \
				and event.pressed:
			targeting_system.cancel()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_cancel"):
			targeting_system.cancel()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed \
			and not Input.is_key_pressed(KEY_CTRL):
		if selection_system.is_multi_selecting:
			selection_system.clear_multi_selection()

# ─── Trigger centralisé ───────────────────────────────────────────────────────

func trigger_effects(minion: Minion, trigger_name: String) -> void:
	effect_manager.trigger_effects(self,minion, trigger_name)

# ─── Mana ─────────────────────────────────────────────────────────────────────

func update_mana_ui() -> void:
	mana_label.text = "%d/%d" % [mana, max_mana]

func _pay_mana(cost: int) -> void:
	mana -= cost
	update_mana_ui()

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
	return source.filter(func(m: Minion): return m.board_row == row)

func get_front_minions(is_player: bool) -> Array[Minion]:
	return get_row_minions(is_player, ROW_FRONT)

func get_back_minions(is_player: bool) -> Array[Minion]:
	return get_row_minions(is_player, ROW_BACK)

func can_summon_to_row(is_player: bool, row: String) -> bool:
	return get_row_minions(is_player, row).size() < MAX_MINIONS_PER_ROW

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
		ROW_FRONT: return [ROW_FRONT]
		ROW_BACK:  return [ROW_BACK]
		_:         return [ROW_FRONT, ROW_BACK]

func can_play_card_on_row(card_data: CardData, row: String) -> bool:
	return row in get_allowed_rows_for_card(card_data)

func has_enemy_taunt(attacker: Minion) -> bool:
	var attackable: Array[Minion] = get_attackable_enemy_minions(attacker)
	for minion in attackable:
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
	await death_system.process_deaths()

# ─── Carte jouée ──────────────────────────────────────────────────────────────

func _on_card_played(card_data: CardData, row: String = ROW_FRONT, insert_index: int = -1) -> void:
	print("_on_card_played appelé — ", card_data.card_name)  # ← combien de fois s'affiche-t-il ?
	print("_on_card_played — row: %s, index: %d" % [row, insert_index])
	if game_over or card_data.cost > mana:
		return
	row = _normalized_row(row)
	if card_data.card_type == "Minion" and not can_play_card_on_row(card_data, row):
		return
	if card_data.card_type == "Minion" and not can_summon_to_row(true, row):
		push_warning("Rangée %s pleine." % row)
		return
	if card_data.requires_target:
		pending_card         = card_data
		pending_row          = row
		pending_insert_index = insert_index
		waiting_for_target   = true
		await card_popup_system.show_targeting_popup(card_data)
		targeting_system.begin_targeting(card_data, row, insert_index)
		return
	card_system.play_card(card_data, row, insert_index)

func summon_minion(card_data: CardData, is_player: bool, row := "Front", insert_index := -1) -> void:
	await board_system.summon_minion(card_data, is_player, row, insert_index)

func _on_targeting_cancelled() -> void:
	waiting_for_target   = false
	pending_card         = null
	pending_row          = ROW_FRONT
	pending_insert_index = -1
	# La carte est encore dans hand_cards, on rafraîchit juste l'affichage
	hand.set_hand(hand_cards)

# ─── Tours ────────────────────────────────────────────────────────────────────

func _on_end_turn_pressed() -> void:
	if game_over:
		return
	turn_system.end_turn()

func draw_card() -> void:
	turn_system.draw_card()

func _on_draw_selected() -> void:
	turn_system.choose_draw()

func _on_mana_selected() -> void:
	turn_system.choose_mana()

func discard_card(card_data: CardData) -> void:
	hand_cards.erase(card_data)
	player_graveyard.add_discard(card_data)

# ─── Cimetière ────────────────────────────────────────────────────────────────

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

# ─── Board ────────────────────────────────────────────────────────────────────

func _has_split_row_containers(is_player: bool) -> bool:
	if is_player:
		return player_front_container != null and player_back_container != null
	return enemy_front_container != null and enemy_back_container != null

func _move_visual_if_needed(_minion: Minion, visual: BoardMinion, container: Control) -> void:
	if visual.get_parent() != container:
		visual.reparent(container)

# ─── Fin de partie ────────────────────────────────────────────────────────────

func check_game_end() -> void:
	if enemy_hero.is_dead() or player_hero.is_dead():
		game_over = true

# ─── Drag ─────────────────────────────────────────────────────────────────────

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
	preview.scale    = Vector2.ONE
	preview.modulate = Color(1, 1, 1, 0.85)
	return preview

func is_dragging_card() -> bool:
	return _is_dragging_card

func _get_visuals_for_dead_minions(dead_minions: Array[Minion]) -> Array[BoardMinion]:
	var visuals: Array[BoardMinion] = []
	for minion in dead_minions:
		var visual: BoardMinion = board_visual_system.find_visual(minion)
		if visual != null:
			visuals.append(visual)
	return visuals
