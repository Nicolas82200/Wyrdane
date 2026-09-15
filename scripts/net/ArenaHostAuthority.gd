extends RefCounted
class_name ArenaHostAuthority

# Applique côté HÔTE une REQUEST_* reçue d'un client (voir ArenaGameCommand)
# à l'ArenaMatch AUTORITAIRE, puis produit LES DEUX messages de résultat :
# `result.public` (BOARD_SYNC, à diffuser à tous) et `result.private`
# (PRIVATE_STATE_SYNC, à envoyer UNIQUEMENT au peer_id du siège concerné —
# voir ArenaGameCommand pour pourquoi les deux sont indispensables : sans le
# second, un client n'apprendrait jamais ce qu'il a reçu en boutique, son or
# restant, ni même si son action a réellement réussi).
#
# Pur (aucun état propre) : opère sur l'ArenaMatch et le seat_id passés en
# paramètre, comme ArenaBotDriver/ArenaEconomy. Ne valide PAS que l'appelant
# a le droit d'agir au nom de ce seat_id (un client ne devrait envoyer de
# REQUEST_* que pour son propre siège) — cette vérification d'autorisation
# revient à l'appelant (le futur point d'entrée réseau qui connaît la
# correspondance peer_id -> seat_id établie par ArenaNetHandshake.seat_for_peer),
# pas à cette classe qui ne fait qu'exécuter une action déjà autorisée.

static func apply(match_: ArenaMatch, seat_id: int, command: Dictionary) -> Dictionary:
	var player: ArenaPlayerState = match_.find_by_seat(seat_id)
	if player == null:
		return {}
	match ArenaGameCommand.type_of(command):
		ArenaGameCommand.REQUEST_BUY:
			match_.buy_card(player, int(command.get("shop_index", -1)))
		ArenaGameCommand.REQUEST_SELL_FROM_HAND:
			var hand_minion: Minion = _hand_minion_at(player, int(command.get("hand_index", -1)))
			if hand_minion != null:
				match_.sell_card(player, hand_minion, false)
		ArenaGameCommand.REQUEST_SELL_FROM_BOARD:
			var board_minion: Minion = _board_minion_at(player, bool(command.get("is_front", true)), int(command.get("board_index", -1)))
			if board_minion != null:
				match_.sell_card(player, board_minion, true)
		ArenaGameCommand.REQUEST_REROLL:
			match_.reroll(player)
		ArenaGameCommand.REQUEST_BUY_XP:
			match_.buy_xp(player)
		ArenaGameCommand.REQUEST_TOGGLE_FREEZE:
			player.toggle_shop_freeze()
		ArenaGameCommand.REQUEST_PLACE:
			var to_place: Minion = _hand_minion_at(player, int(command.get("hand_index", -1)))
			if to_place != null:
				player.place_on_board(to_place, bool(command.get("is_front", true)), int(command.get("index", -1)))
		ArenaGameCommand.REQUEST_MOVE:
			var to_move: Minion = _board_minion_at(player, bool(command.get("is_front_from", true)), int(command.get("board_index_from", -1)))
			if to_move != null:
				player.move_on_board(to_move, bool(command.get("is_front_to", true)), int(command.get("index_to", -1)))
		_:
			return {}
	return {
		"public": ArenaGameCommand.board_sync(
			seat_id, player.hero_hp,
			ArenaBoardSnapshot.serialize_row(player.board_front),
			ArenaBoardSnapshot.serialize_row(player.board_back)),
		"private": ArenaPrivateStateSnapshot.build(player),
	}

static func _hand_minion_at(player: ArenaPlayerState, index: int) -> Minion:
	if index < 0 or index >= player.hand.size():
		return null
	return player.hand[index]

static func _board_minion_at(player: ArenaPlayerState, is_front: bool, index: int) -> Minion:
	var row: Array[Minion] = player.board_row(is_front)
	if index < 0 or index >= row.size():
		return null
	return row[index]
