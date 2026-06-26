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
enum TriggerType {
	INVOCATION,
	DERNIER_SOUFFLE,
	ASSAUT,
	BLESSURE,
	EVEIL,
	DECLIN,
	RALLIEMENT,
	DEUIL,
	SORTILEGE,
	SACRIFICE,
	EXECUTION,
	CARNAGE
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
