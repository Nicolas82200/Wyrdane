extends RefCounted
class_name Keyword
enum Type {
	TAUNT,
	CHARGE,
	AEGIS,
	LIFESTEAL,
	FURY,
	DEADLY_POISON,
	RAVAGE,
	BLACK_WINGS,
}

# Nommé get_keyword_name (et non get_name) : un static get_name est masqué
# par la méthode native Resource.get_name quand on l'appelle via la classe.
static func get_keyword_name(keyword: int) -> String:
	match keyword:
		Type.TAUNT:          return TranslationServer.translate("KW_TAUNT_NAME")
		Type.CHARGE:         return TranslationServer.translate("KW_CHARGE_NAME")
		Type.AEGIS:          return TranslationServer.translate("KW_AEGIS_NAME")
		Type.LIFESTEAL:      return TranslationServer.translate("KW_LIFESTEAL_NAME")
		Type.FURY:           return TranslationServer.translate("KW_FURY_NAME")
		Type.DEADLY_POISON:  return TranslationServer.translate("KW_DEADLY_POISON_NAME")
		Type.RAVAGE:         return TranslationServer.translate("KW_RAVAGE_NAME")
		Type.BLACK_WINGS:    return TranslationServer.translate("KW_BLACK_WINGS_NAME")
		_:                   return "?"

static func from_name(keyword_name: String) -> int:
	match keyword_name:
		"TAUNT":         return Type.TAUNT
		"CHARGE":        return Type.CHARGE
		"AEGIS":         return Type.AEGIS
		"LIFESTEAL":     return Type.LIFESTEAL
		"FURY":          return Type.FURY
		"DEADLY_POISON": return Type.DEADLY_POISON
		"RAVAGE":        return Type.RAVAGE
		"BLACK_WINGS":   return Type.BLACK_WINGS
		_:               return -1
