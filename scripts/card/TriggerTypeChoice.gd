extends Resource
class_name TriggerTypeChoice

@export_enum(
	"ONPLAY", "DEATHRATTLE", "CHARGE", "OnDamaged", "OnAwaken", "OnDecline",
	"RALLY", "OnGrief", "SPELLCAST", "SACRIFICE", "OnExecution", "CARNAGE",
	"OnAttack", "ONTURNSTART", "ONTURNEND", "MOURNING"
) var type: String = "DEATHRATTLE"

func _to_string() -> String:
	return type
