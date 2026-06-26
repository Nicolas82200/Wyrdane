extends RefCounted
class_name Minion

var owner_is_player: bool
var card_data: CardData
var attack: int
var health: int
var max_health: int
var attacks_remaining: int = 0
var keywords: Array[int] = []
var board_row: String = "Front"

# ─── États ────────────────────────────────────────────────────────────────────
var silenced: bool = false
var frozen_turns: int = 0
var corrupted: bool = false
var infected: bool = false
var awakened: bool = false
var declined: bool = false
var buffs: Array = []

func _init(data: CardData, is_player: bool = true, row: String = "Front") -> void:
	owner_is_player = is_player
	card_data = data
	board_row = row
	attack = data.attack
	health = data.health
	max_health = data.health
	keywords = data.get_keyword_values()
	attacks_remaining = 1 if has_keyword(Keyword.Type.CHARGE) else 0

# ─── Combat ───────────────────────────────────────────────────────────────────

func can_attack() -> bool:
	return attacks_remaining > 0 and frozen_turns == 0

func is_frozen() -> bool:
	return frozen_turns > 0

func refresh_attacks() -> void:
	if frozen_turns > 0:
		frozen_turns -= 1
		attacks_remaining = 0
		return
	attacks_remaining = 2 if has_keyword(Keyword.Type.FURY) else 1

func consume_attack() -> void:
	attacks_remaining = max(attacks_remaining - 1, 0)

func take_damage(amount: int) -> void:
	if has_keyword(Keyword.Type.AEGIS):
		remove_keyword(Keyword.Type.AEGIS)
		return
	health = max(health - amount, 0)

func heal(amount: int) -> void:
	health = min(health + amount, max_health)

func is_dead() -> bool:
	return health <= 0

# ─── Keywords ─────────────────────────────────────────────────────────────────

func has_keyword(keyword: int) -> bool:
	return keyword in keywords

func add_keyword(keyword: int) -> void:
	if keyword not in keywords:
		keywords.append(keyword)

func remove_keyword(keyword: int) -> void:
	keywords.erase(keyword)

func get_keywords_text() -> String:
	var names: Array[String] = []
	for keyword in keywords:
		names.append(Keyword.get_name(keyword))
	return ", ".join(names)
