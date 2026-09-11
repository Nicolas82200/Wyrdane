extends Control
class_name GameOverScreen

# Écran de fin de partie : affiché par Battle quand un héros meurt (victoire /
# défaite) ou quand l'adversaire réseau se déconnecte. Bloque tous les inputs
# du plateau et propose de rejouer ou de revenir au menu principal.

signal replay_requested
signal menu_requested
signal add_friend_requested

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
@onready var add_friend_button: Button = $Panel/VBox/ButtonsMargin/ButtonsVBox/AddFriendButton
@onready var view_replay_button: Button = $Panel/VBox/ButtonsMargin/ButtonsVBox/ViewReplayButton
@onready var stats_grid: GridContainer = $Panel/VBox/StatsMargin/StatsGrid
@onready var duration_key: Label  = $Panel/VBox/StatsMargin/StatsGrid/DurationKey
@onready var duration_value: Label = $Panel/VBox/StatsMargin/StatsGrid/DurationValue
@onready var quests_box: VBoxContainer    = $Panel/VBox/QuestsMargin/QuestsBox
@onready var quests_header: Label         = $Panel/VBox/QuestsMargin/QuestsBox/QuestsHeader
@onready var quests_status: Label         = $Panel/VBox/QuestsMargin/QuestsBox/QuestsStatus
@onready var quests_list: VBoxContainer   = $Panel/VBox/QuestsMargin/QuestsBox/QuestsList

# "victory" | "defeat" | "disconnect" — mémorisé pour retraduire à la volée.
var _result: String = "victory"
var _reward_amount: int = 0
var _replay_view: MatchReplayView
# Statistiques de la partie qui vient de se terminer (voir show_stats), affichées
# sous la récompense — vide (grille masquée) tant que show_stats n'a pas été
# appelé, ex: écran de déconnexion sans stats calculées.
var _stats: Dictionary = {}

func _ready() -> void:
	hide()
	reward_label.hide()
	view_replay_button.hide()
	stats_grid.hide()
	quests_box.hide()
	_style_button(replay_button)
	_style_button(menu_button)
	_style_button(add_friend_button)
	_style_button(view_replay_button)
	replay_button.pressed.connect(func(): replay_requested.emit())
	menu_button.pressed.connect(func(): menu_requested.emit())
	add_friend_button.pressed.connect(func(): add_friend_requested.emit())
	view_replay_button.pressed.connect(_on_view_replay_pressed)
	_replay_view = MatchReplayView.new()
	add_child(_replay_view)
	SettingsManager.language_changed.connect(func(_l): _retranslate())

# Appelé par Battle._show_game_over : le journal de combat de la partie qui
# vient de se terminer est-il disponible (voir SettingsManager.last_match_log,
# en mémoire seulement — jamais persisté sur disque) ?
func set_replay_available(available: bool) -> void:
	view_replay_button.visible = available

func _on_view_replay_pressed() -> void:
	_replay_view.show_log(SettingsManager.last_match_log)

# Affiche l'écran pour le résultat donné. En réseau, rejouer n'a pas de sens
# (relancer la scène repartirait en solo contre l'IA, et en déconnexion le pair
# est parti) : seul le retour au menu est proposé. show_add_friend (réseau
# uniquement, hors déconnexion) ouvre l'overlay Steam "ajouter en ami" ciblant
# l'adversaire qui vient d'être affronté (voir Battle._on_add_friend_pressed).
func show_result(result: String, allow_replay: bool = true, show_add_friend: bool = false) -> void:
	_result = result
	_reward_amount = 0
	_stats = {}
	reward_label.hide()
	stats_grid.hide()
	quests_box.hide()
	replay_button.visible = allow_replay and result != "disconnect"
	add_friend_button.visible = show_add_friend and result != "disconnect"
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

# Appelé par Battle._show_game_over juste après show_result, avec la durée du
# match ("duration_sec", formatée en MM:SS).
func show_stats(stats: Dictionary) -> void:
	_stats = stats
	stats_grid.show()
	_update_stats_labels()

func _update_stats_labels() -> void:
	if _stats.is_empty():
		return
	var total_sec: int = int(_stats.get("duration_sec", 0))
	duration_value.text = "%d:%02d" % [total_sec / 60, total_sec % 60]

# Appelé par Battle._show_game_over : récupère et affiche l'avancée des quêtes
# quotidiennes (lecture seule — la réclamation reste dans l'onglet Quêtes du
# menu principal). Pas de section hebdo/unique ici : rester compact sur un
# écran déjà chargé (résultat, récompense, durée, actions).
func show_quests() -> void:
	quests_box.show()
	quests_status.show()
	quests_status.text = SettingsManager.t("PROFILE_LOADING")
	for child in quests_list.get_children():
		child.queue_free()
	if not BackendClient.is_authenticated():
		quests_status.text = SettingsManager.t("QUESTS_UNAVAILABLE")
		return
	BackendClient.get_daily_quests(func(success: bool, data: Dictionary):
		# L'écran peut avoir été refermé (Rejouer/Menu) avant la réponse réseau.
		if not is_instance_valid(self) or not visible:
			return
		if not success:
			quests_status.text = SettingsManager.t("QUESTS_UNAVAILABLE")
			return
		var quests: Array = data.get("quests", [])
		quests_status.hide()
		if quests.is_empty():
			quests_status.show()
			quests_status.text = SettingsManager.t("QUESTS_UNAVAILABLE")
			return
		for quest in quests:
			_add_quest_row(quest)
	)

static func _get_quest_int(quest: Dictionary, key: String, default: int) -> int:
	var value = quest.get(key, default)
	return default if value == null else int(value)

static func _get_quest_str(quest: Dictionary, key: String, default: String) -> String:
	var value = quest.get(key, default)
	return default if value == null else String(value)

func _add_quest_row(quest: Dictionary) -> void:
	var progress := _get_quest_int(quest, "progress", 0)
	var target := _get_quest_int(quest, "target", 1)
	var completed := progress >= target
	var row := Label.new()
	row.autowrap_mode = TextServer.AUTOWRAP_WORD
	row.add_theme_font_size_override("font_size", 14)
	# Coche en préfixe plutôt qu'une distinction uniquement par couleur (voir
	# accessibilité dans CLAUDE.md) : quête accomplie vs en cours.
	var prefix := "✓ " if completed else "• "
	row.add_theme_color_override("font_color",
			Color(0.92, 0.72, 0.28, 0.95) if completed else Color(0.85, 0.8, 0.72, 0.85))
	var desc := SettingsManager.t(_get_quest_str(quest, "description_key", ""))
	row.text = "%s%s (%d/%d)" % [prefix, desc, progress, target]
	quests_list.add_child(row)

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
	add_friend_button.text = SettingsManager.t("battle.gameover.add_friend")
	view_replay_button.text = SettingsManager.t("battle.gameover.view_replay")
	if _reward_amount > 0:
		reward_label.text = SettingsManager.t("battle.gameover.reward") % _reward_amount
	duration_key.text    = SettingsManager.t("battle.gameover.stats.duration")
	_update_stats_labels()
	quests_header.text   = SettingsManager.t("battle.gameover.quests_title")

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
