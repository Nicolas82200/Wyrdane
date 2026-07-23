extends Control
class_name GameOverScreen

# Écran de fin de partie : affiché par Battle quand un héros meurt (victoire /
# défaite) ou quand l'adversaire réseau se déconnecte. Bloque tous les inputs
# du plateau et propose de rejouer ou de revenir au menu principal.

signal replay_requested
signal menu_requested

const TITLE_VICTORY_COLOR    := Color(0.95, 0.82, 0.35)
const TITLE_DEFEAT_COLOR     := Color(0.85, 0.25, 0.2)
const TITLE_DISCONNECT_COLOR := Color(0.75, 0.72, 0.65)

const OVERLAY_FADE_TIME := 0.35
const PANEL_ZOOM_TIME   := 0.35

@onready var overlay: ColorRect       = $Overlay
@onready var panel: PanelContainer    = $Panel
@onready var title_label: Label      = $Panel/VBox/TitleMargin/Title
@onready var subtitle_label: Label   = $Panel/VBox/SubtitleMargin/Subtitle
@onready var replay_button: Button   = $Panel/VBox/ButtonsMargin/ButtonsVBox/ReplayButton
@onready var menu_button: Button     = $Panel/VBox/ButtonsMargin/ButtonsVBox/MenuButton
@onready var reward_label: Label     = $Panel/VBox/RewardLabel

# "victory" | "defeat" | "disconnect" — mémorisé pour retraduire à la volée.
var _result: String = "victory"
var _reward_amount: int = 0

func _ready() -> void:
	hide()
	reward_label.hide()
	_style_button(replay_button)
	_style_button(menu_button)
	replay_button.pressed.connect(func(): replay_requested.emit())
	menu_button.pressed.connect(func(): menu_requested.emit())
	SettingsManager.language_changed.connect(func(_l): _retranslate())

# Affiche l'écran pour le résultat donné. En réseau, rejouer n'a pas de sens
# (relancer la scène repartirait en solo contre l'IA, et en déconnexion le pair
# est parti) : seul le retour au menu est proposé.
func show_result(result: String, allow_replay: bool = true) -> void:
	_result = result
	_reward_amount = 0
	reward_label.hide()
	replay_button.visible = allow_replay and result != "disconnect"
	match result:
		"defeat":
			title_label.add_theme_color_override("font_color", TITLE_DEFEAT_COLOR)
		"disconnect":
			title_label.add_theme_color_override("font_color", TITLE_DISCONNECT_COLOR)
		_:
			title_label.add_theme_color_override("font_color", TITLE_VICTORY_COLOR)
	_retranslate()
	AudioManager.play(AudioManager.OPEN_MENU)
	_animate_show()

# Fondu du fond assombri, puis zoom-in du panneau de résultat — cohérent avec
# le style de TurnBanner (scale+alpha depuis le centre), en plus lent et ample.
func _animate_show() -> void:
	overlay.modulate.a = 0.0
	panel.modulate.a = 0.0
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(1.2, 1.2)
	show()
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(overlay, "modulate:a", 1.0, OVERLAY_FADE_TIME)
	tween.tween_property(panel, "modulate:a", 1.0, PANEL_ZOOM_TIME).set_delay(0.05)
	tween.tween_property(panel, "scale", Vector2.ONE, PANEL_ZOOM_TIME).set_delay(0.05)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Appelé après confirmation serveur du crédit de monnaie (voir
# Battle._show_game_over) : peut arriver après que l'écran soit déjà affiché.
func show_reward(amount: int) -> void:
	_reward_amount = amount
	reward_label.text = SettingsManager.t("battle.gameover.reward") % amount
	reward_label.show()

func _retranslate() -> void:
	match _result:
		"defeat":
			title_label.text    = SettingsManager.t("battle.gameover.defeat")
			subtitle_label.text = SettingsManager.t("battle.gameover.defeat_sub")
		"disconnect":
			title_label.text    = SettingsManager.t("battle.gameover.disconnect")
			subtitle_label.text = SettingsManager.t("battle.gameover.disconnect_sub")
		_:
			title_label.text    = SettingsManager.t("battle.gameover.victory")
			subtitle_label.text = SettingsManager.t("battle.gameover.victory_sub")
	replay_button.text = SettingsManager.t("battle.gameover.replay")
	menu_button.text   = SettingsManager.t("battle.gameover.menu")
	if _reward_amount > 0:
		reward_label.text = SettingsManager.t("battle.gameover.reward") % _reward_amount

# Même habillage que les boutons du menu réglages (SettingsMenu.gd).
func _style_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color                   = Color("1a1a2eaa")
	normal.border_width_left          = 2
	normal.border_width_right         = 2
	normal.border_width_top           = 2
	normal.border_width_bottom        = 2
	normal.border_color               = Color("8b6914")
	normal.corner_radius_top_left     = 6
	normal.corner_radius_top_right    = 6
	normal.corner_radius_bottom_left  = 6
	normal.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color     = Color("2a2a4ecc")
	hover.border_color = Color("c9a227")
	btn.add_theme_stylebox_override("hover", hover)
	var pressed_style := normal.duplicate() as StyleBoxFlat
	pressed_style.bg_color     = Color("0d0d1eee")
	pressed_style.border_color = Color("f0c040")
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_color_override("font_color",       Color("e8d5a3"))
	btn.add_theme_color_override("font_hover_color", Color("fff5d6"))
	btn.add_theme_font_size_override("font_size", 20)
