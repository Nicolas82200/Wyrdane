extends Node
class_name UnitStyle

enum Type {
	# Undead
	ZOMBIE,
	MAJOR_ZOMBIE,
	ABOMINATION,
	SPECTRAL,
	DEATH_KNIGHT,
	# Human
	KNIGHT,
	ARCHER,
	MAGE,
	PALADIN,
	# Elf
	RANGER,
	DRUID,
	BLADE_DANCER,
	# Dwarf
	BERSERKER,
	RUNESMITH,
	# Demon
	IMP,
	DEMON_WARRIOR,
	SUCCUBUS,
	# Global
	INSECT,
	LARVA,
}

static func get_style_name(style: Type) -> String:
	match style:
		Type.ZOMBIE:        return "Zombie"
		Type.MAJOR_ZOMBIE:  return "Zombie Majeur"
		Type.ABOMINATION:   return "Abomination"
		Type.SPECTRAL:      return "Spectral"
		Type.DEATH_KNIGHT:  return "Chevalier de la Mort"
		Type.KNIGHT:        return "Chevalier"
		Type.ARCHER:        return "Archer"
		Type.MAGE:          return "Mage"
		Type.PALADIN:       return "Paladin"
		Type.RANGER:        return "Rôdeur"
		Type.DRUID:         return "Druide"
		Type.BLADE_DANCER:  return "Danseur de Lame"
		Type.BERSERKER:     return "Berserker"
		Type.RUNESMITH:     return "Runeforgeron"
		Type.IMP:           return "Diablotin"
		Type.DEMON_WARRIOR: return "Guerrier Démoniaque"
		Type.SUCCUBUS:      return "Succube"
		_:                  return "Inconnu"

# Retourne les styles valides pour une race donnée
static func get_styles_for_race(race: Race.Type) -> Array[Type]:
	match race:
		Race.Type.UNDEAD: return [Type.ZOMBIE,Type.MAJOR_ZOMBIE, Type.ABOMINATION, Type.SPECTRAL, Type.DEATH_KNIGHT]
		Race.Type.HUMAN:  return [Type.KNIGHT, Type.ARCHER, Type.MAGE, Type.PALADIN]
		Race.Type.ELF:    return [Type.RANGER, Type.DRUID, Type.BLADE_DANCER]
		Race.Type.DWARF:  return [Type.BERSERKER, Type.RUNESMITH]
		Race.Type.DEMON:  return [Type.IMP, Type.DEMON_WARRIOR, Type.SUCCUBUS]
		_:                return [Type.INSECT, Type.LARVA]
