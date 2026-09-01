# KeywordHuman.gd
# Enum dédié aux mots-clés exclusifs à la race Humain.
# Séparé de Keyword.Type pour ne pas mélanger les pools de mots-clés par race
# et permettre d'ajouter facilement d'autres races (Elfe, Nain, Démon...) de la même façon.
extends RefCounted
class_name KeywordHuman

enum Type {
	DISCIPLINE,      # Immunisé aux effets néfastes raciaux (Infection, Corruption, Terreur), au silence et au contrôle mental. Pas immunisé aux débuffs de stats génériques ni au Gel.
	FORMATION,       # Tant qu'un allié est adjacent, ce serviteur gagne +1/+1.
	CONTRE_ATTAQUE,  # Si ce serviteur survit après avoir attaqué ou défendu, inflige à nouveau son ATK au serviteur qui lui a infligé des dégâts.
	COMMANDEMENT,    # Les Humains alliés invoqués après lui gagnent +1/+0 de façon permanente.
	FORTIFICATION,   # Ne peut pas être déplacé, renvoyé en main ou transformé par des effets ennemis.
}

# Nommé get_keyword_name (et non get_name) : un static get_name est masqué
# par la méthode native Resource.get_name quand on l'appelle via la classe.
static func get_keyword_name(keyword: int) -> String:
	match keyword:
		Type.DISCIPLINE:     return TranslationServer.translate("KW_DISCIPLINE_NAME")
		Type.FORMATION:      return TranslationServer.translate("KW_FORMATION_NAME")
		Type.CONTRE_ATTAQUE: return TranslationServer.translate("KW_CONTRE_ATTAQUE_NAME")
		Type.COMMANDEMENT:   return TranslationServer.translate("KW_COMMANDEMENT_NAME")
		Type.FORTIFICATION:  return TranslationServer.translate("KW_FORTIFICATION_NAME")
		_:                   return "?"

static func get_description(keyword: int) -> String:
	match keyword:
		Type.DISCIPLINE:     return TranslationServer.translate("KW_DISCIPLINE_DESC")
		Type.FORMATION:      return TranslationServer.translate("KW_FORMATION_DESC")
		Type.CONTRE_ATTAQUE: return TranslationServer.translate("KW_CONTRE_ATTAQUE_DESC")
		Type.COMMANDEMENT:   return TranslationServer.translate("KW_COMMANDEMENT_DESC")
		Type.FORTIFICATION:  return TranslationServer.translate("KW_FORTIFICATION_DESC")
		_:                   return ""

static func from_name(keyword_name: String) -> int:
	match keyword_name:
		"DISCIPLINE":     return Type.DISCIPLINE
		"FORMATION":      return Type.FORMATION
		"CONTRE_ATTAQUE": return Type.CONTRE_ATTAQUE
		"COMMANDEMENT":   return Type.COMMANDEMENT
		"FORTIFICATION":  return Type.FORTIFICATION
		_:                return Type.DISCIPLINE
