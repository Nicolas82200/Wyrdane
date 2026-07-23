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
# même API que Battle.gd, seule condition pour que Card.gd/DropSystem.gd
# fonctionnent tels quels sans aucune modification).
#
# 4 participants : le joueur humain (index 0) + 3 bots (ArenaBotDriver).

const CARD_SCENE := preload("res://scenes/card/Card.tscn")
const BOARD_MINION_SCENE := preload("res://scenes/minion/BoardMinion.tscn")
const HAND_SCENE := preload("res://scenes/hand/Hand.tscn")
const BACKGROUND_ART := preload("res://assets/background/background-05.jpg")
const ROUNDED_CORNERS_SHADER := preload("res://resources/shaders/rounded_corners.gdshader")
const UI_FONT := preload("res://assets/fonts/MedievalSharp-Bold.ttf")
const HERO_ARTS := [
	preload("res://assets/heros_art/king-aldric-dawnbearer.jpg"),
	preload("res://assets/heros_art/azhar-the-fallen.jpg"),
]
# Icônes réutilisées depuis assets/icons/ existants (aucune icône dédiée
# "vendre"/"prêt" n'existe encore dans le projet) : le Gemme représente l'or
# (vendre = récupérer de l'or), Instant le type Incantation.
const ICON_GEM := preload("res://assets/icons/gem.png")
const ICON_INSTANT := preload("res://assets/icons/instant.png")

# Même vocabulaire de lignes que Battle.gd — requis tel quel par DropSystem.gd
# (battle.ROW_FRONT/battle.ROW_BACK) pour pouvoir le réutiliser sans changement.
const ROW_FRONT := "Front"
const ROW_BACK := "Back"

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
# Main du joueur — la même Hand.tscn/Hand.gd que le mode 1v1 (voir en-tête de
# fichier), pas une approximation construite à la main.
var hand: Hand
var spell_hand_container: HBoxContainer
var viewing_label: Label
var front_row: ArenaBoardRow
var back_row: ArenaBoardRow
# Alias exposés avec les noms attendus par DropSystem.gd (battle.player_front_
# container/player_back_container) — ce sont les mêmes objets que front_row/back_row.
var player_front_container: Control
var player_back_container: Control
var drop_system: DropSystem
var hero_portrait: TextureRect
var hero_hp_overlay: Label
var portraits_column: VBoxContainer
# Joueur (ou GhostBoard) dont le plateau est actuellement affiché — façon TFT,
# cliquer un portrait remplace la vue par le sien, en lecture seule.
var viewed_target = null
var ready_button: Button
var next_round_button: Button
var back_to_menu_button: Button
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

	# Nœud "Board" requis par DropSystem.gd (battle.get_node_or_null("Board")) :
	# reçoit les surlignages de dépôt en survol, sans quoi _ensure_drop_highlights
	# échouerait (voir scripts/systems/DropSystem.gd ligne 65-69).
	var board_overlay := Control.new()
	board_overlay.name = "Board"
	board_overlay.anchor_right = 1.0
	board_overlay.anchor_bottom = 1.0
	board_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board_overlay)

	# Pas de défilement : tout tient dans un écran unique (rangées et marges
	# resserrées plutôt qu'un ScrollContainer).
	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	# Rangée principale : les portraits des autres participants à gauche (façon
	# TFT), le reste du plateau à droite — plus de rangée horizontale de
	# portraits au milieu du flux vertical.
	var root_hbox := HBoxContainer.new()
	root_hbox.add_theme_constant_override("separation", 10)
	root_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root_hbox)

	# ─ Colonne de gauche : portraits cliquables des autres participants (façon
	# TFT) — cliquer en affiche le plateau à la place du sien, en lecture seule.
	portraits_column = VBoxContainer.new()
	portraits_column.add_theme_constant_override("separation", 8)
	portraits_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portraits_column.alignment = BoxContainer.ALIGNMENT_CENTER
	root_hbox.add_child(portraits_column)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_hbox.add_child(vbox)

	# En-tête tout en icônes + chiffres (aucun mot) : rangée, cœur, gemme, étoile.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	vbox.add_child(header)
	round_label = _make_stat(header, ArenaIcon.Kind.FORWARD, null)
	hero_hp_label = _make_stat(header, ArenaIcon.Kind.HEART, null)
	gold_label = _make_stat(header, null, ICON_GEM)
	level_label = _make_stat(header, ArenaIcon.Kind.STAR, null)
	xp_label = _make_label(header)
	xp_label.add_theme_font_size_override("font_size", 12)

	# ─ Boutique : occupe la position "adverse" du plateau — chaque carte
	# proposée est rangée dans la rangée Avant/Arrière qui correspond à son
	# propre board_position (README : lignes adverses), comme si l'offre du
	# tour était le plateau d'en face. Arrière (plus loin du centre) d'abord,
	# Avant (plus proche du centre) ensuite, pour respecter l'empilement
	# vertical du plateau 1v1 (Battle.tscn). Même hauteur de rangée que le 1v1
	# (Battle.tscn : custom_minimum_size = Vector2(1200, 150)).
	shop_back_row = HBoxContainer.new()
	shop_back_row.add_theme_constant_override("separation", 8)
	shop_back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_make_lane_panel(shop_back_row, 150))
	shop_front_row = HBoxContainer.new()
	shop_front_row.add_theme_constant_override("separation", 8)
	shop_front_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_make_lane_panel(shop_front_row, 150))

	var shop_controls := HBoxContainer.new()
	shop_controls.add_theme_constant_override("separation", 8)
	shop_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(shop_controls)
	reroll_button = Button.new()
	reroll_button.pressed.connect(_on_reroll_pressed)
	_style_button(reroll_button, null, ArenaIcon.Kind.REROLL)
	shop_controls.add_child(reroll_button)
	buy_xp_button = Button.new()
	buy_xp_button.pressed.connect(_on_buy_xp_pressed)
	_style_button(buy_xp_button, null, ArenaIcon.Kind.STAR)
	shop_controls.add_child(buy_xp_button)

	# ─ Plateau consulté : Avant proche du centre, Arrière plus loin. Par
	# défaut le sien, mais cliquer un portrait (colonne de gauche) l'échange
	# contre celui d'un autre participant (lecture seule). Pas d'emplacement
	# Rituel/Enchantement pour l'instant (hors scope Arena v1).
	viewing_label = _make_label(vbox)
	front_row = ArenaBoardRow.new()
	front_row.is_front = true
	front_row.on_drop = _on_shop_card_dropped
	front_row.add_theme_constant_override("separation", 8)
	front_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_make_lane_panel(front_row, 150))

	back_row = ArenaBoardRow.new()
	back_row.is_front = false
	back_row.on_drop = _on_shop_card_dropped
	back_row.add_theme_constant_override("separation", 8)
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_make_lane_panel(back_row, 150))

	player_front_container = front_row
	player_back_container = back_row
	drop_system = DropSystem.new()
	drop_system.init(self)

	var mid_row := HBoxContainer.new()
	mid_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mid_row.add_theme_constant_override("separation", 16)
	vbox.add_child(mid_row)
	hero_portrait = _make_hero_portrait(HERO_ARTS[0])
	mid_row.add_child(hero_portrait)
	suspended_label = _make_label(mid_row)

	# ─ Incantations achetées, non lancées (voir _refresh_spells) ─
	spell_hand_container = HBoxContainer.new()
	spell_hand_container.add_theme_constant_override("separation", 6)
	vbox.add_child(spell_hand_container)

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 12)
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(bottom_row)

	ready_button = Button.new()
	ready_button.pressed.connect(_on_ready_pressed)
	_style_button(ready_button, null, ArenaIcon.Kind.PLAY)
	bottom_row.add_child(ready_button)

	next_round_button = Button.new()
	next_round_button.visible = false
	next_round_button.pressed.connect(_on_next_round_pressed)
	_style_button(next_round_button, null, ArenaIcon.Kind.FORWARD)
	bottom_row.add_child(next_round_button)

	back_to_menu_button = Button.new()
	back_to_menu_button.visible = false
	back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)
	_style_button(back_to_menu_button, null, ArenaIcon.Kind.HOME)
	bottom_row.add_child(back_to_menu_button)

	end_game_label = Label.new()
	end_game_label.visible = false
	end_game_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(end_game_label)

	# ─ Main du joueur : la même Hand.tscn/Hand.gd que le mode 1v1, ancrée en
	# bas de l'écran (voir Hand.tscn : anchor_top=1.0, grow_vertical=0) —
	# enfant direct de la racine, pas de la colonne de contenu, pour occuper
	# toute la largeur comme en 1v1. Glisser une carte vers front_row/back_row
	# la pose (voir get_allowed_rows_for_card/can_summon_to_row/drop_system).
	hand = HAND_SCENE.instantiate()
	hand.create_drag_preview = _create_card_drag_preview
	hand.display_cost = func(card_data: CardData) -> Dictionary:
		return {"race": card_data.cost, "generic": 0}
	hand.card_played.connect(_on_hand_card_played)
	add_child(hand)

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
	# séparé à côté.
	hero_hp_overlay = Label.new()
	hero_hp_overlay.anchor_right = 1.0
	hero_hp_overlay.anchor_bottom = 1.0
	hero_hp_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_hp_overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hero_hp_overlay.add_theme_font_size_override("font_size", 24)
	hero_hp_overlay.add_theme_color_override("font_color", Color(0.95, 0.9, 0.85))
	hero_hp_overlay.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	hero_hp_overlay.add_theme_constant_override("outline_size", 6)
	tex.add_child(hero_hp_overlay)
	return tex

# Panneau de rangée façon plateau 1v1 (scenes/battle/Battle.tscn, style
# "lane" gris foncé translucide) : juste le fond visuel d'une rangée Avant/
# Arrière (boutique ou plateau) — pas d'emplacement Rituel/Enchantement.
func _make_lane_panel(row: Control, min_height: float = 160) -> PanelContainer:
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
	panel.custom_minimum_size = Vector2(0, min_height)
	panel.add_child(row)
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
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.z_index = 200
	add_child(preview)
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

func _on_hand_card_played(card_data: CardData, row: String, _insert_index: int) -> void:
	for minion in human.hand:
		if minion.card_data == card_data:
			_on_place_pressed(minion, row == ROW_FRONT)
			return

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

	reroll_button.disabled = human.gold < ArenaConstants.REROLL_COST
	buy_xp_button.disabled = not ArenaEconomy.can_buy_xp(match_.round_number) or human.gold < ArenaConstants.GOLD_TO_XP_RATE or human.level >= 8

	suspended_label.text = str(human.suspended.size()) if not human.suspended.is_empty() else ""

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
# Avant), achetable en la glissant vers son propre plateau (front_row/back_row,
# voir ArenaBoardRow). Un emplacement déjà acheté (carte nulle) n'affiche
# simplement rien jusqu'au prochain reroll. Pas de verrouillage (retiré).
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
# natif vers front_row/back_row) — pas d'action séparée bouton Avant/Arrière,
# la pose se fait en glissant la carte (voir get_allowed_rows_for_card,
# can_summon_to_row, _on_hand_card_played).
func _refresh_hand() -> void:
	var cards: Array[CardData] = []
	for minion in human.hand:
		cards.append(minion.card_data)
	hand.set_hand(cards)

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
		var actions := HBoxContainer.new()
		actions.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(actions)
		var cast_button := Button.new()
		actions.add_child(cast_button)
		_style_button(cast_button, ICON_INSTANT)
		cast_button.pressed.connect(_on_cast_pressed.bind(card_data))
		var sell_button := Button.new()
		actions.add_child(sell_button)
		_style_button(sell_button, ICON_GEM)
		sell_button.pressed.connect(_on_sell_spell_pressed.bind(card_data))

func _add_spell_card_visual(col: Node, card_data: CardData) -> void:
	var card: Card = CARD_SCENE.instantiate()
	col.add_child(card)
	card.scale = Vector2(0.6, 0.6)
	card.set_data(card_data)
	card.set_non_interactive()
	card.cost_label.text = str(card_data.cost)
	card.generic_cost_label.visible = false

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

func _add_board_entry(row: Node, minion: Minion, interactive: bool) -> void:
	var col := VBoxContainer.new()
	row.add_child(col)
	var visual: BoardMinion = BOARD_MINION_SCENE.instantiate()
	col.add_child(visual)
	visual.set_minion(minion)
	if interactive:
		var sell_button := Button.new()
		col.add_child(sell_button)
		_style_button(sell_button, ICON_GEM)
		sell_button.pressed.connect(_on_sell_pressed.bind(minion, true))

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
# un participant (ou le Fantôme s'il est actif) affiche son plateau à la
# place du tien ci-dessus.
func _refresh_portraits() -> void:
	for child in portraits_column.get_children():
		child.queue_free()
	for p in match_.players:
		portraits_column.add_child(_make_participant_button(p, p.display_name, p.is_eliminated, p == human, p.hero_hp))
	if match_.ghost_board != null:
		var ghost: GhostBoard = match_.ghost_board
		portraits_column.add_child(_make_participant_button(ghost, ghost.origin_player_name, false, false, -1))

func _make_participant_button(target, _label_name: String, eliminated: bool, is_self: bool, hp: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(72, 96)
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
	_refresh_ui()

func _on_back_to_menu_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
