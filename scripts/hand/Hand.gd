extends Control
class_name Hand

signal card_played(card_data: CardData, row: String, insert_index: int)
signal drag_started
signal drag_ended
signal mulligan_card_clicked(index: int, card_data: CardData)
signal discard_card_clicked(index: int, card_data: CardData)

@onready var container = $CardsContainer
@onready var preview   = $CardPreview

# Doit rester au-dessus des boutons du plateau (cimetière, deck — z_index 0
# par défaut) pour que la main ne soit jamais recouverte par eux.
const CARD_Z_BASE := 20

const CARD_SCENE      := preload("res://scenes/card/Card.tscn")
const NORMAL_SCALE    := Vector2(0.75, 0.75)
const SPACING         := 115.0
const COMPACT_SPACING := 20.0
const ARC_STRENGTH    := 20.0
# Échelle des cartes pendant le mulligan (main centrée à l'écran), relative à
# NORMAL_SCALE.
const MULLIGAN_SCALE_MULTIPLIER := 1.5
# Hauteur verticale (fraction de l'écran) du centre de la main pendant le
# mulligan — fixe, laisse la place à la bannière au-dessus et au bouton en dessous.
const MULLIGAN_CENTER_Y_RATIO   := 0.52
# Durée totale de l'animation de pioche de la main de départ (une carte après
# l'autre depuis le deck) avant que le mulligan ne devienne interactif.
const OPENING_DRAW_DURATION       := 3.0
# Durée totale de la transition d'entrée en mulligan (chaque carte anime vers
# sa position centrée/agrandie, l'une après l'autre plutôt que toutes en même temps).
const MULLIGAN_TRANSITION_DURATION := 3.0
# Fraction de la hauteur (mise à l'échelle) d'une carte encore visible quand la
# main est repliée — le reste dépasse sous le bas de l'écran
const COLLAPSED_PEEK_RATIO := 0.22
# Bande basse de l'écran qui déclenche le déploiement quand la main est repliée
const EXPAND_ZONE_HEIGHT   := 90.0
# Bande basse qui garde la main déployée une fois ouverte (hystérésis anti-flicker)
const COLLAPSE_ZONE_HEIGHT := 340.0
# Décalage vertical de la carte survolée (se soulève pour se démarquer)
const HOVER_LIFT       := 40.0
# Décalage horizontal maximal appliqué aux cartes voisines pour dégager la carte survolée
const HOVER_PUSH_MAX   := 28.0
# Atténuation du décalage horizontal par carte d'écart supplémentaire
const HOVER_PUSH_DECAY := 0.55
const HAND_START_X     := 80.0
# Délai avant repliement une fois la souris sortie de la zone de main (évite un
# repli trop nerveux) — ignoré quand une carte vient d'être jouée (repli immédiat)
const COLLAPSE_DELAY   := 1.0
# Durée des animations de déploiement/repliement de la main
const LAYOUT_TWEEN_DURATION := 0.28

var _base_positions:    Dictionary     = {}
# Ordre logique fixe des cartes en main (position/index), indépendant de
# l'ordre des enfants du conteneur — celui-ci est réarrangé au survol (voir
# _sync_tree_order) pour que la carte survolée passe réellement au-dessus des
# autres, y compris pour la détection de la souris, sans décaler leur position.
var _hand_order:        Array          = []
var _hovered_card:      Card           = null
var _is_compact:        bool           = false
var can_play_check:     Callable       = Callable()
var create_drag_preview: Callable      = Callable()
var display_cost:       Callable       = Callable()
var _keyword_tooltips:  Array[Control] = []
var _tooltip_layer:     CanvasLayer    = null
var _hovering:          bool           = false
var _mulligan_mode:     bool           = false
var _discard_mode:      bool           = false
# Repli/déploiement façon TCG : la main se range vers le bas hors hover
var _hand_expanded:     bool           = false
# Vrai pendant un drag issu de la main : reste déployée quelle que soit la souris
var _force_expanded:    bool           = false
# Temps écoulé (s) depuis que la souris a quitté la zone de main, en attente du
# délai avant repliement (voir COLLAPSE_DELAY)
var _collapse_elapsed:  float          = 0.0

var _battle: Node = null

func _ready() -> void:
	# Repli seulement : Hand est un enfant STATIQUE de Battle.tscn, donc ses
	# _ready() peuvent s'exécuter avant que get_tree().current_scene ne
	# pointe effectivement vers la scène en cours de chargement (contrairement
	# à BoardMinion, instancié dynamiquement bien après la fin de la
	# transition). Une résolution ratée ici laissait `_battle` invalide toute
	# la partie : la carte se soulevait encore au survol (logique locale à
	# Hand) mais aucun tooltip de mot-clé ne s'affichait jamais, sans erreur
	# visible (bloqué par les gardes is_instance_valid(_battle) plus bas).
	# set_battle(), appelé explicitement par Battle._init_systems(), écrase
	# cette valeur avec la référence garantie correcte.
	_battle = get_tree().current_scene
	preview.set_non_interactive()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.z_index = 100
	preview.hide()

func set_battle(battle: Node) -> void:
	_battle = battle

func _process(delta: float) -> void:
	if _mulligan_mode:
		return
	var should_expand: bool = _force_expanded or _is_mouse_in_hand_zone()
	if should_expand:
		_collapse_elapsed = 0.0
		if not _hand_expanded:
			_hand_expanded = true
			_update_hand_layout(true)
	elif _hand_expanded:
		_collapse_elapsed += delta
		if _collapse_elapsed >= COLLAPSE_DELAY:
			_collapse_elapsed = 0.0
			_hand_expanded = false
			_update_hand_layout(true)

func _is_mouse_in_hand_zone() -> bool:
	var zone_height: float = COLLAPSE_ZONE_HEIGHT if _hand_expanded else EXPAND_ZONE_HEIGHT
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	if mouse_pos.y < size.y - zone_height:
		return false
	var x_range := _hand_cards_x_range()
	if x_range.x > x_range.y:
		return false
	return mouse_pos.x >= x_range.x and mouse_pos.x <= x_range.y

# Étendue horizontale (avec marge) occupée par les cartes en main, utilisée
# pour restreindre la zone de survol qui déploie la main : sans ça, une bande
# couvrant toute la largeur de l'écran se déclenche même en visant un bouton
# éloigné (ex. Fin du tour) situé à la même hauteur.
const HAND_ZONE_X_PADDING := 60.0

func _hand_cards_x_range() -> Vector2:
	_prune_hand_order()
	var cards := _layout_cards()
	if cards.is_empty():
		return Vector2(1.0, -1.0)
	var layout := _compute_layout(cards)
	var last_card: Control = cards[cards.size() - 1]
	var min_x: float = HAND_START_X - HAND_ZONE_X_PADDING
	var max_x: float = HAND_START_X + (cards.size() - 1) * layout["spacing"] + last_card.size.x * layout["scale"].x + HAND_ZONE_X_PADDING
	return Vector2(min_x, max_x)

# Zone basse de l'écran considérée comme « dans la main » : lâcher une carte
# éphémère/rituel/enchantement au-delà de cette zone suffit à la jouer
func get_hand_zone_rect() -> Rect2:
	var zone_height: float = COLLAPSE_ZONE_HEIGHT if _hand_expanded else EXPAND_ZONE_HEIGHT
	var full: Rect2 = get_global_rect()
	return Rect2(
		Vector2(full.position.x, full.position.y + full.size.y - zone_height),
		Vector2(full.size.x, zone_height)
	)


func set_hand(cards: Array[CardData], animate_last: bool = false, deck_origin: Vector2 = Vector2.ZERO) -> void:
	if not animate_last:
		await _set_hand_instant(cards)
	else:
		await _set_hand_animated(cards, deck_origin)

func _set_hand_instant(cards: Array[CardData]) -> void:
	for c in container.get_children():
		c.queue_free()
	_base_positions.clear()
	_hand_order.clear()
	_hovered_card = null
	await get_tree().process_frame

	for card_data in cards:
		if card_data == null:
			push_warning("Hand: carte nulle ignorée")
			continue
		var card: Card = CARD_SCENE.instantiate()
		container.add_child(card)
		card.set_data(card_data)
		card.scale = NORMAL_SCALE
		_connect_card(card)
		_hand_order.append(card)

	await get_tree().process_frame
	for card in container.get_children():
		card.pivot_offset = Vector2(card.size.x / 2.0, card.size.y)
		card.visible = true
	_update_hand_layout(false)

# Anime la pioche de la main de départ, une carte après l'autre depuis le
# deck (même effet visuel qu'une pioche normale, voir _set_hand_animated),
# étalée sur total_duration au total. À appeler avant le mulligan, dont
# l'entrée est elle-même animée séparément (voir set_mulligan_mode).
func play_opening_draw(cards: Array[CardData], deck_origin: Vector2, total_duration: float = OPENING_DRAW_DURATION) -> void:
	for c in container.get_children():
		c.queue_free()
	_base_positions.clear()
	_hand_order.clear()
	_hovered_card = null
	await get_tree().process_frame

	var valid_cards: Array[CardData] = []
	for card_data in cards:
		if card_data == null:
			push_warning("Hand: carte nulle ignorée")
			continue
		valid_cards.append(card_data)
	if valid_cards.is_empty():
		return

	var gap: float = total_duration / float(valid_cards.size())
	for card_data in valid_cards:
		var card: Card = CARD_SCENE.instantiate()
		card.visible = false
		container.add_child(card)
		card.set_data(card_data)
		card.scale = NORMAL_SCALE
		_connect_card(card)
		_hand_order.append(card)
		await get_tree().process_frame
		if not is_instance_valid(self) or not is_instance_valid(card):
			return
		card.pivot_offset = Vector2(card.size.x / 2.0, card.size.y)
		_update_hand_layout(false)

		var final_pos: Vector2 = card.position
		var final_scale: Vector2 = card.scale
		AudioManager.play(AudioManager.DRAW)
		await _fly_ghost_card(card_data, deck_origin, final_pos, final_scale, card, func(): card.visible = true)
		if not is_instance_valid(self):
			return
		await get_tree().create_timer(maxf(gap - 0.5, 0.05)).timeout
		if not is_instance_valid(self):
			return

# Fait voler une carte fantôme (dos visible) depuis deck_origin (position
# globale) jusqu'à local_target_pos (dans le repère de Hand), se retourne à
# mi-chemin, puis appelle on_landed une fois arrivée. Facteur commun entre
# play_opening_draw et _set_hand_animated. target_card est la carte de la main
# que on_landed va rendre visible : si elle a été libérée entre-temps (main
# reconstruite pendant l'animation), on_landed n'est pas appelé.
func _fly_ghost_card(card_data: CardData, deck_origin: Vector2, local_target_pos: Vector2, target_scale: Vector2, target_card: Card, on_landed: Callable) -> void:
	if not is_instance_valid(_battle) or not _battle.is_inside_tree():
		if is_instance_valid(target_card):
			on_landed.call()
		return
	var ghost: Card = CARD_SCENE.instantiate()
	_battle.add_child(ghost)
	ghost.set_data(card_data)
	ghost.drag_enabled = false
	ghost.show_back(true)
	ghost.scale    = target_scale
	ghost.modulate = Color.WHITE
	ghost.z_index  = 100
	ghost.visible  = false
	await get_tree().process_frame
	if not is_instance_valid(ghost):
		return
	if not is_instance_valid(self):
		ghost.queue_free()
		return
	var final_pos: Vector2 = global_position + local_target_pos
	# Le deck est affiché tourné à 90° (DeckButton.rotation dans Battle.tscn) :
	# la carte fantôme part dans cette même orientation, se redresse en vol
	# (90° -> 0°), puis se retourne (dos -> face) une fois droite, tout en
	# continuant sa course vers la main. pivot_offset au centre pour que la
	# rotation ET le retournement (scale:x) restent centrés sur la carte au
	# lieu de pivoter depuis son coin (comportement par défaut de Control).
	ghost.pivot_offset = ghost.size / 2.0
	ghost.rotation = PI / 2.0
	ghost.global_position = deck_origin - ghost.pivot_offset
	ghost.visible = true
	var mid_pos := Vector2(
		(deck_origin.x + final_pos.x) / 2.0,
		(deck_origin.y + final_pos.y) / 2.0 - 100
	)
	# Accessibilité : durée raccourcie si SettingsManager.reduced_motion.
	var step_duration: float = 0.1 * SettingsManager.motion_scale()
	var tween := create_tween()
	tween.set_parallel(false)
	tween.tween_property(ghost, "global_position", mid_pos, step_duration * 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ghost, "rotation", 0.0, step_duration * 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost, "scale:x",          0.0,           step_duration).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(func(): ghost.show_back(false))
	tween.tween_property(ghost, "scale:x",          target_scale.x, step_duration).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(ghost, "global_position",  final_pos,     step_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	if is_instance_valid(ghost):
		ghost.queue_free()
	if is_instance_valid(self) and is_instance_valid(target_card):
		on_landed.call()

func _set_hand_animated(cards: Array[CardData], deck_origin: Vector2) -> void:
	var new_card_data: CardData = cards.back()
	var new_card: Card = CARD_SCENE.instantiate()
	new_card.visible = false
	container.add_child(new_card)
	new_card.set_data(new_card_data)
	new_card.scale = NORMAL_SCALE
	_connect_card(new_card)
	_hand_order.append(new_card)
	await get_tree().process_frame
	if not is_instance_valid(self) or not is_instance_valid(new_card):
		return
	new_card.pivot_offset = Vector2(new_card.size.x / 2.0, new_card.size.y)
	_update_hand_layout(false)

	for i in range(_hand_order.size() - 1):
		var card = _hand_order[i]
		var tween_existing := create_tween()
		tween_existing.set_parallel(true)
		tween_existing.tween_property(card, "position", _base_positions[card], 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween_existing.tween_property(card, "scale",    card.scale,            0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await _fly_ghost_card(new_card_data, deck_origin, new_card.position, new_card.scale, new_card, func(): new_card.visible = true)


func _on_card_clicked(card_data: CardData, row: String = "Front", insert_index: int = -1) -> void:
	card_played.emit(card_data, row, insert_index)


# transition_duration > 0 : à l'entrée en mulligan, étale l'animation des
# cartes vers leur position centrée sur cette durée totale (une carte après
# l'autre) plutôt que toutes en même temps (voir _update_hand_layout_staggered).
func set_mulligan_mode(active: bool, transition_duration: float = -1.0) -> void:
	_mulligan_mode = active
	# Doit rester au-dessus du MulliganDimOverlay (z_index 90 dans Battle.tscn) :
	# la main est l'élément d'interaction du mulligan, elle ne doit pas être
	# assombrie comme le reste du plateau.
	z_index = 91 if active else 0
	if active and not _hand_expanded:
		_hand_expanded = true
		if transition_duration > 0.0:
			_update_hand_layout_staggered(transition_duration)
		else:
			_update_hand_layout(true)
	for card in container.get_children():
		if card is Card:
			card.mulligan_mode = active
			if not active:
				card.set_mulligan_swapped(false)

# Variante de _update_hand_layout qui étale le déplacement/agrandissement de
# chaque carte sur total_duration au total (delay croissant par carte) au
# lieu de toutes les animer en parallèle sur LAYOUT_TWEEN_DURATION.
func _update_hand_layout_staggered(total_duration: float) -> void:
	_prune_hand_order()
	var cards := _layout_cards()
	if cards.is_empty():
		return
	var layout := _compute_layout(cards)
	var hovered_index := cards.find(_hovered_card)
	var count := cards.size()
	var gap: float = total_duration / float(count)
	var leg_duration: float = minf(gap * 1.3, 0.6)
	for i in range(count):
		var card = cards[i]
		var norm := _card_norm(i, count)
		var pos  := _card_position(i, layout, card, norm, hovered_index)
		_base_positions[card] = pos
		card.z_index = CARD_Z_BASE + i
		var delay: float = i * gap
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(card, "position", pos,             leg_duration).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "scale",    layout["scale"], leg_duration).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_sync_tree_order(hovered_index)

func set_card_mulligan_swapped(index: int, swapped: bool) -> void:
	if index < 0 or index >= _hand_order.size():
		return
	var card: Card = _hand_order[index]
	if card is Card:
		card.set_mulligan_swapped(swapped)

func _on_mulligan_card_clicked(card: Card) -> void:
	var index: int = _hand_order.find(card)
	if index != -1:
		mulligan_card_clicked.emit(index, card.data)

# Bascule le mode « sélection pour défausse » (limite 10 cartes en fin de
# tour, voir HandDiscardSystem) — même patron que set_mulligan_mode : un
# simple clic sélectionne une carte au lieu de la jouer, aucun drag possible.
func set_discard_mode(active: bool) -> void:
	_discard_mode = active
	if active and not _hand_expanded:
		_hand_expanded = true
		_update_hand_layout(true)
	for card in container.get_children():
		if card is Card:
			card.discard_mode = active
			if not active:
				card.set_discard_selected(false)

func set_card_discard_selected(index: int, selected: bool) -> void:
	if index < 0 or index >= _hand_order.size():
		return
	var card: Card = _hand_order[index]
	if card is Card:
		card.set_discard_selected(selected)

func _on_discard_card_clicked(card: Card) -> void:
	var index: int = _hand_order.find(card)
	if index != -1:
		discard_card_clicked.emit(index, card.data)

func flip_replace_at(index: int, new_data: CardData) -> void:
	if index < 0 or index >= _hand_order.size():
		return
	var card: Card = _hand_order[index]
	var target_scale_x: float = card.scale.x
	var tween := create_tween()
	tween.tween_property(card, "scale:x", 0.0, 0.12).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(func():
		card.set_data(new_data)
		if display_cost.is_valid():
			card.set_display_cost(display_cost.call(new_data))
	)
	tween.tween_property(card, "scale:x", target_scale_x, 0.12).set_trans(Tween.TRANS_LINEAR)


func _on_card_hover(card: Card) -> void:
	_hovering = true
	if is_instance_valid(_battle) and "game_over" in _battle and _battle.game_over:
		return
	if is_instance_valid(_battle) and _battle.has_method("is_dragging_card") and _battle.call("is_dragging_card"):
		return
	for c in container.get_children():
		if c is Card and c.dragging:
			return
	if card.dragging:
		return
	if _hovered_card != card:
		_hovered_card = card
		_update_hand_layout(true)
	if _mulligan_mode:
		# Pendant le mulligan, la main est déjà agrandie/centrée à l'écran : pas
		# d'aperçu zoomé par-dessus (redondant, cache la bannière) — seuls les
		# tooltips de mots-clés restent utiles, ancrés sur la carte elle-même.
		await get_tree().process_frame
		await get_tree().process_frame
		if not is_instance_valid(self) or not _hovering or card != _hovered_card \
				or not is_instance_valid(card) or card.dragging:
			return
		var card_rect := card.get_global_rect()
		var tooltip_x0: float = card_rect.position.x + card_rect.size.x + 15
		var tooltip_y0: float = card_rect.position.y
		await _show_keyword_tooltips(card, card.data, tooltip_x0, tooltip_y0)
		return
	# Aperçu agrandi de la carte, positionné juste au-dessus d'elle — en plus
	# du léger soulèvement en place (HOVER_LIFT/_card_position), pas à sa place :
	# lisible même quand la main est très resserrée (beaucoup de cartes).
	preview.set_data(card.data)
	if display_cost.is_valid():
		preview.set_display_cost(display_cost.call(card.data))
	preview.scale   = Vector2(1.1, 1.1)
	preview.z_index = 100
	# Centré horizontalement par rapport à la carte survolée : card.pivot_offset
	# est calé sur son centre horizontal (voir _set_hand_instant), donc son point
	# pivot reste au centre visuel de la carte quelle que soit son échelle —
	# contrairement à preview (pivot par défaut en haut-à-gauche), dont le centre
	# visuel décalé de la moitié de sa largeur mise à l'échelle.
	var card_center_x: float = card.global_position.x + card.pivot_offset.x
	var pos := card.global_position
	preview.global_position = Vector2(
		card_center_x - preview.size.x * preview.scale.x * 0.5,
		pos.y - preview.size.y * 1.0
	)
	preview.show()
	if not card.drag_started.is_connected(_hide_preview):
		card.drag_started.connect(_hide_preview, CONNECT_ONE_SHOT)
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(self) or not _hovering or card != _hovered_card \
			or not is_instance_valid(card) or card.dragging:
		return
	var tooltip_x: float = preview.global_position.x + preview.size.x * 1.1 + 15
	var tooltip_y: float = preview.global_position.y
	await _show_keyword_tooltips(card, card.data, tooltip_x, tooltip_y)

func _hide_preview() -> void:
	preview.hide()

## `card` : mouse_entered/mouse_exited entre deux cartes de la main adjacentes
## n'arrivent pas toujours dans un ordre garanti par Godot — un exited périmé
## (celui de l'ancienne carte survolée, arrivant après l'entered de la
## nouvelle) doit être ignoré plutôt que d'effacer à tort le survol actif.
func _on_card_unhover(card: Card) -> void:
	if card != _hovered_card:
		return
	_hovering = false
	preview.hide()
	_hide_keyword_tooltips()
	_hovered_card = null
	_update_hand_layout(true)


## `owner_card` : même garde-fou que ci-dessus, revérifié après l'await pour
## ignorer un survol qui n'est plus le survol actif au moment de la reprise.
func _show_keyword_tooltips(owner_card: Card, card_data: CardData, base_x: float, base_y: float) -> void:
	_hide_keyword_tooltips()
	if card_data == null:
		return
	if not is_instance_valid(_battle) or not _battle.is_inside_tree():
		return
	_tooltip_layer = CanvasLayer.new()
	_tooltip_layer.layer = 20
	_battle.add_child(_tooltip_layer)
	var panels: Array[Control] = TooltipData.build_panels_for_card(card_data, _tooltip_layer)
	await get_tree().process_frame
	if not is_instance_valid(self) or not _hovering or owner_card != _hovered_card \
			or not is_instance_valid(_tooltip_layer):
		return

	var vp := get_viewport_rect().size

	# Reste sur l'écran : bascule à gauche de la preview si la pile déborde à
	# droite, et remonte le point de départ si elle déborde en bas.
	var stack_height := 0.0
	for panel in panels:
		if is_instance_valid(panel):
			stack_height += panel.size.y + 6.0
	if stack_height > 0.0:
		stack_height -= 6.0
		base_y = clampf(base_y, 4.0, maxf(4.0, vp.y - stack_height - 4.0))

	var panel_width := 220.0
	if panels.size() > 0 and is_instance_valid(panels[0]):
		panel_width = panels[0].size.x
	if base_x + panel_width > vp.x - 4.0:
		base_x = maxf(4.0, preview.global_position.x - panel_width - 15)

	for panel in panels:
		if not is_instance_valid(panel):
			continue
		panel.global_position = Vector2(base_x, base_y)
		base_y += panel.size.y + 6
		_keyword_tooltips.append(panel)

func _hide_keyword_tooltips() -> void:
	for tooltip in _keyword_tooltips:
		if is_instance_valid(tooltip):
			tooltip.queue_free()
	_keyword_tooltips.clear()
	if _tooltip_layer and is_instance_valid(_tooltip_layer):
		_tooltip_layer.queue_free()
		_tooltip_layer = null


# Sous-ensemble de _hand_order utilisé pour le calcul de la disposition
# (nombre de cartes, index, espacement) : exclut la carte en cours de glisser-
# déposer, qui reste invisible dans son slot en main tant qu'on ne l'a pas
# lâchée (pour pouvoir annuler proprement le drag). Sans cette exclusion, un
# trou vide subsiste dans l'éventail pendant tout le glisser, jusqu'à ce que
# la carte soit réellement retirée de la main.
func _layout_cards() -> Array:
	return _hand_order.filter(func(c): return not c.dragging)

func _compute_layout(cards: Array) -> Dictionary:
	var count := cards.size()
	var viewport := get_viewport_rect().size
	if _mulligan_mode:
		return _compute_mulligan_layout(cards, viewport)
	var max_width          := viewport.x * 0.3
	var reduction_per_card := 0.04
	var scale_factor       :float= clamp(1.0 - (count - 1) * reduction_per_card, 0.55, 1.2)
	var spacing: float     = SPACING if not _is_compact else COMPACT_SPACING
	if count > 1 and not _is_compact:
		spacing = max(min(spacing, max_width / float(count - 1)), SPACING * 0.3)
	return {
		"scale":       Vector2(scale_factor, scale_factor),
		"spacing":     spacing,
		"hand_bottom": size.y - 30.0,
	}

# Disposition de la main pendant le mulligan : cartes agrandies, centrées à
# l'écran (horizontalement et verticalement) plutôt qu'alignées en bas.
func _compute_mulligan_layout(cards: Array, viewport: Vector2) -> Dictionary:
	var count := cards.size()
	var mscale := NORMAL_SCALE * MULLIGAN_SCALE_MULTIPLIER
	var spacing: float = SPACING * MULLIGAN_SCALE_MULTIPLIER
	var card_w: float = cards[0].size.x if count > 0 else 0.0
	var max_width: float = viewport.x * 0.85
	if count > 1:
		var natural_width: float = (count - 1) * spacing + card_w * mscale.x
		if natural_width > max_width:
			spacing = max((max_width - card_w * mscale.x) / float(count - 1), SPACING * 0.5)
	var total_width: float = (count - 1) * spacing + card_w * mscale.x if count > 0 else 0.0
	var start_x_global: float = (viewport.x - total_width) / 2.0
	var center_y_global: float = viewport.y * MULLIGAN_CENTER_Y_RATIO
	return {
		"scale":    mscale,
		"spacing":  spacing,
		"start_x":  start_x_global - global_position.x,
		"center_y": center_y_global - global_position.y,
	}

func set_compact(compact: bool) -> void:
	if _is_compact == compact:
		return
	_is_compact = compact
	_prune_hand_order()
	var cards := _layout_cards()
	if cards.is_empty():
		return
	var layout := _compute_layout(cards)
	var hovered_index := cards.find(_hovered_card)
	for i in range(cards.size()):
		var card   = cards[i]
		var norm   := _card_norm(i, cards.size())
		var pos    := _card_position(i, layout, card, norm, hovered_index)
		_base_positions[card] = pos
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(card, "position", pos, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_sync_tree_order(hovered_index)

func _update_hand_layout(animated: bool = false) -> void:
	_prune_hand_order()
	var cards := _layout_cards()
	if cards.is_empty():
		return
	var layout := _compute_layout(cards)
	var hovered_index := cards.find(_hovered_card)
	for i in range(cards.size()):
		var card = cards[i]
		var norm := _card_norm(i, cards.size())
		var pos  := _card_position(i, layout, card, norm, hovered_index)
		_base_positions[card] = pos
		card.z_index = 100 if i == hovered_index else CARD_Z_BASE + i
		card.scale   = layout["scale"]
		if animated:
			var tween := create_tween()
			tween.set_parallel(true)
			tween.tween_property(card, "position", pos,             LAYOUT_TWEEN_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(card, "scale",    layout["scale"], LAYOUT_TWEEN_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			card.position = pos
	_sync_tree_order(hovered_index)

# Une carte peut quitter la main en dehors d'un rebuild complet (ex. Card.gd
# s'auto-détruit via queue_free() une fois glissée en jeu). Sans ce
# nettoyage, _hand_order garderait une référence obsolète : soit un nœud
# libéré (tout accès à ses propriétés plante avec "previously freed"), soit un
# nœud toujours valide mais qui n'est plus un enfant du conteneur (move_child
# plante avec "Child is not a child of this node").
func _prune_hand_order() -> void:
	for i in range(_hand_order.size() - 1, -1, -1):
		var card = _hand_order[i]
		if not is_instance_valid(card) or card.get_parent() != container:
			_hand_order.remove_at(i)
	if _hovered_card != null and not is_instance_valid(_hovered_card):
		_hovered_card = null

# Réordonne les enfants du conteneur pour qu'ils suivent l'ordre logique de la
# main, puis place la carte survolée en dernier (donc au-dessus de toutes les
# autres). L'ordre des enfants pilote aussi bien le rendu que la détection de
# la souris sur les zones qui se chevauchent (contrairement au z_index seul,
# qui ne suffit pas à garantir la priorité de survol) : sans ce passage, une
# carte voisine non survolée peut rester "au-dessus" pour la souris malgré le
# z_index, et capter le survol dans la zone de chevauchement, créant une
# oscillation entre les deux cartes.
func _sync_tree_order(hovered_index: int) -> void:
	for i in range(_hand_order.size()):
		var card = _hand_order[i]
		if is_instance_valid(card) and card.get_parent() == container:
			container.move_child(card, i)
	if hovered_index != -1 and hovered_index < _hand_order.size():
		var hovered_card = _hand_order[hovered_index]
		if is_instance_valid(hovered_card) and hovered_card.get_parent() == container:
			container.move_child(hovered_card, container.get_child_count() - 1)

func _card_norm(index: int, count: int) -> float:
	var offset := float(index) - float(count - 1) / 2.0
	return offset / max(float(count - 1) / 2.0, 1.0)

func _card_position(index: int, layout: Dictionary, card: Control, norm: float, hovered_index: int = -1) -> Vector2:
	if _mulligan_mode:
		return _mulligan_card_position(index, layout, card, norm, hovered_index)
	var y: float = layout["hand_bottom"] - card.size.y + (norm * norm) * ARC_STRENGTH
	if not _hand_expanded:
		y += card.size.y * layout["scale"].y * (1.0 - COLLAPSED_PEEK_RATIO)
	var x: float = HAND_START_X + index * layout["spacing"]
	if hovered_index != -1:
		if index == hovered_index:
			y -= HOVER_LIFT
		else:
			var dist   := index - hovered_index
			var steps  := absi(dist) - 1
			var push   := HOVER_PUSH_MAX * pow(HOVER_PUSH_DECAY, steps)
			x += signf(dist) * push
	return Vector2(x, y)

func _mulligan_card_position(index: int, layout: Dictionary, card: Control, norm: float, hovered_index: int = -1) -> Vector2:
	var y: float = layout["center_y"] - card.size.y * layout["scale"].y / 2.0 + (norm * norm) * ARC_STRENGTH
	var x: float = layout["start_x"] + index * layout["spacing"]
	if hovered_index != -1:
		if index == hovered_index:
			y -= HOVER_LIFT
		else:
			var dist   := index - hovered_index
			var steps  := absi(dist) - 1
			var push   := HOVER_PUSH_MAX * pow(HOVER_PUSH_DECAY, steps)
			x += signf(dist) * push
	return Vector2(x, y)


func _relay_drag_started() -> void:
	_force_expanded = true
	_hovered_card = null
	# Referme immédiatement l'écart laissé par la carte qu'on vient de saisir :
	# elle reste en main (invisible) tant que le drag n'est pas résolu, mais ne
	# doit plus réserver sa place dans l'éventail pendant ce temps (voir
	# _layout_cards).
	_update_hand_layout(true)
	drag_started.emit()

func _relay_drag_ended(played: bool = false) -> void:
	_force_expanded = false
	if played:
		# La carte vient d'être jouée : la main se replie tout de suite, sans
		# attendre le délai normal (COLLAPSE_DELAY) ni que la souris quitte sa zone.
		_collapse_elapsed = 0.0
		_hand_expanded = false
	# Que le drag ait été annulé (la carte réintègre son slot) ou résolu (elle
	# va être libérée juste après ce signal), on refait le calcul pour que les
	# autres cartes reprennent leur place correcte dans les deux cas.
	_update_hand_layout(true)
	drag_ended.emit()

func _connect_card(card: Card) -> void:
	card.hand_ref = self

	if not card.card_clicked.is_connected(_on_card_clicked):
		card.card_clicked.connect(_on_card_clicked)
	if not card.drag_started.is_connected(_relay_drag_started):
		card.drag_started.connect(_relay_drag_started)
	if not card.drag_ended.is_connected(_relay_drag_ended):
		card.drag_ended.connect(_relay_drag_ended)
	if not card.mouse_entered.is_connected(_on_card_hover):
		card.mouse_entered.connect(_on_card_hover.bind(card))
	if not card.mouse_exited.is_connected(_on_card_unhover):
		card.mouse_exited.connect(_on_card_unhover.bind(card))
	if not card.mulligan_clicked.is_connected(_on_mulligan_card_clicked):
		card.mulligan_clicked.connect(_on_mulligan_card_clicked.bind(card))
	if not card.discard_clicked.is_connected(_on_discard_card_clicked):
		card.discard_clicked.connect(_on_discard_card_clicked.bind(card))
	card.mulligan_mode = _mulligan_mode
	card.discard_mode = _discard_mode
	for child in card.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_PASS
	if can_play_check.is_valid():
		card.can_drag_check = can_play_check
	if create_drag_preview.is_valid():
		card.create_drag_preview = create_drag_preview
	if display_cost.is_valid():
		card.set_display_cost(display_cost.call(card.data))
	card.update_playable_highlight()

func refresh_costs() -> void:
	if not display_cost.is_valid():
		return
	for card in container.get_children():
		if card is Card and card.data != null and not card.is_queued_for_deletion():
			card.set_display_cost(display_cost.call(card.data))

# À appeler chaque fois que la jouabilité des cartes en main peut changer
# (mana gagné/dépensé, ressource posée, tour qui commence...).
func refresh_playable_highlights() -> void:
	for card in container.get_children():
		if card is Card and card.data != null and not card.is_queued_for_deletion():
			card.update_playable_highlight()
