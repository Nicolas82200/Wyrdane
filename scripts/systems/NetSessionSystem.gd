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
	battle.net_match_session_token = setup.get("match_session_token", "")
	battle.net_emitter = NetEmitter.new(net, battle)
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
		battle.afk_guard.resume_turn_timer()

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
# poursuive pas inutilement le délai de grâce de reconnexion, puis ferme le
# transport. battle.network_manager n'est qu'un emprunt de l'instance
# NetworkManager vivant sous l'autoload MatchmakingOverlay (voir
# MatchmakingOverlay._net/_on_handshake_ready) : ne jamais la queue_free()
# ici, sous peine de laisser MatchmakingOverlay avec une référence libérée et
# de rendre toute partie/invitation suivante impossible pour le reste de la
# session. NetworkManager.close() suffit (ferme juste le transport, le nœud
# reste réutilisable pour le prochain host_game_with/join_game_with). No-op
# en solo.
func close() -> void:
	if battle.network_manager != null:
		var net: NetworkManager = battle.network_manager
		net.send_command(NetCommand.leave_match())
		net.close()
		# NetworkManager est une instance persistante réutilisée par toute la
		# session (voir note plus haut) : sans ces déconnexions explicites, ce
		# NetSessionSystem (et le PactChoiceSystem de cette même bataille,
		# maintenant terminée) restaient abonnés à ses signaux et continuaient
		# à réagir aux parties suivantes une fois la scène Battle détruite —
		# cause du "SCRIPT ERROR: ... on a base object of type 'previously
		# freed'" et de désynchronisations observées en partie réelle après
		# plusieurs reconnexions dans la même session.
		if net.connection_lost.is_connected(_on_connection_lost):
			net.connection_lost.disconnect(_on_connection_lost)
		if net.connection_restored.is_connected(_on_connection_restored):
			net.connection_restored.disconnect(_on_connection_restored)
		if net.peer_disconnected.is_connected(_on_peer_disconnected):
			net.peer_disconnected.disconnect(_on_peer_disconnected)
		if is_instance_valid(battle) and battle.pact_choice_system != null:
			battle.pact_choice_system.cleanup()
		battle.network_manager = null
	NetContext.clear()
