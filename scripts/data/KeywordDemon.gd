# KeywordDemon.gd
# Enum dédié aux mots-clés exclusifs à la race Démon.
# Séparé de Keyword.Type pour ne pas mélanger les pools de mots-clés par race
# (même approche que KeywordHuman.gd et KeywordUndead.gd).
extends RefCounted
class_name KeywordDemon

enum Type {
	PACTE,            # "Pacte X" — le joueur choisit de payer X PV pour activer l'effet de la carte à son déclenchement : choix unique à l'Arrivée pour un serviteur, redemandé à chaque déclenchement pour tout autre trigger (voir PactChoiceSystem).
	CORRUPTION,       # Les attaques infligent Corruption en plus des dégâts (-1 ATK permanent, cumulable).
	TERREUR,          # Quand ce serviteur attaque, la cible ne peut pas attaquer au prochain tour adverse.
	RANG_INFERNAL,    # +1/+0 par tranche de 10 HP manquants sur ton héros (aura recalculée).
	CHAIR_DE_SOUFRE,  # Immunisé à Corruption, à la peur et aux effets de contrôle mental.
	SANG_NOIR,        # +1/+0 permanent chaque fois que ton héros perd des HP à cause de tes propres cartes.
}

# Nommé get_keyword_name (et non get_name) : un static get_name est masqué
# par la méthode native Resource.get_name quand on l'appelle via la classe.
static func get_keyword_name(keyword: int) -> String:
	match keyword:
		Type.PACTE:           return TranslationServer.translate("KW_PACTE_NAME")
		Type.CORRUPTION:      return TranslationServer.translate("KW_CORRUPTION_NAME")
		Type.TERREUR:         return TranslationServer.translate("KW_TERREUR_NAME")
		Type.RANG_INFERNAL:   return TranslationServer.translate("KW_RANG_INFERNAL_NAME")
		Type.CHAIR_DE_SOUFRE: return TranslationServer.translate("KW_CHAIR_DE_SOUFRE_NAME")
		Type.SANG_NOIR:       return TranslationServer.translate("KW_SANG_NOIR_NAME")
		_:                    return "?"

static func get_description(keyword: int) -> String:
	match keyword:
		Type.PACTE:           return TranslationServer.translate("KW_PACTE_DESC")
		Type.CORRUPTION:      return TranslationServer.translate("KW_CORRUPTION_DESC")
		Type.TERREUR:         return TranslationServer.translate("KW_TERREUR_DESC")
		Type.RANG_INFERNAL:   return TranslationServer.translate("KW_RANG_INFERNAL_DESC")
		Type.CHAIR_DE_SOUFRE: return TranslationServer.translate("KW_CHAIR_DE_SOUFRE_DESC")
		Type.SANG_NOIR:       return TranslationServer.translate("KW_SANG_NOIR_DESC")
		_:                    return ""

static func from_name(keyword_name: String) -> int:
	match keyword_name:
		"PACTE":           return Type.PACTE
		"CORRUPTION":      return Type.CORRUPTION
		"TERREUR":         return Type.TERREUR
		"RANG_INFERNAL":   return Type.RANG_INFERNAL
		"CHAIR_DE_SOUFRE": return Type.CHAIR_DE_SOUFRE
		"SANG_NOIR":       return Type.SANG_NOIR
		_:                 return -1
