extends RefCounted
class_name Race

enum Type {
	NONE,
	HUMAN,
	ELF,
	DWARF,
	UNDEAD,
	DEMON,
}

static func get_race_name(race: int) -> String:
	match race:
		Type.HUMAN:   return "Human"
		Type.ELF:     return "Elf"
		Type.DWARF:   return "Dwarf"
		Type.UNDEAD:  return "Undead"
		Type.DEMON:   return "Demon"
		_:            return "None"

static func from_string(s: String) -> int:
	match s:
		"Human":  return Type.HUMAN
		"Elf":    return Type.ELF
		"Dwarf":  return Type.DWARF
		"Undead": return Type.UNDEAD
		"Demon":  return Type.DEMON
		_:        return Type.NONE
