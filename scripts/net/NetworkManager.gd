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
# Coupure transitoire détectée : le match se met en pause, une reconnexion est
# tentée pendant RECONNECT_GRACE_SECONDS avant d'abandonner (peer_disconnected).
signal connection_lost(reason: String)
# La reconnexion a réussi dans le délai de grâce : le match peut reprendre.
signal connection_restored()

var transport: NetTransport = null
var is_host: bool = false

# Raisons de coupure considérées transitoires (perte réseau, P2P Steam qui
# lâche) : on tente une reconnexion avant d'abandonner. Toute autre raison
# (départ volontaire du lobby, échec de recherche...) est traitée en direct
# comme définitive — voir NetLobby et SteamTransport pour leur origine.
const RECONNECTABLE_REASONS := ["peer_disconnected", "steam_p2p_failed"]
const RECONNECT_GRACE_SECONDS := 20.0
const RECONNECT_RETRY_INTERVAL := 2.0

var _last_join_params: Dictionary = {}
var _reconnecting := false
var _reconnect_elapsed := 0.0
var _reconnect_retry_elapsed := 0.0
var _pending_disconnect_reason := ""

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
	_last_join_params = params
	return transport.join(params)

# Envoie une commande de jeu (SUMMON, ATTACK, END_TURN...) au pair distant.
func send_command(command: Dictionary, reliable: bool = true) -> void:
	if transport == null:
		return
	transport.send(var_to_bytes(command), reliable)

func close() -> void:
	if transport != null:
		transport.close()

# Ouvre l'UI d'invitation d'amis du backend actif (no-op si aucun transport
# ou si le backend ne le supporte pas — voir NetTransport.invite_friends).
func invite_friends() -> void:
	if transport != null:
		transport.invite_friends()

# ─── Interne ──────────────────────────────────────────────────────────────────

func _setup_transport(backend: TransportFactory.Backend) -> void:
	print("[NetworkManager] _setup_transport  ancien_transport=%s" % [transport])
	if transport != null:
		transport.close()
		transport.queue_free()
	transport = TransportFactory.create(backend)
	add_child(transport)
	_reconnecting = false
	transport.connected.connect(func() -> void:
		print("[NetworkManager] transport.connected reçu")
		if _reconnecting:
			_reconnecting = false
			connection_restored.emit()
		else:
			peer_connected.emit())
	transport.disconnected.connect(_on_transport_disconnected)
	transport.packet_received.connect(_on_packet_received)
	transport.status.connect(func(message: String) -> void: status.emit(message))

func _on_transport_disconnected(reason: String) -> void:
	if _reconnecting:
		return
	if not (reason in RECONNECTABLE_REASONS):
		peer_disconnected.emit(reason)
		return
	_reconnecting = true
	_reconnect_elapsed = 0.0
	_reconnect_retry_elapsed = 0.0
	_pending_disconnect_reason = reason
	connection_lost.emit(reason)

func _on_packet_received(bytes: PackedByteArray) -> void:
	# allow_objects reste false (défaut) : on ne désérialise jamais d'objets
	# arbitraires venant du réseau — uniquement des types de base (sécurité).
	var command: Variant = bytes_to_var(bytes)
	if not (command is Dictionary):
		return
	if command.get("type", "") == NetCommand.LEAVE_MATCH:
		# Départ volontaire du pair : pas de tentative de reconnexion, la partie
		# est terminée pour de bon, immédiatement.
		_reconnecting = false
		peer_disconnected.emit("peer_left_match")
		return
	command_received.emit(command)

func _process(delta: float) -> void:
	if transport != null:
		transport.poll()
	if not _reconnecting:
		return
	_reconnect_elapsed += delta
	if _reconnect_elapsed >= RECONNECT_GRACE_SECONDS:
		_reconnecting = false
		peer_disconnected.emit(_pending_disconnect_reason)
		return
	# Seul le rejoignant retente activement : l'hôte reste passif, son socket
	# d'écoute accepte déjà une nouvelle connexion sans action de sa part.
	if is_host:
		return
	_reconnect_retry_elapsed += delta
	if _reconnect_retry_elapsed >= RECONNECT_RETRY_INTERVAL:
		_reconnect_retry_elapsed = 0.0
		transport.try_reconnect(_last_join_params)
