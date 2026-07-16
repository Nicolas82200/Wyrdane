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
	# Human (ajouté en fin d'enum pour ne pas décaler les valeurs
	# déjà sérialisées dans les .tres existants)
	SOLDIER,
	# Abomination (race à part entière, distincte du style ABOMINATION
	# utilisé par les serviteurs "abomination" Mort-Vivant existants)
	ABOMINATION_MASS,
}
