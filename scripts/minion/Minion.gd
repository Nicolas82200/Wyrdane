extends RefCounted
class_name Minion

var owner_is_player: bool
var card_data: CardData

# Identifiant réseau stable, partagé entre les deux clients en multijoueur.
# 0 = non enregistré (proxies d'effet, aperçus de drag). Attribué par NetRegistry.
var net_id: int = 0

# Stats permanentes : base de la carte + tous les buffs "définitifs" appliqués (Buff, Commandement...)
var base_attack: int
var base_max_health: int
var damage_taken: int = 0

# Bonus d'aura, recalculés ENTIÈREMENT à chaque update — jamais incrémentés à la main ailleurs
var aura_attack_bonus: int = 0
var aura_health_bonus: int = 0
# Réduction de dégâts : part inhérente à la carte + part d'aura (Pacte de
# Résistance...). L'aura est remise à zéro puis recalculée par AuraSystem.
var aura_damage_reduction: int = 0

var attacks_remaining: int = 0
var keywords: Array[int] = []
var human_keywords: Array[int] = []
var undead_keywords: Array[int] = []
var board_row: String = "Front"

var formation_active: bool = false
var silenced: bool = false
var frozen_turns: int = 0
var corrupted: bool = false
# CHAIR MORTE bloque toute pose d'Infection, quelle que soit la source
var infected: bool = false:
	set(value):
		if value and has_undead_keyword(KeywordUndead.Type.CHAIR_MORTE):
			return
		infected = value
var death_rage_triggered: bool = false  # Mort-rage : une seule fois par serviteur
var revenant_triggered: bool = false    # REVENANT : une seule fois par partie
var awakened: bool = false
var declined: bool = false
var sacrificed: bool = false
var buffs: Array = []

func _init(data: CardData, is_player: bool = true, row: String = "Front") -> void:
	owner_is_player = is_player
	card_data = data
	board_row = row
	base_attack       = data.attack
	base_max_health   = data.health
	damage_taken      = 0
	keywords          = data.get_keyword_values()
	human_keywords    = data.get_human_keyword_values()
	undead_keywords   = data.get_undead_keyword_values()
	attacks_remaining = 1 if has_keyword(Keyword.Type.CHARGE) else 0

# ─── Stats calculées (lecture seule — passe par base_* pour modifier) ─────────
var attack: int:
	get: return max(0, base_attack + aura_attack_bonus)

var max_health: int:
	get: return max(1, base_max_health + aura_health_bonus)

var health: int:
	get: return max(0, max_health - damage_taken)
	set(value):
		damage_taken = max_health - value

# ─── Combat (inchangé) ──────────────────────────────────────────────────────
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

var damage_reduction: int:
	get: return max(0, card_data.damage_reduction + aura_damage_reduction)

func take_damage(amount: int) -> int:
	if has_keyword(Keyword.Type.AEGIS):
		remove_keyword(Keyword.Type.AEGIS)
		return 0
	# Réduction de dégâts : un coup qui touche inflige toujours au moins 1.
	if amount > 0 and damage_reduction > 0:
		amount = max(1, amount - damage_reduction)
	var before: int = health
	health = max(health - amount, 0)
	return before - health

func heal(amount: int) -> void:
	health = min(health + amount, max_health)

func is_dead() -> bool:
	return health <= 0

# ─── Keywords (inchangé + pool Humain) ────────────────────────────────────────
func has_keyword(keyword: int) -> bool:
	return keyword in keywords
func add_keyword(keyword: int) -> void:
	if keyword not in keywords:
		keywords.append(keyword)
func remove_keyword(keyword: int) -> void:
	keywords.erase(keyword)

func has_human_keyword(keyword: int) -> bool:
	return keyword in human_keywords

func add_human_keyword(keyword: int) -> void:
	if keyword not in human_keywords:
		human_keywords.append(keyword)

func remove_human_keyword(keyword: int) -> void:
	human_keywords.erase(keyword)

func has_undead_keyword(keyword: int) -> bool:
	return keyword in undead_keywords

func add_undead_keyword(keyword: int) -> void:
	if keyword not in undead_keywords:
		undead_keywords.append(keyword)

func remove_undead_keyword(keyword: int) -> void:
	undead_keywords.erase(keyword)

func get_keywords_text() -> String:
	var names: Array[String] = []
	for keyword in keywords:
		names.append(Keyword.get_keyword_name(keyword))
	for keyword in human_keywords:
		names.append(KeywordHuman.get_keyword_name(keyword))
	for keyword in undead_keywords:
		names.append(KeywordUndead.get_keyword_name(keyword))
	return ", ".join(names)
