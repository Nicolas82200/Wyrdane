extends Resource
class_name TriggerTypeChoice

# Liste alignée sur TriggerType.get_name — ce sont ces chaînes exactes qui sont
# comparées par EffectManager.has_trigger et TriggerSystem._enchantment_reacts.
@export_enum(
	"ONPLAY", "DEATHRATTLE", "CHARGE", "OnDamaged", "OnAwaken", "OnDecline",
	"OnGrief", "OnSpell", "OnSacrifice", "OnExecution", "OnCarnage",
	"OnAttack", "OnMourning", "OnDeathRage",
	"OnAura", "OnSummon", "OnResonance", "OnSelfDamage", "OnMutation", "OnDevoration"
) var type: String = "DEATHRATTLE"

func _to_string() -> String:
	return type
