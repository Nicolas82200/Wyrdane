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

var _net: NetworkManager
var _local_deck: Array = []
var _is_host: bool = false

var _sent: bool = false
var _remote_deck: Array = []
var _remote_received: bool = false
var _seed: int = 0
var _first_player_is_host: bool = true

func _init(net: NetworkManager, local_deck_paths: Array, is_host: bool) -> void:
	_net = net
	_local_deck = local_deck_paths
	_is_host = is_host
	if _is_host:
		_seed = randi()
		_first_player_is_host = randi() % 2 == 0
	_net.command_received.connect(_on_command_received)

# Lance l'échange : envoie le HELLO local. L'hôte y joint seed + premier joueur.
func start() -> void:
	if _sent:
		return
	var hello := NetCommand.hello(_local_deck, _local_start_id(), _local_stride(), _seed)
	if _is_host:
		hello["first_player_is_host"] = _first_player_is_host
	_net.send_command(hello)
	_sent = true
	_try_finish()

# ─── Réception ────────────────────────────────────────────────────────────────

func _on_command_received(command: Dictionary) -> void:
	if NetCommand.type_of(command) != NetCommand.HELLO:
		return
	print("[NetHandshake] HELLO reçu  self=%s  sent=%s  remote_received_avant=%s" % [self, _sent, _remote_received])
	_remote_deck = command.get("deck", [])
	_remote_received = true
	# L'invité adopte les paramètres partagés décidés par l'hôte.
	if not _is_host:
		_seed = command.get("seed", 0)
		_first_player_is_host = command.get("first_player_is_host", true)
	_try_finish()

func _try_finish() -> void:
	if _sent and _remote_received:
		_finish()

func _finish() -> void:
	print("[NetHandshake] _finish  self=%s" % [self])
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
