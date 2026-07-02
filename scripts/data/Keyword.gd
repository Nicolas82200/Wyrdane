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

static func get_name(keyword: int) -> String:
	match keyword:
		Type.TAUNT:          return "Rempart"
		Type.CHARGE:         return "Assaut"
		Type.AEGIS:          return "Égide"
		Type.LIFESTEAL:      return "Moisson"
		Type.FURY:           return "Frénésie"
		Type.DEADLY_POISON:  return "Venin mortel"
		Type.RAVAGE:         return "Ravage"
		Type.BLACK_WINGS:    return "Ailes noires"
		_:                   return "Inconnu"

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
