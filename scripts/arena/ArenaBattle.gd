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
const SETTINGS_MENU_SCENE := preload("res://scenes/settings/SettingsMenu.tscn")
const BACKGROUND_ART := preload("res://assets/background/background-05.jpg")
const ROUNDED_CORNERS_SHADER := preload("res://resources/shaders/rounded_corners.gdshader")
const UI_FONT := preload("res://assets/fonts/MedievalSharp-Bold.ttf")
const HERO_ARTS := [
	preload("res://assets/heros_art/king-aldric-dawnbearer.jpg"),
	preload("res://assets/heros_art/azhar-the-fallen.jpg"),
]
# Gemme réutilisée depuis assets/icons/ (aucune icône dédiée "vendre" n'existe
# encore dans le projet) : représente l'or, affiché à côté du portrait du héros.
const ICON_GEM := preload("res://assets/icons/gem.png")

# Même taille que PlayerHeroPanel/EnemyHeroPanel en 1v1 (Battle.tscn) — voir
# _make_hero_portrait.
const HERO_PORTRAIT_SIZE := Vector2(135, 187)

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
# Offre affichée au dernier _refresh_shop() (mêmes références CardData, voir
# _animate_slide_in) : sert uniquement à savoir quelles cases sont vraiment
# nouvelles pour l'animation d'arrivée, jamais lu ailleurs.
var _last_shop_offer_snapshot: Array = []
var reroll_button: Button
var buy_xp_button: Button
var freeze_button: Button
var ready_button: Button
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
# Même SettingsMenu.tscn que le 1v1 (Battle.tscn), avec show_quit = true :
# le bouton Fermer y est remplacé par Concéder (retour au menu principal, la
# seule façon de quitter une partie Arena en cours — pas de reprise).
var settings_button: Button
var settings_menu: Control
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

# Minuteur de phase (Boutique/Combat) : la manche s'enchaîne à l'expiration,
# ou plus tôt via ready_button. SHOP_PHASE_DURATION ne contraint que le joueur
# humain (25s, réduit des 45s du design pensé pour 8 joueurs humains). Le
# minuteur de combat, lui, ne bloque plus rien : il tourne en parallèle de
# l'animation à titre indicatif, et le combat réellement terminé enchaîne
# aussitôt sur la manche suivante sans attendre son expiration.
enum Phase { SHOP, COMBAT }
const SHOP_PHASE_DURATION := 25.0
const COMBAT_PHASE_DURATION := 15.0

# ─── Transition animée Boutique -> Combat (demande explicite du joueur) :
# glissement horizontal, voir _animate_slide_out_and_free/_animate_slide_in.
const EXIT_SLIDE_DURATION := 0.35
const ENTRY_SLIDE_DURATION := 0.45
# Budget total de la transition (sortie + tenue de la bannière "Combat" +
# arrivée), inchangé par rapport à l'ancien délai fixe qu'elle remplace.
const COMBAT_TRANSITION_TOTAL_DURATION := 2.0
# Décalage horizontal (px) appliqué en position locale (à l'intérieur même
# des HBoxContainer de rangée, voir _animate_slide_in) pour simuler une
# arrivée/sortie hors-écran.
const SLIDE_OFFSET := 500.0
var current_phase: Phase = Phase.SHOP
var phase_timer: Timer
var phase_label: Label
var phase_time_label: Label

const MAIN_MENU_SCENE := "res://scenes/mainMenu/MainMenu.tscn"

func _ready() -> void:
	ArenaUIBuilder.build(self)
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
	Card.add_drag_shadow(preview)
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
	if not _is_shop_interaction_allowed():
		return
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
	freeze_button.disabled = not in_shop_phase
	freeze_button.button_pressed = human.shop_frozen
	ready_button.disabled = not in_shop_phase

	suspended_label.text = str(human.suspended.size()) if not human.suspended.is_empty() else ""

	_refresh_shop(in_shop_phase)
	_refresh_hand()
	_refresh_board()
	_refresh_portraits()

# ─── Animations de glissement horizontal (transition Boutique -> Combat,
# arrivée de nouvelles cartes en boutique) ─────────────────────────────────
#
# `groups` : { direction(float): Array[Control] } — direction = +1.0 (côté
# droit) ou -1.0 (côté gauche). Les nœuds visés sont des ENFANTS d'un
# HBoxContainer (rangée de plateau/boutique) : leur `position` y est
# normalement entièrement gérée par le conteneur (retriée à chaque ajout/
# retrait d'enfant ou redimensionnement) — mais UNIQUEMENT à ces moments-là,
# jamais en continu. Décaler manuellement `position.x` juste après que le
# conteneur ait posé sa position naturelle, puis le tweener, fonctionne donc
# de façon fiable tant qu'aucun autre tri n'est déclenché pendant l'animation
# (aucun ajout/retrait/redimensionnement des rangées visées ici pendant ce
# court laps de temps).

# Glisse hors-écran (vers `direction`) puis libère chaque nœud des groupes
# fournis — utilisé pour vider le plateau/la boutique juste avant le combat
# (voir _resolve_combat_phase).
func _animate_slide_out_and_free(groups: Dictionary, duration: float) -> void:
	var tween: Tween = null
	for direction in groups:
		for node in groups[direction]:
			if not is_instance_valid(node):
				continue
			if tween == null:
				tween = create_tween()
				tween.set_parallel(true)
			tween.tween_property(node, "position:x", node.position.x + direction * SLIDE_OFFSET, duration)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tween.tween_property(node, "modulate:a", 0.0, duration)
	if tween == null:
		return
	await tween.finished
	for direction in groups:
		for node in groups[direction]:
			if not is_instance_valid(node):
				continue
			var parent: Node = node.get_parent()
			if parent != null:
				parent.remove_child(node)
			node.queue_free()

# Glisse depuis `direction` (position de départ décalée) jusqu'à la position
# naturelle déjà posée par le conteneur — utilisé pour l'arrivée des
# serviteurs en combat (voir _resolve_combat_phase) et des nouvelles cartes
# en boutique (voir _refresh_shop).
func _animate_slide_in(groups: Dictionary, duration: float) -> void:
	var any: bool = false
	for direction in groups:
		for node in groups[direction]:
			if is_instance_valid(node):
				any = true
	if not any:
		return
	# Laisse le conteneur poser la position naturelle de ses enfants (tri
	# déclenché par leur ajout, potentiellement différé) avant de la lire.
	await get_tree().process_frame
	var tween := create_tween()
	tween.set_parallel(true)
	for direction in groups:
		for node in groups[direction]:
			if not is_instance_valid(node):
				continue
			var target_x: float = node.position.x
			node.position.x = target_x + direction * SLIDE_OFFSET
			node.modulate.a = 0.0
			tween.tween_property(node, "position:x", target_x, duration)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(node, "modulate:a", 1.0, duration * 0.7)
	await tween.finished

# La boutique occupe la position "adverse" du plateau : chaque offre est un
# vrai `BoardMinion` (même visuel qu'un serviteur posé, sans texte — voir
# ArenaShopCardSlot ; survoler affiche le détail complet, comme en 1v1), rangée
# dans shop_front_row ou shop_back_row selon son propre board_position ("Back"
# -> Arrière, sinon Avant), achetable en la glissant vers son propre plateau
# (front_row/back_row, voir ArenaBoardRow). Un emplacement déjà acheté (carte
# nulle) n'affiche simplement rien jusqu'au prochain reroll. Pas de
# verrouillage par carte (voir bouton flocon, geler TOUTE l'offre à la fois).
# Hors phase Boutique, les rangées restent vides (pas d'offre affichée) mais
# gardent leur hauteur (voir _refresh_ui) pour ne pas déplacer le plateau.
# Les cartes nouvellement arrivées (offre différente de la précédente, voir
# _last_shop_offer_snapshot) glissent depuis la gauche (demande explicite du
# joueur) — celles déjà affichées avant ce rafraîchissement ne sont pas
# ré-animées à chaque petite action (achat d'une autre case, repositionnement...).
func _refresh_shop(in_shop_phase: bool = true) -> void:
	# remove_child() avant queue_free() (plutôt que queue_free() seul) : la
	# libération réelle est différée en fin de frame, donc les anciennes cases
	# restaient dans shop_front_row/shop_back_row (et donc dans la mise en page
	# de l'HBoxContainer) pendant que les nouvelles étaient déjà ajoutées juste
	# en dessous — le temps d'une frame, deux BoardMinion pouvaient se
	# chevaucher sous le curseur et déclencher chacun leur propre aperçu de
	# survol (BoardMinion._process sonde la position de la souris à chaque
	# frame, sans notion d'exclusivité entre serviteurs). remove_child() retire
	# immédiatement l'ancienne case de la mise en page et déclenche aussitôt
	# son _exit_tree() (voir BoardMinion._exit_tree -> _cleanup_hover).
	for child in shop_front_row.get_children():
		shop_front_row.remove_child(child)
		child.queue_free()
	for child in shop_back_row.get_children():
		shop_back_row.remove_child(child)
		child.queue_free()
	if not in_shop_phase:
		_last_shop_offer_snapshot = []
		return
	var previous: Array = _last_shop_offer_snapshot
	var arrivals: Array = []
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
		if i >= previous.size() or previous[i] != card:
			arrivals.append(slot)
	_last_shop_offer_snapshot = human.shop_offer.duplicate()
	if not arrivals.is_empty():
		_animate_slide_in({-1.0: arrivals}, ENTRY_SLIDE_DURATION)

func _on_shop_card_dropped(shop_index: int, _is_front: bool) -> void:
	if not _is_shop_interaction_allowed():
		return
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
	# remove_child() avant queue_free() : voir _refresh_shop, même correctif
	# (évite qu'une ancienne case et sa remplaçante coexistent une frame dans
	# la mise en page et déclenchent chacune leur propre survol).
	for child in front_row.get_children():
		front_row.remove_child(child)
		child.queue_free()
	for child in back_row.get_children():
		back_row.remove_child(child)
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
	# remove_child() avant queue_free() : voir _refresh_shop/_refresh_board,
	# même correctif — appelée à quasi chaque action du joueur (_refresh_ui),
	# une ancienne case et sa remplaçante coexistant une frame dans la mise en
	# page produisait un flicker visible et une fenêtre où le bouton sur le
	# point d'être libéré pouvait encore intercepter un clic.
	for child in portraits_column.get_children():
		portraits_column.remove_child(child)
		child.queue_free()
	for p in match_.players:
		portraits_column.add_child(_make_participant_button(p, p.display_name, p.is_eliminated, p == human, p.hero_hp))

func _make_participant_button(target, _label_name: String, eliminated: bool, is_self: bool, hp: int) -> Button:
	var btn := Button.new()
	# Assez petit pour que les 8 participants tiennent dans la colonne de
	# gauche sans dépasser (voir portraits_column, ancrée en fraction d'écran :
	# 0.12-0.88, ~630px dispo à 1080p pour 8 boutons + séparation — cette
	# taille (64x78) laisse une bonne marge, contrairement à 52x64 jugée trop
	# petite par le joueur).
	btn.custom_minimum_size = Vector2(64, 78)
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

# Verrou d'action, indépendant de l'état (déjà désactivé/vidé) des contrôles
# eux-mêmes : _refresh_ui() ne s'exécute pas forcément avant qu'un signal en
# vol (clic déjà en cours, ou drop dont le payload a été capturé avant la fin
# de la manche, voir _resolve_combat_phase) n'atteigne son handler — sans ce
# garde-fou explicite ici, une action pouvait encore passer entre l'expiration
# du minuteur et le prochain rafraîchissement de l'UI.
func _is_shop_interaction_allowed() -> bool:
	return not game_over and current_phase == Phase.SHOP

func _on_reroll_pressed() -> void:
	if not _is_shop_interaction_allowed():
		return
	match_.reroll(human)
	_refresh_ui()

func _on_freeze_pressed() -> void:
	if not _is_shop_interaction_allowed():
		return
	human.toggle_shop_freeze()
	_refresh_ui()

func _on_buy_xp_pressed() -> void:
	if not _is_shop_interaction_allowed():
		return
	match_.buy_xp(human)
	_refresh_ui()

# Prêt : termine la phase Boutique tout de suite, sans attendre l'expiration
# du minuteur — voir le commentaire sur `ready_button` dans ArenaUIBuilder.build().
func _on_ready_pressed() -> void:
	if not _is_shop_interaction_allowed():
		return
	phase_timer.stop()
	await _resolve_combat_phase()

func _on_place_pressed(minion: Minion, is_front: bool, index: int = -1) -> void:
	if not _is_shop_interaction_allowed():
		return
	human.place_on_board(minion, is_front, index)
	_refresh_ui()

# Repositionnement (même ligne ou changement de ligne) d'un serviteur déjà
# posé — voir ArenaBoardMinionSlot/ArenaBoardRow.on_reposition.
func _on_board_minion_dropped(minion: Minion, is_front: bool, index: int) -> void:
	if not _is_shop_interaction_allowed():
		return
	human.move_on_board(minion, is_front, index)
	_refresh_ui()

# Vente en glissant un serviteur du plateau sur la boutique — voir ArenaSellZone.
func _on_board_minion_sold(minion: Minion) -> void:
	if not _is_shop_interaction_allowed():
		return
	match_.sell_card(human, minion, true)
	_refresh_ui()

func _on_view_board_pressed(target) -> void:
	viewed_target = target
	_refresh_ui()

# ─── Phase Combat ────────────────────────────────────────────────────────────
# Pas de bouton "round suivant" (le minuteur enchaîne automatiquement Boutique
# -> Combat -> Boutique du round suivant jusqu'à la fin de partie), mais un
# bouton Prêt (ready_button, voir _on_ready_pressed) permet de terminer la
# phase Boutique en avance sans attendre l'expiration du minuteur.

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
	# Rien à faire pour Phase.COMBAT : depuis le correctif ci-dessous, le
	# minuteur y est purement cosmétique (juste l'affichage du temps restant
	# pendant que le combat se déroule) — l'enchaînement vers la manche
	# suivante est déclenché dès que le combat est réellement terminé (voir
	# _resolve_combat_phase), jamais par l'expiration de ce minuteur.

func _resolve_combat_phase() -> void:
	# Démarre le décompte dès l'entrée en combat (demande explicite du
	# joueur) : le combat se déroule PENDANT le décompte plutôt qu'après (le
	# minuteur ne fait plus qu'afficher un temps indicatif en parallèle de
	# l'animation, voir _on_phase_timer_timeout) — dès que le combat est
	# réellement fini (plus bas), on enchaîne immédiatement sur la manche
	# suivante sans attendre le reste du décompte. _start_combat_phase_timer()
	# verrouille aussi la boutique humaine (current_phase gate dans
	# _refresh_ui) : sans ça, tout le temps que prennent les bots à jouer leur
	# manche + match_.end_shop_phase() + le combat animé (plusieurs secondes
	# réelles via les vrais timers d'AnimationSystem, voir live_setup plus bas)
	# restait fenêtre où reroll/achat/pose humains passaient encore alors que
	# la manche est déjà close côté moteur.
	_start_combat_phase_timer()
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
		# Transition animée Boutique -> Combat (demande explicite du joueur,
		# budget total ~2s) : le plateau du joueur affichait ses propres
		# serviteurs (ArenaBoardMinionSlot, glissables) pendant la boutique —
		# ils glissent hors-écran vers la DROITE plutôt que de disparaître
		# instantanément, pendant que la boutique (reconvertie en plateau
		# adverse le temps du combat) glisse vers la GAUCHE. Une fois l'écran
		# vidé, les serviteurs qui vont réellement combattre (BoardMinion nus,
		# non glissables, posés par enable_live_visuals) arrivent en sens
		# inverse : le plateau du joueur depuis la droite, l'adverse depuis
		# la gauche — avant que le combat proprement dit ne démarre.
		await _animate_slide_out_and_free({
			1.0: front_row.get_children() + back_row.get_children(),
			-1.0: shop_front_row.get_children() + shop_back_row.get_children(),
		}, EXIT_SLIDE_DURATION)
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
		await _animate_slide_in({
			1.0: front_row.get_children() + back_row.get_children(),
			-1.0: shop_front_row.get_children() + shop_back_row.get_children(),
		}, ENTRY_SLIDE_DURATION)
		# Tient la bannière "Combat" affichée jusqu'à épuiser le budget total
		# de ~2s (sortie + arrivée déjà écoulées), avant que le vrai combat
		# ne démarre (voir match_.start_combat_phase, appelé juste après
		# ce callable).
		var remaining: float = COMBAT_TRANSITION_TOTAL_DURATION - EXIT_SLIDE_DURATION - ENTRY_SLIDE_DURATION
		if remaining > 0.0:
			await get_tree().create_timer(remaining).timeout
		combat_banner_label.visible = false
	await match_.start_combat_phase(live_setup)
	enemy_hero_panel.visible = false
	_live_sim = null
	# Combat réellement terminé : plus besoin du reste du décompte cosmétique
	# démarré en entrée de fonction, on enchaîne tout de suite.
	phase_timer.stop()

	if match_.is_match_over() or human.is_eliminated:
		_show_game_over()
	else:
		_advance_round()

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
	SceneTransition.change_scene(MAIN_MENU_SCENE)

# Concéder depuis le menu Paramètres (voir settings_menu.concede_requested) :
# pas de réseau à fermer côté Arena (solo local), contrairement à
# Battle._on_quit_match — juste retourner au menu, la partie en cours est perdue.
func _on_settings_quit() -> void:
	settings_menu.close()
	SceneTransition.change_scene(MAIN_MENU_SCENE)
