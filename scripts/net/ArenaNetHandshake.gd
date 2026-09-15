extends Node
class_name ArenaNetHandshake

# Échange d'ouverture réseau Arena — même rôle que NetHandshake.gd (1v1),
# généralisé à un quorum de N pairs en topologie étoile (voir ArenaNetTransport) :
# l'hôte attribue un seat_id stable à chaque client au fil de leur connexion
# (voir ArenaPlayerState.seat_id / ArenaMatch, Phase 1 du chantier réseau
# Arena), combine une contribution de graine RNG par pair (XOR — même principe
# que NetHandshake : aucun pair ne peut choisir seul la graine finale) et ne
# démarre la partie qu'une fois la table complète
# (ArenaConstants.PARTICIPANT_COUNT - 1 clients connectés) — ou plus tôt si
# l'hôte appelle force_start_with_bots() pour combler les sièges restants
# avec des bots (utile pour tester sans réunir 7 pairs réels).
#
# Simplification assumée pour cette étape de fondation (contrairement à
# NetHandshake) : pas de renvoi automatique du HELLO en cas de perte de
# paquet — la fiabilisation du handshake réseau reste à traiter dans une
# phase ultérieure, une fois ce protocole branché sur une vraie partie.
#
# Émis une fois la partie prête à démarrer : `setup` contient "seed" (int,
# identique pour tous), "seat_id" (le sien), "roster" (Array de
# {seat_id, display_name, is_bot}, trié par seat_id — siège 0 = hôte).
signal completed(setup: Dictionary)
signal progress(message: String)
# Hôte uniquement : nombre de vrais joueurs connectés à cet instant (voir
# force_start_with_bots) — permet à une UI de lobby d'afficher "3/7" sans
# avoir à dupliquer le comptage.
signal human_count_changed(count: int, target: int)

var _net: ArenaNetworkManager
var _is_host: bool
var _local_display_name: String
var _local_seed_contribution: int = randi()
var _finished: bool = false

# Hôte uniquement : construit au fil des HELLO reçus.
var _seat_by_peer: Dictionary = {}          # peer_id -> seat_id
var _display_name_by_seat: Dictionary = {}  # seat_id -> display_name
var _seed_by_seat: Dictionary = {}          # seat_id -> contribution
# Sièges comblés par force_start_with_bots() plutôt qu'un vrai HELLO — jamais
# dans _seat_by_peer (aucun peer_id réel ne leur correspond).
var _bot_seats: Dictionary = {}             # seat_id -> true
var _next_seat_id: int = 1                  # 0 réservé à l'hôte

# Client uniquement.
var _host_peer_id: int = 0
var _own_seat_id: int = -1

func _init(net: ArenaNetworkManager, is_host: bool, local_display_name: String) -> void:
	_net = net
	_is_host = is_host
	_local_display_name = local_display_name
	_net.command_received.connect(_on_command_received)
	if _is_host:
		# S'attribue immédiatement le siège 0 (jamais différé à start()) : un
		# HELLO peut arriver dès que le premier client se connecte, avant que
		# quoi que ce soit d'autre n'ait eu l'occasion d'appeler start() — sans
		# ça, un HELLO traité avant cette auto-inscription aurait fait démarrer
		# la partie sans la contribution de graine de l'hôte, invisible dans
		# _seed_by_seat (for seat_id in _seed_by_seat ne l'aurait simplement
		# jamais vue), et _build_roster aurait omis le siège 0.
		_display_name_by_seat[0] = _local_display_name
		_seed_by_seat[0] = _local_seed_contribution
	else:
		_net.peer_joined.connect(_on_peer_joined_as_client)

# Ne fait plus rien côté hôte (l'auto-inscription du siège 0 a lieu dans
# _init, voir ci-dessus) ; toujours un no-op côté client, qui n'a rien à
# envoyer avant d'être effectivement connecté (voir _on_peer_joined_as_client).
# Conservée pour la symétrie avec NetHandshake.start() et comme point d'entrée
# explicite pour un futur appelant.
func start() -> void:
	pass

# Hôte uniquement : seat_id attribué à ce peer_id (voir _register_client),
# ou -1 s'il n'a pas encore envoyé de HELLO. Indispensable à l'appelant
# réseau pour router une REQUEST_* entrante vers ArenaHostAuthority.apply()
# avec le bon seat_id (voir ArenaHostAuthority) — cette correspondance
# n'étant sinon exposée nulle part après le handshake.
func seat_for_peer(peer_id: int) -> int:
	return int(_seat_by_peer.get(peer_id, -1))

# Hôte uniquement : correspondance inverse — peer_id du vrai client occupant
# ce siège, ou -1 si c'est l'hôte lui-même (seat 0), un bot
# (force_start_with_bots) ou un seat_id inconnu. Indispensable pour envoyer
# un message PRIVÉ (PRIVATE_STATE_SYNC) à un siège précis en dehors du flot
# REQUEST_* -> réponse déjà couvert par ArenaHostGameRouter — notamment au
# début de chaque manche (voir ArenaHostRoundSync.broadcast_new_round).
func peer_for_seat(seat_id: int) -> int:
	for peer_id in _seat_by_peer:
		if _seat_by_peer[peer_id] == seat_id:
			return peer_id
	return -1

func cancel() -> void:
	if _finished:
		return
	_finished = true
	if _net.command_received.is_connected(_on_command_received):
		_net.command_received.disconnect(_on_command_received)

# ── Côté client ──

func _on_peer_joined_as_client(peer_id: int, _display_name: String) -> void:
	# Un seul pair possible côté client (l'hôte) : voir ArenaNetTransport —
	# send()/receive() y ignorent déjà peer_id, mais le mémoriser explicitement
	# reste correct et prêt pour une future topologie où ce ne serait plus vrai.
	_host_peer_id = peer_id
	_net.send_command(_host_peer_id, ArenaNetCommand.hello(_local_display_name, _local_seed_contribution))
	progress.emit("Handshake Arena : connecté à l'hôte, en attente d'un siège…")

# ── Réception (les deux rôles partagent le même signal) ──

func _on_command_received(peer_id: int, command: Dictionary) -> void:
	match ArenaNetCommand.type_of(command):
		ArenaNetCommand.HELLO:
			if _is_host:
				_register_client(peer_id, command)
		ArenaNetCommand.SEAT_ASSIGN:
			if not _is_host:
				_own_seat_id = int(command.get("seat_id", -1))
				progress.emit("Handshake Arena : siège %d attribué" % _own_seat_id)
		ArenaNetCommand.START_MATCH:
			if not _is_host:
				_finish(int(command.get("seed", 0)), command.get("roster", []))

# ── Côté hôte ──

func _register_client(peer_id: int, command: Dictionary) -> void:
	if _finished:
		return  # force_start_with_bots() a déjà démarré la partie sans attendre ce pair
	if _seat_by_peer.has(peer_id):
		return  # HELLO dupliqué (paquet renvoyé) : siège déjà attribué, rien à refaire
	var seat_id: int = _next_seat_id
	_next_seat_id += 1
	_seat_by_peer[peer_id] = seat_id
	_display_name_by_seat[seat_id] = str(command.get("display_name", "Joueur"))
	_seed_by_seat[seat_id] = int(command.get("seed", 0))
	_net.send_command(peer_id, ArenaNetCommand.seat_assign(seat_id))
	progress.emit("Handshake Arena : « %s » a rejoint (siège %d, %d/%d)" % [
		_display_name_by_seat[seat_id], seat_id, _seat_by_peer.size(), ArenaConstants.PARTICIPANT_COUNT - 1])
	human_count_changed.emit(_seat_by_peer.size() + 1, ArenaConstants.PARTICIPANT_COUNT)
	if _seat_by_peer.size() >= ArenaConstants.PARTICIPANT_COUNT - 1:
		_start_match()

# Hôte uniquement : comble les sièges encore vacants avec des bots (voir
# ArenaBotSeatController) et démarre la partie immédiatement, sans attendre
# ArenaConstants.PARTICIPANT_COUNT - 1 vrais joueurs — utile pour tester une
# partie réseau sans réunir 7 pairs réels (2-3 amis + des bots, ou même seul
# face à soi-même sur deux instances). No-op si la partie a déjà démarré ou
# si la table est déjà complète de vrais joueurs.
func force_start_with_bots() -> void:
	if not _is_host or _finished:
		return
	var bot_number := 1
	while _display_name_by_seat.size() < ArenaConstants.PARTICIPANT_COUNT:
		var seat_id: int = _next_seat_id
		_next_seat_id += 1
		_display_name_by_seat[seat_id] = "Bot %d" % bot_number
		_bot_seats[seat_id] = true
		bot_number += 1
	_start_match()

func _start_match() -> void:
	var combined_seed: int = 0
	for seat_id in _seed_by_seat:
		combined_seed ^= int(_seed_by_seat[seat_id])
	var roster: Array = _build_roster()
	_net.broadcast_command(ArenaNetCommand.start_match(combined_seed, roster))
	_finish(combined_seed, roster)

func _build_roster() -> Array:
	var seat_ids: Array = _display_name_by_seat.keys()
	seat_ids.sort()
	var roster: Array = []
	for seat_id in seat_ids:
		roster.append({
			"seat_id": seat_id,
			"display_name": _display_name_by_seat[seat_id],
			"is_bot": _bot_seats.has(seat_id),
		})
	return roster

func _finish(seed: int, roster: Array) -> void:
	if _finished:
		return
	_finished = true
	if _net.command_received.is_connected(_on_command_received):
		_net.command_received.disconnect(_on_command_received)
	completed.emit({
		"seed": seed,
		"seat_id": 0 if _is_host else _own_seat_id,
		"roster": roster,
	})
