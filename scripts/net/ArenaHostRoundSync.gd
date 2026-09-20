extends RefCounted
class_name ArenaHostRoundSync

# Diffuse à tous les clients l'état consécutif au déroulé d'une manche côté
# hôte — deux moments distincts, appelés à la suite par ArenaBattle (hôte
# uniquement) :
#
# 1. `broadcast_combat_result`, juste après match_.start_combat_phase() et
#    AVANT match_.advance_round() : un BOARD_SYNC pour CHAQUE siège (le combat
#    peut changer le plateau/PV de n'importe qui, pas seulement celui qui a
#    demandé quelque chose — ArenaHostGameRouter, qui ne répond qu'à
#    l'émetteur d'une REQUEST_*, ne suffit pas ici), puis GAME_OVER
#    (classement final) si la partie est terminée.
#
# 2. `broadcast_new_round`, juste après match_.advance_round() +
#    match_.start_shop_phase() (si la partie continue) : ROUND_ADVANCED
#    (nouveau round_number + le résumé texte du combat qui vient de se jouer,
#    capturé par l'appelant AVANT advance_round() — voir ArenaBattle) suivi
#    d'un PRIVATE_STATE_SYNC pour chaque vrai siège (sa nouvelle offre de
#    boutique, son or/XP/niveau après gain automatique de début de manche —
#    voir ArenaMatch.start_shop_phase) ; rien n'est envoyé aux sièges bot
#    (aucun peer_id réel, voir ArenaNetHandshake.peer_for_seat).
#
# Appelée UNE SEULE FOIS au lancement de la partie aussi (round 1), avec un
# combat_log vide — voir ArenaBattle._start_network_match.

static func broadcast_combat_result(match_: ArenaMatch, net: ArenaNetworkManager) -> void:
	for player in match_.players:
		net.broadcast_command(ArenaGameCommand.board_sync(
			player.seat_id, player.hero_hp,
			ArenaBoardSnapshot.serialize_row(player.board_front),
			ArenaBoardSnapshot.serialize_row(player.board_back)))
	if match_.is_match_over():
		net.broadcast_command(ArenaGameCommand.game_over(_serialize_ranking(match_.final_ranking())))

static func broadcast_new_round(match_: ArenaMatch, net: ArenaNetworkManager, peer_for_seat: Callable, combat_log: Array) -> void:
	net.broadcast_command(ArenaGameCommand.round_advanced(match_.round_number, combat_log))
	for player in match_.players:
		if player.is_bot:
			continue
		var peer_id: int = int(peer_for_seat.call(player.seat_id))
		if peer_id < 0:
			continue  # siège 0 (l'hôte lui-même) : rien à s'envoyer par le réseau
		net.send_command(peer_id, ArenaPrivateStateSnapshot.build(player))

static func _serialize_ranking(ranking: Array) -> Array:
	var out: Array = []
	for player in ranking:
		out.append({"seat_id": player.seat_id, "display_name": player.display_name})
	return out
