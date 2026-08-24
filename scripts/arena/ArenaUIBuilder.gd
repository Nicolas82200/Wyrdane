extends RefCounted
class_name ArenaUIBuilder

# Construction programmatique de l'UI d'ArenaBattle (aucun .tscn détaillé,
# voir en-tête d'ArenaBattle.gd). Extrait de ArenaBattle._build_ui (qui
# concentrait à elle seule ~300 lignes) : purement de la fabrique de nœuds,
# aucune logique de jeu. `build(arena)` peuple les champs UI de `arena`
# (hero_portrait, hand, boutons...) exactement comme le faisait l'ancienne
# méthode membre — appelé une seule fois par ArenaBattle._ready().

static func build(arena) -> void:
	arena.anchor_right = 1.0
	arena.anchor_bottom = 1.0
	# Police unique façon 1v1 (MainMenu.tscn) : hérite à tous les Label/Button
	# enfants sans avoir à la répéter sur chacun.
	arena.add_theme_font_override("font", arena.UI_FONT)

	# Même fond que le plateau 1v1 (scenes/battle/Battle.tscn), pour un rendu
	# cohérent avec le reste du jeu plutôt qu'un arrière-plan vide.
	var background := TextureRect.new()
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.texture = arena.BACKGROUND_ART
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	arena.add_child(background)

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
	arena.add_child(board_root)

	arena.shop_back_row = ArenaSellZone.new()
	arena.shop_back_row.on_sell = arena._on_board_minion_sold
	arena.shop_back_row.add_theme_constant_override("separation", 8)
	arena.shop_back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_add_lane_indicator(board_root, -330.0, -180.0, 0)
	board_root.add_child(_make_lane_background(-330.0, -180.0))
	board_root.add_child(_place_row(arena.shop_back_row, -330.0, -180.0))

	arena.shop_front_row = ArenaSellZone.new()
	arena.shop_front_row.on_sell = arena._on_board_minion_sold
	arena.shop_front_row.add_theme_constant_override("separation", 8)
	arena.shop_front_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_add_lane_indicator(board_root, -160.0, -10.0, 1)
	board_root.add_child(_make_lane_background(-160.0, -10.0))
	board_root.add_child(_place_row(arena.shop_front_row, -160.0, -10.0))

	arena.front_row = ArenaBoardRow.new()
	arena.front_row.is_front = true
	arena.front_row.on_drop = arena._on_shop_card_dropped
	arena.front_row.add_theme_constant_override("separation", 8)
	arena.front_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_add_lane_indicator(board_root, 10.0, 160.0, 0)
	board_root.add_child(_make_lane_background(10.0, 160.0))
	board_root.add_child(_place_row(arena.front_row, 10.0, 160.0))

	arena.back_row = ArenaBoardRow.new()
	arena.back_row.is_front = false
	arena.back_row.on_drop = arena._on_shop_card_dropped
	arena.back_row.add_theme_constant_override("separation", 8)
	arena.back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_add_lane_indicator(board_root, 180.0, 330.0, 1)
	board_root.add_child(_make_lane_background(180.0, 330.0))
	board_root.add_child(_place_row(arena.back_row, 180.0, 330.0))

	arena.player_front_container = arena.front_row
	arena.player_back_container = arena.back_row
	arena.player_front_highlight = _make_drop_highlight(board_root, 10.0, 160.0)
	arena.player_back_highlight = _make_drop_highlight(board_root, 180.0, 330.0)
	arena.drop_system = ArenaDropSystem.new()
	arena.drop_system.init(arena)

	# ─ Héros du joueur : tout en bas de l'écran, centré — mêmes ancrages que
	# PlayerHeroPanel en 1v1 (Battle.tscn : 135x187, anchor_top=anchor_bottom=1.0,
	# offset_left/right ±67.5, offset_top -187, collé au bord bas de l'écran) —
	# reproduit ici à l'identique (voir HERO_PORTRAIT_SIZE), au lieu de la
	# taille réduite (90x125) utilisée jusqu'ici.
	arena.hero_portrait = _make_hero_portrait(arena, arena.HERO_ARTS[0])
	arena.hero_hp_overlay = arena.hero_portrait.get_child(0)
	arena.hero_portrait.anchor_left = 0.5
	arena.hero_portrait.anchor_right = 0.5
	arena.hero_portrait.anchor_top = 1.0
	arena.hero_portrait.anchor_bottom = 1.0
	arena.hero_portrait.offset_left = -arena.HERO_PORTRAIT_SIZE.x / 2.0
	arena.hero_portrait.offset_right = arena.HERO_PORTRAIT_SIZE.x / 2.0
	arena.hero_portrait.offset_top = -arena.HERO_PORTRAIT_SIZE.y
	arena.hero_portrait.offset_bottom = 0.0
	arena.add_child(arena.hero_portrait)

	# ─ Or disponible : à l'emplacement exact du pool de mana en 1v1
	# (`ManaDisplay`, Battle.tscn : anchor 1/1/1/1, 170x60, coin bas-droit) —
	# demande explicite du joueur, pas dans l'en-tête avec le reste des
	# statistiques (seule ressource activement dépensée en phase Boutique).
	var gold_box := HBoxContainer.new()
	gold_box.add_theme_constant_override("separation", 4)
	gold_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var gold_panel := _make_panel_background(gold_box)
	arena.gold_label = _make_stat(gold_box, null, arena.ICON_GEM, SettingsManager.t("ARENA_TOOLTIP_GOLD"))
	gold_panel.size_flags_horizontal = Control.SIZE_FILL
	gold_panel.anchor_left = 1.0
	gold_panel.anchor_right = 1.0
	gold_panel.anchor_top = 1.0
	gold_panel.anchor_bottom = 1.0
	gold_panel.offset_left = -230.0
	gold_panel.offset_right = -60.0
	gold_panel.offset_top = -172.0
	gold_panel.offset_bottom = -112.0
	arena.add_child(gold_panel)

	arena.suspended_label = Label.new()
	arena.suspended_label.anchor_left = 0.5
	arena.suspended_label.anchor_right = 0.5
	arena.suspended_label.anchor_top = 1.0
	arena.suspended_label.anchor_bottom = 1.0
	arena.suspended_label.offset_left = arena.HERO_PORTRAIT_SIZE.x / 2.0 + 10.0
	arena.suspended_label.offset_right = arena.HERO_PORTRAIT_SIZE.x / 2.0 + 110.0
	arena.suspended_label.offset_top = -arena.HERO_PORTRAIT_SIZE.y / 2.0 - 20.0
	arena.suspended_label.offset_bottom = -arena.HERO_PORTRAIT_SIZE.y / 2.0 + 10.0
	arena.add_child(arena.suspended_label)

	# ─ Bandeau du haut : en-tête tout en icônes + chiffres (aucun mot),
	# superposé en haut de l'écran (jamais dans le flux du plateau, pour ne
	# jamais influencer sa position). Décalé à droite du bouton Paramètres
	# (voir plus bas, toujours coin haut-gauche) pour ne pas le chevaucher.
	var top_bar := VBoxContainer.new()
	top_bar.anchor_right = 1.0
	top_bar.offset_left = 72.0
	top_bar.offset_top = 10.0
	top_bar.offset_right = -12.0
	top_bar.add_theme_constant_override("separation", 4)
	arena.add_child(top_bar)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	# Fond façon ManaDisplay (1v1, scenes/battle/Battle.tscn) : un panneau
	# discret derrière les statistiques plutôt qu'une rangée nue posée
	# directement sur le décor — même famille visuelle que les rangées. L'or
	# n'y figure plus (voir plus haut : affiché à côté du portrait du héros).
	top_bar.add_child(_make_panel_background(header))
	arena.round_label = _make_stat(header, ArenaIcon.Kind.FORWARD, null, SettingsManager.t("ARENA_TOOLTIP_ROUND"))
	arena.hero_hp_label = _make_stat(header, ArenaIcon.Kind.HEART, null, SettingsManager.t("ARENA_TOOLTIP_HERO_HP"))
	arena.level_label = _make_stat(header, ArenaIcon.Kind.STAR, null, SettingsManager.t("ARENA_TOOLTIP_LEVEL"))
	arena.xp_label = _make_label(header)
	arena.xp_label.add_theme_font_size_override("font_size", 12)
	arena.xp_label.tooltip_text = SettingsManager.t("ARENA_TOOLTIP_XP")

	# Nom du plateau consulté (voir portraits_column) : sous l'en-tête.
	arena.viewing_label = _make_label(top_bar)

	# ─ Colonne de gauche : portraits cliquables de tous les participants (façon
	# TFT) — cliquer en affiche le plateau à la place du sien, en lecture seule.
	# Ancrée en fraction d'écran (pas un décalage fixe) : à 8 participants les
	# boutons doivent tenir quelle que soit la résolution, contrairement à 4.
	arena.portraits_column = VBoxContainer.new()
	arena.portraits_column.anchor_top = 0.12
	arena.portraits_column.anchor_bottom = 0.88
	arena.portraits_column.offset_left = 12.0
	arena.portraits_column.add_theme_constant_override("separation", 2)
	arena.portraits_column.alignment = BoxContainer.ALIGNMENT_CENTER
	arena.add_child(arena.portraits_column)

	# ─ Paramètres/quitter : coin haut-gauche, toujours au même endroit (demande
	# explicite du joueur) — même SettingsMenu.tscn que le 1v1, avec
	# show_quit = true (bouton Concéder à la place de Fermer, seule façon de
	# quitter une partie en cours). L'en-tête round/PV/niveau/XP (top_bar) est
	# décalé à sa droite (offset_left = 72) pour ne pas le chevaucher.
	arena.settings_button = Button.new()
	arena.settings_button.offset_left = 12.0
	arena.settings_button.offset_right = 64.0
	arena.settings_button.offset_top = 10.0
	arena.settings_button.offset_bottom = 62.0
	arena.settings_button.pressed.connect(func(): arena.settings_menu.open())
	_style_button(arena.settings_button, null, ArenaIcon.Kind.GEAR)
	arena.settings_button.tooltip_text = SettingsManager.t("ARENA_TOOLTIP_SETTINGS")
	arena.add_child(arena.settings_button)

	arena.settings_menu = arena.SETTINGS_MENU_SCENE.instantiate()
	arena.settings_menu.show_quit = true
	arena.settings_menu.concede_requested.connect(arena._on_settings_quit)
	arena.add_child(arena.settings_menu)

	_build_game_over_screen(arena)

	# ─ Main du joueur : la même Hand.tscn/Hand.gd que le mode 1v1, ancrée en
	# bas de l'écran (voir Hand.tscn : anchor_top=1.0, grow_vertical=0) —
	# enfant direct de la racine, pas de la colonne de contenu, pour occuper
	# toute la largeur comme en 1v1. Une seule main pour tout (serviteurs ET
	# Incantations, voir _refresh_hand) : glisser une carte vers front_row/
	# back_row la pose (serviteur) ou la lance (Incantation, cible soi/ses
	# alliés) ; la glisser vers la boutique la vend (voir _on_hand_card_played).
	arena.hand = arena.HAND_SCENE.instantiate()
	arena.hand.create_drag_preview = arena._create_card_drag_preview
	arena.hand.display_cost = func(card_data: CardData) -> Dictionary:
		return {"race": card_data.cost, "generic": 0}
	arena.hand.card_played.connect(arena._on_hand_card_played)
	arena.hand.drag_started.connect(arena._on_hand_drag_started)
	arena.hand.drag_ended.connect(arena._on_hand_drag_ended)
	arena.add_child(arena.hand)

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
	arena.add_child(timer_panel)

	arena.phase_label = Label.new()
	arena.phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arena.phase_label.add_theme_font_size_override("font_size", 18)
	timer_box.add_child(arena.phase_label)

	arena.phase_time_label = Label.new()
	arena.phase_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arena.phase_time_label.add_theme_font_size_override("font_size", 30)
	timer_box.add_child(arena.phase_time_label)

	arena.phase_timer = Timer.new()
	arena.phase_timer.one_shot = true
	arena.phase_timer.timeout.connect(arena._on_phase_timer_timeout)
	arena.add_child(arena.phase_timer)

	# ─ Actualiser/Geler : juste au-dessus du panneau minuteur (même colonne
	# x, coin droit) — demande explicite du joueur, plutôt que regroupés avec
	# Acheter XP/Prêt dans un seul bloc sous l'en-tête. Chaque bouton porte un
	# tooltip (fonction + prix), seul élément d'info sur un bouton par
	# ailleurs sans texte.
	var reroll_row := HBoxContainer.new()
	reroll_row.add_theme_constant_override("separation", 8)
	var reroll_panel := _make_panel_background(reroll_row)
	reroll_panel.anchor_left = 1.0
	reroll_panel.anchor_right = 1.0
	reroll_panel.anchor_top = 0.5
	reroll_panel.anchor_bottom = 0.5
	reroll_panel.offset_left = -150.0
	reroll_panel.offset_right = -20.0
	reroll_panel.offset_bottom = -48.0
	reroll_panel.offset_top = -116.0
	arena.add_child(reroll_panel)
	arena.reroll_button = Button.new()
	arena.reroll_button.pressed.connect(arena._on_reroll_pressed)
	_style_button(arena.reroll_button, null, ArenaIcon.Kind.REROLL)
	arena.reroll_button.tooltip_text = SettingsManager.t("ARENA_TOOLTIP_REROLL") % ArenaConstants.REROLL_COST
	reroll_row.add_child(arena.reroll_button)
	# Gel de la boutique (façon TFT, README « État actuel du prototype ») :
	# préserve l'offre ENTIÈRE (pas une carte à la fois, voir ArenaShopCardSlot
	# — le verrouillage par carte a été retiré) pour la manche suivante.
	# toggle_mode : reste visuellement enfoncé tant que le gel est actif.
	arena.freeze_button = Button.new()
	arena.freeze_button.toggle_mode = true
	arena.freeze_button.pressed.connect(arena._on_freeze_pressed)
	_style_button(arena.freeze_button, null, ArenaIcon.Kind.SNOWFLAKE)
	arena.freeze_button.tooltip_text = SettingsManager.t("ARENA_TOOLTIP_FREEZE")
	reroll_row.add_child(arena.freeze_button)

	# ─ Acheter XP : juste en dessous du panneau minuteur, même colonne x.
	arena.buy_xp_button = Button.new()
	arena.buy_xp_button.anchor_left = 1.0
	arena.buy_xp_button.anchor_right = 1.0
	arena.buy_xp_button.anchor_top = 0.5
	arena.buy_xp_button.anchor_bottom = 0.5
	arena.buy_xp_button.offset_left = -111.0
	arena.buy_xp_button.offset_right = -59.0
	arena.buy_xp_button.offset_top = 48.0
	arena.buy_xp_button.offset_bottom = 100.0
	arena.buy_xp_button.pressed.connect(arena._on_buy_xp_pressed)
	_style_button(arena.buy_xp_button, null, ArenaIcon.Kind.STAR)
	arena.buy_xp_button.tooltip_text = SettingsManager.t("ARENA_TOOLTIP_BUY_XP") % ArenaConstants.GOLD_TO_XP_RATE
	arena.add_child(arena.buy_xp_button)

	# ─ Prêt : juste en dessous du pool d'or (voir gold_panel plus haut, coin
	# bas-droit) — termine la phase Boutique immédiatement plutôt que
	# d'attendre la fin du décompte (les bots ne "attendent" jamais réellement
	# — ils jouent leur propre manche juste après, voir _resolve_combat_phase
	# — donc rien n'empêche de lancer le combat dès que le joueur humain, seul
	# participant réellement freiné par le minuteur, se déclare prêt).
	arena.ready_button = Button.new()
	arena.ready_button.anchor_left = 1.0
	arena.ready_button.anchor_right = 1.0
	arena.ready_button.anchor_top = 1.0
	arena.ready_button.anchor_bottom = 1.0
	arena.ready_button.offset_left = -171.0
	arena.ready_button.offset_right = -119.0
	arena.ready_button.offset_top = -104.0
	arena.ready_button.offset_bottom = -52.0
	arena.ready_button.pressed.connect(arena._on_ready_pressed)
	_style_button(arena.ready_button, null, ArenaIcon.Kind.PLAY)
	arena.ready_button.tooltip_text = SettingsManager.t("ARENA_TOOLTIP_READY")
	arena.add_child(arena.ready_button)

	_build_combat_banner(arena)

# Bandeau "Combat" + portrait du héros adverse (nécessaire à AnimationSystem
# pour le vol de vie/Ravage, voir CombatSystem.gd) : superposés (jamais dans
# le vbox principal, pour ne jamais déplacer les rangées du joueur), masqués
# hors combat. Le bandeau texte ne reste que 2 secondes (annonce), le
# portrait adverse toute la durée du combat animé (voir _resolve_combat_phase).
# Seul endroit du jeu avec du texte écrit, à la demande explicite du joueur.
static func _build_combat_banner(arena) -> void:
	arena.combat_banner_label = Label.new()
	arena.combat_banner_label.anchor_left = 0.5
	arena.combat_banner_label.anchor_right = 0.5
	arena.combat_banner_label.offset_left = -120.0
	arena.combat_banner_label.offset_right = 120.0
	arena.combat_banner_label.offset_top = 16.0
	arena.combat_banner_label.offset_bottom = 66.0
	arena.combat_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arena.combat_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arena.combat_banner_label.add_theme_font_size_override("font_size", 40)
	arena.combat_banner_label.add_theme_color_override("font_color", Color(0.92, 0.3, 0.25))
	arena.combat_banner_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	arena.combat_banner_label.add_theme_constant_override("outline_size", 8)
	arena.combat_banner_label.text = SettingsManager.t("ARENA_PHASE_COMBAT")
	arena.combat_banner_label.visible = false
	arena.combat_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena.add_child(arena.combat_banner_label)

	arena.enemy_hero_panel = _make_hero_portrait(arena, arena.HERO_ARTS[1], 0.6)
	arena.enemy_hp_overlay = arena.enemy_hero_panel.get_child(0)
	arena.enemy_hero_panel.anchor_left = 0.5
	arena.enemy_hero_panel.anchor_right = 0.5
	arena.enemy_hero_panel.offset_left = -arena.HERO_PORTRAIT_SIZE.x * 0.6 / 2.0
	arena.enemy_hero_panel.offset_right = arena.HERO_PORTRAIT_SIZE.x * 0.6 / 2.0
	arena.enemy_hero_panel.offset_top = 74.0
	arena.enemy_hero_panel.visible = false
	arena.enemy_hero_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena.add_child(arena.enemy_hero_panel)

# Écran de fin de partie façon 1v1 (scenes/battle/GameOverScreen.tscn : voile
# sombre + panneau bordé d'or centré) plutôt qu'un simple Label — même
# palette (fond quasi noir, bordure dorée, titre doré) reproduite ici à la
# main (pas de réutilisation directe de la scène 1v1 : structure différente,
# classement de partie au lieu de victoire/défaite simple + récompense).
static func _build_game_over_screen(arena) -> void:
	arena.end_game_overlay = ColorRect.new()
	arena.end_game_overlay.visible = false
	arena.end_game_overlay.anchor_right = 1.0
	arena.end_game_overlay.anchor_bottom = 1.0
	arena.end_game_overlay.color = Color(0, 0, 0, 0.88)
	arena.end_game_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	arena.add_child(arena.end_game_overlay)

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
	arena.add_child(panel)
	# Le voile et le panneau apparaissent/disparaissent ensemble : `panel`
	# porte l'état de référence, `end_game_overlay`/les enfants le suivent.
	arena.end_game_screen_panel = panel

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	arena.end_game_title_label = Label.new()
	arena.end_game_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arena.end_game_title_label.add_theme_font_size_override("font_size", 32)
	arena.end_game_title_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35, 1))
	box.add_child(arena.end_game_title_label)

	box.add_child(HSeparator.new())

	arena.end_game_label = Label.new()
	arena.end_game_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arena.end_game_label.add_theme_font_size_override("font_size", 16)
	arena.end_game_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72, 1))
	box.add_child(arena.end_game_label)

	arena.back_to_menu_button = Button.new()
	arena.back_to_menu_button.pressed.connect(arena._on_back_to_menu_pressed)
	_style_button(arena.back_to_menu_button, null, ArenaIcon.Kind.HOME)
	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_child(arena.back_to_menu_button)
	box.add_child(button_row)

# ─── Fabriques de nœuds (pures, sans dépendance à ArenaBattle) ───────────────

static func _make_label(parent: Node) -> Label:
	var label := Label.new()
	parent.add_child(label)
	return label

# Icône (dessinée ou image réelle) + chiffre, pour l'en-tête sans aucun mot.
# `tooltip` (optionnel) : posé sur le HBox entier (icône + chiffre), pas
# seulement le chiffre, pour que survoler l'icône l'affiche aussi — seule
# façon de comprendre un en-tête tout en pictogrammes sans texte (demande
# explicite du joueur, « UI claire, on comprend tout ce qu'on voit »).
static func _make_stat(parent: Node, vector_kind, image_icon: Texture2D, tooltip: String = "") -> Label:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.tooltip_text = tooltip
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

static func _make_hero_portrait(arena, art: Texture2D, scale_factor: float = 1.0) -> TextureRect:
	var tex := TextureRect.new()
	var size: Vector2 = arena.HERO_PORTRAIT_SIZE * scale_factor
	tex.texture = art
	tex.custom_minimum_size = size
	tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Coins arrondis façon portraits de héros du plateau 1v1 (Battle.tscn) —
	# même shader, un seul rayon (pas de découpe asymétrique haut/bas ici).
	var material := ShaderMaterial.new()
	material.shader = arena.ROUNDED_CORNERS_SHADER
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
	# consulté ET vue de combat animé, voir _build_combat_banner).
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
static func _add_lane_indicator(parent: Control, offset_top: float, offset_bottom: float, filled_row: int) -> void:
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
static func _make_drop_highlight(parent: Control, offset_top: float, offset_bottom: float) -> ColorRect:
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

# Le fond (`_make_lane_background`, un `Panel` nu) et la rangée de serviteurs
# (`_place_row`) sont deux nœuds SÉPARÉS superposés aux mêmes coordonnées —
# jamais la rangée nichée dans un `PanelContainer` (marges de contenu) : un
# `BoardMinion` fait pile la hauteur d'une rangée (150), et l'imbrication dans
# un conteneur à marges le comprimait artificiellement.
# Style commun aux panneaux discrets Arena (rangées, en-tête) : fond gris
# foncé translucide, bordure claire fine, coins arrondis.
static func _lane_style() -> StyleBoxFlat:
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

# Fond seul (un `Panel` nu, jamais un `PanelContainer` : pas de contenu à lui
# imposer de marges) — voir note ci-dessus.
static func _make_lane_background(offset_top: float, offset_bottom: float) -> Panel:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _lane_style())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -600.0
	panel.offset_right = 600.0
	panel.offset_top = offset_top
	panel.offset_bottom = offset_bottom
	return panel

# Positionne la rangée elle-même directement aux coordonnées de la ligne
# (aucun conteneur intermédiaire) — retournée pour être ajoutée par l'appelant.
static func _place_row(row: Control, offset_top: float, offset_bottom: float) -> Control:
	row.custom_minimum_size = Vector2(1200, offset_bottom - offset_top)
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.anchor_top = 0.5
	row.anchor_bottom = 0.5
	row.offset_left = -600.0
	row.offset_right = 600.0
	row.offset_top = offset_top
	row.offset_bottom = offset_bottom
	return row

# Fond discret façon ManaDisplay (1v1) pour un contenu flottant (en-tête de
# statistiques) — même style que les rangées, sans coordonnées de plateau.
static func _make_panel_background(content: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _lane_style())
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.add_child(content)
	return panel

# Style commun à tous les boutons Arena : fond sombre translucide, bordure
# dorée, coins arrondis (même famille visuelle que les panneaux de rangée),
# icône réelle si disponible (voir ICON_* en tête d'ArenaBattle.gd) sinon un
# seul glyphe symbolique agrandi — jamais de mot (voir consigne "pas de texte").
static func _style_button(btn: Button, icon: Texture2D = null, vector_kind = null) -> void:
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
