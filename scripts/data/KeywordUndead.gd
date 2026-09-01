# KeywordUndead.gd
# Enum dédié aux mots-clés exclusifs à la race Mort-Vivant.
# Séparé de Keyword.Type pour ne pas mélanger les pools de mots-clés par race
# (même approche que KeywordHuman.gd).
extends RefCounted
class_name KeywordUndead

enum Type {
	PESTIFERE,    # Les attaques de ce serviteur infligent Infection en plus des dégâts.
	NECROPHAGE,   # Quand un serviteur allié meurt, ce serviteur gagne +1/+1 de façon permanente.
	HORDE,        # Tant que tu contrôles 3 Morts-Vivants ou plus, ce serviteur gagne +1/+0.
	REVENANT,     # La première fois qu'il devrait mourir, se relève avec 1 HP à la place (une fois par partie).
	CHAIR_MORTE,  # Immunisé aux effets néfastes raciaux (Infection, Corruption, Terreur). Pas immunisé aux débuffs de stats génériques ni au Gel.
}

# Nommé get_keyword_name (et non get_name) : un static get_name est masqué
# par la méthode native Resource.get_name quand on l'appelle via la classe.
static func get_keyword_name(keyword: int) -> String:
	match keyword:
		Type.PESTIFERE:   return TranslationServer.translate("KW_PESTIFERE_NAME")
		Type.NECROPHAGE:  return TranslationServer.translate("KW_NECROPHAGE_NAME")
		Type.HORDE:       return TranslationServer.translate("KW_HORDE_NAME")
		Type.REVENANT:    return TranslationServer.translate("KW_REVENANT_NAME")
		Type.CHAIR_MORTE: return TranslationServer.translate("KW_CHAIR_MORTE_NAME")
		_:                return "?"

static func get_description(keyword: int) -> String:
	match keyword:
		Type.PESTIFERE:   return TranslationServer.translate("KW_PESTIFERE_DESC")
		Type.NECROPHAGE:  return TranslationServer.translate("KW_NECROPHAGE_DESC")
		Type.HORDE:       return TranslationServer.translate("KW_HORDE_DESC")
		Type.REVENANT:    return TranslationServer.translate("KW_REVENANT_DESC")
		Type.CHAIR_MORTE: return TranslationServer.translate("KW_CHAIR_MORTE_DESC")
		_:                return ""

static func from_name(keyword_name: String) -> int:
	match keyword_name:
		"PESTIFERE":   return Type.PESTIFERE
		"NECROPHAGE":  return Type.NECROPHAGE
		"HORDE":       return Type.HORDE
		"REVENANT":    return Type.REVENANT
		"CHAIR_MORTE": return Type.CHAIR_MORTE
		_:             return -1
