extends Control
class_name PackShop

# Moteur de révélation des packs, embarqué en overlay transparent par-dessus
# CollectionContentRoot (voir MainMenu.gd) — ne dessine plus d'écran séparé
# (pas de fond assombri, pas de titre, pas de croix de fermeture) : les
# cartes révélées apparaissent directement autour du VRAI pack affiché dans
# la vue Collection (voir ShopCollectionPanel.gd), qui transmet ce nœud comme
# `anchor` à open_owned(). Porte aussi l'indice permanent en bas à droite du
# panneau expliquant Ctrl+clic/Maj+clic (voir CornerHintLabel plus bas).

signal closed

@export var card_scene: PackedScene

const SLOT_GAP := 24.0
const CARD_FLY_DURATION := 0.4
const FIRST_REVEAL_DELAY := 0.15
const REVEAL_STAGGER := 0.45
const RARE_RARITIES := ["Epic", "Legendary"]
const FLASH_ALPHA := {"Epic": 0.22, "Legendary": 0.42}
const HOVER_SCALE := 1.5
const HOVER_ANIM_DURATION := 0.12
const CONTINUE_LABEL_SIZE := Vector2(320, 30)

@onready var reveal_stage: Control = $RevealStage
@onready var status_label: Label = $StatusLabel
@onready var corner_hint_label: Label = $CornerHintLabel
@onready var flash_rect: ColorRect = $FlashRect

var _busy: bool = false
var _revealing: bool = false
var _skip_requested: bool = false
var _catcher: Control = null
var _continue_label: Label = null

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
	SettingsManager.language_changed.connect(func(_l): _retranslate())
	_retranslate()

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

## Calcule les 5 positions de révélation autour de `anchor`, dans l'ordre
## demandé : 1ère carte à gauche, 2e à droite, 3e sous la 1ère, 4e sous la
## 2e, 5e sous le pack.
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
	var card_size: Vector2 = anchor.size
	var revealed_cards: Array = []

	for i in range(entries.size()):
		var skip_now: bool = _skip_requested
		if not skip_now:
			var delay: float = FIRST_REVEAL_DELAY if i == 0 else REVEAL_STAGGER
			await get_tree().create_timer(delay).timeout
			skip_now = _skip_requested
		if not is_instance_valid(self):
			return
		var card_instance: Control = await _reveal_one(entries[i], slots[i % slots.size()], card_size, anchor, skip_now)
		if not is_instance_valid(self):
			return
		revealed_cards.append(card_instance)

	_revealing = false
	_show_continue_label(anchor, card_size)
	await _continue_clicked
	if not is_instance_valid(self):
		return
	_hide_continue_label()
	for c in revealed_cards:
		if is_instance_valid(c):
			c.queue_free()

## Cycle complet d'une carte : jaillit du pack et vole vers sa place en se
## retournant. En mode "skip" (clic pendant l'animation), apparaît
## directement à sa place sans animation.
func _reveal_one(entry: Dictionary, slot_pos: Vector2, card_size: Vector2, anchor: Control, skip: bool) -> Control:
	var card_instance: Control = card_scene.instantiate()
	reveal_stage.add_child(card_instance)
	card_instance.set_non_interactive()
	card_instance.size = card_size
	card_instance.pivot_offset = card_size / 2.0

	if skip:
		card_instance.global_position = slot_pos
		card_instance.scale = Vector2.ONE
		card_instance.show_back(false)
		card_instance.set_data(entry["data"])
		_make_card_hoverable(card_instance)
		if entry["dusted"]:
			_add_dust_badge(card_instance, entry["gold"])
		return card_instance

	AudioManager.play(AudioManager.SHUFFLE)
	card_instance.show_back(true)
	card_instance.scale = Vector2(0.6, 0.6)
	card_instance.global_position = anchor.global_position + (anchor.size - card_size * 0.6) / 2.0

	var move_tween: Tween = create_tween()
	move_tween.tween_property(card_instance, "global_position", slot_pos, CARD_FLY_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	move_tween.parallel().tween_property(card_instance, "scale:y", 1.0, CARD_FLY_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var flip_tween: Tween = create_tween()
	flip_tween.tween_property(card_instance, "scale:x", 0.0, CARD_FLY_DURATION * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	flip_tween.tween_callback(func():
		if not is_instance_valid(card_instance):
			return
		card_instance.show_back(false)
		card_instance.set_data(entry["data"])
		card_instance.set_non_interactive()
		_make_card_hoverable(card_instance)
		if entry["dusted"]:
			_add_dust_badge(card_instance, entry["gold"])
		AudioManager.play(AudioManager.DRAW)
	)
	flip_tween.tween_property(card_instance, "scale:x", 1.0, CARD_FLY_DURATION * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await move_tween.finished
	if not is_instance_valid(self) or not is_instance_valid(card_instance):
		return card_instance

	if RARE_RARITIES.has(entry["data"].rarity):
		await _play_rare_flourish(card_instance, entry)

	return card_instance

## Flourish de tirage rare : flash plein panneau et son distinct, plus
## marqués sur Légendaire que sur Épique.
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

	var flourish: Tween = create_tween()
	flourish.tween_property(card_instance, "scale", Vector2.ONE * 1.18, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flourish.parallel().tween_property(card_instance, "modulate", final_modulate, 0.4)
	flourish.tween_property(card_instance, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_LINEAR)
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

## Agrandissement au survol (x1.5, une fois la carte révélée) — set_non_interactive()
## reste appelé avant, seul mouse_filter est réouvert au survol.
func _make_card_hoverable(card_instance: Control) -> void:
	card_instance.mouse_filter = Control.MOUSE_FILTER_STOP
	card_instance.mouse_entered.connect(func():
		if not is_instance_valid(card_instance):
			return
		card_instance.z_index = 50
		var t := create_tween()
		t.tween_property(card_instance, "scale", Vector2.ONE * HOVER_SCALE, HOVER_ANIM_DURATION) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	card_instance.mouse_exited.connect(func():
		if not is_instance_valid(card_instance):
			return
		card_instance.z_index = 0
		var t := create_tween()
		t.tween_property(card_instance, "scale", Vector2.ONE, HOVER_ANIM_DURATION) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	)

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
## de la vue Collection (pack déjà désactivé côté ShopCollectionPanel, mais
## aussi le bouton Acheter des packs) et sert de cible de clic pour
## "passer l'animation" (pendant _revealing) ou "continuer" (une fois
## revealed_cards affichées et hoverables).
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

func _retranslate() -> void:
	status_label.text = SettingsManager.t("pack_shop.error")
	corner_hint_label.text = SettingsManager.t("collection.multi_open_hint")
