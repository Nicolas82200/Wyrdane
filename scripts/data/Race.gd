extends RefCounted
class_name Race

enum Type {
	NONE,
	HUMAN,
	ELF,
	DWARF,
	UNDEAD,
	DEMON,
	ABOMINATION,
}

static func get_race_name(race: int) -> String:
	match race:
		Type.HUMAN:       return "Human"
		Type.ELF:         return "Elf"
		Type.DWARF:       return "Dwarf"
		Type.UNDEAD:      return "Undead"
		Type.DEMON:       return "Demon"
		Type.ABOMINATION: return "Abomination"
		_:                return "None"

static func from_string(s: String) -> int:
	match s:
		"Human":       return Type.HUMAN
		"Elf":         return Type.ELF
		"Dwarf":       return Type.DWARF
		"Undead":      return Type.UNDEAD
		"Demon":       return Type.DEMON
		"Abomination": return Type.ABOMINATION
		_:             return Type.NONE
