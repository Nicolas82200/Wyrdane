extends Control

# Banc d'essai du socle transport. Lancer deux instances de Godot :
#   - une clique "Héberger"
#   - l'autre saisit l'IP (127.0.0.1 en local) puis "Rejoindre"
# Une fois connectés, "Envoyer ping" fait transiter une commande de test.
#
# Scène jetable : sert uniquement à valider la couche réseau avant d'y brancher
# la logique de jeu.

var _net: NetworkManager
var _log: RichTextLabel
var _ip_field: LineEdit
var _ping_count: int = 0

func _ready() -> void:
	_net = NetworkManager.new()
	add_child(_net)
	_net.peer_connected.connect(_on_peer_connected)
	_net.peer_disconnected.connect(_on_peer_disconnected)
	_net.command_received.connect(_on_command_received)
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

	var ping_btn := Button.new()
	ping_btn.text = "Envoyer ping"
	ping_btn.pressed.connect(_on_ping_pressed)
	buttons.add_child(ping_btn)

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

func _on_ping_pressed() -> void:
	_ping_count += 1
	var cmd := {"type": "PING", "n": _ping_count}
	_net.send_command(cmd)
	_log_line("→ envoyé %s" % [cmd])

# ─── Événements réseau ────────────────────────────────────────────────────────

func _on_peer_connected() -> void:
	_log_line("✓ Pair connecté (host=%s)" % [_net.is_host])

func _on_peer_disconnected(reason: String) -> void:
	_log_line("✗ Pair déconnecté (%s)" % [reason])

func _on_command_received(command: Dictionary) -> void:
	_log_line("← reçu %s" % [command])
