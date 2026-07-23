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
var shop_front_row: HBoxContainer
var shop_back_row: HBoxContainer
var reroll_button: Button
var buy_xp_button: Button
var suspended_label: Label
var hand_container: HBoxContainer
var spell_hand_container: HBoxContainer
var viewing_label: Label
var front_row: ArenaBoardRow
var back_row: ArenaBoardRow
var hero_portrait: TextureRect
var portraits_row: HBoxContainer
# Joueur (ou GhostBoard) dont le plateau est actuellement affiché — façon TFT,
# cliquer un portrait remplace la vue par le sien, en lecture seule.
var viewed_target = null
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
	viewed_target = human
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

	# ─ Boutique : occupe la position "adverse" du plateau — chaque carte
	# proposée est rangée dans la rangée Avant/Arrière qui correspond à son
	# propre board_position (README : lignes adverses), comme si l'offre du
	# tour était le plateau d'en face. Arrière (plus loin du centre) d'abord,
	# Avant (plus proche du centre) ensuite, pour respecter l'empilement
	# vertical du plateau 1v1 (Battle.tscn).
	vbox.add_child(_make_title(SettingsManager.t("ARENA_SHOP_TITLE")))
	shop_back_row = HBoxContainer.new()
	shop_back_row.add_theme_constant_override("separation", 8)
	shop_back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_make_lane_panel(shop_back_row))
	shop_front_row = HBoxContainer.new()
	shop_front_row.add_theme_constant_override("separation", 8)
	shop_front_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_make_lane_panel(shop_front_row))

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

	# ─ Plateau consulté : Avant proche du centre, Arrière plus loin. Par
	# défaut le sien, mais cliquer un portrait (portraits_row plus bas)
	# l'échange contre celui d'un autre participant (lecture seule). Pas
	# d'emplacement Rituel/Enchantement pour l'instant (hors scope Arena v1).
	viewing_label = _make_title("")
	vbox.add_child(viewing_label)
	front_row = ArenaBoardRow.new()
	front_row.is_front = true
	front_row.on_drop = _on_shop_card_dropped
	front_row.add_theme_constant_override("separation", 8)
	front_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_make_lane_panel(front_row))

	back_row = ArenaBoardRow.new()
	back_row.is_front = false
	back_row.on_drop = _on_shop_card_dropped
	back_row.add_theme_constant_override("separation", 8)
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_make_lane_panel(back_row))

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

	ready_button = Button.new()
	ready_button.text = SettingsManager.t("ARENA_READY_BUTTON")
	ready_button.pressed.connect(_on_ready_pressed)
	vbox.add_child(ready_button)

	# ─ Portraits cliquables (façon TFT) : remplace la position du journal de
	# combat — cliquer un participant affiche son plateau ci-dessus à la
	# place du tien (lecture seule). Le journal détaillé reste plus bas.
	vbox.add_child(_make_title(SettingsManager.t("ARENA_PARTICIPANTS_TITLE")))
	portraits_row = HBoxContainer.new()
	portraits_row.add_theme_constant_override("separation", 8)
	vbox.add_child(portraits_row)

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

	vbox.add_child(_make_title(SettingsManager.t("ARENA_COMBAT_LOG_TITLE")))
	combat_log_label = Label.new()
	combat_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(combat_log_label)

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

# Panneau de rangée façon plateau 1v1 (scenes/battle/Battle.tscn, style
# "lane" gris foncé translucide) : juste le fond visuel d'une rangée Avant/
# Arrière (boutique ou plateau) — pas d'emplacement Rituel/Enchantement.
func _make_lane_panel(row: Control) -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.18)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.55, 0.55, 0.6, 0.3)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(0, 160)
	panel.add_child(row)
	return panel

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

	# Si la cible consultée est éliminée (ou invalide), on revient sur son
	# propre plateau plutôt que d'afficher un plateau figé/vidé.
	if viewed_target == null or (viewed_target is ArenaPlayerState and viewed_target.is_eliminated):
		viewed_target = human

	reroll_button.text = SettingsManager.t("ARENA_REROLL_BUTTON")
	reroll_button.disabled = human.gold < ArenaConstants.REROLL_COST
	buy_xp_button.text = SettingsManager.t("ARENA_BUY_XP_BUTTON")
	buy_xp_button.disabled = not ArenaEconomy.can_buy_xp(match_.round_number) or human.gold < ArenaConstants.GOLD_TO_XP_RATE or human.level >= 8

	suspended_label.text = SettingsManager.t("ARENA_SUSPENDED_LABEL") % human.suspended.size() if not human.suspended.is_empty() else ""

	_refresh_shop()
	_refresh_hand()
	_refresh_spells()
	_refresh_board()
	_refresh_portraits()

	ready_button.disabled = game_over
	ready_button.visible = not game_over

# La boutique occupe la position "adverse" du plateau : chaque offre est une
# vraie `Card` (voir ArenaShopCardSlot), rangée dans shop_front_row ou
# shop_back_row selon son propre board_position ("Back" -> Arrière, sinon
# Avant), verrouillable (bouton) et achetable en la glissant vers son propre
# plateau (front_row/back_row, voir ArenaBoardRow). Un emplacement déjà
# acheté (carte nulle) n'affiche simplement rien jusqu'au prochain reroll.
func _refresh_shop() -> void:
	for child in shop_front_row.get_children():
		child.queue_free()
	for child in shop_back_row.get_children():
		child.queue_free()
	for i in human.shop_offer.size():
		var card: CardData = human.shop_offer[i]
		if card == null:
			continue
		var target_row: HBoxContainer = shop_back_row if card.board_position == "Back" else shop_front_row
		var col := VBoxContainer.new()
		target_row.add_child(col)
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

# Affiche le plateau de `viewed_target` (soi-même par défaut, ou tout autre
# participant/le Fantôme consulté via portraits_row) — façon TFT : un seul
# plateau visible à la fois, interactif seulement quand c'est le sien.
func _refresh_board() -> void:
	for child in front_row.get_children():
		child.queue_free()
	for child in back_row.get_children():
		child.queue_free()
	var is_own_board: bool = viewed_target == human
	front_row.on_drop = _on_shop_card_dropped if is_own_board else Callable()
	back_row.on_drop = _on_shop_card_dropped if is_own_board else Callable()

	var is_ghost: bool = viewed_target is GhostBoard
	var front: Array[Minion] = viewed_target.front if is_ghost else viewed_target.board_front
	var back: Array[Minion] = viewed_target.back if is_ghost else viewed_target.board_back
	for minion in front:
		_add_board_entry(front_row, minion, is_own_board)
	for minion in back:
		_add_board_entry(back_row, minion, is_own_board)

	var target_name: String = viewed_target.origin_player_name if is_ghost else viewed_target.display_name
	if is_ghost:
		target_name = SettingsManager.t("ARENA_GHOST_BOARD_LINE") % target_name
	viewing_label.text = SettingsManager.t("ARENA_VIEWING_BOARD_LABEL") % target_name
	hero_portrait.texture = _art_for_target(viewed_target)

func _add_board_entry(row: Node, minion: Minion, interactive: bool) -> void:
	var col := VBoxContainer.new()
	row.add_child(col)
	var visual: BoardMinion = BOARD_MINION_SCENE.instantiate()
	col.add_child(visual)
	visual.set_minion(minion)
	if interactive:
		var sell_button := Button.new()
		sell_button.text = SettingsManager.t("ARENA_SELL_BUTTON")
		sell_button.pressed.connect(_on_sell_pressed.bind(minion, true))
		col.add_child(sell_button)

# Portrait stable par participant (même art réutilisé qu'ailleurs dans le
# jeu, voir décision "pas de génération d'illustrations" du plan Arena) : le
# joueur humain a toujours HERO_ARTS[0], les autres/le Fantôme cyclent sur le
# reste selon leur position dans match_.players.
func _art_for_target(target) -> Texture2D:
	if target is GhostBoard:
		return HERO_ARTS[1 % HERO_ARTS.size()]
	var idx: int = match_.players.find(target)
	return HERO_ARTS[max(idx, 0) % HERO_ARTS.size()]

# Rangée de portraits cliquables (façon TFT) : cliquer un participant (ou le
# Fantôme s'il est actif) affiche son plateau à la place du tien ci-dessus.
func _refresh_portraits() -> void:
	for child in portraits_row.get_children():
		child.queue_free()
	for p in match_.players:
		portraits_row.add_child(_make_participant_button(p, p.display_name, p.is_eliminated, p == human, p.hero_hp))
	if match_.ghost_board != null:
		var ghost: GhostBoard = match_.ghost_board
		portraits_row.add_child(_make_participant_button(ghost, SettingsManager.t("ARENA_GHOST_BOARD_LINE") % ghost.origin_player_name, false, false, -1))

func _make_participant_button(target, label_name: String, eliminated: bool, is_self: bool, hp: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(90, 120)
	btn.icon = _art_for_target(target)
	btn.expand_icon = true
	btn.disabled = eliminated
	var suffix: String = SettingsManager.t("ARENA_ELIMINATED_STATUS") if eliminated else (str(hp) if hp >= 0 else "")
	var self_tag: String = " (%s)" % SettingsManager.t("ARENA_SELF_TAG") if is_self else ""
	btn.text = "%s%s\n%s" % [label_name, self_tag, suffix]
	btn.toggle_mode = true
	btn.button_pressed = target == viewed_target
	if not eliminated:
		btn.pressed.connect(_on_view_board_pressed.bind(target))
	return btn

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

func _on_view_board_pressed(target) -> void:
	viewed_target = target
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
	viewed_target = human
	match_.advance_round()
	match_.start_shop_phase()
	combat_log_label.text = ""
	_refresh_ui()

func _on_back_to_menu_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
