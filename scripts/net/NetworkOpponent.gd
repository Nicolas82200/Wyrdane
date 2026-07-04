extends OpponentDriver
class_name NetworkOpponent

# Implémentation réseau d'OpponentDriver : le camp adverse est un joueur distant.
# On ne DÉCIDE rien ici — on reçoit ses commandes via NetworkManager et on les
# REJOUE localement sur le plateau, dans l'ordre, jusqu'à END_TURN.
#
# Interchangeable avec AISystem : TurnSystem.end_turn() appelle
# battle.opponent.take_turn() sans savoir si l'adversaire est l'IA ou le réseau.

var net: NetworkManager
# Commandes du tour distant reçues mais pas encore rejouées (FIFO).
var _queue: Array[Dictionary] = []
var _turn_over: bool = false

func _init(network_manager: NetworkManager) -> void:
	net = network_manager
	net.command_received.connect(_on_command_received)

# ─── OpponentDriver ───────────────────────────────────────────────────────────

func setup() -> void:
	# Deck adverse, parité d'ids et main de départ sont fixés par le handshake
	# HELLO (brique suivante).
	pass

# Attend et rejoue le tour du joueur distant, commande par commande, jusqu'à
# recevoir END_TURN, puis rend la main à TurnSystem.
func take_turn() -> void:
	_turn_over = false
	while not _turn_over:
		while not _queue.is_empty():
			var cmd: Dictionary = _queue.pop_front()
			if NetCommand.type_of(cmd) == NetCommand.END_TURN:
				_turn_over = true
				break
			await _apply(cmd)
			await battle.pace_actions()
		if not _turn_over:
			# Rien à rejouer pour l'instant : on attend le prochain paquet.
			await battle.get_tree().process_frame

func refresh_ui() -> void:
	pass

# ─── Réception ────────────────────────────────────────────────────────────────

func _on_command_received(command: Dictionary) -> void:
	if not NetCommand.is_valid(command):
		return
	match NetCommand.type_of(command):
		NetCommand.HELLO:
			# Handshake : traité hors de la file de tour (brique suivante).
			pass
		_:
			_queue.append(command)

# ─── Rejeu ────────────────────────────────────────────────────────────────────

# Applique une commande distante au camp ennemi. Chaque branche réutilisera les
# systèmes existants (BoardSystem, CombatSystem, TurnSystem) en désignant les
# serviteurs par net_id via battle.net_registry.resolve().
func _apply(cmd: Dictionary) -> void:
	match NetCommand.type_of(cmd):
		NetCommand.TURN_CHOICE:
			pass  # TODO: rejouer le choix mana/pioche côté ennemi
		NetCommand.PLAY_CARD:
			pass  # TODO: invoquer/lancer côté ennemi avec net_id imposé
		NetCommand.ATTACK:
			pass  # TODO: résoudre l'attaque entre net_ids via CombatSystem
		NetCommand.ATTACK_HERO:
			pass  # TODO: attaque du héros joueur via CombatSystem
		_:
			push_warning("NetworkOpponent : commande non gérée '%s'" % NetCommand.type_of(cmd))
