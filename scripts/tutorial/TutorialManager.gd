extends Control
class_name TutorialManager

# Tutoriel obligatoire du nouveau joueur : une suite linéaire de popups qui
# assombrissent l'écran sauf la ou les zones à regarder (surlignées
# individuellement, jamais fusionnées en un seul grand trou) et disparaissent
# en fondu une fois la VRAIE action demandée effectuée — jamais sur un simple
# clic de complaisance quand une action précise est attendue. Certaines
# popups (pure narration : bienvenue, tour des zones, fin) n'ont pas d'action
# associée et se ferment donc au clic ; toutes les autres (jouer telle carte,
# attaquer, finir son tour, tour adverse) restent affichées — jeu non mis en
# pause, zone concernée pleinement jouable sous la surbrillance — jusqu'à ce
# que Battle/CardSystem/SelectionSystem/TurnSystem appellent le `notify_*`
# correspondant (no-op si `battle.tutorial_manager` est nul, donc aucun coût
# en partie normale).
#
# Limite connue : si le joueur ignore l'action suggérée par une étape et fait
# autre chose à la place, le script reste en attente de la bonne action et
# n'affiche plus de nouvelle popup tant qu'elle n'arrive pas — la partie reste
# jouable normalement, seul le guidage s'interrompt. Accepté comme
# simplification volontaire (voir discussion de conception).

signal _dismissed
signal _event(data: Dictionary)

const DIM_COLOR := Color(0, 0, 0, 0.72)
const HIGHLIGHT_BORDER_COLOR := Color(0.85, 0.7, 0.25, 1.0)
const CARD_DIM_COLOR := Color(0.32, 0.32, 0.32, 1.0)
const POPUP_WIDTH := 480.0
const POPUP_GAP := 24.0
const SCREEN_MARGIN := 20.0
const FADE_IN_TIME := 0.18
const FADE_OUT_TIME := 0.15

var battle: Node
var _dim_rects: Array[ColorRect] = []
var _highlight_pool: Array[Panel] = []
var _popup_panel: PanelContainer
var _popup_label: Label
var _hint_label: Label
var _popup_visible: bool = false
var _script_done: bool = false
# true tant que la popup courante bloque tout (lecture + clic) ; false pour
# les popups d'action (pose cette carte / termine ton tour / attaque...) qui
# laissent le jeu actif sous la surbrillance.
var _popup_paused: bool = true
# true si un clic quelconque referme la popup courante (narration pure) ;
# false pour les popups d'action, qui ne se referment que sur la vraie action.
var _dismiss_on_click: bool = true
# Cibles de la popup courante : le jeu n'étant pas en pause pendant les
# popups d'action, la main peut se redéployer sous la souris (voir
# Hand._process) — on recalcule donc les cadres chaque frame plutôt que de
# les figer au moment de l'affichage.
var _current_targets: Array = []
# true si cette popup a forcé la main à rester dépliée (voir _popup_play_card) ;
# à remettre à plat proprement à la fermeture.
var _forced_hand_expanded: bool = false
# true pendant une popup "pose cette carte" : pas d'assombrissement plein
# écran ni de cadre (voir _show_card_popup/_dim_other_cards), donc _process()
# ne doit pas recalculer de trou/cadre pour cette popup.
var _using_card_dim: bool = false
# true pour une popup qui surligne une cible SANS assombrir le reste de
# l'écran (ex. le bouton Fin du tour) : cadre affiché, aucun voile sombre.
var _highlight_only: bool = false
# Incrémenté à chaque _show_popup(). Sert à distinguer, dans les notify_*,
# "cet événement vient de faire apparaître une NOUVELLE popup" (qu'il faut
# attendre) de "une popup PRÉEXISTANTE, sans rapport avec cet événement,
# est encore affichée" (qu'il ne faut surtout PAS attendre — sinon deadlock :
# ex. cliquer Fin du tour pendant une popup qui attend "player_turn_began"
# bloquait notify_end_turn_pressed() sur une popup qui ne se referme que
# APRÈS que turn_system.end_turn() se soit exécuté — lequel n'est appelé
# qu'une fois notify_end_turn_pressed() revenu).
var _popup_generation: int = 0

func init(_battle: Node) -> void:
	battle = _battle
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Doit toujours s'afficher AU-DESSUS de tout, y compris la main (Hand a son
	# propre z_index pour flotter au-dessus du plateau) — sans quoi la popup
	# se retrouve visuellement sous la main, notamment quand celle-ci est
	# forcée dépliée pendant les popups "pose cette carte".
	z_index = 4096
	_build_ui()
	hide()

func start() -> void:
	run()

func _process(_delta: float) -> void:
	if not _popup_visible or _popup_paused or _using_card_dim:
		return
	var rects := _compute_target_rects(_current_targets)
	if not _highlight_only:
		_position_dim_rects(_dim_hole(rects, false))
	_update_highlights(rects)

# Le "trou" à ne pas assombrir. Deux cas très différents :
#  - Popup d'action (pause=false) : la ou les zones visées DOIVENT rester
#    lisibles et cliquables (ex. les 3 exemplaires interchangeables d'une
#    carte-ressource en main) — on fusionne tout en UN seul trou englobant,
#    sinon le fond assombri recouvrirait les cartes elles-mêmes.
#  - Popup de narration (pause=true) : rien n'est interactif, un trou n'a de
#    sens que pour UNE cible précise ; au-delà (ex. les deux boutons de
#    cimetière aux deux bouts de l'écran), mieux vaut tout assombrir et
#    laisser les cadres individuels désigner chaque zone plutôt que de
#    révéler une large bande vide entre les deux.
func _dim_hole(rects: Array, pause: bool) -> Rect2:
	if not pause:
		return _bounding_rect(rects)
	return rects[0] if rects.size() == 1 else Rect2()

# ─── UI ───────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	for i in range(4):
		var rect := ColorRect.new()
		rect.color = DIM_COLOR
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
		_dim_rects.append(rect)

	_popup_panel = PanelContainer.new()
	_popup_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_panel.custom_minimum_size = Vector2(POPUP_WIDTH, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("1a0e0eee")
	panel_style.border_width_left   = 2
	panel_style.border_width_right  = 2
	panel_style.border_width_top    = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color("c9a227")
	panel_style.content_margin_left   = 20
	panel_style.content_margin_right  = 20
	panel_style.content_margin_top    = 16
	panel_style.content_margin_bottom = 16
	panel_style.shadow_color = Color(0, 0, 0, 0.6)
	panel_style.shadow_size  = 10
	_popup_panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 10)
	_popup_panel.add_child(vbox)

	_popup_label = Label.new()
	_popup_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Largeur fixe indispensable : sans elle, Label calcule sa taille minimale
	# sur le texte NON replié (une seule ligne), ce qui fait exploser la
	# largeur du popup entier bien au-delà de POPUP_WIDTH.
	_popup_label.custom_minimum_size = Vector2(POPUP_WIDTH - 40, 0)
	_popup_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_popup_label.add_theme_font_size_override("font_size", 20)
	_popup_label.add_theme_color_override("font_color", Color("e8d5a3"))
	vbox.add_child(_popup_label)

	_hint_label = Label.new()
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.add_theme_color_override("font_color", Color("a89a7a"))
	vbox.add_child(_hint_label)

	add_child(_popup_panel)

# _input (pas _gui_input) : indépendant du hit-testing/z-order des Controls
# (d'autres overlays comme CombatLogPanel/ReconnectOverlay sont ajoutés à
# Battle après tutorial_manager et pourraient sinon intercepter le clic avant
# qu'il n'atteigne cette popup). process_mode = ALWAYS le laisse fonctionner
# malgré la pause.
func _input(event: InputEvent) -> void:
	if not _popup_visible or not _dismiss_on_click:
		return
	var is_click: bool = false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		is_click = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	if is_click or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_dismiss_popup()

# Rectangle individuel (avec marge) de chaque nœud visé, en coordonnées
# globales — jamais fusionnés : deux cibles éloignées (ex. les deux boutons
# de cimetière) donnent deux cadres distincts, pas une large zone entre eux.
func _compute_target_rects(targets: Array) -> Array:
	var rects: Array = []
	for t in targets:
		if t == null or not (t is CanvasItem) or not is_instance_valid(t):
			continue
		var r: Rect2 = _transformed_rect(t) if t is Control else Rect2(t.global_position, Vector2.ZERO)
		# Pas de marge ajoutée : les cartes en main se chevauchent (effet
		# éventail), un cadre agrandi vers l'extérieur déborderait sur la
		# carte voisine au lieu de rester sur la carte visée.
		rects.append(r)
	return rects

# get_global_rect() ignore l'échelle (et la rotation) du Control : une carte
# en main réduite à 0.75 (Hand.NORMAL_SCALE) obtient un rect ~33% trop grand,
# qui déborde largement sur ses voisines. On calcule donc la vraie boîte
# englobante à partir de la transformation globale plutôt que de
# position/size bruts.
func _transformed_rect(control: Control) -> Rect2:
	var xform := control.get_global_transform()
	var size: Vector2 = control.size
	var corners := [
		xform * Vector2.ZERO,
		xform * Vector2(size.x, 0),
		xform * Vector2(0, size.y),
		xform * size,
	]
	var result := Rect2(corners[0], Vector2.ZERO)
	for c in corners:
		result = result.expand(c)
	return result

func _bounding_rect(rects: Array) -> Rect2:
	if rects.is_empty():
		return Rect2()
	var result: Rect2 = rects[0]
	for i in range(1, rects.size()):
		result = result.merge(rects[i])
	return result

# Bordure fine, fond et ombre transparents : un simple cadre autour de la
# cible, jamais un pavé plein. (Une ombre colorée avait été tentée ici, mais
# à cette taille elle se confondait avec un remplissage plein — retirée.)
func _make_highlight_panel() -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_width_left   = 3
	style.border_width_right  = 3
	style.border_width_top    = 3
	style.border_width_bottom = 3
	style.border_color = HIGHLIGHT_BORDER_COLOR
	style.corner_radius_top_left     = 8
	style.corner_radius_top_right    = 8
	style.corner_radius_bottom_left  = 8
	style.corner_radius_bottom_right = 8
	style.shadow_size = 0
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	return panel

# Un cadre par cible (pool réutilisé d'une popup à l'autre) : chaque zone
# visée est surlignée individuellement, jamais un seul cadre englobant.
func _update_highlights(rects: Array) -> void:
	while _highlight_pool.size() < rects.size():
		_highlight_pool.append(_make_highlight_panel())
	for i in range(_highlight_pool.size()):
		var panel: Panel = _highlight_pool[i]
		if i < rects.size():
			panel.position = rects[i].position
			panel.size = rects[i].size
			panel.visible = true
		else:
			panel.visible = false

# Un seul "trou" géométrique (via 4 bandes) n'a de sens que pour UNE cible :
# au-delà, on assombrit tout l'écran uniformément et les cadres individuels
# suffisent à désigner chaque zone (voir _update_highlights).
func _position_dim_rects(hole: Rect2) -> void:
	var vp: Vector2 = get_viewport_rect().size
	if hole.size == Vector2.ZERO:
		_dim_rects[0].position = Vector2.ZERO
		_dim_rects[0].size = vp
		for i in range(1, 4):
			_dim_rects[i].size = Vector2.ZERO
		return
	_dim_rects[0].position = Vector2.ZERO
	_dim_rects[0].size = Vector2(vp.x, max(0.0, hole.position.y))
	_dim_rects[1].position = Vector2(0, hole.position.y + hole.size.y)
	_dim_rects[1].size = Vector2(vp.x, max(0.0, vp.y - (hole.position.y + hole.size.y)))
	_dim_rects[2].position = Vector2(0, hole.position.y)
	_dim_rects[2].size = Vector2(max(0.0, hole.position.x), hole.size.y)
	_dim_rects[3].position = Vector2(hole.position.x + hole.size.x, hole.position.y)
	_dim_rects[3].size = Vector2(max(0.0, vp.x - (hole.position.x + hole.size.x)), hole.size.y)

# Colle la popup juste à côté de la zone surlignée (au-dessus ou en dessous,
# du côté qui a le plus de place), centrée horizontalement dessus plutôt que
# systématiquement au milieu de l'écran — pour que ce soit visuellement
# évident que la popup se rapporte à CETTE zone-là.
# clearance : zone à ne pas chevaucher pour la POSITION verticale (au-dessus/
# en dessous). Distincte de `hole` (utilisé pour le centrage horizontal et
# resté précis sur les cartes visées) : pendant les popups "pose cette
# carte", la main est forcée dépliée et occupe bien plus de place que les
# seules cartes visées — se référer uniquement à leur rect ferait chevaucher
# le reste de la main déployée sous la popup. `clearance` inclut donc tout
# le contour actuel de la main dans ce cas (voir _popup_play_card).
func _position_popup(hole: Rect2, clearance: Rect2 = Rect2()) -> void:
	var vp: Vector2 = get_viewport_rect().size
	_popup_panel.reset_size()
	var panel_size: Vector2 = _popup_panel.size
	if clearance.size == Vector2.ZERO:
		clearance = hole
	elif hole.size != Vector2.ZERO:
		clearance = clearance.merge(hole)
	# Pas de cible, ou cible(s)/main trop étalée(s) verticalement : aucun côté
	# n'a assez de place pour coller la popup sans chevaucher — on la centre
	# au milieu de l'écran plutôt que de la forcer dans un espace trop étroit.
	var space_below: float = vp.y - (clearance.position.y + clearance.size.y)
	var space_above: float = clearance.position.y
	var fits_above_or_below: bool = max(space_above, space_below) >= panel_size.y + POPUP_GAP
	if clearance.size == Vector2.ZERO or not fits_above_or_below:
		_popup_panel.position = (vp - panel_size) / 2.0
		return
	var anchor: Rect2 = hole if hole.size != Vector2.ZERO else clearance
	var anchor_center_x: float = anchor.position.x + anchor.size.x / 2.0
	var x: float = clamp(anchor_center_x - panel_size.x / 2.0,
		SCREEN_MARGIN, vp.x - panel_size.x - SCREEN_MARGIN)
	var y: float
	if space_below >= panel_size.y + POPUP_GAP or space_below >= space_above:
		y = min(clearance.position.y + clearance.size.y + POPUP_GAP, vp.y - panel_size.y - SCREEN_MARGIN)
	else:
		y = max(clearance.position.y - panel_size.y - POPUP_GAP, SCREEN_MARGIN)
	_popup_panel.position = Vector2(x, y)

# Fondu commun à l'affichage/la fermeture d'une popup (dim + cadres + panneau
# de texte) : évite que tout apparaisse/disparaisse d'un coup.
func _fade(target_alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	for r in _dim_rects:
		tween.tween_property(r, "modulate:a", target_alpha, duration)
	for p in _highlight_pool:
		if p.visible:
			tween.tween_property(p, "modulate:a", target_alpha, duration)
	tween.tween_property(_popup_panel, "modulate:a", target_alpha, duration)
	await tween.finished

# pause : fige l'arbre et bloque tout jusqu'au clic (popups de narration pure).
# dismiss_on_click : false pour les popups d'action, qui ne se referment que
# sur la vraie action visée (drag&drop d'une carte, fin de tour, attaque...)
# et laissent la zone surlignée réellement interactive : aucune pause, aucun
# blocage d'input (mouse_filter = IGNORE) tant qu'une action reste possible.
func _show_popup(text_key: String, targets: Array, pause: bool = true, dismiss_on_click: bool = true, hint_key: String = "", clearance: Rect2 = Rect2(), dim_screen: bool = true) -> void:
	_popup_label.text = SettingsManager.t(text_key)
	if hint_key == "":
		hint_key = "tutorial.click_to_continue" if dismiss_on_click else "tutorial.action_hint"
	_hint_label.text = SettingsManager.t(hint_key)
	_current_targets = targets
	_using_card_dim = false
	_highlight_only = not dim_screen
	var rects := _compute_target_rects(targets)
	if dim_screen:
		_position_dim_rects(_dim_hole(rects, pause))
	else:
		for r in _dim_rects:
			r.size = Vector2.ZERO
	_update_highlights(rects)
	_position_popup(_bounding_rect(rects), clearance)
	mouse_filter = Control.MOUSE_FILTER_STOP if pause else Control.MOUSE_FILTER_IGNORE
	for r in _dim_rects:
		r.modulate.a = 0.0
	for p in _highlight_pool:
		p.modulate.a = 0.0
	_popup_panel.modulate.a = 0.0
	visible = true
	_popup_paused = pause
	_dismiss_on_click = dismiss_on_click
	# Toujours réaffecté explicitement (jamais seulement "true" ici / "false" à
	# la fermeture) : si un enchaînement de popups désynchronise l'état figé
	# d'un ancien appel, ceci le recorrige à chaque affichage plutôt que de
	# laisser l'arbre bloqué en pause indéfiniment (bug observé : plus aucune
	# entrée souris/clavier ne passait, y compris hors du tutoriel).
	get_tree().paused = pause
	_popup_visible = true
	_popup_generation += 1
	_fade(1.0, FADE_IN_TIME)

func _dismiss_popup() -> void:
	if not _popup_visible:
		return
	_popup_visible = false
	# Toujours dépausé à la fermeture, sans condition : aucune popup fermée ne
	# doit jamais laisser la partie figée derrière elle.
	get_tree().paused = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	await _fade(0.0, FADE_OUT_TIME)
	visible = false
	_dismissed.emit()

# Popup de narration pure (pas d'action associée) : se ferme au clic.
func _popup(text_key: String, targets: Array) -> void:
	_show_popup(text_key, targets)
	await _dismissed

# Popup d'action générique : reste affichée (jeu non mis en pause) jusqu'à ce
# que l'événement `kind` (voir notify_*/_wait_for) survienne réellement —
# jamais sur un simple clic.
func _popup_wait_action(text_key: String, targets: Array, kind: String, matcher: Callable = Callable(), hint_key: String = "tutorial.action_hint", dim_screen: bool = true) -> void:
	_show_popup(text_key, targets, false, false, hint_key, Rect2(), dim_screen)
	await _wait_for(kind, matcher)
	await _dismiss_popup()

# Trouve la/les cartes de la main du joueur correspondant à cette CardData
# (plusieurs nœuds si le joueur a plusieurs exemplaires interchangeables,
# ex. les cartes-ressource de la main de départ). Comparaison par
# resource_path plutôt que par identité d'objet : plusieurs copies d'une même
# carte peuvent exister comme des instances distinctes selon comment la main
# a été construite, seul le chemin de la ressource les identifie de façon fiable.
func _find_hand_card_nodes(card: CardData) -> Array:
	var result: Array = []
	if battle.hand == null or card == null:
		return result
	for child in battle.hand.container.get_children():
		if child is Card and _same_card(child.data, card):
			result.append(child)
	return result

func _same_card(a: CardData, b: CardData) -> bool:
	if a == null or b == null:
		return false
	if a == b:
		return true
	return a.resource_path != "" and a.resource_path == b.resource_path

# Contour de TOUTE la main actuellement affichée (pas juste les cartes
# visées) : sert de zone à éviter pour placer la popup verticalement (voir
# _position_popup) — la main dépliée occupe bien plus d'espace que les
# quelques cartes surlignées, il faut passer par-dessus elle en entier, pas
# juste par-dessus les cartes ciblées.
func _hand_bounds() -> Rect2:
	if battle.hand == null:
		return Rect2()
	var result := Rect2()
	var first := true
	for child in battle.hand.container.get_children():
		if child is Control and child.visible:
			var r := _transformed_rect(child)
			if first:
				result = r
				first = false
			else:
				result = result.merge(r)
	if not first:
		# Marge de sécurité vers le haut : les cartes du centre de l'éventail
		# montent plus haut que les bords (ARC_STRENGTH) et le dépli forcé
		# n'a parfois pas fini d'animer au moment de la mesure — sans cette
		# marge, la popup peut chevaucher le sommet de la main déployée.
		const HAND_TOP_SAFETY := 80.0
		result.position.y -= HAND_TOP_SAFETY
		result.size.y += HAND_TOP_SAFETY
	return result

# Assombrit toutes les cartes de la main SAUF celles visées (au lieu d'un
# cadre autour de la carte à jouer) : plus simple, ne risque jamais de
# déborder sur une carte voisine dans l'éventail.
func _dim_other_cards(target_nodes: Array) -> void:
	if battle.hand == null:
		return
	for child in battle.hand.container.get_children():
		if child is Card:
			var target_color: Color = Color.WHITE if child in target_nodes else CARD_DIM_COLOR
			var tween := create_tween()
			tween.tween_property(child, "modulate", target_color, FADE_IN_TIME)

func _undim_all_cards() -> void:
	if battle.hand == null:
		return
	for child in battle.hand.container.get_children():
		if child is Card:
			var tween := create_tween()
			tween.tween_property(child, "modulate", Color.WHITE, FADE_OUT_TIME)

# Popup de texte seule (sans assombrissement plein écran ni cadre) : utilisée
# par _popup_play_card, où l'assombrissement porte sur les cartes elles-mêmes
# (voir _dim_other_cards) plutôt que sur tout l'écran.
func _show_card_popup(text_key: String, hint_key: String, clearance: Rect2) -> void:
	_popup_label.text = SettingsManager.t(text_key)
	_hint_label.text = SettingsManager.t(hint_key)
	for r in _dim_rects:
		r.size = Vector2.ZERO
		r.modulate.a = 0.0
	for p in _highlight_pool:
		p.visible = false
	_position_popup(Rect2(), clearance)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_panel.modulate.a = 0.0
	visible = true
	_popup_paused = false
	_dismiss_on_click = false
	_using_card_dim = true
	get_tree().paused = false
	_popup_visible = true
	_popup_generation += 1
	var tween := create_tween()
	tween.tween_property(_popup_panel, "modulate:a", 1.0, FADE_IN_TIME)

# Popup "pose cette carte" : assombrit toutes les autres cartes de la main
# (jamais un cadre, jamais toute la main assombrie), ne met PAS la partie en
# pause, force la main à rester dépliée (comme au survol) le temps de la
# popup, et ne se referme QUE lorsque le joueur commence à glisser l'une des
# cartes visées (Card.drag_started) — jamais sur un simple clic ailleurs.
func _popup_play_card(text_key: String, card: CardData) -> void:
	var nodes := _find_hand_card_nodes(card)
	if battle.hand != null and not battle.hand._force_expanded:
		battle.hand._force_expanded = true
		_forced_hand_expanded = true
		# Laisse le temps au tween de dépli de la main de se terminer avant de
		# mesurer son contour (Hand._update_hand_layout anime sur 0.3s) —
		# sans cette attente, _hand_bounds() capture encore l'ancienne mise
		# en page repliée et la popup peut chevaucher le haut de la main.
		await get_tree().create_timer(0.35).timeout
		nodes = _find_hand_card_nodes(card)
	if nodes.is_empty():
		# Filet de sécurité (ne devrait pas arriver avec le deck fixe du
		# tutoriel) : on retombe sur une popup classique pour ne jamais
		# bloquer le script si la carte est introuvable en main.
		await _popup(text_key, [battle.hand])
		return
	_dim_other_cards(nodes)
	_show_card_popup(text_key, "tutorial.drag_to_continue", _hand_bounds())
	for node in nodes:
		if not node.drag_started.is_connected(_on_target_card_drag_started):
			node.drag_started.connect(_on_target_card_drag_started, CONNECT_ONE_SHOT)
	await _dismissed
	_using_card_dim = false
	_undim_all_cards()
	# Ne relâche le dépli forcé que si aucun drag n'est réellement en cours
	# (le drag qui a fermé la popup a déjà mis à jour ce même flag lui-même).
	if _forced_hand_expanded and battle.hand != null and not battle.is_dragging_card():
		battle.hand._force_expanded = false
	_forced_hand_expanded = false

func _on_target_card_drag_started() -> void:
	if _popup_visible:
		_dismiss_popup()

# ─── Notifications (appelées par Battle/CardSystem/SelectionSystem/TurnSystem) ─

# N'attend une popup encore affichée après l'émission QUE si CET événement en
# a fait apparaître une nouvelle (generation changée) — jamais une popup
# préexistante sans rapport, qui ne se refermera que suite à un événement
# ULTÉRIEUR dépendant du retour de cet appel (sinon deadlock, voir
# _popup_generation).
func notify_card_played(card_data: CardData) -> void:
	var gen := _popup_generation
	_event.emit({"kind": "card_played", "payload": card_data})
	if _popup_visible and _popup_generation != gen:
		await _dismissed

func notify_end_turn_pressed() -> void:
	var gen := _popup_generation
	_event.emit({"kind": "end_turn", "payload": null})
	if _popup_visible and _popup_generation != gen:
		await _dismissed

func notify_combat() -> void:
	var gen := _popup_generation
	_event.emit({"kind": "combat", "payload": null})
	if _popup_visible and _popup_generation != gen:
		await _dismissed

func notify_player_turn_began() -> void:
	var gen := _popup_generation
	_event.emit({"kind": "player_turn_began", "payload": null})
	if _popup_visible and _popup_generation != gen:
		await _dismissed

# Appelé par Battle quand le héros ennemi meurt en mode tutoriel : dernière
# popup de félicitations, puis déblocage définitif (multijoueur/deckbuilder).
func notify_victory() -> void:
	await _popup("tutorial.complete", [])
	SettingsManager.set_tutorial_completed()
	battle.get_tree().change_scene_to_file(battle.MAIN_MENU_SCENE)

# ─── Attentes ─────────────────────────────────────────────────────────────────

func _wait_for(kind: String, matcher: Callable = Callable()) -> void:
	while true:
		var data: Dictionary = await _event
		if data.get("kind") == kind and (matcher.is_null() or matcher.call(data.get("payload"))):
			return

func _wait_card(card: CardData) -> void:
	await _wait_for("card_played", func(p): return _same_card(p, card))

func _wait_minion() -> void:
	await _wait_for("card_played", func(p): return p != null and p.card_type == "Minion")

# ─── Script du tutoriel ───────────────────────────────────────────────────────

func run() -> void:
	var b: Node = battle
	var player_hero_panel: Control = b.get_node("PlayerHeroPanel")
	var enemy_hero_panel: Control  = b.get_node("EnemyHeroPanel")

	await _popup("tutorial.welcome", [player_hero_panel, enemy_hero_panel])

	# Petit tour des zones du plateau avant d'entrer dans le vif du sujet :
	# chacune n'accueille qu'un type de carte précis.
	await _popup("tutorial.zone_rows", [b.player_front_container, b.player_back_container])
	await _popup("tutorial.zone_resource", [b.player_resource_zone])
	await _popup("tutorial.zone_ritual", [b.player_ritual_zone])
	await _popup("tutorial.zone_enchantment", [b.player_enchantment_zone])
	await _popup("tutorial.zone_graveyard", [b.player_graveyard_btn, b.enemy_graveyard_btn])

	await _popup_play_card("tutorial.resource_intro", TutorialDeck.resource_card())
	await _wait_card(TutorialDeck.resource_card())

	await _popup_play_card("tutorial.minion_intro", TutorialDeck.zombie_card())
	await _wait_minion()

	await _popup_wait_action("tutorial.end_turn_intro", [b.end_turn_button], "end_turn",
		Callable(), "tutorial.hint_end_turn", false)

	await _popup_wait_action("tutorial.enemy_turn_intro",
		[b.enemy_front_container, enemy_hero_panel], "player_turn_began",
		Callable(), "tutorial.hint_watch")

	await _popup_play_card("tutorial.turn2_resource", TutorialDeck.resource_card())
	await _wait_card(TutorialDeck.resource_card())

	await _popup_wait_action("tutorial.attack_intro",
		[b.player_front_container, b.enemy_front_container], "combat",
		Callable(), "tutorial.hint_attack")

	await _popup_play_card("tutorial.taunt_intro", TutorialDeck.wandering_corpse_card())
	await _wait_card(TutorialDeck.wandering_corpse_card())

	await _popup_wait_action("tutorial.turn2_end_wait", [b.end_turn_button], "player_turn_began",
		Callable(), "tutorial.hint_end_turn", false)

	await _popup_play_card("tutorial.turn3_resource", TutorialDeck.resource_card())
	await _wait_card(TutorialDeck.resource_card())

	await _popup_play_card("tutorial.spell_intro", TutorialDeck.necrotic_breath_card())
	await _wait_card(TutorialDeck.necrotic_breath_card())

	await _popup_wait_action("tutorial.turn3_end_wait", [b.end_turn_button], "player_turn_began",
		Callable(), "tutorial.hint_end_turn", false)

	await _popup_play_card("tutorial.trigger_intro", TutorialDeck.gaunt_servant_card())
	await _wait_card(TutorialDeck.gaunt_servant_card())

	await _popup("tutorial.finish_intro", [enemy_hero_panel])
	_script_done = true
