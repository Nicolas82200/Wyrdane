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

## Races dotées d'au moins une carte (utilisé pour ne proposer, dans l'UI,
## que des races effectivement jouables — Elfe/Nain n'ont encore aucune carte).
static func get_implemented_races() -> Array[int]:
	return [Type.HUMAN, Type.UNDEAD, Type.DEMON, Type.ABOMINATION]

static func from_string(s: String) -> int:
	match s:
		"Human":       return Type.HUMAN
		"Elf":         return Type.ELF
		"Dwarf":       return Type.DWARF
		"Undead":      return Type.UNDEAD
		"Demon":       return Type.DEMON
		"Abomination": return Type.ABOMINATION
		_:             return Type.NONE
