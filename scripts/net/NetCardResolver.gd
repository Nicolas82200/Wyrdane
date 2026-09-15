extends RefCounted
class_name NetCardResolver

# Résout une carte reçue du réseau à partir de son resource_path — utilisé
# par NetworkOpponent (1v1) et ArenaBoardSnapshot (Arena) : factorisé pour
# que cette vérification de sécurité (chemin restreint au dossier des
# cartes, jetons d'invocation refusés — un pair ne doit jamais pouvoir faire
# charger un chemin arbitraire du projet, ni transmettre un jeton qu'il n'a
# normalement pas le droit de désigner) ne soit pas dupliquée et ne risque
# pas de diverger entre les deux modes.

const CARDS_RESOURCE_PREFIX := "res://resources/cards/"

static func resolve(path: String) -> CardData:
	if not path.begins_with(CARDS_RESOURCE_PREFIX) or not path.ends_with(".tres"):
		push_warning("NetCardResolver : chemin de carte refusé '%s'" % path)
		return null
	var card: CardData = load(path) as CardData
	if card == null:
		push_warning("NetCardResolver : carte introuvable '%s'" % path)
		return null
	if card.is_token:
		push_warning("NetCardResolver : jeton refusé '%s'" % path)
		return null
	return card
