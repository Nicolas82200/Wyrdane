extends Node
class_name ArenaNetworkManager

# Chef d'orchestre réseau Arena — même rôle que NetworkManager.gd (1v1),
# généralisé à N pairs : se place au-dessus d'ArenaNetTransport, ne connaît
# jamais le backend concret (Steam). Sérialise/désérialise les commandes
# (Dictionary <-> octets) et les route, en identifiant systématiquement le
# pair concerné (`peer_id`) — contrairement au 1v1 où le pair est implicite
# (un seul possible). Gardé séparé de NetworkManager.gd (voir ArenaNetTransport
# pour la justification).
#
# Pas de reconnexion automatique pour l'instant (contrairement au 1v1,
# NetworkManager.RECONNECT_GRACE_SECONDS) : un pair qui décroche est
# simplement signalé via peer_left — la robustesse réseau (reconnexion,
# tolérance aux pairs manquants) reste à traiter dans une phase ultérieure.

signal peer_joined(peer_id: int, display_name: String)
signal peer_left(peer_id: int, reason: String)
signal command_received(peer_id: int, command: Dictionary)
signal status(message: String)
signal disconnected(reason: String)
signal session_ready(session_id: int)

var transport: ArenaNetTransport = null
var is_host: bool = false

# Même limite que NetworkManager.MAX_PACKET_BYTES (voir sa justification).
const MAX_PACKET_BYTES := 262144  # 256 Ko

func host_game_with(backend: ArenaTransportFactory.Backend, params: Dictionary = {}) -> int:
	set_transport(ArenaTransportFactory.create(backend))
	is_host = true
	return transport.host(params)

func join_game_with(backend: ArenaTransportFactory.Backend, params: Dictionary = {}) -> int:
	set_transport(ArenaTransportFactory.create(backend))
	is_host = false
	return transport.join(params)

# Point d'injection : utilisé en production par host_game_with/join_game_with
# (via ArenaTransportFactory), et directement par les tests pour brancher un
# transport simulé (voir tests/unit/doubles/fake_arena_net_transport.gd) sans
# dépendre de Steam — voir CLAUDE.md « Tests automatisés ».
func set_transport(t: ArenaNetTransport) -> void:
	if transport != null:
		transport.close()
		transport.queue_free()
	transport = t
	add_child(transport)
	transport.peer_joined.connect(func(peer_id: int, display_name: String) -> void: peer_joined.emit(peer_id, display_name))
	transport.peer_left.connect(func(peer_id: int, reason: String) -> void: peer_left.emit(peer_id, reason))
	transport.packet_received.connect(_on_packet_received)
	transport.status.connect(func(message: String) -> void: status.emit(message))
	transport.disconnected.connect(func(reason: String) -> void: disconnected.emit(reason))
	transport.session_ready.connect(func(session_id: int) -> void: session_ready.emit(session_id))

func send_command(peer_id: int, command: Dictionary, reliable: bool = true) -> void:
	if transport == null:
		return
	transport.send(peer_id, var_to_bytes(command), reliable)

func broadcast_command(command: Dictionary, reliable: bool = true) -> void:
	if transport == null:
		return
	transport.broadcast(var_to_bytes(command), reliable)

func close() -> void:
	if transport != null:
		transport.close()

func connected_peer_ids() -> Array[int]:
	return transport.connected_peer_ids() if transport != null else []

# ─── Interne ──────────────────────────────────────────────────────────────────

func _on_packet_received(peer_id: int, bytes: PackedByteArray) -> void:
	if bytes.size() > MAX_PACKET_BYTES:
		push_warning("ArenaNetworkManager : paquet ignoré (%d octets > limite)" % bytes.size())
		return
	# allow_objects reste false (défaut) : jamais d'objets arbitraires désérialisés
	# depuis le réseau, uniquement des types de base (sécurité).
	var command: Variant = bytes_to_var(bytes)
	if not (command is Dictionary):
		return
	command_received.emit(peer_id, command)

func _process(_delta: float) -> void:
	if transport != null:
		transport.poll()
