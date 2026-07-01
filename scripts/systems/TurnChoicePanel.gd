extends Control

class_name TurnChoicePanel

signal draw_selected
signal mana_selected

const HOVER_SCALE := Vector2(1.06, 1.06)

@onready var background: ColorRect = $Background
@onready var draw_button: Button = %DrawButton
@onready var mana_button: Button = %ManaButton

# Un tween de scale par carte, pour ne pas cumuler hover + entrée
var _scale_tweens: Dictionary = {}

func _ready() -> void:
	hide()
	_setup_card(draw_button, _on_draw_button_pressed)
	_setup_card(mana_button, _on_mana_button_pressed)

func _setup_card(button: Button, on_pressed: Callable) -> void:
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
		var tween := _new_scale_tween(button).set_parallel(true)
		tween.tween_property(button, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
		tween.tween_property(button, "modulate:a", 1.0, 0.2).set_delay(delay)
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
	AudioManager.play(AudioManager.HOVER)
	button.pivot_offset = button.size / 2.0
	_new_scale_tween(button).tween_property(button, "scale", HOVER_SCALE, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_card_mouse_exited(button: Button) -> void:
	if button.disabled:
		return
	_new_scale_tween(button).tween_property(button, "scale", Vector2.ONE, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# ─── Sélection ────────────────────────────────────────────────────────────────

func _on_draw_button_pressed() -> void:
	_confirm_choice(draw_button, draw_selected)

func _on_mana_button_pressed() -> void:
	_confirm_choice(mana_button, mana_selected)

func _confirm_choice(chosen: Button, selected_signal: Signal) -> void:
	draw_button.disabled = true
	mana_button.disabled = true
	AudioManager.play(AudioManager.BUTTON)
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
