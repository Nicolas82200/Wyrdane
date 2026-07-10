extends Node
class_name NetworkManager

# Chef d'orchestre réseau. Se place AU-DESSUS du transport : il ne connaît que
# l'interface NetTransport, jamais ENet ou Steam directement. Rôle du socle
# actuel : établir la connexion, sérialiser/désérialiser les commandes de jeu
# (Dictionary <-> octets) et les router.
#
# Les étapes suivantes (handshake decks, qui commence, rejeu des commandes)
# viendront se brancher sur les signaux ci-dessous.

signal peer_connected()
signal peer_disconnected(reason: String)
signal command_received(command: Dictionary)
# Relais du diagnostic de connexion du transport (affiché au lobby).
signal status(message: String)

var transport: NetTransport = null
var is_host: bool = false

func host_game(port: int = NetTransport.DEFAULT_PORT,
		backend: TransportFactory.Backend = TransportFactory.Backend.ENET) -> int:
	return host_game_with(backend, {"port": port})

func join_game(ip: String, port: int = NetTransport.DEFAULT_PORT,
		backend: TransportFactory.Backend = TransportFactory.Backend.ENET) -> int:
	return join_game_with(backend, {"ip": ip, "port": port})

# Variantes génériques : params opaque interprété par le backend
# (ENet : ip/port ; Steam : lobby_id optionnel, sinon partie rapide).
func host_game_with(backend: TransportFactory.Backend, params: Dictionary = {}) -> int:
	_setup_transport(backend)
	is_host = true
	return transport.host(params)

func join_game_with(backend: TransportFactory.Backend, params: Dictionary = {}) -> int:
	_setup_transport(backend)
	is_host = false
	return transport.join(params)

# Envoie une commande de jeu (SUMMON, ATTACK, END_TURN...) au pair distant.
func send_command(command: Dictionary, reliable: bool = true) -> void:
	if transport == null:
		return
	transport.send(var_to_bytes(command), reliable)

func close() -> void:
	if transport != null:
		transport.close()

# ─── Interne ──────────────────────────────────────────────────────────────────

func _setup_transport(backend: TransportFactory.Backend) -> void:
	print("[NetworkManager] _setup_transport  ancien_transport=%s" % [transport])
	if transport != null:
		transport.close()
		transport.queue_free()
	transport = TransportFactory.create(backend)
	add_child(transport)
	transport.connected.connect(func() -> void: 
		print("[NetworkManager] transport.connected reçu")
		peer_connected.emit())
	transport.disconnected.connect(func(reason: String) -> void: peer_disconnected.emit(reason))
	transport.packet_received.connect(_on_packet_received)
	transport.status.connect(func(message: String) -> void: status.emit(message))

func _on_packet_received(bytes: PackedByteArray) -> void:
	# allow_objects reste false (défaut) : on ne désérialise jamais d'objets
	# arbitraires venant du réseau — uniquement des types de base (sécurité).
	var command: Variant = bytes_to_var(bytes)
	if command is Dictionary:
		command_received.emit(command)

func _process(_delta: float) -> void:
	if transport != null:
		transport.poll()
