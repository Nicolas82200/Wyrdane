extends Control

# Point d'entrée du multijoueur (IP directe / LAN). Lancer deux instances :
#   - l'une clique « Héberger »
#   - l'autre saisit l'IP (127.0.0.1 en local) puis « Rejoindre »
# À la connexion, un handshake échange les decks / la graine / le premier joueur,
# puis les DEUX clients basculent sur la scène Battle en mode réseau.

const BATTLE_SCENE := "res://scenes/battle/Battle.tscn"
const MAIN_MENU_SCENE := "res://scenes/mainMenu/MainMenu.tscn"

var _net: NetworkManager
var _handshake: NetHandshake
var _log: RichTextLabel
var _ip_field: LineEdit

func _ready() -> void:
	_net = NetworkManager.new()
	add_child(_net)
	_net.peer_connected.connect(_on_peer_connected)
	_net.peer_disconnected.connect(_on_peer_disconnected)
	_build_ui()

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var buttons := HBoxContainer.new()
	root.add_child(buttons)

	var host_btn := Button.new()
	host_btn.text = "Héberger"
	host_btn.pressed.connect(_on_host_pressed)
	buttons.add_child(host_btn)

	_ip_field = LineEdit.new()
	_ip_field.text = "127.0.0.1"
	_ip_field.custom_minimum_size = Vector2(160, 0)
	buttons.add_child(_ip_field)

	var join_btn := Button.new()
	join_btn.text = "Rejoindre"
	join_btn.pressed.connect(_on_join_pressed)
	buttons.add_child(join_btn)

	var back_btn := Button.new()
	back_btn.text = SettingsManager.t("NET_BACK")
	back_btn.pressed.connect(_on_back_pressed)
	buttons.add_child(back_btn)

	_log = RichTextLabel.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_log)

func _log_line(text: String) -> void:
	_log.append_text(text + "\n")

# ─── Actions UI ───────────────────────────────────────────────────────────────

func _on_host_pressed() -> void:
	var err := _net.host_game()
	_log_line("Héberge sur le port %d (err=%d)" % [NetTransport.DEFAULT_PORT, err])

func _on_join_pressed() -> void:
	var err := _net.join_game(_ip_field.text)
	_log_line("Rejoint %s (err=%d)" % [_ip_field.text, err])

func _on_back_pressed() -> void:
	# Coupe une éventuelle connexion en cours avant de revenir au menu.
	_net.close()
	AudioManager.play(AudioManager.CLOSE_MENU)
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

# ─── Connexion → handshake → bataille ─────────────────────────────────────────

func _on_peer_connected() -> void:
	_log_line("✓ Pair connecté — handshake…")
	_handshake = NetHandshake.new(_net, _local_deck_paths(), _net.is_host)
	add_child(_handshake)
	_handshake.completed.connect(_on_handshake_ready)
	_handshake.start()

func _on_peer_disconnected(reason: String) -> void:
	_log_line("✗ Pair déconnecté (%s)" % [reason])

# Deck local mélangé, sous forme de resource_path (identifiant partagé).
func _local_deck_paths() -> Array:
	var active := DeckManager.get_active_deck()
	if active == null:
		return []
	var paths: Array = active.card_paths.duplicate()
	paths.shuffle()
	return paths

func _on_handshake_ready(setup: Dictionary) -> void:
	_log_line("Handshake OK — lancement de la bataille réseau…")
	# Le NetworkManager doit survivre au changement de scène : on le reparente
	# sous la racine de l'arbre avant de charger Battle.
	_net.get_parent().remove_child(_net)
	get_tree().root.add_child(_net)
	NetContext.active = true
	NetContext.net = _net
	NetContext.is_host = _net.is_host
	NetContext.setup = setup
	get_tree().change_scene_to_file(BATTLE_SCENE)
