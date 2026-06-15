extends RefCounted
class_name Keyword

enum Type {
	TAUNT,
	CHARGE,
	PROTECTION,
	LIFESTEAL,
	FURY
}

static func get_name(keyword: int) -> String:
	match keyword:
		Type.TAUNT:
			return "Taunt"
		Type.CHARGE:
			return "Charge"
		Type.PROTECTION:
			return "Protection"
		Type.LIFESTEAL:
			return "Lifesteal"
		Type.FURY:
			return "Fury"
		_:
			return "Unknown"
