class_name EffectType
enum Type {
	DAMAGE        = 0,
	HEAL          = 1,
	BUFF          = 2,
	SUMMON_MINION = 3,
	SUMMON_SELF   = 4,
	DRAW_CARD     = 5,
	DESTROY       = 6,
	SILENCE       = 7,
	TRANSFORM     = 8,
	STEAL_HEALTH  = 9,
	INFECT_ENEMY  = 10,
	HEAL_HERO     = 11,
	RETURN_TO_HAND = 12,
	DAMAGE_ALL    = 13,  # splash / tous les ennemis
	BUFF_ROW      = 14,  # buff une rangée entière
	SUMMON_RANDOM = 15,  # invoque un Mort-Vivant aléatoire
	FREEZE        = 16,  # gèle une cible
	DEBUFF        = 17,  # réduit ATK/HP
	RESURRECT     = 18,  # ressuscite depuis le cimetière
	STEAL_MINION  = 19,  # prend contrôle d'un serviteur
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
		Type.HEAL_HERO:      return "HealHero"
		Type.RETURN_TO_HAND: return "ReturnToHand"
		Type.DAMAGE_ALL:     return "DamageAll"
		Type.BUFF_ROW:       return "BuffRow"
		Type.SUMMON_RANDOM:  return "SummonRandom"
		Type.FREEZE:         return "Freeze"
		Type.DEBUFF:         return "Debuff"
		Type.RESURRECT:      return "Resurrect"
		Type.STEAL_MINION:   return "StealMinion"
		_:                   return "Unknown"

static func from_name(effect_name: String) -> int:
	match effect_name:
		"Damage":        return Type.DAMAGE
		"Heal":          return Type.HEAL
		"Buff":          return Type.BUFF
		"SummonMinion":  return Type.SUMMON_MINION
		"SummonSelf":    return Type.SUMMON_SELF
		"DrawCard":      return Type.DRAW_CARD
		"Destroy":       return Type.DESTROY
		"Silence":       return Type.SILENCE
		"Transform":     return Type.TRANSFORM
		"StealHealth":   return Type.STEAL_HEALTH
		"InfectEnemy":   return Type.INFECT_ENEMY
		"HealHero":      return Type.HEAL_HERO
		"ReturnToHand":  return Type.RETURN_TO_HAND
		"DamageAll":     return Type.DAMAGE_ALL
		"BuffRow":       return Type.BUFF_ROW
		"SummonRandom":  return Type.SUMMON_RANDOM
		"Freeze":        return Type.FREEZE
		"Debuff":        return Type.DEBUFF
		"Resurrect":     return Type.RESURRECT
		"StealMinion":   return Type.STEAL_MINION
		_:               return Type.DAMAGE
