class_name TriggerType

enum Type {
	BATTLECRY = 0,
	DEATHRATTLE = 1,
	CHARGE = 2,
	ON_DAMAGED = 3,
	ON_AWAKEN = 4,
	ON_DECLINE = 5,
	ON_RALLY = 6,
	ON_GRIEF = 7,
	ON_SPELL = 8,
	ON_SACRIFICE = 9,
	ON_EXECUTION = 10,
	ON_CARNAGE = 11,
	ON_ATTACK = 12,
	ON_TURN_START = 13,
	ON_TURN_END = 14,
	ON_MOURNING = 15,
}

static func get_name(trigger_type: int) -> String:
	match trigger_type:
		Type.BATTLECRY:     return "BATTLECRY"
		Type.DEATHRATTLE:   return "DEATHRATTLE"
		Type.CHARGE:        return "CHARGE"
		Type.ON_DAMAGED:    return "OnDamaged"
		Type.ON_AWAKEN:     return "OnAwaken"
		Type.ON_DECLINE:    return "OnDecline"
		Type.ON_RALLY:      return "RALLY"
		Type.ON_GRIEF:      return "OnGrief"
		Type.ON_SPELL:      return "SPELLCAST"
		Type.ON_SACRIFICE:  return "SACRIFICE"
		Type.ON_EXECUTION:  return "OnExecution"
		Type.ON_CARNAGE:    return "CARNAGE"
		Type.ON_ATTACK:     return "OnAttack"
		Type.ON_TURN_START: return "ONTURNSTART"
		Type.ON_TURN_END:   return "ONTURNEND"
		Type.ON_MOURNING:   return "MOURNING"
		_:                  return "Unknown"

static func from_name(trigger_name: String) -> int:
	match trigger_name:
		"BATTLECRY":     return Type.BATTLECRY
		"DEATHRATTLE":   return Type.DEATHRATTLE
		"CHARGE":        return Type.CHARGE
		"OnDamaged":     return Type.ON_DAMAGED
		"OnAwaken":      return Type.ON_AWAKEN
		"OnDecline":     return Type.ON_DECLINE
		"RALLY":         return Type.ON_RALLY
		"OnGrief":       return Type.ON_GRIEF
		"SPELLCAST":     return Type.ON_SPELL
		"SACRIFICE":     return Type.ON_SACRIFICE
		"OnExecution":   return Type.ON_EXECUTION
		"CARNAGE":       return Type.ON_CARNAGE
		"OnAttack":      return Type.ON_ATTACK
		"ONTURNSTART":   return Type.ON_TURN_START
		"ONTURNEND":     return Type.ON_TURN_END
		"MOURNING":      return Type.ON_MOURNING
		_:               return Type.BATTLECRY
