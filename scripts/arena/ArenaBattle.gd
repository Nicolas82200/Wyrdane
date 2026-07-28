extends Control

# Scène racine du prototype Arena (voir plan Arena « Refonte visuelle »).
# Reprend le look du plateau 1v1 (scenes/battle/Battle.tscn) en réutilisant
# les vrais visuels `Card`/`BoardMinion`, construits ici programmatiquement
# (pas de .tscn détaillé) pour éviter le risque d'édition de scène à la main.
# La boutique occupe la position "rangée adverse" (Avant, la plus proche du
# centre) ; acheter un serviteur se fait en le glissant vers son propre
# plateau (drag & drop autonome, voir ArenaShopCardSlot/ArenaBoardRow — pas
# de réutilisation de Card.gd/DropSystem.gd, pensés pour le mana/ciblage 1v1).
# L'achat rejoint la main ; la pose sur le plateau se fait ensuite en glissant
# la carte de la main vers une rangée, exactement comme en 1v1 : la main
# réutilise directement Hand.tscn/Hand.gd (voir _create_card_drag_preview et
# get_allowed_rows_for_card/can_summon_to_row/player_front_container/
# player_back_container/drop_system ci-dessous, qui donnent à ArenaBattle la
# même API que Battle.gd, seule condition pour que Card.gd fonctionne tel quel
# sans aucune modification). `drop_system` est ArenaDropSystem (pas DropSystem.gd,
# spécifique 1v1) : même contrat, avec en plus une rangée virtuelle "Shop" pour
# vendre une carte de la main en la lâchant sur la boutique.
#
# ArenaConstants.PARTICIPANT_COUNT participants (8 par défaut) : le joueur
# humain (index 0) + le reste en bots (ArenaBotDriver).

const BOARD_MINION_SCENE := preload("res://scenes/minion/BoardMinion.tscn")
const HAND_SCENE := preload("res://scenes/hand/Hand.tscn")
const BACKGROUND_ART := preload("res://assets/background/background-05.jpg")
const ROUNDED_CORNERS_SHADER := preload("res://resources/shaders/rounded_corners.gdshader")
const UI_FONT := preload("res://assets/fonts/MedievalSharp-Bold.ttf")
const HERO_ARTS := [
	preload("res://assets/heros_art/king-aldric-dawnbearer.jpg"),
	preload("res://assets/heros_art/azhar-the-fallen.jpg"),
]
# Gemme réutilisée depuis assets/icons/ (aucune icône dédiée "vendre" n'existe
# encore dans le projet) : représente l'or, pour le solde en en-tête.
const ICON_GEM := preload("res://assets/icons/gem.png")

# Même vocabulaire de lignes que Battle.gd — requis tel quel par DropSystem.gd
# (battle.ROW_FRONT/battle.ROW_BACK) pour pouvoir le réutiliser sans changement.
const ROW_FRONT := "Front"
const ROW_BACK := "Back"

var match_: ArenaMatch
var human: ArenaPlayerState
var bots: Array[ArenaPlayerState] = []
var bot_driver := ArenaBotDriver.new()
var game_over: bool = false
# Interrogé en duck-typing par BoardMinion.gd (._is_dragging_card(), voir
# BoardMinion.gd) pour couper sa création de tooltip de survol pendant
# n'importe quel glisser de carte de la main — sans ce contrat identique à
# Battle.gd (1v1), rien n'empêche BoardMinion de croire qu'un vrai serviteur
# est survolé quand c'est l'aperçu de drag qui suit la souris, et de faire
# apparaître une Card fantôme jamais nettoyée (voir _create_card_drag_preview).
var _is_dragging_card: bool = false

var round_label: Label
var hero_hp_label: Label
var gold_label: Label
var xp_label: Label
var level_label: Label
var shop_front_row: ArenaSellZone
var shop_back_row: ArenaSellZone
var reroll_button: Button
var buy_xp_button: Button
var suspended_label: Label
# Main du joueur — la même Hand.tscn/Hand.gd que le mode 1v1 (voir en-tête de
# fichier), pas une approximation construite à la main.
var hand: Hand
var viewing_label: Label
var front_row: ArenaBoardRow
var back_row: ArenaBoardRow
# Alias exposés avec les noms attendus par DropSystem.gd (battle.player_front_
# container/player_back_container) — ce sont les mêmes objets que front_row/back_row.
var player_front_container: Control
var player_back_container: Control
# Surlignage vert façon 1v1 (Battle.tscn : PlayerFrontHighlight/PlayerBack
# Highlight) pendant le glisser d'une carte de la main — voir ArenaDropSystem.
var player_front_highlight: ColorRect
var player_back_highlight: ColorRect
var drop_system: ArenaDropSystem
var hero_portrait: TextureRect
var hero_hp_overlay: Label
var portraits_column: VBoxContainer
# Joueur (ou GhostBoard) dont le plateau est actuellement affiché — façon TFT,
# cliquer un portrait remplace la vue par le sien, en lecture seule.
var viewed_target = null
var back_to_menu_button: Button
var end_game_overlay: ColorRect
var end_game_screen_panel: PanelContainer
var end_game_title_label: Label
var end_game_label: Label

# ─── Combat animé (voir _resolve_combat_phase) : rejoue le combat du joueur
# humain avec les vraies animations 1v1 (CombatSystem/AnimationSystem/
# BoardVisualSystem, voir SimulatedBattle.enable_live_visuals) — pas de scène
# ni de plateau séparé : les rangées Avant/Arrière (front_row/back_row, déjà
# celles du joueur en phase Boutique) servent aussi de plateau "joueur"
# pendant le combat, et les rangées de la boutique (shop_front_row/
# shop_back_row, vidées de leurs offres) servent de plateau "adverse" —
# cohérent avec le choix de design déjà fait pour la boutique (« occupe la
# position adverse du plateau »). Une banderole "Combat" (bandeau + portrait
# du héros adverse, superposés, jamais dans le vbox) s'affiche 2 secondes
# avant que le combat ne démarre réellement.
var combat_banner_label: Label
var enemy_hero_panel: TextureRect
var enemy_hp_overlay: Label
# Rempli pendant le combat animé (voir SimulatedBattle.enable_live_visuals),
# pour synchroniser l'affichage des PV en direct (SimHeroSystem.update_ui()
# ne fait rien, voir _process) — remis à null une fois le combat terminé.
var _live_sim: SimulatedBattle = null

# ─── Minuteur de phase (Boutique/Combat) : plus de bouton "prêt"/"round
# suivant", la partie s'enchaîne automatiquement à l'expiration du minuteur
# (voir _start_shop_phase_timer/_on_phase_timer_timeout/_resolve_combat_phase/
# _advance_round).
enum Phase { SHOP, COMBAT }
const SHOP_PHASE_DURATION := 10.0
const COMBAT_PHASE_DURATION := 15.0
var current_phase: Phase = Phase.SHOP
var phase_timer: Timer
var phase_label: Label
var phase_time_label: Label

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
	bots = []
	for i in ArenaConstants.PARTICIPANT_COUNT - 1:
		bots.append(ArenaPlayerState.new("Bot %d" % (i + 1), true))
	var players: Array[ArenaPlayerState] = [human]
	players.append_array(bots)
	match_ = ArenaMatch.new(players, pool)
	viewed_target = human
	match_.start_shop_phase()
	_start_shop_phase_timer()

# ─── Construction de l'UI (programmatique, pas de .tscn détaillé) ────────────

func _build_ui() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	# Police unique façon 1v1 (MainMenu.tscn) : hérite à tous les Label/Button
	# enfants sans avoir à la répéter sur chacun.
	add_theme_font_override("font", UI_FONT)

	# Même fond que le plateau 1v1 (scenes/battle/Battle.tscn), pour un rendu
	# cohérent avec le reste du jeu plutôt qu'un arrière-plan vide.
	var background := TextureRect.new()
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.texture = BACKGROUND_ART
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(background)

	# ─ Plateau : mêmes coordonnées que le 1v1 (scenes/battle/Battle.tscn,
	# lignes 345-411) — 4 rangées de 1200x150 centrées sur l'écran (ancrage
	# 0.5/0.5 + décalages fixes), pas empilées dans un flux vertical qui
	# pousserait tout vers le haut. La boutique occupe la position "adverse"
	# (Arrière/Avant les plus proches du centre-haut) — pendant le combat
	# animé, ses rangées (vidées de leurs offres) servent de plateau adverse
	# (voir _resolve_combat_phase) ; le plateau du joueur (Avant/Arrière les
	# plus proches du centre-bas) ne bouge donc jamais, ni entre les phases
	# ni ici : les décalages sont fixes, jamais recalculés depuis un flux.
	var board_root := Control.new()
	board_root.anchor_right = 1.0
	board_root.anchor_bottom = 1.0
	board_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board_root)

	shop_back_row = ArenaSellZone.new()
	shop_back_row.on_sell = _on_board_minion_sold
	shop_back_row.add_theme_constant_override("separation", 8)
	shop_back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_add_lane_indicator(board_root, -330.0, -180.0, 0)
	board_root.add_child(_make_lane_panel(shop_back_row, -330.0, -180.0))

	shop_front_row = ArenaSellZone.new()
	shop_front_row.on_sell = _on_board_minion_sold
	shop_front_row.add_theme_constant_override("separation", 8)
	shop_front_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_add_lane_indicator(board_root, -160.0, -10.0, 1)
	board_root.add_child(_make_lane_panel(shop_front_row, -160.0, -10.0))

	front_row = ArenaBoardRow.new()
	front_row.is_front = true
	front_row.on_drop = _on_shop_card_dropped
	front_row.add_theme_constant_override("separation", 8)
	front_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_add_lane_indicator(board_root, 10.0, 160.0, 0)
	board_root.add_child(_make_lane_panel(front_row, 10.0, 160.0))

	back_row = ArenaBoardRow.new()
	back_row.is_front = false
	back_row.on_drop = _on_shop_card_dropped
	back_row.add_theme_constant_override("separation", 8)
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_add_lane_indicator(board_root, 180.0, 330.0, 1)
	board_root.add_child(_make_lane_panel(back_row, 180.0, 330.0))

	player_front_container = front_row
	player_back_container = back_row
	player_front_highlight = _make_drop_highlight(board_root, 10.0, 160.0)
	player_back_highlight = _make_drop_highlight(board_root, 180.0, 330.0)
	drop_system = ArenaDropSystem.new()
	drop_system.init(self)

	# ─ Héros du joueur : tout en bas de l'écran, centré — mêmes ancrages que
	# PlayerHeroPanel en 1v1 (anchor_top=anchor_bottom=1.0, offset_top négatif).
	hero_portrait = _make_hero_portrait(HERO_ARTS[0])
	hero_hp_overlay = hero_portrait.get_child(0)
	hero_portrait.anchor_left = 0.5
	hero_portrait.anchor_right = 0.5
	hero_portrait.anchor_top = 1.0
	hero_portrait.anchor_bottom = 1.0
	hero_portrait.offset_left = -45.0
	hero_portrait.offset_right = 45.0
	hero_portrait.offset_top = -135.0
	hero_portrait.offset_bottom = -10.0
	add_child(hero_portrait)

	suspended_label = Label.new()
	suspended_label.anchor_left = 0.5
	suspended_label.anchor_right = 0.5
	suspended_label.anchor_top = 1.0
	suspended_label.anchor_bottom = 1.0
	suspended_label.offset_left = 55.0
	suspended_label.offset_right = 155.0
	suspended_label.offset_top = -80.0
	suspended_label.offset_bottom = -50.0
	add_child(suspended_label)

	# ─ Bandeau du haut : en-tête tout en icônes + chiffres (aucun mot) et
	# contrôles boutique, superposés en haut de l'écran (jamais dans le flux
	# du plateau, pour ne jamais influencer sa position).
	var top_bar := VBoxContainer.new()
	top_bar.anchor_right = 1.0
	top_bar.offset_left = 12.0
	top_bar.offset_top = 10.0
	top_bar.offset_right = -12.0
	top_bar.add_theme_constant_override("separation", 4)
	add_child(top_bar)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	# Fond façon ManaDisplay (1v1, scenes/battle/Battle.tscn) : un panneau
	# discret derrière les statistiques plutôt qu'une rangée nue posée
	# directement sur le décor — même famille visuelle que les rangées.
	top_bar.add_child(_make_panel_background(header))
	round_label = _make_stat(header, ArenaIcon.Kind.FORWARD, null)
	hero_hp_label = _make_stat(header, ArenaIcon.Kind.HEART, null)
	gold_label = _make_stat(header, null, ICON_GEM)
	level_label = _make_stat(header, ArenaIcon.Kind.STAR, null)
	xp_label = _make_label(header)
	xp_label.add_theme_font_size_override("font_size", 12)

	var shop_controls := HBoxContainer.new()
	shop_controls.add_theme_constant_override("separation", 8)
	top_bar.add_child(shop_controls)
	reroll_button = Button.new()
	reroll_button.pressed.connect(_on_reroll_pressed)
	_style_button(reroll_button, null, ArenaIcon.Kind.REROLL)
	shop_controls.add_child(reroll_button)
	buy_xp_button = Button.new()
	buy_xp_button.pressed.connect(_on_buy_xp_pressed)
	_style_button(buy_xp_button, null, ArenaIcon.Kind.STAR)
	shop_controls.add_child(buy_xp_button)

	# Nom du plateau consulté (voir portraits_column) : sous les contrôles boutique.
	viewing_label = _make_label(top_bar)

	# ─ Colonne de gauche : portraits cliquables de tous les participants (façon
	# TFT) — cliquer en affiche le plateau à la place du sien, en lecture seule.
	# Ancrée en fraction d'écran (pas un décalage fixe) : à 8 participants les
	# boutons doivent tenir quelle que soit la résolution, contrairement à 4.
	portraits_column = VBoxContainer.new()
	portraits_column.anchor_top = 0.12
	portraits_column.anchor_bottom = 0.88
	portraits_column.offset_left = 12.0
	portraits_column.add_theme_constant_override("separation", 2)
	portraits_column.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(portraits_column)

	_build_game_over_screen()

	# ─ Main du joueur : la même Hand.tscn/Hand.gd que le mode 1v1, ancrée en
	# bas de l'écran (voir Hand.tscn : anchor_top=1.0, grow_vertical=0) —
	# enfant direct de la racine, pas de la colonne de contenu, pour occuper
	# toute la largeur comme en 1v1. Une seule main pour tout (serviteurs ET
	# Incantations, voir _refresh_hand) : glisser une carte vers front_row/
	# back_row la pose (serviteur) ou la lance (Incantation, cible soi/ses
	# alliés) ; la glisser vers la boutique la vend (voir _on_hand_card_played).
	hand = HAND_SCENE.instantiate()
	hand.create_drag_preview = _create_card_drag_preview
	hand.display_cost = func(card_data: CardData) -> Dictionary:
		return {"race": card_data.cost, "generic": 0}
	hand.card_played.connect(_on_hand_card_played)
	hand.drag_started.connect(_on_hand_drag_started)
	hand.drag_ended.connect(_on_hand_drag_ended)
	add_child(hand)

	# ─ Minuteur de phase (Boutique/Combat), au milieu à droite de l'écran — la
	# partie s'enchaîne automatiquement à son expiration, plus de bouton
	# "prêt"/"round suivant" à cliquer (voir _start_shop_phase_timer et suite).
	# Seul endroit du jeu avec du texte écrit (demande explicite du joueur) :
	# le nom de la phase, traduit via SettingsManager.t (voir game.csv).
	var timer_box := VBoxContainer.new()
	timer_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var timer_panel := _make_panel_background(timer_box)
	timer_panel.anchor_left = 1.0
	timer_panel.anchor_right = 1.0
	timer_panel.anchor_top = 0.5
	timer_panel.anchor_bottom = 0.5
	timer_panel.offset_left = -150.0
	timer_panel.offset_right = -20.0
	timer_panel.offset_top = -40.0
	timer_panel.offset_bottom = 40.0
	add_child(timer_panel)

	phase_label = Label.new()
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.add_theme_font_size_override("font_size", 18)
	timer_box.add_child(phase_label)

	phase_time_label = Label.new()
	phase_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_time_label.add_theme_font_size_override("font_size", 30)
	timer_box.add_child(phase_time_label)

	phase_timer = Timer.new()
	phase_timer.one_shot = true
	phase_timer.timeout.connect(_on_phase_timer_timeout)
	add_child(phase_timer)

	_build_combat_banner()

# Bandeau "Combat" + portrait du héros adverse (nécessaire à AnimationSystem
# pour le vol de vie/Ravage, voir CombatSystem.gd) : superposés (jamais dans
# le vbox principal, pour ne jamais déplacer les rangées du joueur), masqués
# hors combat. Le bandeau texte ne reste que 2 secondes (annonce), le
# portrait adverse toute la durée du combat animé (voir _resolve_combat_phase).
# Seul endroit du jeu avec du texte écrit, à la demande explicite du joueur.
func _build_combat_banner() -> void:
	combat_banner_label = Label.new()
	combat_banner_label.anchor_left = 0.5
	combat_banner_label.anchor_right = 0.5
	combat_banner_label.offset_left = -120.0
	combat_banner_label.offset_right = 120.0
	combat_banner_label.offset_top = 16.0
	combat_banner_label.offset_bottom = 66.0
	combat_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combat_banner_label.add_theme_font_size_override("font_size", 40)
	combat_banner_label.add_theme_color_override("font_color", Color(0.92, 0.3, 0.25))
	combat_banner_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	combat_banner_label.add_theme_constant_override("outline_size", 8)
	combat_banner_label.text = SettingsManager.t("ARENA_PHASE_COMBAT")
	combat_banner_label.visible = false
	combat_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(combat_banner_label)

	enemy_hero_panel = _make_hero_portrait(HERO_ARTS[1], 0.6)
	enemy_hp_overlay = enemy_hero_panel.get_child(0)
	enemy_hero_panel.anchor_left = 0.5
	enemy_hero_panel.anchor_right = 0.5
	enemy_hero_panel.offset_left = -27.0
	enemy_hero_panel.offset_right = 27.0
	enemy_hero_panel.offset_top = 74.0
	enemy_hero_panel.visible = false
	enemy_hero_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(enemy_hero_panel)

# Écran de fin de partie façon 1v1 (scenes/battle/GameOverScreen.tscn : voile
# sombre + panneau bordé d'or centré) plutôt qu'un simple Label — même
# palette (fond quasi noir, bordure dorée, titre doré) reproduite ici à la
# main (pas de réutilisation directe de la scène 1v1 : structure différente,
# classement de partie au lieu de victoire/défaite simple + récompense).
func _build_game_over_screen() -> void:
	end_game_overlay = ColorRect.new()
	end_game_overlay.visible = false
	end_game_overlay.anchor_right = 1.0
	end_game_overlay.anchor_bottom = 1.0
	end_game_overlay.color = Color(0, 0, 0, 0.88)
	end_game_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(end_game_overlay)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.05, 0.04, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.55, 0.41, 0.08, 1)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_bottom_left = 8

	var panel := PanelContainer.new()
	panel.visible = false
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -220.0
	panel.offset_top = -170.0
	panel.offset_right = 220.0
	panel.offset_bottom = 170.0
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)
	# Le voile et le panneau apparaissent/disparaissent ensemble : `panel`
	# porte l'état de référence, `end_game_overlay`/les enfants le suivent.
	end_game_screen_panel = panel

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	end_game_title_label = Label.new()
	end_game_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_game_title_label.add_theme_font_size_override("font_size", 32)
	end_game_title_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35, 1))
	box.add_child(end_game_title_label)

	box.add_child(HSeparator.new())

	end_game_label = Label.new()
	end_game_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_game_label.add_theme_font_size_override("font_size", 16)
	end_game_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72, 1))
	box.add_child(end_game_label)

	back_to_menu_button = Button.new()
	back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)
	_style_button(back_to_menu_button, null, ArenaIcon.Kind.HOME)
	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_child(back_to_menu_button)
	box.add_child(button_row)

func _make_label(parent: Node) -> Label:
	var label := Label.new()
	parent.add_child(label)
	return label

# Icône (dessinée ou image réelle) + chiffre, pour l'en-tête sans aucun mot.
func _make_stat(parent: Node, vector_kind, image_icon: Texture2D) -> Label:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)
	if image_icon != null:
		var tex := TextureRect.new()
		tex.texture = image_icon
		tex.custom_minimum_size = Vector2(20, 20)
		tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(tex)
	elif vector_kind != null:
		box.add_child(ArenaIcon.make(vector_kind, 20.0))
	return _make_label(box)

func _make_hero_portrait(art: Texture2D, scale_factor: float = 1.0) -> TextureRect:
	var tex := TextureRect.new()
	var size := Vector2(90, 125) * scale_factor
	tex.texture = art
	tex.custom_minimum_size = size
	tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Coins arrondis façon portraits de héros du plateau 1v1 (Battle.tscn) —
	# même shader, un seul rayon (pas de découpe asymétrique haut/bas ici).
	var material := ShaderMaterial.new()
	material.shader = ROUNDED_CORNERS_SHADER
	material.set_shader_parameter("rect_size", size)
	material.set_shader_parameter("radius_top_left", 16.0)
	material.set_shader_parameter("radius_top_right", 16.0)
	material.set_shader_parameter("radius_bottom_right", 16.0)
	material.set_shader_parameter("radius_bottom_left", 16.0)
	tex.material = material

	# PV inscrits directement sur le portrait, superposés — même pattern que
	# Battle.tscn (HealthLabel plein cadre par-dessus Portrait), pas un chiffre
	# séparé à côté. Le label est le seul enfant du portrait : l'appelant le
	# récupère via `portrait.get_child(0)` plutôt que par une variable membre
	# partagée, pour pouvoir créer plusieurs portraits indépendants (plateau
	# consulté ET vue de combat animé, voir _build_combat_view).
	var overlay := Label.new()
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay.add_theme_font_size_override("font_size", 24)
	overlay.add_theme_color_override("font_color", Color(0.95, 0.9, 0.85))
	overlay.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	overlay.add_theme_constant_override("outline_size", 6)
	tex.add_child(overlay)
	return tex

# Panneau de rangée façon plateau 1v1 (scenes/battle/Battle.tscn, style
# "lane" gris foncé translucide) : juste le fond visuel d'une rangée Avant/
# Arrière (boutique ou plateau) — pas d'emplacement Rituel/Enchantement.
# Icône discrète au centre d'une rangée vide (voir scripts/battle/LaneIndicator.gd,
# réutilisé tel quel — même script que le 1v1) : reprend exactement les
# offsets de Battle.tscn (120x120, centrée sur la même ligne verticale que le
# panneau). Ajoutée AVANT le panneau (voir appels ci-dessus) pour rester
# derrière les serviteurs une fois la rangée occupée.
func _add_lane_indicator(parent: Control, offset_top: float, offset_bottom: float, filled_row: int) -> void:
	var mid: float = (offset_top + offset_bottom) / 2.0
	var indicator := LaneIndicator.new()
	indicator.filled_row = filled_row
	indicator.anchor_left = 0.5
	indicator.anchor_right = 0.5
	indicator.anchor_top = 0.5
	indicator.anchor_bottom = 0.5
	indicator.offset_left = -60.0
	indicator.offset_right = 60.0
	indicator.offset_top = mid - 60.0
	indicator.offset_bottom = mid + 60.0
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(indicator)

# Surlignage vert de dépôt (voir Battle.tscn : PlayerFrontHighlight/PlayerBack
# Highlight, même couleur), affiché pendant le glisser d'une carte de la main
# au-dessus d'une rangée où elle peut être posée — voir ArenaDropSystem.
# update_player_drop_highlight. Masqué par défaut.
func _make_drop_highlight(parent: Control, offset_top: float, offset_bottom: float) -> ColorRect:
	var highlight := ColorRect.new()
	highlight.visible = false
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight.color = Color(0, 1, 0, 0.2)
	highlight.anchor_left = 0.5
	highlight.anchor_right = 0.5
	highlight.anchor_top = 0.5
	highlight.anchor_bottom = 0.5
	highlight.offset_left = -600.0
	highlight.offset_right = 600.0
	highlight.offset_top = offset_top
	highlight.offset_bottom = offset_bottom
	parent.add_child(highlight)
	return highlight

# Positionnée exactement comme une ligne du plateau 1v1 (Battle.tscn, lignes
# 345-411) : ancrée au centre de l'écran (anchor 0.5/0.5), décalages fixes en
# pixels par rapport à ce centre — jamais dans un flux qui la ferait bouger
# selon ce qu'il y a au-dessus. `offset_top`/`offset_bottom` reproduisent
# ceux d'EnemyBackLine/EnemyFrontLine/PlayerFrontLine/PlayerBackLine.
# Style commun aux panneaux discrets Arena (rangées, en-tête) : fond gris
# foncé translucide, bordure claire fine, coins arrondis.
func _lane_style() -> StyleBoxFlat:
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
	return style

func _make_lane_panel(row: Control, offset_top: float, offset_bottom: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _lane_style())
	panel.custom_minimum_size = Vector2(1200, offset_bottom - offset_top)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -600.0
	panel.offset_right = 600.0
	panel.offset_top = offset_top
	panel.offset_bottom = offset_bottom
	panel.add_child(row)
	return panel

# Fond discret façon ManaDisplay (1v1) pour un contenu flottant (en-tête de
# statistiques) — même style que les rangées, sans coordonnées de plateau.
func _make_panel_background(content: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _lane_style())
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.add_child(content)
	return panel

# Style commun à tous les boutons Arena : fond sombre translucide, bordure
# dorée, coins arrondis (même famille visuelle que les panneaux de rangée),
# icône réelle si disponible (voir ICON_* en tête de fichier) sinon un seul
# glyphe symbolique agrandi — jamais de mot (voir consigne "pas de texte").
func _style_button(btn: Button, icon: Texture2D = null, vector_kind = null) -> void:
	btn.custom_minimum_size = Vector2(52, 52)
	btn.text = ""
	if icon != null:
		btn.icon = icon
		btn.expand_icon = true
	elif vector_kind != null:
		# Icône dessinée à la volée (ArenaIcon) plutôt qu'un glyphe Unicode :
		# le rendu d'un glyphe dépend de la police active et n'est pas
		# garanti, un dessin vectoriel simple l'est toujours.
		var vec_icon := ArenaIcon.make(vector_kind, 26.0)
		vec_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vec_icon.anchor_left = 0.5
		vec_icon.anchor_top = 0.5
		vec_icon.anchor_right = 0.5
		vec_icon.anchor_bottom = 0.5
		vec_icon.offset_left = -13.0
		vec_icon.offset_top = -13.0
		vec_icon.offset_right = 13.0
		vec_icon.offset_bottom = 13.0
		btn.add_child(vec_icon)
	btn.add_theme_color_override("font_color", Color(0.92, 0.85, 0.65))
	btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.09, 0.06, 0.75)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(0.65, 0.52, 0.28, 0.85)
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_right = 8
	normal.corner_radius_bottom_left = 8

	var hover := normal.duplicate()
	hover.bg_color = Color(0.22, 0.17, 0.1, 0.85)
	hover.border_color = Color(0.85, 0.7, 0.35, 0.95)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.06, 0.05, 0.03, 0.9)

	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.08, 0.08, 0.08, 0.4)
	disabled.border_color = Color(0.4, 0.4, 0.4, 0.4)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)

# ─── API attendue par Card.gd/DropSystem.gd (voir Battle.gd, mêmes signatures) ─
# Ces méthodes/propriétés (ROW_FRONT/ROW_BACK, player_front_container/
# player_back_container, drop_system, get_allowed_rows_for_card,
# can_summon_to_row) sont ce qui permet de réutiliser Card.gd/DropSystem.gd
# tels quels pour la main : ils ne connaissent Battle.gd que par duck-typing
# (get_tree().current_scene), jamais par référence directe à sa classe.

func _create_card_drag_preview(card_data: CardData) -> Control:
	var preview: BoardMinion = BOARD_MINION_SCENE.instantiate() as BoardMinion
	preview.z_index = 200
	add_child(preview)
	# Après add_child(), pas avant : BoardMinion._ready() (déclenché par
	# add_child) réécrit inconditionnellement mouse_filter = STOP, ce qui
	# écraserait une valeur posée plus tôt. Sans ce IGNORE, l'aperçu de
	# glisser-déposer se comporte comme un vrai serviteur posé aux yeux de
	# BoardMinion._process() (sondage de survol) : la souris étant en
	# permanence dessus pendant le drag, ça déclenche _on_mouse_entered() qui
	# fait apparaître une Card agrandie juste à sa droite — jamais nettoyée
	# ensuite puisque l'aperçu est détruit via queue_free() sans jamais
	# déclencher _on_mouse_exited() (pas de _exit_tree() dans BoardMinion.gd
	# pour rattraper ce cas) : une "copie" de carte fantôme qui reste à
	# l'écran à chaque carte glissée depuis la main.
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.set_minion(Minion.new(card_data, true, ROW_FRONT))
	if card_data.card_type != "Minion":
		preview.attack_label.visible = false
		preview.health_label.visible = false
	preview.scale = Vector2.ONE
	preview.modulate = Color(1, 1, 1, 0.85)
	return preview

func get_allowed_rows_for_card(card_data: CardData) -> Array[String]:
	if card_data == null or card_data.card_type != "Minion":
		return [ROW_FRONT, ROW_BACK]
	match card_data.board_position:
		ROW_FRONT: return [ROW_FRONT]
		ROW_BACK: return [ROW_BACK]
		_: return [ROW_FRONT, ROW_BACK]

func can_summon_to_row(_is_player: bool, row: String) -> bool:
	return human.can_place_on_row(row == ROW_FRONT)

func is_dragging_card() -> bool:
	return _is_dragging_card

func _on_hand_drag_started() -> void:
	_is_dragging_card = true
	hand.set_compact(true)

func _on_hand_drag_ended() -> void:
	_is_dragging_card = false
	hand.set_compact(false)

# Résout la carte lâchée (serviteur ou Incantation, la main ne fait plus de
# distinction visuelle entre les deux) puis l'action correspondant à la zone
# visée : boutique = vente, plateau = pose (serviteur) ou lancer (Incantation,
# cible toujours soi/ses alliés — voir ArenaMatch.cast_spell).
func _on_hand_card_played(card_data: CardData, row: String, insert_index: int) -> void:
	if row == ArenaDropSystem.ROW_SHOP:
		for minion in human.hand:
			if minion.card_data == card_data:
				match_.sell_card(human, minion, false)
				_refresh_ui()
				return
		if human.spell_hand.has(card_data):
			match_.sell_spell(human, card_data)
			_refresh_ui()
		return
	for minion in human.hand:
		if minion.card_data == card_data:
			_on_place_pressed(minion, row == ROW_FRONT, insert_index)
			return
	if human.spell_hand.has(card_data):
		await match_.cast_spell(human, card_data)
		_refresh_ui()

func _process(_delta: float) -> void:
	if phase_timer == null:
		return
	phase_time_label.text = str(ceili(phase_timer.time_left)) if phase_timer.time_left > 0.0 else "0"
	# SimHeroSystem.update_ui() (voir SimulatedBattle) ne fait rien : les PV
	# affichés pendant le combat animé sont synchronisés ici, à chaque frame,
	# tant qu'un combat est en cours (_live_sim non nul, voir _resolve_combat_phase).
	if _live_sim != null:
		hero_hp_overlay.text = str(max(_live_sim.player_hero.health, 0))
		enemy_hp_overlay.text = str(max(_live_sim.enemy_hero.health, 0))

# ─── Rafraîchissement ────────────────────────────────────────────────────────

func _refresh_ui() -> void:
	# En-tête tout en chiffres (voir _make_stat) : pas de mot, l'icône donne
	# le sens (rangée/cœur/gemme/étoile).
	round_label.text = str(match_.round_number)
	hero_hp_label.text = str(human.hero_hp)
	gold_label.text = str(human.gold)
	level_label.text = str(human.level)
	var next_level_xp: int = ArenaConstants.xp_required_for_next_level(human.level)
	xp_label.text = "" if next_level_xp < 0 else "%d/%d" % [human.xp, next_level_xp]

	# Si la cible consultée est éliminée (ou invalide), on revient sur son
	# propre plateau plutôt que d'afficher un plateau figé/vidé.
	if viewed_target == null or (viewed_target is ArenaPlayerState and viewed_target.is_eliminated):
		viewed_target = human

	# La boutique n'est utilisable qu'en phase Boutique (voir minuteur) : pas de
	# reroll/XP/achat pendant l'affichage du résultat de combat. Les panneaux
	# restent visibles (juste vidés, voir _refresh_shop) plutôt que masqués :
	# les cacher retirerait leur hauteur de la mise en page verticale et ferait
	# remonter tout ce qui suit (plateau, héros...), qui doit rester à la même
	# place tout au long de la partie.
	var in_shop_phase: bool = not game_over and current_phase == Phase.SHOP
	reroll_button.disabled = not in_shop_phase or human.gold < ArenaConstants.REROLL_COST
	buy_xp_button.disabled = not in_shop_phase or not ArenaEconomy.can_buy_xp(match_.round_number) or human.gold < ArenaConstants.GOLD_TO_XP_RATE or human.level >= 8

	suspended_label.text = str(human.suspended.size()) if not human.suspended.is_empty() else ""

	_refresh_shop(in_shop_phase)
	_refresh_hand()
	_refresh_board()
	_refresh_portraits()

# La boutique occupe la position "adverse" du plateau : chaque offre est une
# vraie `Card` (voir ArenaShopCardSlot), rangée dans shop_front_row ou
# shop_back_row selon son propre board_position ("Back" -> Arrière, sinon
# Avant), achetable en la glissant vers son propre plateau (front_row/back_row,
# voir ArenaBoardRow). Un emplacement déjà acheté (carte nulle) n'affiche
# simplement rien jusqu'au prochain reroll. Pas de verrouillage (retiré).
# Hors phase Boutique, les rangées restent vides (pas d'offre affichée) mais
# gardent leur hauteur (voir _refresh_ui) pour ne pas déplacer le plateau.
func _refresh_shop(in_shop_phase: bool = true) -> void:
	for child in shop_front_row.get_children():
		child.queue_free()
	for child in shop_back_row.get_children():
		child.queue_free()
	if not in_shop_phase:
		return
	for i in human.shop_offer.size():
		var card: CardData = human.shop_offer[i]
		if card == null:
			continue
		var target_row: HBoxContainer = shop_back_row if card.board_position == "Back" else shop_front_row
		var slot := ArenaShopCardSlot.new()
		# `target_row` est déjà dans l'arbre de scène avant setup() (qui
		# instancie et configure une vraie Card en enfant) : les @onready
		# de Card ne sont peuplés qu'une fois le nœud réellement entré dans
		# l'arbre (voir Hand.gd : add_child() puis set_data(), jamais l'inverse).
		target_row.add_child(slot)
		slot.setup(card, i)

func _on_shop_card_dropped(shop_index: int, _is_front: bool) -> void:
	# L'achat par glisser-déposer rejoint la main (comme un achat au clic) ;
	# la pose sur le plateau reste une action séparée et volontaire du joueur
	# (boutons Avant/Arrière dans la main), pas automatique au moment du drop.
	match_.buy_card(human, shop_index)
	_refresh_ui()

# Rebâtit intégralement la main via Hand.gd (même comportement que le 1v1 :
# éventail, survol qui soulève la carte, repli en bas de l'écran, drag&drop
# natif vers front_row/back_row) — une seule main pour les serviteurs ET les
# Incantations achetées (arena_only, voir CARDS.md « Cartes exclusives
# Arena »), pas deux zones séparées. La pose (serviteur), le lancer
# (Incantation, cible toujours soi/ses alliés) et la vente se font tous en
# glissant la carte (voir get_allowed_rows_for_card, can_summon_to_row,
# _on_hand_card_played) — pas de bouton dédié.
#
# `hand.set_hand()` est asynchrone (deux `await get_tree().process_frame` en
# interne, voir Hand.gd) : appelée sans attendre (comme ici, `_refresh_ui()`
# n'étant elle-même jamais awaited par la plupart des handlers d'action), deux
# actions rapprochées (achat puis pose en un clin d'œil) peuvent chevaucher
# deux appels en vol simultanément — la seconde `set_hand()` vide/reconstruit
# `container` alors que la première n'a pas fini d'y ajouter ses cartes,
# doublant/déplaçant des cartes de façon incohérente (symptôme observé : des
# cartes en double, mal positionnées). `_hand_refresh_running`/`_hand_refresh_
# dirty` sérialise les reconstructions : un appel qui arrive pendant qu'une
# reconstruction tourne déjà se contente de marquer "à refaire" et attend le
# signal de fin plutôt que de laisser deux coroutines toucher `container` en
# même temps.
signal _hand_refreshed
var _hand_refresh_running: bool = false
var _hand_refresh_dirty: bool = false

func _refresh_hand() -> void:
	if _hand_refresh_running:
		_hand_refresh_dirty = true
		await _hand_refreshed
		return
	_hand_refresh_running = true
	while true:
		_hand_refresh_dirty = false
		var cards: Array[CardData] = []
		for minion in human.hand:
			cards.append(minion.card_data)
		for card_data in human.spell_hand:
			cards.append(card_data)
		await hand.set_hand(cards)
		# Étoile de fusion (voir ArenaStarOverlay) : Hand.gd ne connaît que des
		# CardData, jamais le Minion/star_level qui l'accompagne — les cartes
		# apparaissent dans `hand.container` dans le même ordre que `cards`
		# ci-dessus, donc les `human.hand.size()` premiers nœuds correspondent
		# aux serviteurs (jamais les Incantations, qui n'ont pas de star_level).
		var card_nodes := hand.container.get_children()
		for i in human.hand.size():
			if i >= card_nodes.size():
				break
			var minion: Minion = human.hand[i]
			if minion.star_level > 1:
				ArenaStarOverlay.add_to(card_nodes[i], minion.star_level)
		if not _hand_refresh_dirty:
			break
	_hand_refresh_running = false
	_hand_refreshed.emit()

# Affiche le plateau de `viewed_target` (soi-même par défaut, ou tout autre
# participant/le Fantôme consulté via la colonne de portraits) — façon TFT :
# un seul plateau visible à la fois, interactif seulement quand c'est le sien.
func _refresh_board() -> void:
	for child in front_row.get_children():
		child.queue_free()
	for child in back_row.get_children():
		child.queue_free()
	var is_own_board: bool = viewed_target == human
	front_row.on_drop = _on_shop_card_dropped if is_own_board else Callable()
	back_row.on_drop = _on_shop_card_dropped if is_own_board else Callable()
	front_row.on_reposition = _on_board_minion_dropped if is_own_board else Callable()
	back_row.on_reposition = _on_board_minion_dropped if is_own_board else Callable()

	var is_ghost: bool = viewed_target is GhostBoard
	var front: Array[Minion] = viewed_target.front if is_ghost else viewed_target.board_front
	var back: Array[Minion] = viewed_target.back if is_ghost else viewed_target.board_back
	for minion in front:
		_add_board_entry(front_row, minion, is_own_board)
	for minion in back:
		_add_board_entry(back_row, minion, is_own_board)

	# Nom seul (pas de phrase) : juste assez pour lever l'ambiguïté sur le
	# plateau affiché, sans texte de remplissage.
	viewing_label.text = viewed_target.origin_player_name if is_ghost else viewed_target.display_name
	hero_portrait.texture = _art_for_target(viewed_target)
	# PV inscrits sur le portrait (voir _make_hero_portrait) — pas de valeur
	# pour le Fantôme, qui n'a pas de héros (juste un plateau figé).
	hero_hp_overlay.text = "" if is_ghost else str(viewed_target.hero_hp)

# Interactif (son propre plateau) : le serviteur est glissable, pour se
# repositionner sur sa ligne, changer de ligne, ou être vendu en le lâchant
# sur la boutique (voir ArenaBoardMinionSlot/ArenaBoardRow/ArenaSellZone) —
# plus de bouton dédié. Lecture seule (plateau d'un autre joueur consulté) :
# juste le visuel, sans wrapper glissable.
func _add_board_entry(row: Node, minion: Minion, interactive: bool) -> void:
	if interactive:
		var slot := ArenaBoardMinionSlot.new()
		row.add_child(slot)
		slot.setup(minion)
	else:
		var visual: BoardMinion = BOARD_MINION_SCENE.instantiate()
		row.add_child(visual)
		visual.set_minion(minion)

# Portrait stable par participant (même art réutilisé qu'ailleurs dans le
# jeu, voir décision "pas de génération d'illustrations" du plan Arena) : le
# joueur humain a toujours HERO_ARTS[0], les autres/le Fantôme cyclent sur le
# reste selon leur position dans match_.players.
func _art_for_target(target) -> Texture2D:
	if target is GhostBoard:
		return HERO_ARTS[1 % HERO_ARTS.size()]
	var idx: int = match_.players.find(target)
	return HERO_ARTS[max(idx, 0) % HERO_ARTS.size()]

# Colonne de portraits cliquables (façon TFT), à gauche de l'écran : cliquer
# un participant affiche son plateau à la place du tien ci-dessus. Le Fantôme
# (plateau figé du dernier éliminé, comble l'appariement à effectif impair —
# voir GhostBoard/README) n'est volontairement pas montré ici : c'est un
# détail d'appariement interne, pas un participant à consulter.
func _refresh_portraits() -> void:
	for child in portraits_column.get_children():
		child.queue_free()
	for p in match_.players:
		portraits_column.add_child(_make_participant_button(p, p.display_name, p.is_eliminated, p == human, p.hero_hp))

func _make_participant_button(target, _label_name: String, eliminated: bool, is_self: bool, hp: int) -> Button:
	var btn := Button.new()
	# Assez petit pour que les 8 participants tiennent dans la colonne de
	# gauche sans dépasser (voir portraits_column, ancrée en fraction d'écran).
	btn.custom_minimum_size = Vector2(52, 64)
	btn.icon = _art_for_target(target)
	btn.expand_icon = true
	btn.disabled = eliminated
	# PV en chiffre seul (pas de nom : le portrait suffit à identifier), "✕"
	# pour un participant éliminé. Le tien ressort par une teinte dorée plutôt
	# qu'une étiquette texte "(toi)".
	btn.text = "✕" if eliminated else (str(hp) if hp >= 0 else "")
	btn.toggle_mode = true
	btn.button_pressed = target == viewed_target
	btn.modulate = Color(1.15, 1.05, 0.75) if is_self else Color(1, 1, 1)
	if not eliminated:
		btn.pressed.connect(_on_view_board_pressed.bind(target))
	return btn

# ─── Actions joueur ──────────────────────────────────────────────────────────

func _on_reroll_pressed() -> void:
	match_.reroll(human)
	_refresh_ui()

func _on_buy_xp_pressed() -> void:
	match_.buy_xp(human)
	_refresh_ui()

func _on_place_pressed(minion: Minion, is_front: bool, index: int = -1) -> void:
	human.place_on_board(minion, is_front, index)
	_refresh_ui()

# Repositionnement (même ligne ou changement de ligne) d'un serviteur déjà
# posé — voir ArenaBoardMinionSlot/ArenaBoardRow.on_reposition.
func _on_board_minion_dropped(minion: Minion, is_front: bool, index: int) -> void:
	human.move_on_board(minion, is_front, index)
	_refresh_ui()

# Vente en glissant un serviteur du plateau sur la boutique — voir ArenaSellZone.
func _on_board_minion_sold(minion: Minion) -> void:
	match_.sell_card(human, minion, true)
	_refresh_ui()

func _on_view_board_pressed(target) -> void:
	viewed_target = target
	_refresh_ui()

# ─── Phase Combat ────────────────────────────────────────────────────────────
# Plus de bouton "prêt"/"round suivant" : le minuteur enchaîne automatiquement
# Boutique -> Combat -> Boutique du round suivant, jusqu'à la fin de partie.

func _start_shop_phase_timer() -> void:
	current_phase = Phase.SHOP
	phase_label.text = SettingsManager.t("ARENA_SHOP_TITLE")
	phase_timer.start(SHOP_PHASE_DURATION)
	_refresh_ui()

func _start_combat_phase_timer() -> void:
	current_phase = Phase.COMBAT
	phase_label.text = SettingsManager.t("ARENA_PHASE_COMBAT")
	phase_timer.start(COMBAT_PHASE_DURATION)
	_refresh_ui()

func _on_phase_timer_timeout() -> void:
	if game_over:
		return
	if current_phase == Phase.SHOP:
		await _resolve_combat_phase()
	else:
		_advance_round()

func _resolve_combat_phase() -> void:
	for bot in bots:
		if not bot.is_alive():
			continue
		bot_driver.play_shop_phase(bot, match_)
		bot_driver.play_positioning_phase(bot)
		# Après la pose, pas avant : les Incantations "tout le plateau" doivent
		# viser la composition finale du bot, pas un plateau encore incomplet.
		await bot_driver.cast_spells_phase(bot, match_)
	match_.end_shop_phase()

	# Seul l'appariement du joueur humain (jamais les combats bots-contre-bots,
	# jamais regardés) est rejoué avec les vraies animations 1v1 — voir
	# ArenaMatch._resolve_pairing/SimulatedBattle.enable_live_visuals. Pas de
	# plateau séparé : la boutique (vidée de ses offres, voir _refresh_shop)
	# sert de plateau adverse, exactement comme prévu par le design d'origine
	# ("la boutique occupe la position adverse du plateau").
	var live_setup := func(sim: SimulatedBattle) -> void:
		_live_sim = sim
		# Le plateau du joueur affichait ses propres serviteurs (ArenaBoardMinionSlot,
		# glissables) pendant la boutique : on les retire avant que le combat n'y
		# pose ses propres visuels (BoardMinion nus, non glissables), sans quoi
		# les deux se superposeraient.
		for row in [front_row, back_row, shop_front_row, shop_back_row]:
			for child in row.get_children().duplicate():
				row.remove_child(child)
				child.queue_free()
		# Pas d'interaction possible pendant le combat animé (rien à acheter/
		# poser/vendre) : coupe le drop, restauré par le prochain _refresh_board().
		front_row.on_drop = Callable()
		front_row.on_reposition = Callable()
		back_row.on_drop = Callable()
		back_row.on_reposition = Callable()
		sim.enable_live_visuals(
			self, front_row, back_row, shop_front_row, shop_back_row,
			hero_portrait, enemy_hero_panel)
		enemy_hero_panel.visible = true
		combat_banner_label.visible = true
		await get_tree().create_timer(2.0).timeout
		combat_banner_label.visible = false
	await match_.start_combat_phase(live_setup)
	enemy_hero_panel.visible = false
	_live_sim = null

	if match_.is_match_over() or human.is_eliminated:
		_show_game_over()
	else:
		_start_combat_phase_timer()

func _show_game_over() -> void:
	game_over = true
	phase_timer.stop()
	end_game_overlay.visible = true
	end_game_screen_panel.visible = true
	end_game_title_label.text = SettingsManager.t("ARENA_DEFEAT_TITLE") if human.is_eliminated else SettingsManager.t("ARENA_VICTORY_TITLE")
	var lines: Array[String] = [SettingsManager.t("ARENA_RANKING_TITLE") + " :"]
	var ranking: Array[ArenaPlayerState] = match_.final_ranking()
	for i in ranking.size():
		lines.append("  %d. %s" % [i + 1, ranking[i].display_name])
	end_game_label.text = "\n".join(lines)
	_refresh_ui()

func _advance_round() -> void:
	viewed_target = human
	match_.advance_round()
	match_.start_shop_phase()
	_start_shop_phase_timer()

func _on_back_to_menu_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
