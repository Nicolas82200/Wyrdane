extends Control

# Scène racine du prototype Arena (voir plan Arena, étape 7). UI
# volontairement grossière (Labels/Buttons, aucune animation) : l'objectif est
# de valider le moteur de règles (ArenaMatch/SimulatedBattle/ArenaBotDriver),
# pas le rendu visuel — voir décisions du plan ("résumé texte instantané",
# "bouton Prêt sans timer", scène quasi-final laissée pour plus tard).
#
# 4 participants : le joueur humain (index 0) + 3 bots (ArenaBotDriver).

var match_: ArenaMatch
var human: ArenaPlayerState
var bots: Array[ArenaPlayerState] = []
var bot_driver := ArenaBotDriver.new()
var game_over: bool = false

var round_label: Label
var hero_hp_label: Label
var gold_label: Label
var xp_label: Label
var level_label: Label
var participants_label: Label
var shop_row: HBoxContainer
var reroll_button: Button
var buy_xp_button: Button
var suspended_label: Label
var hand_container: VBoxContainer
var front_container: HBoxContainer
var back_container: HBoxContainer
var ready_button: Button
var next_round_button: Button
var back_to_menu_button: Button
var combat_log_label: Label
var end_game_label: Label

const MAIN_MENU_SCENE := "res://scenes/mainMenu/MainMenu.tscn"

func _ready() -> void:
	_build_ui()
	_start_match()

func _start_match() -> void:
	if not CardLibrary.is_loaded:
		CardLibrary.load_all_cards()
	var pool := ArenaCardPool.new(CardLibrary.all_cards)
	human = ArenaPlayerState.new("Joueur", false)
	bots = [
		ArenaPlayerState.new("Bot 1", true),
		ArenaPlayerState.new("Bot 2", true),
		ArenaPlayerState.new("Bot 3", true),
	]
	var players: Array[ArenaPlayerState] = [human]
	players.append_array(bots)
	match_ = ArenaMatch.new(players, pool)
	match_.start_shop_phase()
	_refresh_ui()

# ─── Construction de l'UI (programmatique, pas de .tscn détaillé) ────────────

func _build_ui() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0

	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	vbox.add_child(header)
	round_label = _make_label(header)
	hero_hp_label = _make_label(header)
	gold_label = _make_label(header)
	xp_label = _make_label(header)
	level_label = _make_label(header)

	participants_label = _make_label(vbox)

	vbox.add_child(_make_title(SettingsManager.t("ARENA_SHOP_TITLE")))
	shop_row = HBoxContainer.new()
	shop_row.add_theme_constant_override("separation", 8)
	vbox.add_child(shop_row)

	var shop_controls := HBoxContainer.new()
	shop_controls.add_theme_constant_override("separation", 8)
	vbox.add_child(shop_controls)
	reroll_button = Button.new()
	reroll_button.pressed.connect(_on_reroll_pressed)
	shop_controls.add_child(reroll_button)
	buy_xp_button = Button.new()
	buy_xp_button.pressed.connect(_on_buy_xp_pressed)
	shop_controls.add_child(buy_xp_button)

	vbox.add_child(_make_title(SettingsManager.t("ARENA_HAND_TITLE")))
	suspended_label = _make_label(vbox)
	hand_container = VBoxContainer.new()
	vbox.add_child(hand_container)

	var board_row := HBoxContainer.new()
	board_row.add_theme_constant_override("separation", 24)
	vbox.add_child(board_row)
	var front_col := VBoxContainer.new()
	board_row.add_child(front_col)
	front_col.add_child(_make_title(SettingsManager.t("ARENA_BOARD_FRONT_TITLE")))
	front_container = HBoxContainer.new()
	front_col.add_child(front_container)
	var back_col := VBoxContainer.new()
	board_row.add_child(back_col)
	back_col.add_child(_make_title(SettingsManager.t("ARENA_BOARD_BACK_TITLE")))
	back_container = HBoxContainer.new()
	back_col.add_child(back_container)

	ready_button = Button.new()
	ready_button.text = SettingsManager.t("ARENA_READY_BUTTON")
	ready_button.pressed.connect(_on_ready_pressed)
	vbox.add_child(ready_button)

	vbox.add_child(_make_title(SettingsManager.t("ARENA_COMBAT_LOG_TITLE")))
	combat_log_label = Label.new()
	combat_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(combat_log_label)

	next_round_button = Button.new()
	next_round_button.text = SettingsManager.t("ARENA_NEXT_ROUND_BUTTON")
	next_round_button.visible = false
	next_round_button.pressed.connect(_on_next_round_pressed)
	vbox.add_child(next_round_button)

	end_game_label = Label.new()
	end_game_label.visible = false
	vbox.add_child(end_game_label)

	back_to_menu_button = Button.new()
	back_to_menu_button.text = SettingsManager.t("ARENA_BACK_TO_MENU_BUTTON")
	back_to_menu_button.visible = false
	back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)
	vbox.add_child(back_to_menu_button)

func _make_label(parent: Node) -> Label:
	var label := Label.new()
	parent.add_child(label)
	return label

func _make_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	return label

# ─── Rafraîchissement ────────────────────────────────────────────────────────

func _refresh_ui() -> void:
	round_label.text = SettingsManager.t("ARENA_ROUND_LABEL") % match_.round_number
	hero_hp_label.text = SettingsManager.t("ARENA_HERO_HP_LABEL") % human.hero_hp
	gold_label.text = SettingsManager.t("ARENA_GOLD_LABEL") % human.gold
	xp_label.text = SettingsManager.t("ARENA_XP_LABEL") % human.xp
	var next_level_xp: int = ArenaConstants.xp_required_for_next_level(human.level)
	if next_level_xp < 0:
		level_label.text = SettingsManager.t("ARENA_LEVEL_MAX_LABEL") % human.level
	else:
		level_label.text = SettingsManager.t("ARENA_LEVEL_PROGRESS_LABEL") % [human.level, human.xp, next_level_xp]

	var lines: Array[String] = []
	lines.append(SettingsManager.t("ARENA_PARTICIPANTS_TITLE") + " :")
	for p in match_.players:
		var status: String = SettingsManager.t("ARENA_ELIMINATED_STATUS") if p.is_eliminated else str(p.hero_hp)
		lines.append("  %s : %s" % [p.display_name, status])
	participants_label.text = "\n".join(lines)

	reroll_button.text = SettingsManager.t("ARENA_REROLL_BUTTON")
	reroll_button.disabled = human.gold < ArenaConstants.REROLL_COST
	buy_xp_button.text = SettingsManager.t("ARENA_BUY_XP_BUTTON")
	buy_xp_button.disabled = not ArenaEconomy.can_buy_xp(match_.round_number) or human.gold < ArenaConstants.GOLD_TO_XP_RATE or human.level >= 8

	suspended_label.text = SettingsManager.t("ARENA_SUSPENDED_LABEL") % human.suspended.size() if not human.suspended.is_empty() else ""

	_refresh_shop()
	_refresh_hand()
	_refresh_board()

	ready_button.disabled = game_over
	ready_button.visible = not game_over

func _refresh_shop() -> void:
	for child in shop_row.get_children():
		child.queue_free()
	for i in human.shop_offer.size():
		var card: CardData = human.shop_offer[i]
		var col := VBoxContainer.new()
		shop_row.add_child(col)
		var buy_button := Button.new()
		if card == null:
			buy_button.text = "—"
			buy_button.disabled = true
		else:
			buy_button.text = "%s (%d)" % [card.display_name(), card.cost]
			buy_button.disabled = human.gold < card.cost or human.is_hand_full()
			buy_button.pressed.connect(_on_buy_pressed.bind(i))
		col.add_child(buy_button)
		var lock_button := Button.new()
		var locked: bool = i < human.shop_locked.size() and human.shop_locked[i]
		lock_button.text = SettingsManager.t("ARENA_UNLOCK_BUTTON") if locked else SettingsManager.t("ARENA_LOCK_BUTTON")
		lock_button.disabled = card == null
		lock_button.pressed.connect(_on_lock_pressed.bind(i))
		col.add_child(lock_button)

func _refresh_hand() -> void:
	for child in hand_container.get_children():
		child.queue_free()
	for minion in human.hand:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		hand_container.add_child(row)
		row.add_child(_make_label_text(_minion_summary(minion)))
		var front_button := Button.new()
		front_button.text = SettingsManager.t("ARENA_PLACE_FRONT_BUTTON")
		front_button.disabled = not human.can_place_on_row(true)
		front_button.pressed.connect(_on_place_pressed.bind(minion, true))
		row.add_child(front_button)
		var back_button := Button.new()
		back_button.text = SettingsManager.t("ARENA_PLACE_BACK_BUTTON")
		back_button.disabled = not human.can_place_on_row(false)
		back_button.pressed.connect(_on_place_pressed.bind(minion, false))
		row.add_child(back_button)
		var sell_button := Button.new()
		sell_button.text = SettingsManager.t("ARENA_SELL_BUTTON")
		sell_button.pressed.connect(_on_sell_pressed.bind(minion, false))
		row.add_child(sell_button)

func _refresh_board() -> void:
	for child in front_container.get_children():
		child.queue_free()
	for child in back_container.get_children():
		child.queue_free()
	for minion in human.board_front:
		front_container.add_child(_make_board_entry(minion))
	for minion in human.board_back:
		back_container.add_child(_make_board_entry(minion))

func _make_board_entry(minion: Minion) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_child(_make_label_text(_minion_summary(minion)))
	var sell_button := Button.new()
	sell_button.text = SettingsManager.t("ARENA_SELL_BUTTON")
	sell_button.pressed.connect(_on_sell_pressed.bind(minion, true))
	col.add_child(sell_button)
	return col

func _minion_summary(minion: Minion) -> String:
	var star: String = " ★%d" % minion.star_level if minion.star_level > 1 else ""
	return "%s%s (%d/%d, %d⬡)" % [minion.card_data.display_name(), star, minion.attack, minion.health, minion.card_data.cost]

func _make_label_text(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label

# ─── Actions joueur ──────────────────────────────────────────────────────────

func _on_buy_pressed(index: int) -> void:
	match_.buy_card(human, index)
	_refresh_ui()

func _on_lock_pressed(index: int) -> void:
	match_.lock_card(human, index)
	_refresh_ui()

func _on_reroll_pressed() -> void:
	match_.reroll(human)
	_refresh_ui()

func _on_buy_xp_pressed() -> void:
	match_.buy_xp(human)
	_refresh_ui()

func _on_place_pressed(minion: Minion, is_front: bool) -> void:
	human.place_on_board(minion, is_front)
	_refresh_ui()

func _on_sell_pressed(minion: Minion, from_board: bool) -> void:
	match_.sell_card(human, minion, from_board)
	_refresh_ui()

# ─── Phase Combat ────────────────────────────────────────────────────────────

func _on_ready_pressed() -> void:
	ready_button.disabled = true
	for bot in bots:
		if not bot.is_alive():
			continue
		bot_driver.play_shop_phase(bot, match_)
		bot_driver.play_positioning_phase(bot)
	match_.end_shop_phase()
	await match_.start_combat_phase()
	combat_log_label.text = "\n".join(match_.last_combat_summaries)

	if match_.is_match_over() or human.is_eliminated:
		_show_game_over()
	else:
		next_round_button.visible = true
	_refresh_ui()

func _show_game_over() -> void:
	game_over = true
	end_game_label.visible = true
	back_to_menu_button.visible = true
	if human.is_eliminated:
		end_game_label.text = SettingsManager.t("ARENA_DEFEAT_TITLE")
	else:
		end_game_label.text = SettingsManager.t("ARENA_VICTORY_TITLE")

func _on_next_round_pressed() -> void:
	next_round_button.visible = false
	match_.advance_round()
	match_.start_shop_phase()
	combat_log_label.text = ""
	_refresh_ui()

func _on_back_to_menu_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
