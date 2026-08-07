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
const PREVIEW_SCALE := 0.9

var card_data: CardData
var is_player: bool

var _hover_preview: Card = null
var _tooltip_layer: CanvasLayer = null
var _keyword_tooltips: Array[Control] = []
var _mouse_is_over: bool = false
var _battle: Node = null

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
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		activate_requested.emit(card_data, is_player)
		accept_event()

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

	# Tooltips du côté opposé à l'aperçu par rapport à la carte survolée
	var tooltip_x := _hover_preview.global_position.x - 15 if show_left \
		else _hover_preview.global_position.x + preview_width + 15
	var tooltip_y := _hover_preview.global_position.y
	await _show_keyword_tooltips(tooltip_x, tooltip_y, show_left)

func _on_mouse_exited() -> void:
	_mouse_is_over = false
	_cleanup_hover()

func _cleanup_hover() -> void:
	_hide_keyword_tooltips()
	if _hover_preview and is_instance_valid(_hover_preview):
		_hover_preview.queue_free()
	_hover_preview = null

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

	var panels: Array[Control] = TooltipData.build_panels_for_card(card_data, _tooltip_layer)
	await get_tree().process_frame

	if not _mouse_is_over:
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
		if not is_instance_valid(_tooltip_layer):
			return
		var race_panel := TooltipData.make_race_tooltip(TooltipData.RACE_DESCRIPTIONS[card_data.race])
		race_panel.position = Vector2(-9999, -9999)
		_tooltip_layer.add_child(race_panel)
		await get_tree().process_frame
		if is_instance_valid(race_panel) and is_instance_valid(_hover_preview):
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
