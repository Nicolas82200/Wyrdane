extends RefCounted
class_name ArenaPrivateStateSnapshot

# Sérialise l'état PRIVÉ d'un siège Arena pour le réseau (voir
# ArenaGameCommand.PRIVATE_STATE_SYNC) — jamais diffusé, envoyé uniquement au
# siège concerné (contrairement à ArenaBoardSnapshot, public). Couvre tout ce
# que BOARD_SYNC ne transmet jamais : main, Incantations achetées, offre de
# boutique, or/XP/niveau/gel — sans ce message, un client n'aurait aucun
# moyen de savoir ce qu'il a reçu en boutique ou combien d'or il lui reste
# (voir ArenaGameCommand pour le contexte complet de cette lacune).

# `cards` : Array[CardData] pouvant contenir des null (case de boutique déjà
# achetée, voir ArenaMatch.buy_card qui vide l'entrée sans retirer la case).
static func serialize_card_refs(cards: Array) -> Array:
	var out: Array = []
	for card in cards:
		out.append(card.resource_path if card != null else "")
	return out

# Une entrée vide ("") redevient null (case de boutique vide) plutôt qu'une
# carte refusée par NetCardResolver — la distinction compte pour l'affichage
# (case vide vs carte invalide).
static func deserialize_card_refs(paths: Array) -> Array[CardData]:
	var out: Array[CardData] = []
	for raw in paths:
		var path: String = str(raw)
		out.append(NetCardResolver.resolve(path) if path != "" else null)
	return out

static func build(player: ArenaPlayerState) -> Dictionary:
	return ArenaGameCommand.private_state_sync(
		player.seat_id,
		player.gold, player.xp, player.level, player.shop_frozen,
		ArenaBoardSnapshot.serialize_row(player.hand),
		serialize_card_refs(player.spell_hand),
		serialize_card_refs(player.shop_offer))
