# KeywordHuman.gd
# Enum dédié aux mots-clés exclusifs à la race Humain.
# Séparé de Keyword.Type pour ne pas mélanger les pools de mots-clés par race
# et permettre d'ajouter facilement d'autres races (Elfe, Nain, Démon...) de la même façon.
extends RefCounted
class_name KeywordHuman

enum Type {
	DISCIPLINE,      # Immunisé aux effets de silence, contrôle mental et peur ennemis.
	FORMATION,       # Tant qu'un allié est adjacent, ce serviteur gagne +1/+1.
	CONTRE_ATTAQUE,  # Blessure : si ce serviteur survit, inflige son ATK en retour à l'attaquant.
	COMMANDEMENT,    # Les Humains alliés invoqués après lui gagnent +1/+0 de façon permanente.
	FORTIFICATION,   # Ne peut pas être déplacé, renvoyé en main ou transformé par des effets ennemis.
}

static func get_name(keyword: int) -> String:
	match keyword:
		Type.DISCIPLINE:     return "Discipline"
		Type.FORMATION:      return "Formation"
		Type.CONTRE_ATTAQUE: return "Contre-attaque"
		Type.COMMANDEMENT:   return "Commandement"
		Type.FORTIFICATION:  return "Fortification"
		_:                   return "Inconnu"

static func get_description(keyword: int) -> String:
	match keyword:
		Type.DISCIPLINE:
			return "Immunisé aux effets de silence, contrôle mental et peur ennemis."
		Type.FORMATION:
			return "Tant qu'un serviteur allié est adjacent, ce serviteur gagne +1/+1."
		Type.CONTRE_ATTAQUE:
			return "Blessure : si ce serviteur survit, inflige son ATK en retour à l'attaquant."
		Type.COMMANDEMENT:
			return "Les serviteurs Humains alliés invoqués après lui gagnent +1/+0 de façon permanente."
		Type.FORTIFICATION:
			return "Ne peut pas être déplacé, renvoyé en main ou transformé par des effets ennemis."
		_:
			return ""

static func from_name(keyword_name: String) -> int:
	match keyword_name:
		"DISCIPLINE":     return Type.DISCIPLINE
		"FORMATION":      return Type.FORMATION
		"CONTRE_ATTAQUE": return Type.CONTRE_ATTAQUE
		"COMMANDEMENT":   return Type.COMMANDEMENT
		"FORTIFICATION":  return Type.FORTIFICATION
		_:                return Type.DISCIPLINE
