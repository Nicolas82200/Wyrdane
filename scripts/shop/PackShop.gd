extends Control
class_name PackShop

# Écran d'ouverture de packs (première itération du système de progression :
# monnaie gagnée en jouant, dépensée ici contre des cartes aléatoires
# pondérées par rareté — voir POST /api/packs/open côté wyrdane-backend).
#
# Plein écran (pas de fenêtre encadrée) : un voile assombrit tout le menu et
# le paquet, un empilement de dos de carte à gauche de l'écran (PackVisual),
# tourne sur lui-même. Chaque tour du paquet fait apparaître une carte qui
# s'envole vers une place en grille du côté droit de l'écran, à une taille
# adaptée au nombre de cartes révélées (voir Hand.gd, preview.scale, pour la
# référence de zoom "survol" quand une seule carte est révélée). Le joueur
# peut ouvrir plusieurs packs d'affilée (x1/x3/x5) : l'API backend n'ouvrant
# qu'un pack par requête, le client enchaîne les appels puis révèle toutes
# les cartes dans une seule séquence. Les tirages Épique/Légendaire ont un
# flourish renforcé (flash plein écran, son distinct) — volontairement sans
# particules ni secousse d'écran.

@export var card_scene: PackedScene

const CARD_SIZE := Vector2(250, 375)
# Taille de repos maximale d'une carte révélée quand une seule est affichée,
# alignée sur le zoom de survol utilisé dans la main (voir Hand.gd,
# _on_card_hover, preview.scale = 1.1). Réduite dynamiquement si la grille de
# révélation contient plusieurs cartes (voir _compute_grid_slots).
const HOVER_SCALE := 1.1
const GRID_MIN_SCALE := 0.55
const PACK_SCALE := 1.3
const PACK_LAYER_COUNT := 4
const PACK_LAYER_OFFSET := 6.0
const PACK_FLIP_DURATION := 0.22
const CARD_FLY_DURATION := 0.45
const FIRST_REVEAL_DELAY := 0.25
const REVEAL_STAGGER := 0.85
const RARE_RARITIES := ["Epic", "Legendary"]
const ODDS_TOOLTIP_DURATION := 4.0
const FLASH_ALPHA := {"Epic": 0.22, "Legendary": 0.42}
# Zone de révélation : partie droite de l'écran, à droite du paquet (voir
# PackCenter dans PackShop.tscn, ancré sur les ~34% gauches de l'écran).
const GRID_AREA_LEFT_RATIO := 0.34
const GRID_AREA_SIDE_MARGIN := 40.0
const GRID_AREA_TOP := 150.0
const GRID_AREA_BOTTOM := 170.0
const GRID_MAX_COLUMNS := 5
# Fraction de chaque cellule de grille effectivement occupée par la carte (le
# reste forme l'espacement entre cartes).
const GRID_CELL_PADDING := 0.86

@onready var shake_layer: Control = $ShakeLayer
@onready var title_label: Label = $ShakeLayer/TitleLabel
@onready var balance_label: Label = $ShakeLayer/InfoRow/BalanceLabel
@onready var progress_label: Label = $ShakeLayer/InfoRow/ProgressLabel
@onready var status_label: Label = $ShakeLayer/StatusLabel
@onready var close_x_button: Button = $ShakeLayer/CloseXButton
@onready var pack_stage: Control = $ShakeLayer/PackStage
@onready var pack_center: CenterContainer = $ShakeLayer/PackStage/PackCenter
@onready var free_button: Button = $ShakeLayer/FreeButtonRow/FreeButton
@onready var open_x1_button: Button = $ShakeLayer/BottomBar/OpenX1Button
@onready var open_x3_button: Button = $ShakeLayer/BottomBar/OpenX3Button
@onready var open_x5_button: Button = $ShakeLayer/BottomBar/OpenX5Button
@onready var odds_button: Button = $ShakeLayer/BottomBar/OddsButton
@onready var skip_hint_label: Label = $ShakeLayer/SkipHintLabel
@onready var flash_rect: ColorRect = $FlashRect

var _revealing: bool = false
var _skip_requested: bool = false
var _pack_visual: Control = null
var _idle_spin_tween: Tween = null
# Échelle de repos utilisée pour la révélation en cours, recalculée à chaque
# séquence selon le nombre de cartes (voir _compute_grid_slots).
var _reveal_scale: float = HOVER_SCALE

signal _pack_request_completed(code: int, cards: Array)

func _ready() -> void:
	hide()
	status_label.hide()
	skip_hint_label.hide()
	_resize_shake_layer()
	get_viewport().size_changed.connect(_resize_shake_layer)
	_pack_visual = _build_pack_visual(pack_center)
	_style_close_x_button()
	open_x1_button.pressed.connect(func(): _open_pack(false, 1))
	open_x3_button.pressed.connect(func(): _open_pack(false, 3))
	open_x5_button.pressed.connect(func(): _open_pack(false, 5))
	odds_button.pressed.connect(_on_odds_pressed)
	# Bouton d'ouverture gratuite : outil de test, réservé aux builds debug
	# (l'export release ne l'affiche pas) et refusé côté serveur (403) tant
	# que DEV_FREE_PACKS n'est pas activé sur le backend.
	free_button.get_parent().visible = OS.is_debug_build()
	free_button.pressed.connect(func(): _open_pack(true, 1))
	close_x_button.set_meta("no_click_sound", true)
	close_x_button.pressed.connect(func(): AudioManager.play(AudioManager.CLOSE_MENU); hide())
	skip_hint_label.gui_input.connect(_on_skip_input)
	CurrencyManager.balance_changed.connect(func(new_balance: int): _update_balance_label(new_balance))
	CollectionManager.collection_loaded.connect(_update_progress_label)
	SettingsManager.language_changed.connect(func(_l): _retranslate())
	_retranslate()
	_update_balance_label(CurrencyManager.balance)
	_update_progress_label()
	_start_idle_spin()

func refresh() -> void:
	CurrencyManager.sync_from_backend()
	CollectionManager.sync_from_backend()
	_clear_cards()
	status_label.hide()
	_start_idle_spin()

func _resize_shake_layer() -> void:
	if not is_instance_valid(shake_layer):
		return
	shake_layer.size = get_viewport_rect().size

## Empilement de dos de carte façon paquet fermé, décalés en diagonale.
## Ajouté à "parent" en tout premier : les layers entrent ainsi dans l'arbre
## de scène et leur _ready() (donc les @onready de Card) s'exécute avant
## qu'on appelle show_back() dessus.
func _build_pack_visual(parent: Control) -> Control:
	var stack_size: Vector2 = CARD_SIZE + Vector2(PACK_LAYER_OFFSET, PACK_LAYER_OFFSET) * (PACK_LAYER_COUNT - 1)
	var visual := Control.new()
	visual.custom_minimum_size = stack_size
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.pivot_offset = stack_size / 2.0
	visual.scale = Vector2(PACK_SCALE, PACK_SCALE)

	parent.add_child(visual)

	for i in PACK_LAYER_COUNT:
		var layer := card_scene.instantiate()
		visual.add_child(layer)
		layer.set_non_interactive()
		layer.size = CARD_SIZE
		layer.position = Vector2(i, i) * PACK_LAYER_OFFSET
		layer.show_back(true)
	return visual

## Rotation lente perpétuelle du paquet tant qu'aucune ouverture n'est en
## cours (ambiance visuelle de l'écran).
func _start_idle_spin() -> void:
	_stop_spin()
	if not is_instance_valid(_pack_visual):
		return
	_idle_spin_tween = create_tween()
	_idle_spin_tween.set_loops()
	_idle_spin_tween.tween_property(_pack_visual, "scale:x", 0.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_spin_tween.tween_property(_pack_visual, "scale:x", PACK_SCALE, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_spin() -> void:
	if _idle_spin_tween and _idle_spin_tween.is_valid():
		_idle_spin_tween.kill()
	_idle_spin_tween = null
	if is_instance_valid(_pack_visual):
		_pack_visual.scale = Vector2(PACK_SCALE, PACK_SCALE)

func _set_action_buttons_disabled(disabled: bool) -> void:
	open_x1_button.disabled = disabled
	open_x3_button.disabled = disabled
	open_x5_button.disabled = disabled
	free_button.disabled = disabled

## Ouvre `quantity` packs d'affilée (l'API backend n'en ouvre qu'un par
## requête) puis révèle toutes les cartes tirées dans une seule séquence. Si
## un appel échoue en cours de route (solde épuisé après les premiers packs
## payés, par ex.), les cartes déjà obtenues sont tout de même révélées.
func _open_pack(free: bool, quantity: int) -> void:
	_set_action_buttons_disabled(true)
	status_label.hide()

	var all_cards: Array = []
	var last_code := 200
	for i in quantity:
		var result: Dictionary = await _request_single_pack(free)
		if not is_instance_valid(self):
			return
		last_code = result["code"]
		var cards: Array = result["cards"]
		if last_code != 200 or cards.is_empty():
			break
		all_cards.append_array(cards)

	_on_packs_opened(last_code, all_cards)

func _request_single_pack(free: bool) -> Dictionary:
	CurrencyManager.open_pack(func(code: int, cards: Array): _pack_request_completed.emit(code, cards), free)
	var result: Array = await _pack_request_completed
	return {"code": result[0], "cards": result[1]}

func _on_packs_opened(code: int, cards: Array) -> void:
	_clear_cards()

	if cards.is_empty():
		_set_action_buttons_disabled(false)
		status_label.text = SettingsManager.t("pack_shop.error")
		status_label.show()
		_start_idle_spin()
		return

	# Les cartes tirées viennent d'être octroyées côté serveur (grantCard) :
	# resynchronise la collection pour qu'elles soient utilisables tout de
	# suite dans le deckbuilder sans attendre le prochain redémarrage.
	CollectionManager.sync_from_backend()

	var entries: Array = []
	for card_row in cards:
		var card_data: CardData = CardLibrary.card_by_backend_id.get(card_row.get("id"), null)
		if card_data == null:
			continue
		entries.append({
			"data": card_data,
			"dusted": card_row.get("dusted", false),
			"gold": int(card_row.get("goldEarned", 0)),
		})

	if code != 200:
		status_label.text = SettingsManager.t("pack_shop.error")
		status_label.show()

	_reveal_sequence(entries)

## Calcule une grille de positions (côté droit de l'écran, à droite du
## paquet) pour `count` cartes, ainsi que l'échelle de repos à leur appliquer
## pour qu'elles restent toutes visibles sans déborder du cadre.
func _compute_grid_slots(count: int) -> Dictionary:
	var viewport_size: Vector2 = get_viewport_rect().size
	var area_left: float = viewport_size.x * GRID_AREA_LEFT_RATIO + GRID_AREA_SIDE_MARGIN
	var area_right: float = viewport_size.x - GRID_AREA_SIDE_MARGIN
	var area_top: float = GRID_AREA_TOP
	var area_bottom: float = viewport_size.y - GRID_AREA_BOTTOM
	var area_size := Vector2(max(area_right - area_left, 1.0), max(area_bottom - area_top, 1.0))

	var columns: int = clamp(count, 1, GRID_MAX_COLUMNS)
	var rows: int = int(ceil(float(count) / columns))
	var cell_size := Vector2(area_size.x / columns, area_size.y / rows)

	var scale_x: float = cell_size.x * GRID_CELL_PADDING / CARD_SIZE.x
	var scale_y: float = cell_size.y * GRID_CELL_PADDING / CARD_SIZE.y
	var reveal_scale: float = clamp(min(scale_x, scale_y, HOVER_SCALE), GRID_MIN_SCALE, HOVER_SCALE)

	var cols_in_last_row: int = count - (rows - 1) * columns
	var slots: Array = []
	for i in count:
		var row: int = i / columns
		var cols_in_row: int = columns if row < rows - 1 else cols_in_last_row
		var row_left: float = area_left + (area_size.x - cols_in_row * cell_size.x) / 2.0
		var col: int = i % columns
		slots.append(Vector2(
			row_left + (col + 0.5) * cell_size.x,
			area_top + (row + 0.5) * cell_size.y
		))

	return {"slots": slots, "scale": reveal_scale}

## Révèle les cartes tirées une par une : à chaque tour du paquet, une carte
## en jaillit et vole vers sa place en grille à droite en se retournant.
## Cliquer sur l'indice "passer" affiché pendant la séquence saute directement
## le reste des cartes sans animation.
func _reveal_sequence(entries: Array) -> void:
	_revealing = true
	_skip_requested = false
	skip_hint_label.show()
	_stop_spin()

	var grid: Dictionary = _compute_grid_slots(entries.size())
	var slots: Array = grid["slots"]
	_reveal_scale = grid["scale"]

	for i in range(entries.size()):
		var skip_now := _skip_requested
		if not skip_now:
			var delay := FIRST_REVEAL_DELAY if i == 0 else REVEAL_STAGGER
			await get_tree().create_timer(delay).timeout
			skip_now = _skip_requested
		if not is_instance_valid(self):
			return
		await _reveal_one(entries[i], slots[i], skip_now)
		if not is_instance_valid(self):
			return

	skip_hint_label.hide()
	_revealing = false
	_set_action_buttons_disabled(false)
	_update_progress_label()
	_start_idle_spin()

func _on_skip_input(event: InputEvent) -> void:
	if _revealing and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_skip_requested = true

## Cycle complet d'une carte : tour du paquet, puis envol+retournement vers sa
## place. En mode "skip", la carte apparaît directement à sa place sans
## animation.
func _reveal_one(entry: Dictionary, slot_pos: Vector2, skip: bool) -> void:
	if skip:
		_place_card_instant(entry, slot_pos)
		return

	await _pulse_pack_flip()
	if not is_instance_valid(self):
		return

	var card_instance := _spawn_pack_card()
	await _fly_and_reveal(card_instance, entry, slot_pos)

## Un tour complet du paquet (dos toujours visible), accompagné du son de
## mélange — le geste qui "fait sortir" la prochaine carte.
func _pulse_pack_flip() -> void:
	if not is_instance_valid(_pack_visual):
		return
	AudioManager.play(AudioManager.SHUFFLE)
	var tween := create_tween()
	tween.tween_property(_pack_visual, "scale:x", 0.0, PACK_FLIP_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(_pack_visual, "scale:x", PACK_SCALE, PACK_FLIP_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished

## Carte face cachée qui apparaît au centre du paquet, prête à s'envoler.
func _spawn_pack_card() -> Control:
	var card_instance := card_scene.instantiate()
	pack_stage.add_child(card_instance)
	card_instance.set_non_interactive()
	card_instance.size = CARD_SIZE
	card_instance.pivot_offset = CARD_SIZE / 2.0
	card_instance.scale = Vector2(PACK_SCALE, PACK_SCALE)
	card_instance.show_back(true)
	var center: Vector2 = _pack_visual.get_global_rect().get_center()
	card_instance.global_position = center - CARD_SIZE / 2.0
	return card_instance

## Envol vers la place assignée en grille, avec un flip (façon pièce qui
## tourne) au passage qui révèle la carte à mi-chemin.
func _fly_and_reveal(card_instance: Control, entry: Dictionary, slot_pos: Vector2) -> void:
	var card_data: CardData = entry["data"]
	var target_position: Vector2 = slot_pos - CARD_SIZE / 2.0

	var move_tween := create_tween()
	move_tween.tween_property(card_instance, "global_position", target_position, CARD_FLY_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	move_tween.parallel().tween_property(card_instance, "scale:y", _reveal_scale, CARD_FLY_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var flip_tween := create_tween()
	flip_tween.tween_property(card_instance, "scale:x", 0.0, CARD_FLY_DURATION * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	flip_tween.tween_callback(func():
		if not is_instance_valid(card_instance):
			return
		card_instance.show_back(false)
		card_instance.set_data(card_data)
		card_instance.set_non_interactive()
		card_instance.pivot_offset = CARD_SIZE / 2.0
		if entry["dusted"]:
			_add_dust_badge(card_instance, entry["gold"])
		AudioManager.play(AudioManager.DRAW)
	)
	flip_tween.tween_property(card_instance, "scale:x", _reveal_scale, CARD_FLY_DURATION * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await move_tween.finished
	if not is_instance_valid(self) or not is_instance_valid(card_instance):
		return

	if RARE_RARITIES.has(card_data.rarity):
		await _play_rare_flourish(card_instance, entry)

## Flourish de tirage rare : flash plein écran et son distinct, plus marqués
## sur Légendaire que sur Épique. Volontairement discret (pas de particules ni
## de secousse d'écran).
func _play_rare_flourish(card_instance: Control, entry: Dictionary) -> void:
	if not is_instance_valid(card_instance):
		return
	var card_data: CardData = entry["data"]
	var rarity: String = card_data.rarity
	var legendary: bool = rarity == "Legendary"
	var glow_color: Color = Card.RARITY_COLORS.get(rarity, Color.WHITE)

	if legendary:
		AudioManager.play_with_pitch(AudioManager.CONFIRM, 0.85, 0.95)
	else:
		AudioManager.play_with_pitch(AudioManager.CONFIRM, 0.98, 1.08)
	if legendary:
		await get_tree().create_timer(0.12).timeout
		if is_instance_valid(card_instance):
			AudioManager.play_with_pitch(AudioManager.CONFIRM, 1.05, 1.15)

	_flash_screen(glow_color, FLASH_ALPHA.get(rarity, 0.2))

	var final_modulate: Color = Color(0.6, 0.6, 0.6, 1) if entry["dusted"] else Color.WHITE
	card_instance.modulate = Color(glow_color.r * 1.6, glow_color.g * 1.6, glow_color.b * 1.6, 1.0)

	var flourish := create_tween()
	flourish.tween_property(card_instance, "scale", Vector2(_reveal_scale, _reveal_scale) * 1.18, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flourish.parallel().tween_property(card_instance, "modulate", final_modulate, 0.4)
	flourish.tween_property(card_instance, "scale", Vector2(_reveal_scale, _reveal_scale), 0.14).set_trans(Tween.TRANS_LINEAR)
	await flourish.finished

## Flash coloré plein écran (teinte de la rareté), léger et bref.
func _flash_screen(color: Color, peak_alpha: float) -> void:
	if not is_instance_valid(flash_rect):
		return
	flash_rect.color = Color(color.r, color.g, color.b, 0.0)
	var tween := create_tween()
	tween.tween_property(flash_rect, "color:a", peak_alpha, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash_rect, "color:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## Miniature statique placée directement à sa place en grille, sans
## animation (mode "passer").
func _place_card_instant(entry: Dictionary, slot_pos: Vector2) -> void:
	var card_data: CardData = entry["data"]
	var card_instance := card_scene.instantiate()
	pack_stage.add_child(card_instance)
	card_instance.set_non_interactive()
	card_instance.size = CARD_SIZE
	card_instance.pivot_offset = CARD_SIZE / 2.0
	card_instance.scale = Vector2(_reveal_scale, _reveal_scale)
	card_instance.global_position = slot_pos - CARD_SIZE / 2.0
	card_instance.show_back(false)
	card_instance.set_data(card_data)
	if entry["dusted"]:
		_add_dust_badge(card_instance, entry["gold"])

## Petit panneau flottant listant les probabilités de tirage par rareté
## (miroir client de RARITY_WEIGHTS côté backend, purement indicatif).
func _on_odds_pressed() -> void:
	var weights: Dictionary = CurrencyManager.RARITY_WEIGHTS_DISPLAY
	var total := 0
	for w in weights.values():
		total += w

	var lines: PackedStringArray = []
	for rarity in ["Common", "Rare", "Epic", "Legendary"]:
		var percent: float = 100.0 * float(weights.get(rarity, 0)) / total
		lines.append("%s : %.0f%%" % [SettingsManager.t("rarity.%s" % rarity.to_lower()), percent])

	var panel := TooltipData.make_tooltip_panel(SettingsManager.t("pack_shop.odds_title"), "\n".join(lines))
	panel.position = Vector2(-9999, -9999)
	add_child(panel)
	await get_tree().process_frame
	if not is_instance_valid(panel) or not is_instance_valid(odds_button):
		return
	panel.global_position = odds_button.global_position + Vector2((odds_button.size.x - panel.size.x) / 2.0, odds_button.size.y + 6.0)
	await get_tree().create_timer(ODDS_TOOLTIP_DURATION).timeout
	if is_instance_valid(panel):
		panel.queue_free()

## Badge affiché sur les cartes en double (déjà à MAX_COPIES) : le pack a
## converti cet exemplaire en or plutôt que de l'ajouter à la collection
## (voir packModel.openPack côté wyrdane-backend).
func _add_dust_badge(card_instance: Control, gold_earned: int) -> void:
	card_instance.modulate = Color(0.6, 0.6, 0.6, 1)

	var badge_bg := StyleBoxFlat.new()
	badge_bg.bg_color = Color(0.05, 0.04, 0.02, 0.9)
	badge_bg.set_corner_radius_all(4)
	badge_bg.content_margin_left   = 6
	badge_bg.content_margin_right  = 6
	badge_bg.content_margin_top    = 2
	badge_bg.content_margin_bottom = 2

	var badge_panel := PanelContainer.new()
	badge_panel.add_theme_stylebox_override("panel", badge_bg)
	badge_panel.anchor_left   = 0.0
	badge_panel.anchor_right  = 1.0
	badge_panel.anchor_top    = 1.0
	badge_panel.anchor_bottom = 1.0
	badge_panel.offset_top    = -30
	badge_panel.offset_bottom = -6
	badge_panel.mouse_filter  = Control.MOUSE_FILTER_IGNORE

	var badge_label := Label.new()
	badge_label.text = SettingsManager.t("pack_shop.dust_format") % gold_earned
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.add_theme_font_size_override("font_size", 13)
	badge_label.add_theme_color_override("font_color", Color(0.98, 0.85, 0.40, 1))
	badge_panel.add_child(badge_label)

	card_instance.add_child(badge_panel)

func _clear_cards() -> void:
	for child in pack_stage.get_children():
		if child == pack_center:
			continue
		child.queue_free()

func _update_balance_label(new_balance: int) -> void:
	balance_label.text = SettingsManager.t("pack_shop.balance") % new_balance

## Teaser de complétion de collection : cartes obtenues (>=1 exemplaire) sur
## le total de cartes collectionnables (exclut les cartes-ressource, jamais
## octroyées par un pack — voir packModel.fetchDrawablePool côté backend).
func _update_progress_label() -> void:
	var total := 0
	var owned := 0
	for card_data: CardData in CardLibrary.all_cards:
		if card_data.card_type == "Resource":
			continue
		total += 1
		if CollectionManager.is_owned(card_data):
			owned += 1
	progress_label.text = SettingsManager.t("pack_shop.progress") % [owned, total]

func _style_close_x_button() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.set_corner_radius_all(6)
	close_x_button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("8b1a1a55")
	close_x_button.add_theme_stylebox_override("hover", hover)

func _retranslate() -> void:
	title_label.text = SettingsManager.t("pack_shop.title")
	open_x1_button.text = SettingsManager.t("pack_shop.open_x1") % (CurrencyManager.PACK_COST * 1)
	open_x3_button.text = SettingsManager.t("pack_shop.open_x3") % (CurrencyManager.PACK_COST * 3)
	open_x5_button.text = SettingsManager.t("pack_shop.open_x5") % (CurrencyManager.PACK_COST * 5)
	odds_button.text = SettingsManager.t("pack_shop.odds_button")
	free_button.text = SettingsManager.t("pack_shop.open_free_button")
	close_x_button.tooltip_text = SettingsManager.t("pack_shop.close")
	skip_hint_label.text = SettingsManager.t("pack_shop.skip_hint")
	status_label.text = SettingsManager.t("pack_shop.error")
	_update_balance_label(CurrencyManager.balance)
	_update_progress_label()
