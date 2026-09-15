extends RefCounted
class_name ArenaPrivateStateMirror

# Applique un PRIVATE_STATE_SYNC reçu (voir ArenaGameCommand/
# ArenaPrivateStateSnapshot) à SON PROPRE ArenaPlayerState local — ce message
# n'est jamais reçu pour le siège d'un autre participant (l'hôte ne
# l'envoie qu'au siège concerné), contrairement à ArenaRemoteBoardMirror qui
# reflète le plateau public de N'IMPORTE QUEL siège.
#
# Pur : ne fait que réécrire l'état depuis le contenu du message — aucune
# validation de règle ici (déjà faite côté hôte par ArenaHostAuthority avant
# l'envoi), le client ne fait que refléter ce que l'hôte a déjà validé.

static func apply(player: ArenaPlayerState, command: Dictionary) -> void:
	player.gold = int(command.get("gold", player.gold))
	player.xp = int(command.get("xp", player.xp))
	player.level = int(command.get("level", player.level))
	player.shop_frozen = bool(command.get("shop_frozen", player.shop_frozen))
	player.hand = ArenaBoardSnapshot.deserialize_row(command.get("hand", []), true)
	player.spell_hand = ArenaPrivateStateSnapshot.deserialize_card_refs(command.get("spell_hand", []))
	player.shop_offer = ArenaPrivateStateSnapshot.deserialize_card_refs(command.get("shop_offer", []))
