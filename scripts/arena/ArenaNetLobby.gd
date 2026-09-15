extends Control

# Point d'entrée du mode Arena : Solo (comportement historique, inchangé),
# Héberger ou Rejoindre une table réseau (voir ArenaNetContext/README
# « Réseau & Visibilité »). UI construite entièrement par code (même
# convention que ArenaBattle.gd) pour éviter le risque d'édition de scène à
# la main — scène racine quasi vide, juste ce script attaché.
#
# "Rejoindre" lance une recherche de partie rapide (aucune saisie de code de
# table) : même logique que ArenaSteamTransport.join({}) sans lobby_id — la
# première table Wyrdane Arena ouverte trouvée. Portée réduite assumée : pas
# d'invitation d'amis Steam ni de liste de tables ici pour cette première
# version, contrairement au lobby 1v1 (MatchmakingOverlay).

const ARENA_BATTLE_SCENE := "res://scenes/arena/ArenaBattle.tscn"
const MAIN_MENU_SCENE := "res://scenes/mainMenu/MainMenu.tscn"

var _net: ArenaNetworkManager = null
var _handshake: ArenaNetHandshake = null
# Mémorisé plutôt que déduit d'un .bind() sur le signal completed (même
# callback pour héberger/rejoindre) : évite toute ambiguïté sur l'ordre des
# arguments bind() côté Godot 4 (les arguments liés sont ajoutés APRÈS ceux
# du signal, pas avant).
var _pending_is_host: bool = false

var _root_box: VBoxContainer
var _status_label: Label
var _roster_label: Label
var _force_start_button: Button

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	var background := ColorRect.new()
	background.color = Color(0.05, 0.05, 0.08)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_root_box = VBoxContainer.new()
	_root_box.set_anchors_preset(Control.PRESET_CENTER)
	_root_box.custom_minimum_size = Vector2(420, 0)
	_root_box.add_theme_constant_override("separation", 14)
	add_child(_root_box)

	_show_pick_step()

func _clear_root() -> void:
	for child in _root_box.get_children():
		_root_box.remove_child(child)
		child.queue_free()

func _make_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	return label

# ─── Étape 1 : choix du mode ──────────────────────────────────────────────────

func _show_pick_step() -> void:
	_clear_root()
	_root_box.add_child(_make_title(SettingsManager.t("ARENA_LOBBY_TITLE")))

	var solo_button := Button.new()
	solo_button.text = SettingsManager.t("ARENA_LOBBY_SOLO")
	solo_button.pressed.connect(_on_solo_pressed)
	_root_box.add_child(solo_button)

	var host_button := Button.new()
	host_button.text = SettingsManager.t("ARENA_LOBBY_HOST")
	host_button.pressed.connect(_on_host_pressed)
	_root_box.add_child(host_button)

	var join_button := Button.new()
	join_button.text = SettingsManager.t("ARENA_LOBBY_JOIN")
	join_button.pressed.connect(_on_join_pressed)
	_root_box.add_child(join_button)

	_root_box.add_child(_make_back_button(_on_back_to_menu_pressed))

func _make_back_button(on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = SettingsManager.t("ARENA_LOBBY_CANCEL")
	button.pressed.connect(on_pressed)
	return button

func _on_solo_pressed() -> void:
	SceneTransition.change_scene(ARENA_BATTLE_SCENE)

func _on_back_to_menu_pressed() -> void:
	SceneTransition.change_scene(MAIN_MENU_SCENE)

# ─── Étape 2a : héberger ──────────────────────────────────────────────────────

func _on_host_pressed() -> void:
	_pending_is_host = true
	_net = ArenaNetworkManager.new()
	add_child(_net)
	var err: int = _net.host_game_with(ArenaTransportFactory.Backend.STEAM)
	if err != OK:
		_show_steam_unavailable()
		return
	_net.status.connect(_on_status)
	_handshake = ArenaNetHandshake.new(_net, true, _local_display_name())
	_handshake.progress.connect(_on_status)
	_handshake.human_count_changed.connect(_on_human_count_changed)
	_handshake.completed.connect(_on_handshake_completed)
	_show_hosting_step()

func _show_hosting_step() -> void:
	_clear_root()
	_root_box.add_child(_make_title(SettingsManager.t("ARENA_LOBBY_HOSTING")))
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_root_box.add_child(_status_label)
	_roster_label = Label.new()
	_roster_label.text = "1/%d" % ArenaConstants.PARTICIPANT_COUNT
	_roster_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root_box.add_child(_roster_label)
	# Permet de démarrer sans attendre 7 vrais joueurs (voir
	# ArenaNetHandshake.force_start_with_bots) : les sièges encore vacants
	# sont comblés par des bots, pilotés ensuite comme en solo.
	_force_start_button = Button.new()
	_force_start_button.text = SettingsManager.t("ARENA_LOBBY_FORCE_START")
	_force_start_button.pressed.connect(func() -> void: _handshake.force_start_with_bots())
	_root_box.add_child(_force_start_button)
	_root_box.add_child(_make_back_button(_on_cancel_pressed))

func _on_human_count_changed(count: int, target: int) -> void:
	if _roster_label != null:
		_roster_label.text = "%d/%d" % [count, target]

# ─── Étape 2b : rejoindre ─────────────────────────────────────────────────────

func _on_join_pressed() -> void:
	_pending_is_host = false
	_net = ArenaNetworkManager.new()
	add_child(_net)
	var err: int = _net.join_game_with(ArenaTransportFactory.Backend.STEAM)
	if err != OK:
		_show_steam_unavailable()
		return
	_net.status.connect(_on_status)
	_handshake = ArenaNetHandshake.new(_net, false, _local_display_name())
	_handshake.progress.connect(_on_status)
	_handshake.completed.connect(_on_handshake_completed)
	_show_joining_step()

func _show_joining_step() -> void:
	_clear_root()
	_root_box.add_child(_make_title(SettingsManager.t("ARENA_LOBBY_JOINING")))
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_root_box.add_child(_status_label)
	_root_box.add_child(_make_back_button(_on_cancel_pressed))

# ─── Commun ───────────────────────────────────────────────────────────────────

func _local_display_name() -> String:
	# Pas d'intégration SteamService ici (pseudo Steam affiché seulement côté
	# 1v1 aujourd'hui) : portée réduite assumée pour cette première version,
	# nom générique par défaut.
	return SettingsManager.t("ARENA_LOBBY_DEFAULT_NAME")

func _on_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message

func _on_handshake_completed(setup: Dictionary) -> void:
	ArenaNetContext.active = true
	ArenaNetContext.is_host = _pending_is_host
	ArenaNetContext.net = _net
	ArenaNetContext.handshake = _handshake if _pending_is_host else null
	ArenaNetContext.setup = setup
	# Détache _net de CETTE scène (lobby, sur le point d'être détruite par le
	# changement de scène) AVANT de la quitter : contrairement à NetworkManager
	# (1v1), parenté sous MatchmakingOverlay — un AUTOLOAD qui ne disparaît
	# jamais — _net est ici l'enfant d'un nœud de scène ordinaire, qui serait
	# sinon libéré avec tout son sous-arbre au moment du changement de scène.
	# Orphelin mais vivant (conservé par la référence statique ArenaNetContext.net),
	# rien ne le libère entre les deux scènes ; ArenaBattle.gd le reparente dans
	# son propre arbre dès son _ready() (voir _start_network_match), ce qui
	# relance son _process()/transport.poll() après ce court intermède.
	remove_child(_net)
	SceneTransition.change_scene(ARENA_BATTLE_SCENE)

func _on_cancel_pressed() -> void:
	if _net != null:
		_net.close()
	SceneTransition.change_scene(MAIN_MENU_SCENE)

func _show_steam_unavailable() -> void:
	_clear_root()
	var label := Label.new()
	label.text = SettingsManager.t("ARENA_LOBBY_STEAM_UNAVAILABLE")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_root_box.add_child(label)
	_root_box.add_child(_make_back_button(_on_back_to_menu_pressed))
