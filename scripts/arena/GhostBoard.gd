extends RefCounted
class_name GhostBoard

# Snapshot figé du plateau du dernier joueur éliminé (README « Ghost Board »).
# Ce n'est PAS une possession réelle de cartes : les vraies cartes du joueur
# retournent au pool séparément (ArenaMatch._eliminate) ; ce snapshot est une
# copie indépendante utilisée uniquement pour combler l'appariement à
# effectif impair. Il ne peut jamais être modifié après capture (pas de
# scaling) et n'est jamais lui-même éliminé/remplacé, seulement écrasé par un
# nouveau capture() quand un autre joueur est éliminé.

var origin_player_name: String = ""
var front: Array[Minion] = []
var back: Array[Minion] = []

static func capture(player: ArenaPlayerState) -> GhostBoard:
	var ghost := GhostBoard.new()
	ghost.origin_player_name = player.display_name
	for m in player.board_front:
		ghost.front.append(_clone(m))
	for m in player.board_back:
		ghost.back.append(_clone(m))
	return ghost

static func _clone(m: Minion) -> Minion:
	var clone := Minion.new(m.card_data, false, m.board_row)
	clone.base_attack = m.base_attack
	clone.base_max_health = m.base_max_health
	clone.star_level = m.star_level
	return clone
