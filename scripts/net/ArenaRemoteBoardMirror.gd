extends RefCounted
class_name ArenaRemoteBoardMirror

# Applique un BOARD_SYNC reçu (état public d'un siège, voir ArenaGameCommand/
# ArenaHostAuthority) à l'ArenaPlayerState correspondant — utilisé par tout
# client (l'hôte compris, pour les sièges qu'il ne pilote pas directement)
# afin de garder le plateau de chaque participant à jour, SANS jamais
# connaître sa main ni sa boutique (strictement privées, voir README
# « Réseau & Visibilité »).
#
# Pur : ne fait que réécrire board_front/board_back/hero_hp depuis le
# contenu du message — aucune validation de règle ici (déjà faite côté hôte
# par ArenaHostAuthority avant diffusion), un client ne fait que refléter ce
# que l'hôte a déjà validé.

static func apply(match_: ArenaMatch, command: Dictionary) -> void:
	var seat_id: int = int(command.get("seat_id", -1))
	var player: ArenaPlayerState = match_.find_by_seat(seat_id)
	if player == null:
		return
	player.hero_hp = int(command.get("hero_hp", player.hero_hp))
	player.board_front = ArenaBoardSnapshot.deserialize_row(command.get("front", []), true)
	player.board_back = ArenaBoardSnapshot.deserialize_row(command.get("back", []), false)
