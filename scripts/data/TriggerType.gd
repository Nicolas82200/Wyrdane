extends RefCounted
class_name TriggerType
enum Type {
	ONPLAY        = 0,
	DEATHRATTLE   = 1,
	CHARGE        = 2,
	ON_DAMAGED    = 3,
	ON_AWAKEN     = 4,   # Éveil
	ON_DECLINE    = 5,   # Déclin
	ON_GRIEF      = 7,   # Deuil
	ON_SPELL      = 8,   # Sortilège
	ON_SACRIFICE  = 9,
	ON_EXECUTION  = 10,
	ON_CARNAGE    = 11,
	ON_ATTACK     = 12, # Attaque (fusionne l'ancien Ralliement/OnRally)
	ON_MOURNING   = 15,
	ON_DEATH_RAGE = 16, # Mort-rage
	ON_AURA       = 17, # Présence
	ON_SUMMON     = 18, # Renfort
	ON_RESONANCE  = 19, # Résonance (Mort-Vivant ou Humain attaque)
	ON_SELF_DAMAGE = 20, # Le héros du camp perd des HP à cause d'une de ses propres cartes (Démon)
	ON_MUTATION   = 21, # Mutation (Abomination) : un serviteur allié Abomination gagne une mutation
	ON_DEVORATION = 22, # Dévoration : n'importe quel serviteur (allié ou ennemi) meurt en jeu
}
static func get_name(trigger_type: int) -> String:
	match trigger_type:
		Type.ONPLAY:        return "ONPLAY"
		Type.DEATHRATTLE:   return "DEATHRATTLE"
		Type.CHARGE:        return "CHARGE"
		Type.ON_DAMAGED:    return "OnDamaged"
		Type.ON_AWAKEN:     return "OnAwaken"
		Type.ON_DECLINE:    return "OnDecline"
		Type.ON_GRIEF:      return "OnGrief"
		Type.ON_SPELL:      return "OnSpell"
		Type.ON_SACRIFICE:  return "OnSacrifice"
		Type.ON_EXECUTION:  return "OnExecution"
		Type.ON_CARNAGE:    return "OnCarnage"
		Type.ON_ATTACK:     return "OnAttack"
		Type.ON_MOURNING:   return "OnMourning"
		Type.ON_DEATH_RAGE: return "OnDeathRage"
		Type.ON_AURA:       return "OnAura"
		Type.ON_SUMMON:     return "OnSummon"
		Type.ON_RESONANCE:  return "OnResonance"
		Type.ON_SELF_DAMAGE: return "OnSelfDamage"
		Type.ON_MUTATION:   return "OnMutation"
		Type.ON_DEVORATION: return "OnDevoration"
		_:                  return "Unknown"
static func from_name(trigger_name: String) -> int:
	match trigger_name:
		"ONPLAY":       return Type.ONPLAY
		"DEATHRATTLE":  return Type.DEATHRATTLE
		"CHARGE":       return Type.CHARGE
		"OnDamaged":    return Type.ON_DAMAGED
		"OnAwaken":     return Type.ON_AWAKEN
		"OnDecline":    return Type.ON_DECLINE
		"OnGrief":      return Type.ON_GRIEF
		"OnSpell":      return Type.ON_SPELL
		"OnSacrifice":  return Type.ON_SACRIFICE
		"OnExecution":  return Type.ON_EXECUTION
		"OnCarnage":    return Type.ON_CARNAGE
		"OnAttack":     return Type.ON_ATTACK
		"OnMourning":   return Type.ON_MOURNING
		"OnDeathRage":  return Type.ON_DEATH_RAGE
		"OnAura":       return Type.ON_AURA
		"OnSummon":     return Type.ON_SUMMON
		"OnResonance":  return Type.ON_RESONANCE
		"OnSelfDamage": return Type.ON_SELF_DAMAGE
		"OnMutation":   return Type.ON_MUTATION
		"OnDevoration": return Type.ON_DEVORATION
		_:              return Type.ONPLAY
