extends Node
class_name NetHandshake

# Échange d'ouverture entre les deux clients, juste après la connexion et avant
# le premier tour. Chaque client envoie son deck (liste de resource_path déjà
# mélangée) ; l'hôte fait autorité sur les paramètres partagés de la partie :
# la graine RNG (pour que tous les tirages aléatoires soient identiques) et le
# joueur qui commence.
#
# La parité d'ids réseau est déduite localement de is_host (voir NetRegistry) :
#   - hôte  : 2, 4, 6...  (start=2, stride=2)
#   - invité : 3, 5, 7... (start=3, stride=2)
# Les serviteurs miroirs reçus du réseau gardent l'id imposé par l'émetteur, donc
# aucune collision possible.

# Émis quand les deux HELLO ont été échangés. setup contient tout ce qu'il faut
# pour démarrer la bataille réseau (voir _finish).
# (nommé "completed" et non "ready" : Node possède déjà un signal "ready".)
signal completed(setup: Dictionary)
# Trace lisible de l'avancement (renvois de HELLO...), affichée au lobby.
signal progress(message: String)

# Le tout premier paquet P2P peut se perdre pendant l'établissement de la
# session (Steam notamment : NAT, relais). Le HELLO est donc renvoyé
# périodiquement jusqu'à ce que le pair ait confirmé sa réception (HELLO_ACK) —
# l'échange est idempotent, les doublons sont sans effet.
const RESEND_INTERVAL := 1.0

var _net: NetworkManager
var _local_deck: Array = []
var _is_host: bool = false

var _sent: bool = false
var _remote_deck: Array = []
var _remote_received: bool = false
var _acked: bool = false
var _finished: bool = false
# Contribution locale à la graine partagée, générée avant tout échange avec le
# pair : chaque client l'envoie dans son propre HELLO sans connaître celle de
# l'autre, donc ni l'hôte ni l'invité ne peut choisir la graine finale
# unilatéralement (l'ancien schéma laissait l'hôte l'imposer seul).
var _local_seed_contribution: int = randi()
var _remote_seed_contribution: int = 0
var _seed: int = 0
var _first_player_is_host: bool = true
var _resend_clock: float = 0.0
var _resend_count: int = 0

func _init(net: NetworkManager, local_deck_paths: Array, is_host: bool) -> void:
	_net = net
	_local_deck = local_deck_paths
	_is_host = is_host
	_net.command_received.connect(_on_command_received)

# Lance l'échange : envoie le HELLO local, avec notre contribution de graine.
func start() -> void:
	if _sent:
		return
	_send_hello()
	_sent = true

# Renvoi périodique du HELLO tant que le pair n'en a pas accusé réception.
func _process(delta: float) -> void:
	if _finished or not _sent or _acked:
		return
	_resend_clock += delta
	if _resend_clock < RESEND_INTERVAL:
		return
	_resend_clock = 0.0
	_resend_count += 1
	_send_hello()
	progress.emit("Handshake : HELLO renvoyé (%d) — en attente du pair…" % _resend_count)

func _send_hello() -> void:
	var hello := NetCommand.hello(_local_deck, _local_start_id(), _local_stride(), _local_seed_contribution)
	_net.send_command(hello)

# ─── Réception ────────────────────────────────────────────────────────────────

func _on_command_received(command: Dictionary) -> void:
	match NetCommand.type_of(command):
		NetCommand.HELLO:
			print("[NetHandshake] HELLO reçu  self=%s  sent=%s  remote_received_avant=%s" % [self, _sent, _remote_received])
			_remote_deck = _sanitize_deck(command.get("deck", []))
			_remote_received = true
			# Combine notre contribution avec celle du pair (déjà envoyée avant
			# réception de la sienne, donc ni l'un ni l'autre n'a pu l'ajuster
			# après coup) : les deux clients obtiennent la même graine et le même
			# premier joueur sans qu'aucun des deux ne les impose seul.
			_remote_seed_contribution = int(command.get("seed", 0))
			_seed = _local_seed_contribution ^ _remote_seed_contribution
			# Fait global (pas relatif à "moi") : les deux clients calculent la
			# même graine combinée, donc la même valeur ici.
			_first_player_is_host = (_seed % 2) == 0
			# Confirme la réception — renvoyé aussi sur les HELLO doublons, au
			# cas où un ACK précédent se serait perdu avant la session P2P.
			_net.send_command(NetCommand.hello_ack())
			_try_finish()
		NetCommand.HELLO_ACK:
			_acked = true
			_try_finish()

# Le deck reçu ne sert qu'à afficher des compteurs cosmétiques (voir
# NetworkOpponent), mais reste stocké tel quel : on filtre les entrées non-
# String et on borne sa taille pour éviter qu'un pair n'envoie un tableau
# démesuré (déni de service local mémoire/CPU), sans chercher à valider ici
# la légalité complète du deck (copies/race), qui n'a pas d'impact sécurité.
const MAX_DECK_ENTRIES := 200

func _sanitize_deck(deck: Array) -> Array:
	var clean: Array = []
	for entry in deck:
		if entry is String:
			clean.append(entry)
		if clean.size() >= MAX_DECK_ENTRIES:
			break
	return clean

func _try_finish() -> void:
	# On ne termine que lorsque le pair a REÇU notre deck (_acked) et que nous
	# avons le sien : sans cela, un des deux camps pouvait passer en bataille
	# pendant que l'autre restait bloqué au lobby.
	if _sent and _remote_received and _acked and not _finished:
		_finish()

func _finish() -> void:
	print("[NetHandshake] _finish  self=%s" % [self])
	_finished = true
	set_process(false)
	var setup := {
		"opponent_deck": _remote_deck,
		"seed": _seed,
		"local_first": _is_host == _first_player_is_host,
		"parity_start": _local_start_id(),
		"parity_stride": _local_stride(),
	}
	_net.command_received.disconnect(_on_command_received)
	completed.emit(setup)

# ─── Parité d'ids locale ──────────────────────────────────────────────────────

func _local_start_id() -> int:
	return 2 if _is_host else 3

func _local_stride() -> int:
	return 2
