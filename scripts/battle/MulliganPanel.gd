extends Control
class_name MulliganPanel

## Panneau de mulligan : affiché une seule fois, juste avant le premier tour.
## Le joueur clique sur les cartes de sa main de départ qu'il veut remplacer
## (elles se marquent en rouge), puis valide. Créé entièrement en code par
## Battle (aucun nœud dans Battle.tscn), même principe que TurnBanner.

signal confirmed(discarded: Array)

const CARD_SCENE   := preload("res://scenes/card/Card.tscn")
const CARD_SIZE    := Vector2(250, 375)
const CARD_SCALE   := Vector2(0.85, 0.85)
const CARD_SPACING := 230.0
const MARK_COLOR   := Color(0.75, 0.1, 0.1, 0.5)

var _cards: Array[Card]           = []
var _marked: Dictionary           = {}  # Card -> bool
var _mark_overlays: Dictionary    = {}  # Card -> ColorRect

var _background: ColorRect
var _title: Label
var _hint: Label
var _cards_container: Control
var _confirm_button: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()

	_background = ColorRect.new()
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.color = Color(0, 0, 0, 0.72)
	_background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_background)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 22)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 32)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_title)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_hint)

	_cards_container = Control.new()
	_cards_container.custom_minimum_size = Vector2(CARD_SPACING * 5, CARD_SIZE.y * CARD_SCALE.y + 10)
	_cards_container.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(_cards_container)

	_confirm_button = Button.new()
	_confirm_button.custom_minimum_size = Vector2(220, 48)
	_confirm_button.set_meta("no_click_sound", true)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	vbox.add_child(_confirm_button)

	SettingsManager.language_changed.connect(func(_l): _retranslate())
	_retranslate()

func _retranslate() -> void:
	_title.text          = SettingsManager.t("mulligan.title")
	_hint.text            = SettingsManager.t("mulligan.hint")
	_confirm_button.text = SettingsManager.t("mulligan.confirm")

# ─── Affichage ──────────────────────────────────────────────────────────────

func show_mulligan(hand_cards: Array[CardData]) -> void:
	_clear_cards()
	var row_width: float = CARD_SPACING * max(hand_cards.size() - 1, 0) + CARD_SIZE.x * CARD_SCALE.x
	var start_x: float = (_cards_container.custom_minimum_size.x - row_width) / 2.0
	# Le pivot est fixé au centre dès la création (pour l'animation d'entrée et
	# le hover à venir) : la position doit donc être compensée pour que le
	# rendu final (à CARD_SCALE) tombe pile sur le slot visé.
	var pivot := CARD_SIZE / 2.0
	var pivot_shift := pivot * (Vector2.ONE - CARD_SCALE)
	for i in range(hand_cards.size()):
		var card_data: CardData = hand_cards[i]
		var slot_pos := Vector2(start_x + i * CARD_SPACING, 0)
		var card: Card = CARD_SCENE.instantiate()
		card.drag_enabled = false
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cards_container.add_child(card)
		card.set_data(card_data)
		card.pivot_offset = pivot
		card.scale = CARD_SCALE
		card.position = slot_pos - pivot_shift

		var mark := ColorRect.new()
		mark.color = MARK_COLOR
		mark.size = CARD_SIZE * CARD_SCALE
		mark.position = slot_pos
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.visible = false
		_cards_container.add_child(mark)

		var overlay := Button.new()
		overlay.flat = true
		overlay.size = CARD_SIZE * CARD_SCALE
		overlay.position = slot_pos
		overlay.focus_mode = Control.FOCUS_NONE
		overlay.pressed.connect(_on_card_toggled.bind(card))
		_cards_container.add_child(overlay)

		_cards.append(card)
		_marked[card] = false
		_mark_overlays[card] = mark

	_confirm_button.disabled = false
	modulate.a = 0.0
	show()
	await get_tree().process_frame
	_play_entrance()

func _play_entrance() -> void:
	modulate.a = 1.0
	_background.modulate.a = 0.0
	create_tween().tween_property(_background, "modulate:a", 1.0, 0.25)
	var delay := 0.0
	for card in _cards:
		card.modulate.a = 0.0
		card.scale = CARD_SCALE * 0.7
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(delay)
		tween.tween_property(card, "scale", CARD_SCALE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
		delay += 0.08

# ─── Sélection ──────────────────────────────────────────────────────────────

func _on_card_toggled(card: Card) -> void:
	var marked: bool = not _marked[card]
	_marked[card] = marked
	_mark_overlays[card].visible = marked
	var target_scale: Vector2 = CARD_SCALE * (0.9 if marked else 1.0)
	create_tween().tween_property(card, "scale", target_scale, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_confirm_pressed() -> void:
	if _confirm_button.disabled:
		return
	_confirm_button.disabled = true
	var discarded: Array[CardData] = []
	for card in _cards:
		if _marked[card]:
			discarded.append(card.data)
	AudioManager.play(AudioManager.CONFIRM)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished
	hide()
	_clear_cards()
	confirmed.emit(discarded)

func _clear_cards() -> void:
	for child in _cards_container.get_children():
		child.queue_free()
	_cards.clear()
	_marked.clear()
	_mark_overlays.clear()
