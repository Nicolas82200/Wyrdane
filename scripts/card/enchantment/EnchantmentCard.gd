extends Control

# Visuel d'une carte Enchantement, Rituel ou Ressource posée dans sa zone.
# Affiche le card art comme les unités sur le board ; au survol, la carte
# originale apparaît en aperçu à gauche, ou à droite si la zone est trop
# proche du bord de l'écran, avec les tooltips de mots-clés — même
# comportement que BoardMinion.
# Les Rituels de Sacrifice du joueur sont cliquables : le clic demande leur
# activation (choix des victimes via SacrificeSystem).

signal activate_requested(card_data: CardData, is_player: bool)

const ACTIVATABLE_TINT := Color(1.25, 1.15, 0.75)
const CARD_SCENE = preload("res://scenes/card/Card.tscn")
const PREVIEW_SCALE := Card.HOVER_ZOOM_SCALE

var card_data: CardData
var is_player: bool

var _hover_preview: Card = null
var _tooltip_layer: CanvasLayer = null
var _keyword_tooltips: Array[Control] = []
var _mouse_is_over: bool = false
var _battle: Node = null
# Bulle "Clic droit pour agrandir/afficher/cacher les informations" — voir
# TooltipData.battle_hover_mode.
var _hint_panel: PanelContainer = null

# Aperçus des jetons invoqués par ce Rituel/Enchantement (ex: Cercle
# d'Invocation), voir CardData.get_summon_preview_cards et
# Hand._show_summon_previews (même principe).
var _token_previews:      Array[Card]              = []
var _token_preview_links: Array[PreviewLinkOverlay] = []
const TOKEN_PREVIEW_SCALE_RATIO := 0.75

func _ready() -> void:
	_battle = get_tree().current_scene
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	tree_exiting.connect(_cleanup_hover)

func setup(new_data: CardData, new_is_player: bool) -> void:
	card_data = new_data
	is_player = new_is_player
	if card_data.texture:
		$Art.texture = card_data.texture
	$CostBadge.text = str(card_data.cost)
	$TurnsLabel.visible = false

# Compteur de charges restantes (Rituels à durée limitée uniquement)
func set_turns_left(turns: int) -> void:
	$TurnsLabel.visible = turns > 0
	if turns > 0:
		var fmt: String = SettingsManager.t("enchant.charges_many") if turns > 1 else SettingsManager.t("enchant.charges_one")
		$TurnsLabel.text = fmt % turns

# Surbrillance dorée quand le rituel est activable (Sacrifice disponible)
func set_activatable(on: bool) -> void:
	modulate = ACTIVATABLE_TINT if on else Color.WHITE

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			activate_requested.emit(card_data, is_player)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_on_right_click()

# ─── Hover & Preview ──────────────────────────────────────────────────────────
# Même aperçu que BoardMinion. Les zones enchantements/rituels/ressources ne
# sont pas toutes du même côté du board (ex: zone de ressource du joueur à
# gauche) : l'aperçu apparaît à gauche s'il tient à l'écran, sinon à droite.

func _on_mouse_entered() -> void:
	_mouse_is_over = true
	if card_data == null or _battle == null:
		return
	if "game_over" in _battle and _battle.game_over:
		return
	if _battle.has_method("is_dragging_card") and _battle.call("is_dragging_card"):
		return
	# Plus d'aperçu agrandi automatique au survol (demande utilisateur
	# 2026-09-25) : par défaut, seule la bulle d'indication apparaît, ancrée
	# au-dessus de cette petite carte — voir TooltipData.battle_hover_mode.
	if not TooltipData.battle_shows_zoom():
		_show_hint_panel(global_position.x + size.x * 0.5, global_position.y)
		return
	await _create_and_show_zoom()

## Instancie et positionne l'aperçu agrandi (voir _on_mouse_entered/
## _toggle_and_refresh_tooltips, qui appelle aussi ceci quand le zoom vient
## d'être activé par un clic droit pendant que la souris est déjà dessus).
func _create_and_show_zoom() -> void:
	if _hover_preview != null:
		return
	if CARD_SCENE == null or not CARD_SCENE.can_instantiate():
		push_error("EnchantmentCard: CARD_SCENE is invalid")
		return
	_hover_preview = CARD_SCENE.instantiate()
	if _hover_preview == null:
		push_error("EnchantmentCard: instantiate() returned null")
		return
	_hover_preview.drag_enabled = false
	# PASS : le joueur visant naturellement la grande carte plutôt que la
	# petite carte d'origine derrière elle, le clic droit dessus doit aussi
	# basculer les tooltips (voir TooltipData.tooltips_expanded).
	_hover_preview.mouse_filter = Control.MOUSE_FILTER_PASS
	_hover_preview.gui_input.connect(_on_preview_right_click)
	_hover_preview.z_index = 1000
	_hover_preview.visible = false
	_battle.add_child(_hover_preview)
	_hover_preview.set_data(card_data)
	_hover_preview.scale = Vector2(PREVIEW_SCALE, PREVIEW_SCALE)
	await get_tree().process_frame

	# Évite les états invalides si la souris sort pendant l'await
	if not _mouse_is_over or not is_instance_valid(_hover_preview):
		_cleanup_hover()
		return

	var preview_width := _hover_preview.size.x * PREVIEW_SCALE
	var show_left := global_position.x - preview_width - 15 >= 0.0
	var preview_x := global_position.x - preview_width - 15 if show_left else global_position.x + size.x + 15
	_hover_preview.global_position = Vector2(
		preview_x,
		global_position.y + (size.y - _hover_preview.size.y * PREVIEW_SCALE) / 2.0
	)
	_hover_preview.visible = true
	_refresh_hover_extras(show_left)

## Affiche l'aperçu de jetons invoqués (comme avant, systématique dès que
## l'aperçu agrandi est visible) et repositionne la bulle d'indication ; selon
## TooltipData.battle_shows_info(), affiche ou cache les tooltips détaillés.
func _refresh_hover_extras(show_left: bool) -> void:
	if not is_instance_valid(_hover_preview) or not _hover_preview.visible:
		return
	_show_summon_previews(card_data)

	var preview_width := _hover_preview.size.x * PREVIEW_SCALE
	var hint_center_x := _hover_preview.global_position.x + preview_width * 0.5
	_show_hint_panel(hint_center_x, _hover_preview.global_position.y)

	# Tooltips du côté opposé à l'aperçu par rapport à la carte survolée
	var tooltip_x := _hover_preview.global_position.x - 15 if show_left \
		else _hover_preview.global_position.x + preview_width + 15
	var tooltip_y := _hover_preview.global_position.y
	if TooltipData.battle_shows_info():
		await _show_keyword_tooltips(tooltip_x, tooltip_y, show_left)
	else:
		_hide_keyword_tooltips()

func _on_mouse_exited() -> void:
	_mouse_is_over = false
	_cleanup_hover()

func _cleanup_hover() -> void:
	_hide_keyword_tooltips()
	_hide_hint_panel()
	_clear_summon_previews()
	if _hover_preview and is_instance_valid(_hover_preview):
		_hover_preview.queue_free()
	_hover_preview = null

## Fait avancer TooltipData.battle_hover_mode d'un cran (HIDDEN -> ZOOM ->
## ZOOM_AND_INFO -> HIDDEN) pour toute la session et rafraîchit l'affichage
## courant si cette carte est actuellement survolée. Déclenchée par un clic
## droit sur cette carte elle-même (petite carte d'origine).
func _on_right_click() -> void:
	_toggle_and_refresh_tooltips()

## Même bascule, depuis un clic droit sur la grande preview (voir
## _on_mouse_entered, _hover_preview.mouse_filter = PASS) — le joueur visant
## naturellement la carte agrandie plutôt que la petite carte derrière elle.
func _on_preview_right_click(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT
			and event.pressed):
		return
	accept_event()
	_toggle_and_refresh_tooltips()

## Même bascule depuis un clic droit sur un aperçu de jeton invoqué (voir
## _show_summon_previews) — ces cartes n'ont pas leur propre pile de tooltips,
## seule celle de cette carte compte, donc même rafraîchissement.
func _on_token_preview_right_click(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT
			and event.pressed):
		return
	accept_event()
	_toggle_and_refresh_tooltips()

func _toggle_and_refresh_tooltips() -> void:
	TooltipData.cycle_battle_hover_mode()
	if not _mouse_is_over:
		return
	if not TooltipData.battle_shows_zoom():
		_cleanup_hover()
		_show_hint_panel(global_position.x + size.x * 0.5, global_position.y)
		return
	if not is_instance_valid(_hover_preview):
		# Le zoom vient d'être activé alors qu'aucun aperçu n'existait encore
		# (état HIDDEN) : (re)joue la création comme un survol normal.
		await _create_and_show_zoom()
		return
	var preview_width := _hover_preview.size.x * PREVIEW_SCALE
	var show_left := global_position.x - preview_width - 15 >= 0.0
	_refresh_hover_extras(show_left)

## Voir Hand._show_summon_previews (même principe) : un aperçu supplémentaire
## par jeton fixe invoqué par ce Rituel/Enchantement, à côté de
## _hover_preview, relié par un PreviewLinkOverlay dédié. Placés à GAUCHE de
## _hover_preview s'il y a la place, sinon à DROITE.
func _show_summon_previews(data: CardData) -> void:
	_clear_summon_previews()
	if data == null or not is_instance_valid(_hover_preview) or not is_instance_valid(_battle):
		return
	var tokens := data.get_summon_preview_cards()
	if tokens.is_empty():
		return
	var token_scale := Vector2(PREVIEW_SCALE, PREVIEW_SCALE) * TOKEN_PREVIEW_SCALE_RATIO
	const TOKEN_SPACING := 18.0
	const SIDE_MARGIN := 20.0

	var new_tokens: Array[Card] = []
	for token_data in tokens:
		var token_card: Card = CARD_SCENE.instantiate()
		if token_card == null:
			continue
		_battle.add_child(token_card)
		token_card.set_non_interactive()
		# PASS (pas IGNORE) : voir _hover_preview.mouse_filter ci-dessus, même
		# raison — le clic droit sur un jeton invoqué doit aussi basculer les
		# tooltips.
		token_card.mouse_filter = Control.MOUSE_FILTER_PASS
		token_card.gui_input.connect(_on_token_preview_right_click)
		token_card.z_index = 1000
		token_card.set_data(token_data)
		token_card.scale = token_scale
		new_tokens.append(token_card)
	if new_tokens.is_empty():
		return

	var token_width: float = new_tokens[0].size.x * token_scale.x
	var strip_width: float = float(new_tokens.size()) * token_width \
		+ float(new_tokens.size() - 1) * TOKEN_SPACING
	var preview_left: float = _hover_preview.global_position.x
	var preview_right: float = preview_left + _hover_preview.size.x * PREVIEW_SCALE
	var space_left: float = preview_left - SIDE_MARGIN
	var place_left: bool = space_left >= strip_width

	var base_y: float = _hover_preview.global_position.y \
		+ _hover_preview.size.y * PREVIEW_SCALE * 0.5
	var start_x: float = preview_left - SIDE_MARGIN - strip_width if place_left \
		else preview_right + SIDE_MARGIN
	var link_from: Vector2 = _hover_preview.global_position + Vector2(
		0.0 if place_left else _hover_preview.size.x * PREVIEW_SCALE,
		_hover_preview.size.y * PREVIEW_SCALE * 0.5
	)

	for i in range(new_tokens.size()):
		var token_card: Card = new_tokens[i]
		var token_x: float = start_x + float(i) * (token_width + TOKEN_SPACING)
		token_card.global_position = Vector2(token_x, base_y - token_card.size.y * token_scale.y * 0.5)
		token_card.visible = true
		_token_previews.append(token_card)

		var link := PreviewLinkOverlay.new()
		link.z_index = 999
		_battle.add_child(link)
		var link_to: Vector2 = token_card.global_position + Vector2(
			token_width if place_left else 0.0,
			token_card.size.y * token_scale.y * 0.5
		)
		link.show_link(link_from, link_to)
		_token_preview_links.append(link)

func _clear_summon_previews() -> void:
	for token_card in _token_previews:
		if is_instance_valid(token_card):
			token_card.visible = false
			token_card.queue_free()
	_token_previews.clear()
	for link in _token_preview_links:
		if is_instance_valid(link):
			link.queue_free()
	_token_preview_links.clear()

# ─── Tooltips — délégués à TooltipData ───────────────────────────────────────
# anchor_x est le bord DROIT des panneaux (align_right = true, ils s'empilent
# vers la gauche) ou leur bord GAUCHE (align_right = false, ils s'empilent
# vers la droite) — toujours du côté opposé à l'aperçu pour ne pas le recouvrir.

func _show_keyword_tooltips(anchor_x: float, base_y: float, align_right: bool) -> void:
	_hide_keyword_tooltips()
	if card_data == null:
		return
	_tooltip_layer = CanvasLayer.new()
	_tooltip_layer.layer = 20
	_battle.add_child(_tooltip_layer)
	# Capturé localement : `_tooltip_layer` (membre partagé) peut avoir été
	# réassigné par un survol plus récent d'ici la reprise des await ci-dessous
	# (sortie/re-entrée rapide sur cette même carte) — comparer à `my_layer`
	# plutôt qu'au membre courant évite d'agir sur/pour une session périmée.
	var my_layer := _tooltip_layer

	var panels: Array[Control] = TooltipData.build_panels_for_card(card_data, my_layer)
	await get_tree().process_frame

	if not _mouse_is_over or _tooltip_layer != my_layer:
		_hide_keyword_tooltips()
		return

	# Remonte le point de départ si la pile déborde en bas de l'écran, pour
	# qu'elle reste entièrement visible plutôt que de couler hors du cadre.
	var vp := get_viewport_rect().size
	var stack_height := 0.0
	for panel in panels:
		if is_instance_valid(panel):
			stack_height += panel.size.y + 6.0
	if stack_height > 0.0:
		stack_height -= 6.0
		base_y = clampf(base_y, 4.0, maxf(4.0, vp.y - stack_height - 4.0))

	var y := base_y
	for panel in panels:
		if not is_instance_valid(panel):
			continue
		var panel_x := anchor_x - panel.size.x if align_right else anchor_x
		panel_x = clampf(panel_x, 4.0, vp.x - panel.size.x - 4.0)
		panel.global_position = Vector2(panel_x, y)
		y += panel.size.y + 6
		_keyword_tooltips.append(panel)

	if TooltipData.RACE_DESCRIPTIONS.has(card_data.race):
		if _tooltip_layer != my_layer or not is_instance_valid(my_layer):
			return
		var race_panel := TooltipData.make_race_tooltip(TooltipData.RACE_DESCRIPTIONS[card_data.race])
		race_panel.position = Vector2(-9999, -9999)
		my_layer.add_child(race_panel)
		await get_tree().process_frame
		if _tooltip_layer == my_layer and _mouse_is_over \
				and is_instance_valid(race_panel) and is_instance_valid(_hover_preview):
			var preview_bottom  := _hover_preview.global_position.y + _hover_preview.size.y * PREVIEW_SCALE
			var preview_center_x := _hover_preview.global_position.x + (_hover_preview.size.x * PREVIEW_SCALE) / 2.0
			var rx: float = clampf(
				preview_center_x - race_panel.size.x / 2.0, 4.0, vp.x - race_panel.size.x - 4.0)
			var ry := preview_bottom + 6
			if ry + race_panel.size.y > vp.y - 4.0:
				ry = _hover_preview.global_position.y - race_panel.size.y - 6
			race_panel.global_position = Vector2(rx, ry)
			_keyword_tooltips.append(race_panel)

func _hide_keyword_tooltips() -> void:
	for tooltip in _keyword_tooltips:
		if is_instance_valid(tooltip):
			tooltip.queue_free()
	_keyword_tooltips.clear()
	if _tooltip_layer and is_instance_valid(_tooltip_layer):
		_tooltip_layer.queue_free()
		_tooltip_layer = null

## `center_x`/`above_y` : voir Hand._show_hint_panel (même principe).
func _show_hint_panel(center_x: float, above_y: float) -> void:
	_hide_hint_panel()
	if not is_instance_valid(_battle):
		return
	_hint_panel = TooltipData.make_battle_hint_panel()
	_hint_panel.z_index = 1000
	_battle.add_child(_hint_panel)
	await get_tree().process_frame
	if not _mouse_is_over or not is_instance_valid(_hint_panel):
		return
	_hint_panel.global_position = Vector2(
		center_x - _hint_panel.size.x * 0.5, above_y - _hint_panel.size.y - 6)

func _hide_hint_panel() -> void:
	if _hint_panel and is_instance_valid(_hint_panel):
		_hint_panel.queue_free()
	_hint_panel = null
