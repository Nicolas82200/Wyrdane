extends Control

# Panneau de profil joueur, ouvert en cliquant sur le pseudo en bas à gauche du
# menu principal (voir MainMenu._on_profile_button_pressed). Identité (avatar/
# pseudo) lue directement via SteamService, comme MainMenu._update_steam_profile ;
# le reste (date de création de compte, collection, stats solo/ranked) vient de
# GET /api/profile (BackendClient.get_profile).

@onready var avatar: TextureRect            = $Overlay/Panel/VBox/Margin/VBox/Header/Avatar
@onready var name_label: Label              = $Overlay/Panel/VBox/Margin/VBox/Header/NameLabel
@onready var member_since_label: Label       = $Overlay/Panel/VBox/Margin/VBox/MemberSinceLabel
@onready var collection_label: Label         = $Overlay/Panel/VBox/Margin/VBox/CollectionLabel
@onready var solo_stats_label: Label         = $Overlay/Panel/VBox/Margin/VBox/SoloStatsLabel
@onready var ranked_stats_label: Label       = $Overlay/Panel/VBox/Margin/VBox/RankedStatsLabel
@onready var close_button: Button            = $Overlay/Panel/VBox/Margin/VBox/CloseButton

func _ready() -> void:
	close_button.set_meta("no_click_sound", true)
	close_button.pressed.connect(func():
		AudioManager.play(AudioManager.CLOSE_MENU)
		hide()
	)
	SettingsManager.language_changed.connect(func(_l): _retranslate())
	_retranslate()

func open() -> void:
	AudioManager.play(AudioManager.OPEN_MENU)
	_update_identity()
	_show_placeholders()
	show()
	var panel := $Overlay/Panel
	panel.pivot_offset = panel.size / 2.0
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.94, 0.94)
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.15)
	tween.parallel().tween_property(panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_fetch_profile()

# BackendClient.login_with_steam() est lancé de façon asynchrone au démarrage
# du menu (voir MainMenu._start_backend_sync) : si le joueur ouvre ce panneau
# avant la fin de la connexion, is_authenticated() est encore faux. On
# attendait alors login_succeeded pour rien — sans jamais relancer la requête,
# le panneau restait bloqué sur "Chargement..." indéfiniment.
func _fetch_profile() -> void:
	if BackendClient.is_authenticated():
		BackendClient.get_profile(_on_profile_response)
		return
	if not BackendClient.login_succeeded.is_connected(_on_login_succeeded):
		BackendClient.login_succeeded.connect(_on_login_succeeded, CONNECT_ONE_SHOT)
	if not BackendClient.login_failed.is_connected(_on_login_failed):
		BackendClient.login_failed.connect(_on_login_failed, CONNECT_ONE_SHOT)

func _on_login_succeeded(_user: Dictionary) -> void:
	if not is_inside_tree() or not visible:
		return
	BackendClient.get_profile(_on_profile_response)

func _on_login_failed(_reason: String) -> void:
	if not is_inside_tree() or not visible:
		return
	_show_unavailable()

func _on_profile_response(success: bool, data: Dictionary) -> void:
	if not is_inside_tree() or not visible:
		return
	if success:
		_populate(data)
	else:
		_show_unavailable()

func _show_unavailable() -> void:
	var dash := SettingsManager.t("PROFILE_UNAVAILABLE")
	member_since_label.text = dash
	collection_label.text = dash
	solo_stats_label.text = dash
	ranked_stats_label.text = dash

func _update_identity() -> void:
	if not SteamService.ensure_init():
		return
	var persona := SteamService.local_persona_name()
	if persona != "":
		name_label.text = persona
	var tex := SteamService.local_avatar_texture()
	if tex:
		avatar.texture = tex

func _show_placeholders() -> void:
	var dash := SettingsManager.t("PROFILE_LOADING")
	member_since_label.text = dash
	collection_label.text = dash
	solo_stats_label.text = dash
	ranked_stats_label.text = dash

func _populate(data: Dictionary) -> void:
	var created_at: String = str(data.get("created_at", ""))
	var date_str := created_at.substr(0, 10) if created_at.length() >= 10 else SettingsManager.t("PROFILE_UNAVAILABLE")
	member_since_label.text = SettingsManager.t("PROFILE_MEMBER_SINCE") % date_str

	var collection_count := int(data.get("collection_count", 0))
	collection_label.text = SettingsManager.t("PROFILE_COLLECTION_COUNT") % collection_count

	var solo: Dictionary = data.get("solo", {})
	solo_stats_label.text = SettingsManager.t("PROFILE_SOLO_STATS") % [int(solo.get("wins", 0)), int(solo.get("losses", 0))]

	var ranked: Dictionary = data.get("ranked", {})
	ranked_stats_label.text = SettingsManager.t("PROFILE_RANKED_STATS") % [
		int(ranked.get("wins", 0)), int(ranked.get("losses", 0)),
		int(ranked.get("mmr", 0)), int(ranked.get("rank", 0)),
	]

func _retranslate() -> void:
	$Overlay/Panel/VBox/Margin/VBox/TitleLabel.text = SettingsManager.t("PROFILE_TITLE")
	close_button.text = SettingsManager.t("MENU_CLOSE")
	if not visible:
		return
	_show_placeholders()
