extends Node
class_name NetSessionSystem

# Session réseau d'une bataille : bascule Battle en mode réseau (adversaire
# distant, émission des actions locales, alignement RNG/registry sur le
# handshake), réagit aux coupures/reconnexions du transport, et ferme
# proprement la connexion en quittant/rejouant un match.

var battle

func init(_battle) -> void:
	battle = _battle

# Bascule la bataille en mode réseau : l'adversaire devient un joueur distant
# (NetworkOpponent), les actions locales sont émises (NetEmitter), et le
# NetRegistry / la graine RNG sont alignés sur le handshake.
func setup() -> void:
	var net: NetworkManager = NetContext.net
	var setup: Dictionary = NetContext.setup
	battle.network_manager = net
	# RNG de jeu déterministe et partagé entre les deux clients.
	battle.game_rng.seed = setup.get("seed", 0)
	battle.net_registry.configure(setup.get("parity_start", 1), setup.get("parity_stride", 1))
	battle.net_local_first = setup.get("local_first", true)
	battle.net_opponent_backend_id = setup.get("opponent_backend_id", 0)
	battle.net_client_match_id = setup.get("client_match_id", "")
	battle.net_emitter = NetEmitter.new(net)
	net.connection_lost.connect(_on_connection_lost)
	net.connection_restored.connect(_on_connection_restored)
	net.peer_disconnected.connect(_on_peer_disconnected)
	var netopp := NetworkOpponent.new(net)
	battle.add_child(netopp)
	netopp.init(battle)
	battle.opponent = netopp

# Coupure réseau transitoire détectée (Wifi, P2P Steam) : on met le match en
# pause (fige le décompte de tour et bloque les inputs) sans l'arrêter — une
# reconnexion est tentée en arrière-plan par NetworkManager pendant son délai
# de grâce. Si elle échoue, _on_peer_disconnected prend le relais.
func _on_connection_lost(_reason: String) -> void:
	if battle.game_over:
		return
	battle.reconnecting = true
	battle.turn_timer.stop()
	battle.reconnect_overlay.show_overlay(NetworkManager.RECONNECT_GRACE_SECONDS)

# Reconnexion réussie dans le délai de grâce : le match reprend là où il en était.
func _on_connection_restored() -> void:
	if battle.game_over:
		return
	battle.reconnecting = false
	battle.reconnect_overlay.hide_overlay()
	if not battle.enemy_turn_active and not battle._mulligan_active:
		battle.turn_timer.start()

# Pair définitivement perdu (délai de grâce de reconnexion expiré, ou coupure
# non transitoire) : on stoppe le match et on affiche l'écran de fin en mode
# déconnexion (retour au menu uniquement, rejouer n'a pas de sens sans le pair).
func _on_peer_disconnected(_reason: String) -> void:
	if battle.game_over:
		return
	battle.game_over = true
	battle.reconnecting = false
	battle.reconnect_overlay.hide_overlay()
	battle.enemy_turn_active = false
	battle.turn_timer.stop()
	battle._show_game_over("disconnect")

# Ferme proprement la connexion réseau (appelé en quittant ou en rejouant un
# match) : prévient le pair (voir NetCommand.leave_match) pour qu'il ne
# poursuive pas inutilement le délai de grâce de reconnexion, puis libère le
# transport reparenté sous la racine. No-op en solo.
func close() -> void:
	if battle.network_manager != null:
		battle.network_manager.send_command(NetCommand.leave_match())
		battle.network_manager.close()
		battle.network_manager.queue_free()
		battle.network_manager = null
	NetContext.clear()
