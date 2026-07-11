extends Control

class_name TurnChoicePanel

signal draw_selected
signal mana_selected

const HOVER_SCALE := Vector2(1.06, 1.06)
const PEEK_ALPHA := 0.12

@onready var background: ColorRect = $Background
@onready var draw_button: Button = %DrawButton
@onready var mana_button: Button = %ManaButton
@onready var peek_button: Button = %PeekButton

@onready var _subtitle:   Label = $CenterContainer/VBox/Header/Subtitle
@onready var _title:      Label = $CenterContainer/VBox/Header/Title
@onready var _draw_title: Label = $CenterContainer/VBox/HBox/DrawButton/Margin/VBox/CardTitle
@onready var _draw_desc:  Label = $CenterContainer/VBox/HBox/DrawButton/Margin/VBox/Desc
@onready var _mana_title: Label = $CenterContainer/VBox/HBox/ManaButton/Margin/VBox/CardTitle
@onready var _mana_desc:  Label = $CenterContainer/VBox/HBox/ManaButton/Margin/VBox/Desc
@onready var _hint:       Label = $CenterContainer/VBox/Hint

# Un tween de scale par carte, pour ne pas cumuler hover + entrée
var _scale_tweens: Dictionary = {}
var _peek_tween: Tween

func _ready() -> void:
	hide()
	_setup_card(draw_button, _on_draw_button_pressed)
	_setup_card(mana_button, _on_mana_button_pressed)
	# Presser "voir ma main" n'a pas d'action : pas de son de clic
	peek_button.set_meta("no_click_sound", true)
	peek_button.mouse_entered.connect(_set_peek.bind(true))
	peek_button.mouse_exited.connect(_set_peek.bind(false))
	SettingsManager.language_changed.connect(func(_l): _retranslate())
	_retranslate()

# Met à jour les libellés fixes du panneau dans la langue courante.
func _retranslate() -> void:
	_subtitle.text   = SettingsManager.t("turn.start")
	_title.text      = SettingsManager.t("turn.choose")
	_draw_title.text = SettingsManager.t("turn.draw_title")
	_draw_desc.text  = SettingsManager.t("turn.draw_desc")
	_mana_title.text = SettingsManager.t("turn.mana_title")
	_mana_desc.text  = SettingsManager.t("turn.mana_desc")
	_hint.text       = SettingsManager.t("turn.hint")
	peek_button.text = SettingsManager.t("turn.peek")

func _setup_card(button: Button, on_pressed: Callable) -> void:
	# Le son de confirmation est joué dans _confirm_choice, pas le clic générique
	button.set_meta("no_click_sound", true)
	button.pressed.connect(on_pressed)
	button.mouse_entered.connect(_on_card_mouse_entered.bind(button))
	button.mouse_exited.connect(_on_card_mouse_exited.bind(button))

func show_choice() -> void:
	draw_button.disabled = false
	mana_button.disabled = false
	modulate.a = 0.0
	show()
	# Attendre une frame pour que le layout donne leur taille aux cartes
	await get_tree().process_frame
	_play_entrance()

# ─── Animations ───────────────────────────────────────────────────────────────

func _play_entrance() -> void:
	modulate.a = 1.0
	background.modulate.a = 0.0
	create_tween().tween_property(background, "modulate:a", 1.0, 0.25)
	var delay := 0.0
	for button in [draw_button, mana_button]:
		button.pivot_offset = button.size / 2.0
		button.scale = Vector2(0.7, 0.7)
		button.modulate.a = 0.0
		# Le fondu tourne sur un tween séparé du scale : survoler la carte pendant
		# son entrée tue le tween de scale (via _new_scale_tween) et ne doit pas
		# interrompre le fondu, sinon la carte reste transparente pour toujours.
		_new_scale_tween(button).tween_property(button, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
		create_tween().tween_property(button, "modulate:a", 1.0, 0.2).set_delay(delay)
		delay += 0.12

func _new_scale_tween(button: Button) -> Tween:
	if _scale_tweens.has(button) and _scale_tweens[button].is_valid():
		_scale_tweens[button].kill()
	var tween := create_tween()
	_scale_tweens[button] = tween
	return tween

func _on_card_mouse_entered(button: Button) -> void:
	if button.disabled:
		return
	button.pivot_offset = button.size / 2.0
	_new_scale_tween(button).tween_property(button, "scale", HOVER_SCALE, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_card_mouse_exited(button: Button) -> void:
	if button.disabled:
		return
	_new_scale_tween(button).tween_property(button, "scale", Vector2.ONE, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# ─── Voir ma main ─────────────────────────────────────────────────────────────

# Tant que le bouton est survolé, le panneau s'estompe pour laisser voir la main
func _set_peek(peeking: bool) -> void:
	if not visible or draw_button.disabled:
		return
	if _peek_tween and _peek_tween.is_valid():
		_peek_tween.kill()
	_peek_tween = create_tween()
	_peek_tween.tween_property(self, "modulate:a", PEEK_ALPHA if peeking else 1.0, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# ─── Sélection ────────────────────────────────────────────────────────────────

# Le panneau attend-il un choix ? (visible et boutons encore actifs)
func is_active() -> bool:
	return visible and not draw_button.disabled

# Raccourcis clavier : déclenchent le même chemin qu'un clic sur la carte
func select_draw() -> void:
	_on_draw_button_pressed()

func select_mana() -> void:
	_on_mana_button_pressed()

func _on_draw_button_pressed() -> void:
	_confirm_choice(draw_button, draw_selected)

func _on_mana_button_pressed() -> void:
	_confirm_choice(mana_button, mana_selected)

func _confirm_choice(chosen: Button, selected_signal: Signal) -> void:
	draw_button.disabled = true
	mana_button.disabled = true
	if _peek_tween and _peek_tween.is_valid():
		_peek_tween.kill()
	AudioManager.play(AudioManager.CONFIRM)
	var other: Button = mana_button if chosen == draw_button else draw_button
	chosen.pivot_offset = chosen.size / 2.0
	var tween := _new_scale_tween(chosen).set_parallel(true)
	tween.tween_property(chosen, "scale", Vector2(1.12, 1.12), 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(other, "modulate:a", 0.25, 0.18)
	tween.chain().tween_property(self, "modulate:a", 0.0, 0.15)
	await tween.finished
	hide()
	# Remettre le panneau dans un état propre pour le prochain tour
	chosen.scale = Vector2.ONE
	other.modulate.a = 1.0
	modulate.a = 1.0
	selected_signal.emit()
