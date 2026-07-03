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
	CHAIR_MORTE,  # Immunisé à l'Infection, au poison (Venin mortel) et aux effets de peur.
}

# Nommé get_keyword_name (et non get_name) : un static get_name est masqué
# par la méthode native Resource.get_name quand on l'appelle via la classe.
static func get_keyword_name(keyword: int) -> String:
	match keyword:
		Type.PESTIFERE:   return "Pestiféré"
		Type.NECROPHAGE:  return "Nécrophage"
		Type.HORDE:       return "Horde"
		Type.REVENANT:    return "Revenant"
		Type.CHAIR_MORTE: return "Chair morte"
		_:                return "Inconnu"

static func get_description(keyword: int) -> String:
	match keyword:
		Type.PESTIFERE:
			return "Les attaques de ce serviteur infligent Infection en plus des dégâts."
		Type.NECROPHAGE:
			return "Quand un serviteur allié meurt, ce serviteur gagne +1/+1 de façon permanente."
		Type.HORDE:
			return "Tant que tu contrôles 3 Morts-Vivants ou plus, ce serviteur gagne +1/+0."
		Type.REVENANT:
			return "La première fois que ce serviteur devrait mourir, il se relève avec 1 HP à la place (une seule fois par partie)."
		Type.CHAIR_MORTE:
			return "Immunisé à l'Infection, au poison et aux effets de peur."
		_:
			return ""

static func from_name(keyword_name: String) -> int:
	match keyword_name:
		"PESTIFERE":   return Type.PESTIFERE
		"NECROPHAGE":  return Type.NECROPHAGE
		"HORDE":       return Type.HORDE
		"REVENANT":    return Type.REVENANT
		"CHAIR_MORTE": return Type.CHAIR_MORTE
		_:             return -1
