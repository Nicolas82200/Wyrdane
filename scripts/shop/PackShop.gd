extends Control
class_name PackShop

# Moteur de révélation des packs, embarqué en overlay transparent par-dessus
# CollectionContentRoot (voir MainMenu.gd) — ne dessine plus d'écran séparé
# (pas de fond assombri, pas de titre, pas de croix de fermeture) : les
# cartes révélées apparaissent directement autour du VRAI pack affiché dans
# la vue Collection (voir ShopCollectionPanel.gd), qui transmet ce nœud comme
# `anchor` à open_owned(). Porte aussi les éléments permanents du panneau qui
# doivent rester indépendants du flux/scroll de ShopCollectionPanel : l'indice
# Ctrl+clic/Maj+clic en bas à droite (CornerHintLabel) et le bouton "Acheter
# des packs" ancré tout en bas du panneau (BuyPacksButton, voir
# buy_packs_pressed plus bas — MainMenu s'y connecte comme à `closed`).

signal closed
signal buy_packs_pressed

@export var card_scene: PackedScene

# Taille native de Card.tscn (voir DeckBuilder.CARD_BASE_SIZE) : ses éléments
# internes (Art notamment) ont une custom_minimum_size figée à cette valeur,
# donc TOUJOURS instancier une carte à cette taille et la redimensionner via
# `scale` — jamais via `.size`, qui se ferait remonter (clampé) à ce minimum
# et afficherait la carte bien plus grande que prévu.
const CARD_NATIVE_SIZE := Vector2(250, 375)
const SLOT_GAP := 24.0
const CARD_FLY_DURATION := 0.4
const FIRST_REVEAL_DELAY := 0.15
const REVEAL_STAGGER := 0.45
const RARE_RARITIES := ["Epic", "Legendary"]
const FLASH_ALPHA := {"Epic": 0.22, "Legendary": 0.42}
# Agrandissement au survol : preview flottante à côté de la carte survolée
# (même principe que DeckBuilder.card_preview), à la taille native x ce
# facteur — cohérent avec DeckBuilder.PREVIEW_SCALE.
const PREVIEW_SCALE := 1.15
const CONTINUE_LABEL_SIZE := Vector2(320, 30)

@onready var reveal_stage: Control = $RevealStage
@onready var status_label: Label = $StatusLabel
@onready var corner_hint_label: Label = $CornerHintLabel
@onready var buy_packs_button: Button = $BuyPacksButton
@onready var flash_rect: ColorRect = $FlashRect

var _busy: bool = false
var _revealing: bool = false
var _skip_requested: bool = false
var _catcher: Control = null
var _continue_label: Label = null
var _preview_card: Control = null

signal _pack_request_completed(code: int, cards: Array)
signal _continue_clicked

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.hide()
	# Toujours au-dessus de ShopCollectionScroll (son sibling précédent dans
	# CollectionContentRoot, voir MainMenu.tscn) : sans ça, les cartes
	# révélées et le catcher de clic passeraient DERRIÈRE le contenu de la
	# vue Collection au lieu de s'afficher/réagir par-dessus.
	move_to_front()
	_style_action_button(buy_packs_button)
	buy_packs_button.pressed.connect(func(): buy_packs_pressed.emit())
	_build_preview_card()
	SettingsManager.language_changed.connect(func(_l): _retranslate())
	_retranslate()

## Carte agrandie flottante affichée au survol d'une carte révélée (voir
## _make_card_hoverable) — instance unique et partagée, positionnée à chaque
## survol plutôt que recréée.
func _build_preview_card() -> void:
	_preview_card = card_scene.instantiate()
	add_child(_preview_card)
	_preview_card.set_non_interactive()
	_preview_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_card.size = CARD_NATIVE_SIZE
	_preview_card.pivot_offset = Vector2.ZERO
	_preview_card.scale = Vector2.ONE * PREVIEW_SCALE
	_preview_card.z_index = 100
	_preview_card.hide()

## Point d'entrée public : ouvre jusqu'à `quantity` packs du stock du joueur
## (CurrencyManager.free_packs) et révèle les cartes de chaque pack, l'une
## après l'autre, directement autour de `anchor` (le TextureRect du pack
## affiché dans ShopCollectionPanel). Entre deux packs, et à la fin, attend
## un clic ("Cliquer pour continuer") avant de poursuivre/se refermer.
func open_owned(quantity: int, anchor: Control) -> void:
	if _busy:
		return
	var count: int = min(quantity, CurrencyManager.free_packs)
	if count <= 0:
		return

	_busy = true
	status_label.hide()
	buy_packs_button.disabled = true
	_show_catcher()

	var opened_any := false
	for i in count:
		var result: Dictionary = await _request_single_owned_pack()
		if not is_instance_valid(self):
			return
		var code: int = result["code"]
		var cards: Array = result["cards"]
		if code != 200 or cards.is_empty():
			status_label.text = SettingsManager.t("pack_shop.error")
			status_label.show()
			break
		opened_any = true
		var entries: Array = _build_entries(cards)
		await _reveal_pack(entries, anchor)
		if not is_instance_valid(self):
			return

	if opened_any:
		AchievementManager.on_pack_opened()
		# Les cartes tirées viennent d'être octroyées côté serveur (grantCard) :
		# resynchronise la collection pour qu'elles soient utilisables tout de
		# suite dans le deckbuilder sans attendre le prochain redémarrage.
		CollectionManager.sync_from_backend()

	_hide_catcher()
	buy_packs_button.disabled = false
	_busy = false
	closed.emit()

func _request_single_owned_pack() -> Dictionary:
	CurrencyManager.open_owned_pack(func(code: int, cards: Array): _pack_request_completed.emit(code, cards))
	var result: Array = await _pack_request_completed
	return {"code": result[0], "cards": result[1]}

func _build_entries(cards: Array) -> Array:
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
	return entries

## Calcule les 5 positions de révélation autour de `anchor` (en tenant
## compte de sa taille RÉELLE affichée), dans l'ordre demandé : 1ère carte à
## gauche, 2e à droite, 3e sous la 1ère, 4e sous la 2e, 5e sous le pack.
func _compute_slots(anchor: Control) -> Array:
	var pos: Vector2 = anchor.global_position
	var size: Vector2 = anchor.size
	var left: Vector2 = pos + Vector2(-(size.x + SLOT_GAP), 0)
	var right: Vector2 = pos + Vector2(size.x + SLOT_GAP, 0)
	var below_left: Vector2 = left + Vector2(0, size.y + SLOT_GAP)
	var below_right: Vector2 = right + Vector2(0, size.y + SLOT_GAP)
	var below_center: Vector2 = pos + Vector2(0, size.y + SLOT_GAP)
	return [left, right, below_left, below_right, below_center]

## Révèle les (jusqu'à 5) cartes d'UN pack autour de `anchor`, puis attend un
## clic ("Cliquer pour continuer") avant de nettoyer et de rendre la main à
## open_owned() (pack suivant, ou fin de séquence).
func _reveal_pack(entries: Array, anchor: Control) -> void:
	_revealing = true
	_skip_requested = false

	var slots: Array = _compute_slots(anchor)
	# Facteur d'échelle pour que la carte, instanciée à sa taille native,
	# s'affiche exactement à la taille du pack d'où elle vient (anchor.size).
	var scale_factor: float = anchor.size.x / CARD_NATIVE_SIZE.x
	var revealed_cards: Array = []

	for i in range(entries.size()):
		var skip_now: bool = _skip_requested
		if not skip_now:
			var delay: float = FIRST_REVEAL_DELAY if i == 0 else REVEAL_STAGGER
			await get_tree().create_timer(delay).timeout
			skip_now = _skip_requested
		if not is_instance_valid(self):
			return
		var card_instance: Control = await _reveal_one(entries[i], slots[i % slots.size()], scale_factor, anchor, skip_now)
		if not is_instance_valid(self):
			return
		revealed_cards.append(card_instance)

	_revealing = false
	_show_continue_label(anchor, anchor.size)
	await _continue_clicked
	if not is_instance_valid(self):
		return
	_hide_continue_label()
	if is_instance_valid(_preview_card):
		_preview_card.hide()
	for c in revealed_cards:
		if is_instance_valid(c):
			c.queue_free()

## Cycle complet d'une carte : jaillit du pack et vole vers sa place en se
## retournant. En mode "skip" (clic pendant l'animation), apparaît
## directement à sa place sans animation. `scale_factor` : taille native x ce
## facteur = taille du pack (voir _reveal_pack) — la carte garde sa taille
## native (`size`) et n'est redimensionnée que via `scale` (voir
## CARD_NATIVE_SIZE), pivot en haut à gauche pour que `slot_pos`/`global_position`
## représente directement son coin visuel, quel que soit le facteur d'échelle.
func _reveal_one(entry: Dictionary, slot_pos: Vector2, scale_factor: float, anchor: Control, skip: bool) -> Control:
	var card_instance: Control = card_scene.instantiate()
	reveal_stage.add_child(card_instance)
	card_instance.set_non_interactive()
	card_instance.size = CARD_NATIVE_SIZE
	card_instance.pivot_offset = Vector2.ZERO

	if skip:
		card_instance.global_position = slot_pos
		card_instance.scale = Vector2.ONE * scale_factor
		card_instance.show_back(false)
		card_instance.set_data(entry["data"])
		_make_card_hoverable(card_instance, entry["data"])
		if entry["dusted"]:
			_add_dust_badge(card_instance, entry["gold"])
		return card_instance

	AudioManager.play(AudioManager.SHUFFLE)
	card_instance.show_back(true)
	var start_scale: float = scale_factor * 0.6
	card_instance.scale = Vector2.ONE * start_scale
	card_instance.global_position = anchor.global_position + (anchor.size - CARD_NATIVE_SIZE * start_scale) / 2.0

	var move_tween: Tween = create_tween()
	move_tween.tween_property(card_instance, "global_position", slot_pos, CARD_FLY_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	move_tween.parallel().tween_property(card_instance, "scale:y", scale_factor, CARD_FLY_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var flip_tween: Tween = create_tween()
	flip_tween.tween_property(card_instance, "scale:x", 0.0, CARD_FLY_DURATION * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	flip_tween.tween_callback(func():
		if not is_instance_valid(card_instance):
			return
		card_instance.show_back(false)
		card_instance.set_data(entry["data"])
		card_instance.set_non_interactive()
		_make_card_hoverable(card_instance, entry["data"])
		if entry["dusted"]:
			_add_dust_badge(card_instance, entry["gold"])
		AudioManager.play(AudioManager.DRAW)
	)
	flip_tween.tween_property(card_instance, "scale:x", scale_factor, CARD_FLY_DURATION * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await move_tween.finished
	if not is_instance_valid(self) or not is_instance_valid(card_instance):
		return card_instance

	if RARE_RARITIES.has(entry["data"].rarity):
		await _play_rare_flourish(card_instance, entry, scale_factor)

	return card_instance

## Flourish de tirage rare : flash plein panneau et son distinct, plus
## marqués sur Légendaire que sur Épique.
func _play_rare_flourish(card_instance: Control, entry: Dictionary, scale_factor: float) -> void:
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

	var flourish: Tween = create_tween()
	flourish.tween_property(card_instance, "scale", Vector2.ONE * scale_factor * 1.18, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flourish.parallel().tween_property(card_instance, "modulate", final_modulate, 0.4)
	flourish.tween_property(card_instance, "scale", Vector2.ONE * scale_factor, 0.14).set_trans(Tween.TRANS_LINEAR)
	await flourish.finished

func _flash_screen(color: Color, peak_alpha: float) -> void:
	if not is_instance_valid(flash_rect):
		return
	flash_rect.color = Color(color.r, color.g, color.b, 0.0)
	var tween: Tween = create_tween()
	tween.tween_property(flash_rect, "color:a", peak_alpha, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash_rect, "color:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## Badge affiché sur les cartes en double (déjà à MAX_COPIES) : le pack a
## converti cet exemplaire en or plutôt que de l'ajouter à la collection.
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
	badge_label.add_theme_font_size_override("font_size", Typography.MICRO)
	badge_label.add_theme_color_override("font_color", Color(0.98, 0.85, 0.40, 1))
	badge_panel.add_child(badge_label)

	card_instance.add_child(badge_panel)

## Au survol d'une carte révélée (une fois face visible) : affiche la preview
## flottante partagée en grand à côté (même principe que le deck builder),
## avec toutes les infos de la carte lisibles à sa taille native x
## PREVIEW_SCALE. set_non_interactive() reste appelé avant, seul mouse_filter
## est réouvert au survol.
func _make_card_hoverable(card_instance: Control, card_data: CardData) -> void:
	card_instance.mouse_filter = Control.MOUSE_FILTER_STOP
	card_instance.mouse_entered.connect(func():
		if not is_instance_valid(card_instance) or not is_instance_valid(_preview_card):
			return
		_preview_card.set_data(card_data)
		_position_preview(card_instance)
		_preview_card.show()
	)
	card_instance.mouse_exited.connect(func():
		if is_instance_valid(_preview_card):
			_preview_card.hide()
	)

## Rectangle VISUEL réel d'un Control mis à l'échelle avec un pivot en
## (0,0) : get_global_rect() ignore `scale` (ne reflète que `size`), donc
## insuffisant ici où toutes les cartes gardent leur `size` native.
func _visual_rect(control: Control) -> Rect2:
	return Rect2(control.global_position, control.size * control.scale)

## Positionne la preview flottante à côté de la carte survolée (à droite par
## défaut, repliée à gauche si ça déborderait), toujours entièrement visible
## à l'écran.
func _position_preview(card_instance: Control) -> void:
	var preview_size: Vector2 = CARD_NATIVE_SIZE * PREVIEW_SCALE
	var vp: Vector2 = get_viewport_rect().size
	var card_rect: Rect2 = _visual_rect(card_instance)

	var preview_x: float = card_rect.position.x + card_rect.size.x + 12.0
	if preview_x + preview_size.x > vp.x - 4.0:
		preview_x = card_rect.position.x - preview_size.x - 12.0
	preview_x = clampf(preview_x, 4.0, vp.x - preview_size.x - 4.0)
	var preview_y: float = clampf(card_rect.position.y, 4.0, vp.y - preview_size.y - 4.0)

	_preview_card.global_position = Vector2(preview_x, preview_y)

## Texte "Cliquer pour continuer", centré sous la rangée basse des cartes
## révélées.
func _show_continue_label(anchor: Control, card_size: Vector2) -> void:
	var label := Label.new()
	label.text = SettingsManager.t("pack_shop.continue_hint")
	label.add_theme_font_size_override("font_size", Typography.BODY)
	label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35, 1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = CONTINUE_LABEL_SIZE
	var below_row_bottom: float = anchor.global_position.y + anchor.size.y + SLOT_GAP + card_size.y
	label.global_position = Vector2(
		anchor.global_position.x + anchor.size.x / 2.0 - CONTINUE_LABEL_SIZE.x / 2.0,
		below_row_bottom + SLOT_GAP
	)
	reveal_stage.add_child(label)
	_continue_label = label
	label.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(label, "modulate:a", 1.0, 0.25)

func _hide_continue_label() -> void:
	if is_instance_valid(_continue_label):
		_continue_label.queue_free()
	_continue_label = null

## Catcher plein panneau, actif pendant toute la durée d'une ouverture (du
## premier appel réseau jusqu'au dernier clic "Continuer") : bloque le reste
## de la vue Collection (pack déjà désactivé côté ShopCollectionPanel, bouton
## Acheter des packs déjà désactivé — voir open_owned) et sert de cible de
## clic pour "passer l'animation" (pendant _revealing) ou "continuer" (une
## fois les cartes affichées et hoverables).
func _show_catcher() -> void:
	var catcher := Control.new()
	catcher.name = "OpenCatcher"
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(_on_catcher_input)
	reveal_stage.add_child(catcher)
	reveal_stage.move_child(catcher, 0)
	_catcher = catcher

func _hide_catcher() -> void:
	if is_instance_valid(_catcher):
		_catcher.queue_free()
	_catcher = null

func _on_catcher_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _revealing:
			_skip_requested = true
		else:
			_continue_clicked.emit()

## Habille le bouton "Acheter des packs" dans le même style parchemin/or que
## le reste des popups custom du jeu (voir DeckBuilder._make_popup_overlay)
## au lieu du thème Godot par défaut — aucun Theme global n'est configuré
## pour le projet, donc rien d'autre ne l'aurait fait pour nous.
func _style_action_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.12, 0.06, 0.95)
	normal.border_color = Color(0.6, 0.45, 0.15, 0.85)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.24, 0.18, 0.08, 0.95)
	hover.border_color = Color(0.85, 0.65, 0.20, 1.0)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.10, 0.08, 0.04, 0.95)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.10, 0.09, 0.08, 0.6)
	disabled.border_color = Color(0.4, 0.35, 0.25, 0.5)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	btn.add_theme_color_override("font_hover_color", Color(0.98, 0.88, 0.5, 1))
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.5, 0.45, 0.7))

func _retranslate() -> void:
	status_label.text = SettingsManager.t("pack_shop.error")
	corner_hint_label.text = SettingsManager.t("collection.multi_open_hint")
	buy_packs_button.text = SettingsManager.t("collection.buy_packs_button")
