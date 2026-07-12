class_name TargetType

enum Type {
	SELF = 0,
	ENEMY_HERO = 1,
	OWNER_HERO = 2,
	ENEMY_MINION = 3,
	ALLY_MINION = 4,
	ALL_ENEMIES = 5,
	ALL_ALLIES = 6,
	ALL_MINIONS = 7,
	RANDOM_ENEMY = 8,
	RANDOM_ALLY = 9,
	ANY_MINION = 10,
}

static func get_name(target_type: int) -> String:
	match target_type:
		Type.SELF:           return "Self"
		Type.ENEMY_HERO:     return "EnemyHero"
		Type.OWNER_HERO:     return "OwnerHero"
		Type.ENEMY_MINION:   return "EnemyMinion"
		Type.ALLY_MINION:    return "AllyMinion"
		Type.ALL_ENEMIES:    return "AllEnemies"
		Type.ALL_ALLIES:     return "AllAllies"
		Type.ALL_MINIONS:    return "AllMinions"
		Type.RANDOM_ENEMY:   return "RandomEnemy"
		Type.RANDOM_ALLY:    return "RandomAlly"
		Type.ANY_MINION:     return "AnyMinion"
		_:                   return "Unknown"

static func from_name(target_name: String) -> int:
	match target_name:
		"Self":         return Type.SELF
		"EnemyHero":    return Type.ENEMY_HERO
		"OwnerHero":    return Type.OWNER_HERO
		"EnemyMinion":  return Type.ENEMY_MINION
		"AllyMinion":   return Type.ALLY_MINION
		"AllEnemies":   return Type.ALL_ENEMIES
		"AllAllies":    return Type.ALL_ALLIES
		"AllMinions":   return Type.ALL_MINIONS
		"RandomEnemy":  return Type.RANDOM_ENEMY
		"RandomAlly":   return Type.RANDOM_ALLY
		"AnyMinion":    return Type.ANY_MINION
		_:              return Type.SELF
