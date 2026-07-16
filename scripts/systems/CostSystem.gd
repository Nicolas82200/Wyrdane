extends RefCounted
class_name CostSystem

# Coût effectif en mana d'une carte, après réductions :
#  - remises temporaires par carte ("cette carte coûte 1 de moins ce tour",
#    ex. Doigt Décharné) — expirent à la fin du tour du joueur ;
#  - auras d'enchantements (Présence) :
#      AuraSpellCostReduction      : les sorts alliés coûtent N de moins (min 1)
#      AuraFirstOfRaceCostReduction: le premier serviteur de la race joué chaque
#                                    tour coûte N de moins (min 1)
# Le paiement (_pay_mana) et la jouabilité (can_afford_card) passent par ici ;
# la valeur de base card_data.cost n'est jamais modifiée.

var battle

# Remises temporaires : CardData (instance en main) -> réduction cumulée.
var _temp_discounts: Dictionary = {}
# Nombre de serviteurs joués ce tour, par camp puis par race (clé = Race.Type).
var _race_played_this_turn: Dictionary = {true: {}, false: {}}

# ─── Ressources de race (voir README « Système de Ressources par Race ») ──────
# % du coût verrouillé sur le pool de race de la carte, selon sa rareté.
const RACE_LOCK_PCT := {
	"Common":    0.40,
	"Rare":      0.55,
	"Epic":      0.70,
	"Legendary": 0.85,
}

func init(_battle) -> void:
	battle = _battle

# Part du coût payable UNIQUEMENT depuis le pool de la race de la carte.
func get_race_cost(card_data: CardData, is_player: bool) -> int:
	var total: int = get_cost(card_data, is_player)
	return compute_race_cost(total, card_data.race, card_data.rarity, card_data.race_cost_override)

# Version statique de la répartition race/générique, utilisable sans instance de
# bataille (aperçus en main-hors-partie, deck builder, cimetière...) : n'a besoin
# que du coût total déjà connu (typiquement card_data.cost, sans remises).
static func compute_race_cost(total: int, race: int, rarity: String, override: int) -> int:
	if total <= 0 or race == Race.Type.NONE:
		return 0
	if override >= 0:
		return clampi(override, 0, total)
	var pct: float = RACE_LOCK_PCT.get(rarity, 0.40)
	return clampi(int(round(total * pct)), 1, total)

# Part du coût payable depuis n'importe quel pool en surplus.
func get_generic_cost(card_data: CardData, is_player: bool) -> int:
	return get_cost(card_data, is_player) - get_race_cost(card_data, is_player)

# Le camp peut-il payer cette carte avec ses pools de ressource actuels ?
func can_afford(card_data: CardData, is_player: bool) -> bool:
	if card_data == null:
		return false
	var race_cost: int = get_race_cost(card_data, is_player)
	var generic_cost: int = get_generic_cost(card_data, is_player)
	var pool: Dictionary = battle.race_mana_pool(is_player)
	var race_available: int = int(pool.get(card_data.race, 0))
	if race_available < race_cost:
		return false
	var total_available: int = 0
	for r in pool:
		total_available += int(pool[r])
	return total_available - race_cost >= generic_cost

# Déduit le coût de la carte des pools de ressource du camp (race verrouillée
# d'abord, puis surplus générique pris sur n'importe quel pool).
func pay(card_data: CardData, is_player: bool) -> void:
	var race_cost: int = get_race_cost(card_data, is_player)
	var generic_cost: int = get_generic_cost(card_data, is_player)
	var pool: Dictionary = battle.race_mana_pool(is_player)
	pool[card_data.race] = int(pool.get(card_data.race, 0)) - race_cost
	var remaining: int = generic_cost
	for r in pool.keys():
		if remaining <= 0:
			break
		var available: int = int(pool[r])
		if available <= 0:
			continue
		var take: int = min(available, remaining)
		pool[r] = available - take
		remaining -= take

func get_cost(card_data: CardData, is_player: bool) -> int:
	if card_data == null:
		return 0
	var cost: int = card_data.cost
	# Auras de coût (min 1 : une carte à 1 ne devient jamais gratuite par aura)
	var aura_reduction: int = _aura_reduction(card_data, is_player)
	if aura_reduction > 0:
		cost = max(1, cost - aura_reduction)
	# Remises temporaires par carte (peuvent descendre à 0)
	if _temp_discounts.has(card_data):
		cost = max(0, cost - int(_temp_discounts[card_data]))
	return cost

func _aura_reduction(card_data: CardData, is_player: bool) -> int:
	var reduction: int = 0
	for entry in battle.trigger_system.get_active_enchantments(is_player):
		var enchant: CardData = entry["card_data"]
		if not enchant.trigger_types.any(func(t): return t.type == "OnAura"):
			continue
		for effect in enchant.effects:
			match effect.effect_id:
				"AuraSpellCostReduction":
					if card_data.card_type != "Minion":
						reduction += effect.value
				"AuraFirstOfRaceCostReduction":
					if card_data.card_type == "Minion" \
							and card_data.race == Race.from_string(effect.race_filter) \
							and _race_played_count(is_player, card_data.race) == 0:
						reduction += effect.value
	return reduction

func _race_played_count(is_player: bool, race: int) -> int:
	return int(_race_played_this_turn[is_player].get(race, 0))

# ─── Remises temporaires ──────────────────────────────────────────────────────

func add_temp_discount(card_data: CardData, amount: int) -> void:
	if card_data == null or amount <= 0:
		return
	_temp_discounts[card_data] = int(_temp_discounts.get(card_data, 0)) + amount
	if battle.hand != null:
		battle.hand.refresh_costs()

# ─── Suivi de tour ────────────────────────────────────────────────────────────

# À appeler quand une carte est effectivement jouée (après paiement).
func on_card_played(card_data: CardData, is_player: bool) -> void:
	if card_data == null:
		return
	_temp_discounts.erase(card_data)
	if card_data.card_type == "Minion":
		var per_race: Dictionary = _race_played_this_turn[is_player]
		per_race[card_data.race] = int(per_race.get(card_data.race, 0)) + 1
	else:
		await _charge_spell_discount_self_damage(card_data, is_player)

# Sanctuaire Écarlate : la première fois que sa remise de coût s'applique à un
# sort allié chaque tour, le héros propriétaire de l'enchantement perd 1 HP.
# `triggered_this_turn` (partagé avec TriggerSystem, remis à zéro à chaque
# début de tour) sert de témoin "déjà chargé" pour cette instance.
func _charge_spell_discount_self_damage(card_data: CardData, is_player: bool) -> void:
	for entry in battle.trigger_system.get_active_enchantments(is_player):
		var enchant: CardData = entry["card_data"]
		if not enchant.trigger_types.any(func(t): return t.type == "OnAura"):
			continue
		for effect in enchant.effects:
			if effect.effect_id == "AuraSpellCostReduction" and not entry["triggered_this_turn"]:
				entry["triggered_this_turn"] = true
				await battle.hero_system.self_damage(is_player, 1)

# Début du tour d'un camp : ses compteurs "premier de la race" repartent à zéro.
func on_turn_started(is_player: bool) -> void:
	_race_played_this_turn[is_player] = {}

# Fin du tour du joueur local : les remises "ce tour" expirent.
func expire_end_of_player_turn() -> void:
	_temp_discounts.clear()
	if battle.hand != null:
		battle.hand.refresh_costs()
