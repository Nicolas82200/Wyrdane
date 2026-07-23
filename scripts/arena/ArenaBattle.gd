extends Control

# Scène racine du prototype Arena (voir plan Arena « Refonte visuelle »).
# Reprend le look du plateau 1v1 (scenes/battle/Battle.tscn) en réutilisant
# les vrais visuels `Card`/`BoardMinion`, construits ici programmatiquement
# (pas de .tscn détaillé) pour éviter le risque d'édition de scène à la main.
# La boutique occupe la position "rangée adverse" (Avant, la plus proche du
# centre) ; acheter un serviteur se fait en le glissant vers son propre
# plateau (drag & drop autonome, voir ArenaShopCardSlot/ArenaBoardRow — pas
# de réutilisation de Card.gd/DropSystem.gd, pensés pour le mana/ciblage 1v1).
# L'achat rejoint la main (comme un achat au clic) ; la pose sur le plateau
# reste une action séparée via les boutons Avant/Arrière de la main.
#
# 4 participants : le joueur humain (index 0) + 3 bots (ArenaBotDriver).

const CARD_SCENE := preload("res://scenes/card/Card.tscn")
const BOARD_MINION_SCENE := preload("res://scenes/minion/BoardMinion.tscn")
const HERO_ARTS := [
	preload("res://assets/heros_art/king-aldric-dawnbearer.jpg"),
	preload("res://assets/heros_art/azhar-the-fallen.jpg"),
]

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
var hand_container: HBoxContainer
var spell_hand_container: HBoxContainer
var front_row: ArenaBoardRow
var back_row: ArenaBoardRow
var hero_portrait: TextureRect
var other_boards_container: VBoxContainer
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
	# Le pool Arena inclut les cartes exclusives à ce mode (CardData.arena_only)
	# en plus du pool 1v1 normal (voir CardLibrary.arena_only_cards).
	var pool_cards: Array[CardData] = CardLibrary.all_cards + CardLibrary.arena_only_cards
	var pool := ArenaCardPool.new(pool_cards)
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

	var scroll := ScrollContainer.new()
	margin.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	vbox.add_child(header)
	round_label = _make_label(header)
	hero_hp_label = _make_label(header)
	gold_label = _make_label(header)
	xp_label = _make_label(header)
	level_label = _make_label(header)

	participants_label = _make_label(vbox)

	# ─ Rangée boutique : occupe la position "Avant adverse" du plateau ─
	vbox.add_child(_make_title(SettingsManager.t("ARENA_SHOP_TITLE")))
	shop_row = HBoxContainer.new()
	shop_row.add_theme_constant_override("separation", 8)
	shop_row.alignment = BoxContainer.ALIGNMENT_CENTER
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

	var center_sep := HSeparator.new()
	vbox.add_child(center_sep)

	# ─ Plateau du joueur : Avant proche du centre, Arrière plus loin ─
	vbox.add_child(_make_title(SettingsManager.t("ARENA_BOARD_FRONT_TITLE")))
	front_row = ArenaBoardRow.new()
	front_row.is_front = true
	front_row.on_drop = _on_shop_card_dropped
	front_row.add_theme_constant_override("separation", 8)
	front_row.alignment = BoxContainer.ALIGNMENT_CENTER
	front_row.custom_minimum_size = Vector2(0, 160)
	vbox.add_child(front_row)

	vbox.add_child(_make_title(SettingsManager.t("ARENA_BOARD_BACK_TITLE")))
	back_row = ArenaBoardRow.new()
	back_row.is_front = false
	back_row.on_drop = _on_shop_card_dropped
	back_row.add_theme_constant_override("separation", 8)
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	back_row.custom_minimum_size = Vector2(0, 160)
	vbox.add_child(back_row)

	var hero_row := HBoxContainer.new()
	hero_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hero_row)
	hero_portrait = _make_hero_portrait(HERO_ARTS[0])
	hero_row.add_child(hero_portrait)

	# ─ Main du joueur ─
	vbox.add_child(_make_title(SettingsManager.t("ARENA_HAND_TITLE")))
	suspended_label = _make_label(vbox)
	hand_container = HBoxContainer.new()
	hand_container.add_theme_constant_override("separation", 8)
	vbox.add_child(hand_container)

	vbox.add_child(_make_title(SettingsManager.t("ARENA_SPELL_HAND_TITLE")))
	spell_hand_container = HBoxContainer.new()
	spell_hand_container.add_theme_constant_override("separation", 8)
	vbox.add_child(spell_hand_container)

	vbox.add_child(_make_title(SettingsManager.t("ARENA_OTHER_BOARDS_TITLE")))
	other_boards_container = VBoxContainer.new()
	other_boards_container.add_theme_constant_override("separation", 6)
	vbox.add_child(other_boards_container)

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

func _make_hero_portrait(art: Texture2D, scale_factor: float = 1.0) -> TextureRect:
	var tex := TextureRect.new()
	tex.texture = art
	tex.custom_minimum_size = Vector2(90, 125) * scale_factor
	tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return tex

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
	_refresh_spells()
	_refresh_board()
	_refresh_other_boards()

	ready_button.disabled = game_over
	ready_button.visible = not game_over

# La boutique occupe la position "Avant adverse" : chaque offre est une vraie
# `Card` (voir ArenaShopCardSlot), verrouillable (bouton) et achetable en la
# glissant vers son propre plateau (front_row/back_row, voir ArenaBoardRow).
func _refresh_shop() -> void:
	for child in shop_row.get_children():
		child.queue_free()
	for i in human.shop_offer.size():
		var card: CardData = human.shop_offer[i]
		var col := VBoxContainer.new()
		shop_row.add_child(col)
		var slot := ArenaShopCardSlot.new()
		# `col` doit déjà être dans l'arbre de scène avant setup() (qui
		# instancie et configure une vraie Card en enfant) : les @onready
		# de Card ne sont peuplés qu'une fois le nœud réellement entré dans
		# l'arbre (voir Hand.gd : add_child() puis set_data(), jamais l'inverse).
		col.add_child(slot)
		slot.setup(card, i)
		var lock_button := Button.new()
		var locked: bool = i < human.shop_locked.size() and human.shop_locked[i]
		lock_button.text = SettingsManager.t("ARENA_UNLOCK_BUTTON") if locked else SettingsManager.t("ARENA_LOCK_BUTTON")
		lock_button.disabled = card == null
		lock_button.pressed.connect(_on_lock_pressed.bind(i))
		col.add_child(lock_button)

func _on_shop_card_dropped(shop_index: int, _is_front: bool) -> void:
	# L'achat par glisser-déposer rejoint la main (comme un achat au clic) ;
	# la pose sur le plateau reste une action séparée et volontaire du joueur
	# (boutons Avant/Arrière dans la main), pas automatique au moment du drop.
	match_.buy_card(human, shop_index)
	_refresh_ui()

func _refresh_hand() -> void:
	for child in hand_container.get_children():
		child.queue_free()
	for minion in human.hand:
		var col := VBoxContainer.new()
		hand_container.add_child(col)
		_add_minion_card_visual(col, minion)
		var front_button := Button.new()
		front_button.text = SettingsManager.t("ARENA_PLACE_FRONT_BUTTON")
		front_button.disabled = not human.can_place_on_row(true)
		front_button.pressed.connect(_on_place_pressed.bind(minion, true))
		col.add_child(front_button)
		var back_button := Button.new()
		back_button.text = SettingsManager.t("ARENA_PLACE_BACK_BUTTON")
		back_button.disabled = not human.can_place_on_row(false)
		back_button.pressed.connect(_on_place_pressed.bind(minion, false))
		col.add_child(back_button)
		var sell_button := Button.new()
		sell_button.text = SettingsManager.t("ARENA_SELL_BUTTON")
		sell_button.pressed.connect(_on_sell_pressed.bind(minion, false))
		col.add_child(sell_button)

# `col` doit déjà être dans l'arbre de scène (voir commentaire _refresh_shop) :
# on l'ajoute avant d'instancier/configurer la Card, jamais après.
func _add_minion_card_visual(col: Node, minion: Minion) -> void:
	var card: Card = CARD_SCENE.instantiate()
	col.add_child(card)
	card.scale = Vector2(0.6, 0.6)
	card.set_data(minion.card_data)
	card.set_non_interactive()
	card.cost_label.text = str(minion.card_data.cost)
	card.generic_cost_label.visible = false
	card.attack_label.text = str(minion.attack)
	card.health_label.text = str(minion.health)
	if minion.star_level > 1:
		card.name_label.text += " ★%d" % minion.star_level

# Incantations achetées (arena_only, voir CARDS.md « Cartes exclusives
# Arena ») : uniquement des effets ciblant soi-même/ses alliés (Buff/
# GrantKeyword/HealHero) — aucun ciblage à choisir, "Lancer" les applique
# immédiatement (à soi, tout le plateau, ou une rangée).
func _refresh_spells() -> void:
	for child in spell_hand_container.get_children():
		child.queue_free()
	for card_data in human.spell_hand:
		var col := VBoxContainer.new()
		spell_hand_container.add_child(col)
		_add_spell_card_visual(col, card_data)
		var cast_button := Button.new()
		cast_button.text = SettingsManager.t("ARENA_CAST_BUTTON")
		cast_button.pressed.connect(_on_cast_pressed.bind(card_data))
		col.add_child(cast_button)
		var sell_button := Button.new()
		sell_button.text = SettingsManager.t("ARENA_SELL_BUTTON")
		sell_button.pressed.connect(_on_sell_spell_pressed.bind(card_data))
		col.add_child(sell_button)

func _add_spell_card_visual(col: Node, card_data: CardData) -> void:
	var card: Card = CARD_SCENE.instantiate()
	col.add_child(card)
	card.scale = Vector2(0.6, 0.6)
	card.set_data(card_data)
	card.set_non_interactive()
	card.cost_label.text = str(card_data.cost)
	card.generic_cost_label.visible = false

func _refresh_board() -> void:
	for child in front_row.get_children():
		child.queue_free()
	for child in back_row.get_children():
		child.queue_free()
	for minion in human.board_front:
		_add_board_entry(front_row, minion)
	for minion in human.board_back:
		_add_board_entry(back_row, minion)

func _add_board_entry(row: Node, minion: Minion) -> void:
	var col := VBoxContainer.new()
	row.add_child(col)
	var visual: BoardMinion = BOARD_MINION_SCENE.instantiate()
	col.add_child(visual)
	visual.set_minion(minion)
	var sell_button := Button.new()
	sell_button.text = SettingsManager.t("ARENA_SELL_BUTTON")
	sell_button.pressed.connect(_on_sell_pressed.bind(minion, true))
	col.add_child(sell_button)

# Le plateau de chaque joueur est visible de tous (README « Visibilité entre
# joueurs ») — lecture seule (aucun signal de clic connecté), à échelle
# réduite. La main/boutique de chacun reste privée, donc jamais affichée.
func _refresh_other_boards() -> void:
	for child in other_boards_container.get_children():
		child.queue_free()
	var art_index := 0
	for p in match_.players:
		if p == human:
			continue
		art_index += 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		other_boards_container.add_child(row)
		row.add_child(_make_hero_portrait(HERO_ARTS[art_index % HERO_ARTS.size()], 0.5))
		var info := VBoxContainer.new()
		row.add_child(info)
		if p.is_eliminated:
			info.add_child(_make_label_text("%s — %s" % [p.display_name, SettingsManager.t("ARENA_ELIMINATED_STATUS")]))
			continue
		info.add_child(_make_label_text(SettingsManager.t("ARENA_OTHER_BOARD_LINE") % [p.display_name, p.hero_hp]))
		var minions_box := HBoxContainer.new()
		minions_box.add_theme_constant_override("separation", 2)
		info.add_child(minions_box)
		var minions: Array[Minion] = p.board_front + p.board_back
		if minions.is_empty():
			minions_box.add_child(_make_label_text(SettingsManager.t("ARENA_OTHER_BOARD_EMPTY")))
		else:
			for minion in minions:
				var visual: BoardMinion = BOARD_MINION_SCENE.instantiate()
				visual.scale = Vector2(0.5, 0.5)
				minions_box.add_child(visual)
				visual.set_minion(minion)
	_refresh_ghost_board()

func _refresh_ghost_board() -> void:
	var ghost: GhostBoard = match_.ghost_board
	if ghost == null:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	other_boards_container.add_child(row)
	var info := VBoxContainer.new()
	row.add_child(info)
	info.add_child(_make_label_text(SettingsManager.t("ARENA_GHOST_BOARD_LINE") % ghost.origin_player_name))
	var minions_box := HBoxContainer.new()
	minions_box.add_theme_constant_override("separation", 2)
	info.add_child(minions_box)
	var minions: Array[Minion] = ghost.front + ghost.back
	if minions.is_empty():
		minions_box.add_child(_make_label_text(SettingsManager.t("ARENA_OTHER_BOARD_EMPTY")))
	else:
		for minion in minions:
			var visual: BoardMinion = BOARD_MINION_SCENE.instantiate()
			visual.scale = Vector2(0.5, 0.5)
			minions_box.add_child(visual)
			visual.set_minion(minion)

func _minion_summary(minion: Minion) -> String:
	var star: String = " ★%d" % minion.star_level if minion.star_level > 1 else ""
	return "%s%s (%d/%d, %d⬡)" % [minion.card_data.display_name(), star, minion.attack, minion.health, minion.card_data.cost]

func _make_label_text(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label

# ─── Actions joueur ──────────────────────────────────────────────────────────

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

func _on_cast_pressed(card_data: CardData) -> void:
	await match_.cast_spell(human, card_data)
	_refresh_ui()

func _on_sell_spell_pressed(card_data: CardData) -> void:
	match_.sell_spell(human, card_data)
	_refresh_ui()

# ─── Phase Combat ────────────────────────────────────────────────────────────

func _on_ready_pressed() -> void:
	ready_button.disabled = true
	for bot in bots:
		if not bot.is_alive():
			continue
		bot_driver.play_shop_phase(bot, match_)
		bot_driver.play_positioning_phase(bot)
		# Après la pose, pas avant : les Incantations "tout le plateau" doivent
		# viser la composition finale du bot, pas un plateau encore incomplet.
		await bot_driver.cast_spells_phase(bot, match_)
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
	var title: String = SettingsManager.t("ARENA_DEFEAT_TITLE") if human.is_eliminated else SettingsManager.t("ARENA_VICTORY_TITLE")
	var lines: Array[String] = [title, "", SettingsManager.t("ARENA_RANKING_TITLE") + " :"]
	var ranking: Array[ArenaPlayerState] = match_.final_ranking()
	for i in ranking.size():
		lines.append("  %d. %s" % [i + 1, ranking[i].display_name])
	end_game_label.text = "\n".join(lines)

func _on_next_round_pressed() -> void:
	next_round_button.visible = false
	match_.advance_round()
	match_.start_shop_phase()
	combat_log_label.text = ""
	_refresh_ui()

func _on_back_to_menu_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
