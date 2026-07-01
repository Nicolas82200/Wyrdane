extends RefCounted
class_name TriggerType
enum Type {
	ONPLAY        = 0,
	DEATHRATTLE   = 1,
	CHARGE        = 2,
	ON_DAMAGED    = 3,
	ON_AWAKEN     = 4,   # Éveil
	ON_DECLINE    = 5,   # Déclin
	ON_RALLY      = 6,   # Ralliement
	ON_GRIEF      = 7,   # Deuil
	ON_SPELL      = 8,   # Sortilège
	ON_SACRIFICE  = 9,
	ON_EXECUTION  = 10,
	ON_CARNAGE    = 11,
	ON_ATTACK     = 12,
	ON_TURN_START = 13,
	ON_TURN_END   = 14,
	ON_MOURNING   = 15,
	ON_DEATH_RAGE = 16, # Mort-rage
	ON_AURA       = 17, # Présence
	ON_SUMMON     = 18, # Appel
	ON_RESONANCE  = 19, # Résonance (Mort-Vivant ou Humain attaque)
}
static func get_name(trigger_type: int) -> String:
	match trigger_type:
		Type.ONPLAY:        return "ONPLAY"
		Type.DEATHRATTLE:   return "DEATHRATTLE"
		Type.CHARGE:        return "CHARGE"
		Type.ON_DAMAGED:    return "OnDamaged"
		Type.ON_AWAKEN:     return "OnAwaken"
		Type.ON_DECLINE:    return "OnDecline"
		Type.ON_RALLY:      return "OnRally"
		Type.ON_GRIEF:      return "OnGrief"
		Type.ON_SPELL:      return "OnSpell"
		Type.ON_SACRIFICE:  return "OnSacrifice"
		Type.ON_EXECUTION:  return "OnExecution"
		Type.ON_CARNAGE:    return "OnCarnage"
		Type.ON_ATTACK:     return "OnAttack"
		Type.ON_TURN_START: return "OnTurnStart"
		Type.ON_TURN_END:   return "OnTurnEnd"
		Type.ON_MOURNING:   return "OnMourning"
		Type.ON_DEATH_RAGE: return "OnDeathRage"
		Type.ON_AURA:       return "OnAura"
		Type.ON_SUMMON:     return "OnSummon"
		Type.ON_RESONANCE:  return "OnResonance"
		_:                  return "Unknown"
static func from_name(trigger_name: String) -> int:
	match trigger_name:
		"ONPLAY":       return Type.ONPLAY
		"DEATHRATTLE":  return Type.DEATHRATTLE
		"CHARGE":       return Type.CHARGE
		"OnDamaged":    return Type.ON_DAMAGED
		"OnAwaken":     return Type.ON_AWAKEN
		"OnDecline":    return Type.ON_DECLINE
		"OnRally":      return Type.ON_RALLY
		"OnGrief":      return Type.ON_GRIEF
		"OnSpell":      return Type.ON_SPELL
		"OnSacrifice":  return Type.ON_SACRIFICE
		"OnExecution":  return Type.ON_EXECUTION
		"OnCarnage":    return Type.ON_CARNAGE
		"OnAttack":     return Type.ON_ATTACK
		"OnTurnStart":  return Type.ON_TURN_START
		"OnTurnEnd":    return Type.ON_TURN_END
		"OnMourning":   return Type.ON_MOURNING
		"OnDeathRage":  return Type.ON_DEATH_RAGE
		"OnAura":       return Type.ON_AURA
		"OnSummon":     return Type.ON_SUMMON
		"OnResonance":  return Type.ON_RESONANCE
		_:              return Type.ONPLAY
