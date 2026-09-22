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

# Remises temporaires, par camp puis par CardData (instance en main) -> réduction
# cumulée. Scopées par camp car une CardData chargée depuis un .tres est partagée
# (même instance Resource) entre le deck joueur et le deck IA/adverse quand les
# deux piochent la même carte : sans ce scope, une remise obtenue par un camp
# s'appliquerait aussi à la copie en main de l'autre camp.
var _temp_discounts: Dictionary = {true: {}, false: {}}
# Nombre de serviteurs joués ce tour, par camp puis par race (clé = Race.Type).
var _race_played_this_turn: Dictionary = {true: {}, false: {}}
# Remises accordées côté joueur LOCAL à une carte non encore jouée (ex. Doigt
# Écarlate : pioche une carte, celle-ci coûte moins ce tour si Démon) en
# attente de synchronisation réseau — voir take_pending_sync_discounts().
var _pending_sync_discounts: Array[Dictionary] = []

# ─── Ressources de race (voir README « Système de Ressources par Race ») ──────
# % du coût verrouillé sur le pool de race de la carte, selon sa rareté.
const RACE_LOCK_PCT := {
	"Common":    0.25,
	"Rare":      0.40,
	"Epic":      0.55,
	"Legendary": 0.65,
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
	var discounts: Dictionary = _temp_discounts[is_player]
	if discounts.has(card_data):
		cost = max(0, cost - int(discounts[card_data]))
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
					# "Incantation" = Éphémère uniquement : les Rituels/Enchantements
					# ne sont pas des sorts au sens de cette réduction (comportement
					# corrigé — auparavant "!= Minion" les incluait à tort).
					if card_data.card_type == "Instant":
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

func add_temp_discount(card_data: CardData, amount: int, is_player: bool = true) -> void:
	if card_data == null or amount <= 0:
		return
	var discounts: Dictionary = _temp_discounts[is_player]
	discounts[card_data] = int(discounts.get(card_data, 0)) + amount
	if is_player and battle.hand != null:
		battle.hand.refresh_costs()
	# Remise sur une carte de NOTRE main réelle (donc inconnue du pair) : sans
	# transmission explicite, son mirroir de notre coût resterait trop haut et
	# pourrait rejeter à tort notre PLAY_CARD plus tard (can_afford renvoyant
	# false alors que le coût réel, remisé, est payable) — voir
	# NetworkOpponent._apply_play_card et take_pending_sync_discounts().
	if is_player and battle.net_emitter != null and not card_data.resource_path.is_empty():
		_pending_sync_discounts.append({"card": card_data.resource_path, "amount": amount})

# Vide et retourne les remises accordées depuis le dernier appel, à joindre à
# la commande réseau PLAY_CARD de la carte actuellement en cours de résolution
# (voir CardSystem.gd) — le pair les rejoue via
# NetworkOpponent._apply_play_card -> add_temp_discount(..., false).
func take_pending_sync_discounts() -> Array[Dictionary]:
	var pending: Array[Dictionary] = _pending_sync_discounts
	_pending_sync_discounts = []
	return pending

# ─── Suivi de tour ────────────────────────────────────────────────────────────

# À appeler quand une carte est effectivement jouée (après paiement).
func on_card_played(card_data: CardData, is_player: bool) -> void:
	if card_data == null:
		return
	_temp_discounts[is_player].erase(card_data)
	if card_data.card_type == "Minion":
		var per_race: Dictionary = _race_played_this_turn[is_player]
		per_race[card_data.race] = int(per_race.get(card_data.race, 0)) + 1
	elif card_data.card_type == "Instant":
		await _charge_spell_discount_self_damage(card_data, is_player)
	# La carte jouée peut avoir consommé une réduction "premier de la race"
	# (AuraFirstOfRaceCostReduction) : les autres cartes de la race en main
	# ne sont plus réduites, il faut réafficher leur coût réel.
	if is_player and battle.hand != null:
		battle.hand.refresh_costs()

# Sanctuaire Écarlate : la première fois que sa remise de coût s'applique à un
# sort allié chaque tour, le héros propriétaire de l'enchantement perd 1 HP.
# `triggered_this_turn` (partagé avec TriggerSystem, remis à zéro à chaque
# début de tour) sert de témoin "déjà chargé" pour cette instance.
func _charge_spell_discount_self_damage(_card_data: CardData, is_player: bool) -> void:
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
	if is_player and battle.hand != null:
		battle.hand.refresh_costs()

# Fin du tour du joueur local : ses remises "ce tour" expirent.
func expire_end_of_player_turn() -> void:
	_temp_discounts[true].clear()
	if battle.hand != null:
		battle.hand.refresh_costs()

# Fin du tour adverse : ses remises "ce tour" expirent (symétrique à
# expire_end_of_player_turn, sans quoi une remise gagnée pendant le tour
# adverse survivrait un tour de trop côté joueur puisque les deux camps
# partagent le même dictionnaire par instance de CardData).
func expire_end_of_enemy_turn() -> void:
	_temp_discounts[false].clear()

# ─── Pools de mana par race ────────────────────────────────────────────────
# Un pool par race (voir README « Système de Ressources par Race ») : plus de
# mana générique unique. `battle.race_mana`/`battle.race_max_mana` appartiennent
# au joueur ; `opponent.race_mana`/`opponent.race_max_mana` au camp adverse.

func race_mana_pool(is_player: bool) -> Dictionary:
	return battle.race_mana if is_player else battle.opponent.race_mana

func race_max_mana_pool(is_player: bool) -> Dictionary:
	return battle.race_max_mana if is_player else battle.opponent.race_max_mana

# Recharge le pool courant de chaque race à son maximum (début de tour) et
# efface tout mana temporaire hors-race (GainMana) : "le surplus non dépensé
# est perdu au tour suivant" (Vortex des Âmes).
func refill_mana_pool(is_player: bool = true) -> void:
	var pool: Dictionary = race_mana_pool(is_player)
	var max_pool: Dictionary = race_max_mana_pool(is_player)
	pool.clear()
	for r in max_pool:
		pool[r] = max_pool[r]

# Une carte-ressource jouée est consommée : +1 (actuel et max) au pool de sa
# race, action à part qui ne consomme pas le droit de jouer une carte normale
# mais limitée à une par tour et par camp. La carte est ensuite simplement
# retirée de la partie (déjà sortie de la main par l'appelant) : aucune zone
# ne la garde, elle n'est donc récupérable par aucun effet. La pose visuelle
# en zone dédiée (EnchantmentSystem.add_resource) est conservée mais
# désactivée pour l'instant — voir Battle.RESOURCE_ZONE_ENABLED.
func play_resource_card(card_data: CardData, is_player: bool = true) -> void:
	if battle.resource_played_this_turn.get(is_player, false):
		return
	battle.resource_played_this_turn[is_player] = true
	var pool: Dictionary = race_mana_pool(is_player)
	var max_pool: Dictionary = race_max_mana_pool(is_player)
	max_pool[card_data.race] = int(max_pool.get(card_data.race, 0)) + 1
	pool[card_data.race]     = int(pool.get(card_data.race, 0)) + 1
	if battle.RESOURCE_ZONE_ENABLED:
		battle.enchantment_system.add_resource(card_data, is_player)
	battle.combat_log.card_played(card_data, is_player)
	if is_player:
		battle.update_mana_ui()
	else:
		battle.update_enemy_mana_ui()
		battle.enemy_mana_display.pulse_max()
