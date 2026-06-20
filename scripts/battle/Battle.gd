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

var player_minions: Array[Minion] = []
var enemy_minions: Array[Minion]  = []

var player_graveyard: Graveyard = Graveyard.new()
var enemy_graveyard: Graveyard  = Graveyard.new()

var selected_attacker: Minion         = null
var selected_board_minion: BoardMinion = null
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

var selected_attackers: Array[Minion] = []
var selected_board_minions: Array[BoardMinion] = []
var minion_to_visual: Dictionary = {} # Minion -> BoardMinion
var is_multi_selecting: bool = false
var _is_dragging_card: bool = false

var _known_minions: Array[Minion] = []
var _refreshing: bool = false
var _refresh_again: bool = false
var _processing_deaths: bool = false
var _drop_highlights: Dictionary = {}
var _drop_placeholder: Control = null
var _drop_placeholder_row: String = ""
var _drop_placeholder_index: int = -1
var _last_placeholder_index: int = -1
var _last_placeholder_row: String = ""

# ─── Setup ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	load_deck()
	hand.can_play_check = can_afford_card
	hand.create_drag_preview = _create_card_drag_preview
	var enemy_card: CardData = load("res://resources/cards/undead/infected-berserker.tres") as CardData
	enemy_minions.append(Minion.new(enemy_card, false, ROW_FRONT))
	player_hero = Hero.new(30)
	enemy_hero  = Hero.new(30)
	hand.card_played.connect(_on_card_played)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	$EnemyHeroPanel.hero_clicked.connect(_on_enemy_hero_clicked)

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

func _setup_graveyard_ui(graveyard: Graveyard, button: Button, preview: Card, count_label: Label, preview_scale: Vector2) -> void:
	preview.visible = false
	button.visible  = false
	preview.scale   = preview_scale
	graveyard.graveyard_changed.connect(func(): _update_graveyard_btn(graveyard, preview, count_label))
	button.pressed.connect(func(): graveyard_view.open(graveyard))
	if preview.has_method("set_non_interactive"):
		preview.set_non_interactive()

func load_deck() -> void:
	var card: CardData = load("res://resources/cards/undead/minor-horde.tres") as CardData
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

func get_row_minions(is_player: bool, row: String) -> Array[Minion]:
	var source: Array[Minion] = player_minions if is_player else enemy_minions
	return source.filter(func(m): return m.board_row == row)

func get_front_minions(is_player: bool) -> Array[Minion]:
	return get_row_minions(is_player, ROW_FRONT)

func get_back_minions(is_player: bool) -> Array[Minion]:
	return get_row_minions(is_player, ROW_BACK)

func can_summon_to_row(is_player: bool, row: String) -> bool:
	return get_row_minions(is_player, row).size() < MAX_MINIONS_PER_ROW

func summon_minion(card_data: CardData, is_player: bool = true, row: String = ROW_FRONT, insert_index: int = -1) -> bool:
	row = _normalized_row(row)
	if not can_summon_to_row(is_player, row):
		push_warning("Rangée %s pleine : impossible de poser %s." % [row, card_data.card_name])
		return false

	var minion: Minion = Minion.new(card_data, is_player, row)

	if is_player:
		_insert_minion_in_row(player_minions, minion, row, insert_index)
	else:
		_insert_minion_in_row(enemy_minions, minion, row, insert_index)
	_spawn_minion_visual(minion, is_player)
	trigger_effects(minion, "BATTLECRY")
	refresh_board()
	return true

func _spawn_minion_visual(minion: Minion, is_player: bool) -> void:
	var container: Control

	if _has_split_row_containers(is_player):
		container = player_front_container if minion.board_row == ROW_FRONT else player_back_container
	else:
		container = player_container if is_player else enemy_container

	if container == null:
		return

	var visual: BoardMinion = BOARD_MINION_SCENE.instantiate()
	container.add_child(visual)

	visual.set_minion(minion)

	minion_to_visual[minion] = visual

	if is_player:
		visual.minion_clicked.connect(_on_player_minion_clicked)
	else:
		visual.minion_clicked.connect(_on_enemy_minion_clicked)

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
	play_card(card_data, row, insert_index)

func play_card(card_data: CardData, row: String = ROW_FRONT, insert_index: int = -1) -> void:
	_pay_mana(card_data.cost)
	var idx := hand_cards.find(card_data)
	if idx != -1:
		hand_cards.remove_at(idx)
	await get_tree().process_frame
	hand._update_hand_layout(true)
	if card_data.card_type == "Minion":
		summon_minion(card_data, true, row, insert_index)
	else:
		player_graveyard.add_spell(card_data)
		for effect in card_data.effects:
			EffectManagerData.execute_effect(self, null, effect)
			refresh_board()

func resolve_card_target(target: Minion) -> void:
	if pending_card == null:
		return
	_pay_mana(pending_card.cost)
	for effect in pending_card.effects:
		EffectManagerData.execute_targeted_effect(self, effect, target)
	hand_cards.erase(pending_card)
	if pending_card.card_type == "Minion":
		summon_minion(pending_card, true, pending_row, pending_insert_index)
	else:
		player_graveyard.add_spell(pending_card)
	hand.set_hand(hand_cards)
	pending_card       = null
	pending_row        = ROW_FRONT
	pending_insert_index = -1
	waiting_for_target = false
	refresh_board()

# ─── Combat ───────────────────────────────────────────────────────────────────

func resolve_combat(attacker: Minion, defender: Minion) -> void:
	var attacker_visual := _find_board_minion_visual(attacker)
	var defender_visual := _find_board_minion_visual(defender)
	if attacker_visual and defender_visual:
		await _animate_attack_lunge(
		attacker_visual,
		defender_visual
)
	trigger_effects(attacker, "OnAttack")
	var attacker_damage := attacker.attack
	var defender_damage := defender.attack
	defender.take_damage(attacker_damage)
	attacker.take_damage(defender_damage)
	if attacker.has_keyword(Keyword.Type.DEADLY_POISON) and defender.health > 0:
		defender.health = 0
	if defender.has_keyword(Keyword.Type.DEADLY_POISON) and attacker.health > 0:
		attacker.health = 0
	trigger_effects(defender, "OnDamaged")
	if attacker.has_keyword(Keyword.Type.LIFESTEAL):
		get_owner_hero(attacker).heal(attacker_damage)
	attacker.attacks_remaining -= 1
	# Mise à jour des PV visibles
	refresh_board()
	await get_tree().create_timer(0.25).timeout
	# Les morts disparaissent ensemble
	await remove_dead_minions()
	update_hero_ui()
	check_game_end()


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
		await get_tree().create_timer(0.35).timeout
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

func _perform_hero_attack(attacker: Minion) -> void:
	var attacker_visual := _find_board_minion_visual(attacker)
	if attacker_visual != null:
		var hero_panel: Control = $EnemyHeroPanel
		await _animate_attack_lunge(attacker_visual, hero_panel)
	damage_hero(enemy_hero, attacker.attack)
	if attacker.has_keyword(Keyword.Type.LIFESTEAL):
		get_owner_hero(attacker).heal(attacker.attack)
	attacker.attacks_remaining -= 1

# ─── Sélection / Clicks ───────────────────────────────────────────────────────

func _on_player_minion_clicked(minion: Minion, board_minion: BoardMinion) -> void:
	if game_over or not minion.can_attack():
		return

	var ctrl_held := Input.is_key_pressed(KEY_CTRL)

	if ctrl_held:
		# Si une sélection simple existait déjà, on la fait basculer dans la multi-sélection
		if not is_multi_selecting and selected_attacker != null and selected_board_minion != null:
			selected_attackers.append(selected_attacker)
			selected_board_minions.append(selected_board_minion)
			selected_attacker     = null
			selected_board_minion = null

		# Multi-sélection
		is_multi_selecting = true
		if minion in selected_attackers:
			# Déselectionne si déjà sélectionné
			var idx := selected_attackers.find(minion)
			selected_attackers.remove_at(idx)
			selected_board_minions.remove_at(idx)
			board_minion.set_selected(false)
		else:
			selected_attackers.append(minion)
			selected_board_minions.append(board_minion)
			board_minion.set_selected(true)

		if selected_attackers.is_empty():
			is_multi_selecting = false
	else:
		# Sélection simple — vide la multi-sélection
		clear_multi_selection()
		is_multi_selecting = false
		if selected_board_minion:
			selected_board_minion.set_selected(false)
		selected_attacker     = minion
		selected_board_minion = board_minion
		board_minion.set_selected(true, true)

func _on_enemy_minion_clicked(target: Minion, _board_minion: BoardMinion) -> void:
	if game_over:
		return
	if waiting_for_target:
		if target not in get_attackable_enemy_minions(null):
			return
		resolve_card_target(target)
		return

	# Multi-attaque séquentielle
	if is_multi_selecting and not selected_attackers.is_empty():
		if not _can_attack_minion_target(selected_attackers[0], target):
			return
		await _resolve_multi_attack(target)
		return

	# Attaque simple
	if selected_attacker == null or not _can_attack_minion_target(selected_attacker, target):
		return
	await resolve_combat(selected_attacker, target)
	clear_selection()

func _on_enemy_hero_clicked() -> void:
	if game_over:
		return

	if is_multi_selecting and not selected_attackers.is_empty():
		await _resolve_multi_attack_hero()
		return

	if selected_attacker == null or not _can_attack_hero(selected_attacker):
		return
	await _perform_hero_attack(selected_attacker)
	clear_selection()
	check_game_end()
	refresh_board()

func clear_selection() -> void:
	if selected_board_minion:
		selected_board_minion.set_selected(false)
	selected_board_minion = null
	selected_attacker     = null
	clear_multi_selection()

func clear_multi_selection() -> void:
	for bm in selected_board_minions:
		if is_instance_valid(bm):
			bm.set_selected(false)
	selected_attackers.clear()
	selected_board_minions.clear()
	is_multi_selecting = false

func _sort_attackers_left_to_right(attackers: Array[Minion]) -> Array[Minion]:
	var sorted: Array[Minion] = attackers.duplicate()
	sorted.sort_custom(func(a, b): return player_minions.find(a) < player_minions.find(b))
	return sorted

func _resolve_multi_attack(target: Minion) -> void:
	var attackers := _sort_attackers_left_to_right(selected_attackers)
	clear_multi_selection()
	for attacker in attackers:
		if target.is_dead():
			break  # Cible morte, on arrête
		if attacker == null or attacker.is_dead() or not attacker.can_attack():
			continue
		if not _can_attack_minion_target(attacker, target):
			continue
		await resolve_combat(attacker, target)
		await get_tree().create_timer(0.4).timeout

func _resolve_multi_attack_hero() -> void:
	var attackers := _sort_attackers_left_to_right(selected_attackers)
	clear_multi_selection()
	for attacker in attackers:
		if attacker == null or attacker.is_dead() or not attacker.can_attack():
			continue
		if not _can_attack_hero(attacker):
			continue
		await _perform_hero_attack(attacker)
		await get_tree().create_timer(0.4).timeout
	check_game_end()
	refresh_board()

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
	if selected_attacker and selected_attacker not in player_minions:
		clear_selection()
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
		0.08
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Charge
	attack_tween.tween_property(
		attacker_visual,
		"position",
		start_position + impact_offset,
		0.10
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
		0.18
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await attack_tween.finished
	if is_instance_valid(attacker_visual):
		attacker_visual.z_index = 0

func _has_split_row_containers(is_player: bool) -> bool:
	if is_player:
		return player_front_container != null and player_back_container != null
	return enemy_front_container != null and enemy_back_container != null

func _rebuild_minion_visuals(
	container: Node,
	minions: Array[Minion],
	is_player: bool,
	previously_existing: Array[Minion]
) -> void:
	if container == null:
		return
	for minion in minions:
		# déjà existant → on ne recrée pas
		if minion_to_visual.has(minion):
			var existing: BoardMinion = minion_to_visual[minion]
			if is_instance_valid(existing):
				existing.update_display()
				_move_visual_if_needed(minion, existing, container)
			continue
		# nouveau minion → spawn
		var visual: BoardMinion = BOARD_MINION_SCENE.instantiate()
		container.add_child(visual)
		visual.set_minion(minion)
		minion_to_visual[minion] = visual
		if is_player:
			visual.minion_clicked.connect(_on_player_minion_clicked)
		else:
			visual.minion_clicked.connect(_on_enemy_minion_clicked)
		_play_summon_animation(visual)

func _move_visual_if_needed(minion: Minion, visual: BoardMinion, container: Control) -> void:
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
		if is_multi_selecting:
			clear_multi_selection()

func get_player_drop_row_at(mouse: Vector2, card_data: CardData = null) -> String:
	var allowed_rows: Array[String] = get_allowed_rows_for_card(card_data)
	if player_front_container is Control and player_front_container.get_global_rect().has_point(mouse):
		return ROW_FRONT if ROW_FRONT in allowed_rows else ""
	if player_back_container is Control and player_back_container.get_global_rect().has_point(mouse):
		return ROW_BACK if ROW_BACK in allowed_rows else ""
	return ""

func get_player_drop_index_at(mouse: Vector2, row: String) -> int:
	return _get_stable_player_drop_index_at(mouse, row)

func _get_raw_player_drop_index_at(mouse: Vector2, row: String) -> int:
	var container: Control = _get_player_row_container(row)
	if container == null:
		return -1
	var index: int = 0
	for child in container.get_children():
		if child is BoardMinion:
			var rect: Rect2 = child.get_global_rect()
			if mouse.x < rect.position.x + rect.size.x * 0.5:
				return index
			index += 1
	return index

func update_player_drop_highlight(card_data: CardData, mouse: Vector2, display_show: bool) -> bool:
	_ensure_drop_highlights()
	var allowed_rows: Array[String] = get_allowed_rows_for_card(card_data)
	for row in [ROW_FRONT, ROW_BACK]:
		var panel: Panel = _drop_highlights.get(row) as Panel
		var row_container: Control = _get_player_row_container(row)
		if panel == null or row_container == null:
			continue
		var can_show: bool = display_show and row in allowed_rows and can_summon_to_row(true, row)
		panel.visible = can_show
		if can_show:
			_fit_drop_highlight_to(row_container, panel)
	var drop_row: String = get_player_drop_row_at(mouse, card_data)
	if display_show and not drop_row.is_empty() and can_summon_to_row(true, drop_row):
		var insert_index: int = _get_stable_player_drop_index_at(mouse, drop_row)
		_update_drop_placeholder(drop_row, insert_index)
		return true
	_clear_drop_placeholder()
	return false

func clear_player_drop_highlight() -> void:
	for panel in _drop_highlights.values():
		var control: Control = panel as Control
		if control != null:
			control.visible = false
	_clear_drop_placeholder()

func _ensure_drop_highlights() -> void:
	if not _drop_highlights.is_empty():
		return
	var board: Control = get_node_or_null("Board") as Control
	if board == null:
		return
	for row in [ROW_FRONT, ROW_BACK]:
		var panel: Panel = Panel.new()
		panel.name = "Player%sDropHighlight" % row
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.visible = false
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = DROP_HIGHLIGHT_COLOR
		style.border_color = DROP_HIGHLIGHT_BORDER_COLOR
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		panel.add_theme_stylebox_override("panel", style)
		board.add_child(panel)
		_drop_highlights[row] = panel

func _fit_drop_highlight_to(row_container: Control, panel: Control) -> void:
	var board: Control = get_node_or_null("Board") as Control
	if board == null:
		return
	var rect: Rect2 = row_container.get_global_rect()
	var board_origin: Vector2 = board.global_position
	panel.position = rect.position - board_origin
	panel.size = rect.size
	board.move_child(panel, 0)

func _get_player_row_container(row: String) -> Control:
	if row == ROW_BACK:
		return player_back_container
	return player_front_container

func _update_drop_placeholder(row: String, insert_index: int) -> void:
	var container: Control = _get_player_row_container(row)
	if container == null:
		return
	if _drop_placeholder == null:
		_drop_placeholder = _create_drop_placeholder()
	if _drop_placeholder.get_parent() != container:
		if _drop_placeholder.get_parent() != null:
			_drop_placeholder.get_parent().remove_child(_drop_placeholder)
		container.add_child(_drop_placeholder)
	_drop_placeholder.visible = true
	_drop_placeholder.custom_minimum_size = BOARD_MINION_SIZE
	_drop_placeholder_row = row
	_drop_placeholder_index = insert_index
	# Only rearrange if the index actually changed to prevent constant layout recalculation
	if _last_placeholder_index != insert_index or _last_placeholder_row != row:
		var child_index: int = _get_row_child_index_for_insert(container, insert_index)
		container.move_child(_drop_placeholder, child_index)
		_last_placeholder_index = insert_index
		_last_placeholder_row = row

func _create_drop_placeholder() -> Panel:
	var placeholder: Panel = Panel.new()
	placeholder.name = "DropPlaceholder"
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placeholder.custom_minimum_size = BOARD_MINION_SIZE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.45, 0.05, 0.16)
	style.border_color = DROP_HIGHLIGHT_BORDER_COLOR
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	placeholder.add_theme_stylebox_override("panel", style)
	return placeholder

func _get_row_child_index_for_insert(container: Control, insert_index: int) -> int:
	var seen_minions: int = 0
	var fallback_index: int = container.get_child_count()
	for i in range(container.get_child_count()):
		var child: Node = container.get_child(i)
		if child == _drop_placeholder:
			continue
		if child is BoardMinion:
			if seen_minions == insert_index:
				return i
			seen_minions += 1
		fallback_index = i + 1
	return fallback_index

func _get_stable_player_drop_index_at(mouse: Vector2, row: String) -> int:
	if _drop_placeholder != null and _drop_placeholder.visible and _drop_placeholder_row == row:
		var placeholder_rect: Rect2 = _drop_placeholder.get_global_rect().grow(35.0)
		if placeholder_rect.has_point(mouse):
			return _drop_placeholder_index
	return _get_raw_player_drop_index_at(mouse, row)

func _clear_drop_placeholder() -> void:
	if _drop_placeholder == null:
		return
	_drop_placeholder.visible = false
	_drop_placeholder_row = ""
	_drop_placeholder_index = -1
	_last_placeholder_index = -1
	_last_placeholder_row = ""
	if _drop_placeholder.get_parent() != null:
		_drop_placeholder.get_parent().remove_child(_drop_placeholder)

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
	preview.modulate = Color(1, 1, 1, 0.85)
	add_child(preview)
	preview.set_minion(Minion.new(card_data, true, ROW_FRONT))
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
