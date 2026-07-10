class_name Hero
extends RefCounted

var health: int
var max_health: int
# Blocage de soin (Rituel de la Terreur) : tant que > 0, heal() est sans effet.
# Décrémenté à la fin du tour du propriétaire du héros (TurnSystem).
var heal_block_turns: int = 0

func _init(start_health := 30):
	max_health = start_health
	health = start_health

func take_damage(amount: int) -> void:
	health -= amount

func heal(amount: int) -> void:
	if heal_block_turns > 0:
		return
	health += amount

func is_dead() -> bool:
	return health <= 0
