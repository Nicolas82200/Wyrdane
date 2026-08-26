# KeywordAbomination.gd
# Enum dédié aux mots-clés exclusifs à la race Abomination.
# Séparé de Keyword.Type pour ne pas mélanger les pools de mots-clés par race
# (même approche que KeywordDemon.gd, KeywordHuman.gd et KeywordUndead.gd).
extends RefCounted
class_name KeywordAbomination

enum Type {
	MUTATION,          # Mute (Table de Mutation) chaque fois qu'il survit à une blessure. Permanent, cumulable.
	FUSION,             # Sacrifice un allié adjacent : absorbe ses stats restantes ET un de ses mots-clés au choix.
	VIRULENT,           # Dernier Souffle : le serviteur allié adjacent déclenche immédiatement une mutation.
	CHAIR_ADAPTATIVE,   # Arrivée : copie un mot-clé au choix présent sur un serviteur en jeu (allié ou ennemi).
	ASSIMILATION,       # Dévoration : absorbe les restes pour gagner +1/+1 jusqu'au début du prochain tour (une fois par mort).
	INSTABLE,           # Ne peut pas être ciblé par des effets de soin, alliés ou ennemis.
}

static func get_keyword_name(keyword: int) -> String:
	match keyword:
		Type.MUTATION:          return TranslationServer.translate("KW_MUTATION_NAME")
		Type.FUSION:             return TranslationServer.translate("KW_FUSION_NAME")
		Type.VIRULENT:           return TranslationServer.translate("KW_VIRULENT_NAME")
		Type.CHAIR_ADAPTATIVE:   return TranslationServer.translate("KW_CHAIR_ADAPTATIVE_NAME")
		Type.ASSIMILATION:       return TranslationServer.translate("KW_ASSIMILATION_NAME")
		Type.INSTABLE:           return TranslationServer.translate("KW_INSTABLE_NAME")
		_:                       return "?"

static func get_description(keyword: int) -> String:
	match keyword:
		Type.MUTATION:          return TranslationServer.translate("KW_MUTATION_DESC")
		Type.FUSION:             return TranslationServer.translate("KW_FUSION_DESC")
		Type.VIRULENT:           return TranslationServer.translate("KW_VIRULENT_DESC")
		Type.CHAIR_ADAPTATIVE:   return TranslationServer.translate("KW_CHAIR_ADAPTATIVE_DESC")
		Type.ASSIMILATION:       return TranslationServer.translate("KW_ASSIMILATION_DESC")
		Type.INSTABLE:           return TranslationServer.translate("KW_INSTABLE_DESC")
		_:                       return ""

static func from_name(keyword_name: String) -> int:
	match keyword_name:
		"MUTATION":          return Type.MUTATION
		"FUSION":             return Type.FUSION
		"VIRULENT":           return Type.VIRULENT
		"CHAIR_ADAPTATIVE":   return Type.CHAIR_ADAPTATIVE
		"ASSIMILATION":       return Type.ASSIMILATION
		"INSTABLE":           return Type.INSTABLE
		_:                    return -1
