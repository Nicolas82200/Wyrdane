extends NetTransport
class_name ENetTransport

# Implémentation ENet du transport, pour du jeu en IP directe / LAN.
#
# On utilise ENetMultiplayerPeer EN DIRECT (put_packet/get_packet), sans passer
# par le MultiplayerAPI haut-niveau de Godot (@rpc, MultiplayerSynchronizer) :
# cela nous marierait à ENet et casserait la portabilité vers Steam. On garde
# donc notre propre canal d'octets.
#
# 1v1 : un seul pair distant. On mémorise son id pour cibler les envois.

var _peer: ENetMultiplayerPeer = null
var _remote_peer_id: int = 0

func host(params: Dictionary) -> int:
	var port: int = params.get("port", DEFAULT_PORT)
	_peer = ENetMultiplayerPeer.new()
	var err: int = _peer.create_server(port, 1)  # 1 seul client : c'est du 1v1
	if err != OK:
		_peer = null
		return err
	_connect_peer_signals()
	return OK

func join(params: Dictionary) -> int:
	var ip: String = params.get("ip", "127.0.0.1")
	var port: int = params.get("port", DEFAULT_PORT)
	_peer = ENetMultiplayerPeer.new()
	var err: int = _peer.create_client(ip, port)
	if err != OK:
		_peer = null
		return err
	_connect_peer_signals()
	return OK

func send(bytes: PackedByteArray, reliable: bool = true) -> void:
	if _peer == null or _remote_peer_id == 0:
		return
	_peer.set_transfer_mode(
		MultiplayerPeer.TRANSFER_MODE_RELIABLE if reliable
		else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)
	_peer.set_target_peer(_remote_peer_id)
	_peer.put_packet(bytes)

func poll() -> void:
	if _peer == null:
		return
	_peer.poll()
	while _peer.get_available_packet_count() > 0:
		packet_received.emit(_peer.get_packet())

func close() -> void:
	if _peer != null:
		_peer.close()
		_peer = null
	_remote_peer_id = 0

# ─── Interne ──────────────────────────────────────────────────────────────────

func _connect_peer_signals() -> void:
	_peer.peer_connected.connect(_on_peer_connected)
	_peer.peer_disconnected.connect(_on_peer_disconnected)

func _on_peer_connected(id: int) -> void:
	_remote_peer_id = id
	connected.emit()

func _on_peer_disconnected(_id: int) -> void:
	_remote_peer_id = 0
	disconnected.emit("peer_disconnected")
