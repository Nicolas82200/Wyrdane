class_name EffectType

enum Type {
	DAMAGE = 0,
	HEAL = 1,
	BUFF = 2,
	SUMMON_MINION = 3,
	SUMMON_SELF = 4,
	DRAW_CARD = 5,
	DESTROY = 6,
	SILENCE = 7,
	TRANSFORM = 8,
	STEAL_HEALTH = 9,
	INFECT_ENEMY = 10,
}

static func get_name(effect_type: int) -> String:
	match effect_type:
		Type.DAMAGE:         return "Damage"
		Type.HEAL:           return "Heal"
		Type.BUFF:           return "Buff"
		Type.SUMMON_MINION:  return "SummonMinion"
		Type.SUMMON_SELF:    return "SummonSelf"
		Type.DRAW_CARD:      return "DrawCard"
		Type.DESTROY:        return "Destroy"
		Type.SILENCE:        return "Silence"
		Type.TRANSFORM:      return "Transform"
		Type.STEAL_HEALTH:   return "StealHealth"
		Type.INFECT_ENEMY:   return "InfectEnemy"
		_:                   return "Unknown"

static func from_name(effect_name: String) -> int:
	match effect_name:
		"Damage":         return Type.DAMAGE
		"Heal":           return Type.HEAL
		"Buff":           return Type.BUFF
		"SummonMinion":   return Type.SUMMON_MINION
		"SummonSelf":     return Type.SUMMON_SELF
		"DrawCard":       return Type.DRAW_CARD
		"Destroy":        return Type.DESTROY
		"Silence":        return Type.SILENCE
		"Transform":      return Type.TRANSFORM
		"StealHealth":    return Type.STEAL_HEALTH
		"InfectEnemy":    return Type.INFECT_ENEMY
		_:                return Type.DAMAGE
