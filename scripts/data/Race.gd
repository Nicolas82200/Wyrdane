extends RefCounted
class_name Race

enum Type {
	NONE,

	HUMAN,
	ELF,
	DWARF,
	UNDEAD,
	DEMON
}

static func get_name(race: int) -> String:
	match race:
		Type.HUMAN:
			return "Human"
		Type.ELF:
			return "Elf"
		Type.DWARF:
			return "Dwarf"
		Type.UNDEAD:
			return "Undead"
		Type.DEMON:
			return "Demon"
		_:
			return "None"
