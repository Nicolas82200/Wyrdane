extends RefCounted
class_name CampaignRewardPicker

# Sélection de cartes de récompense après un nœud de combat/boutique : tirage
# pondéré par rareté, puis carte aléatoire dans le pool de cette rareté pour
# la race de la run. Logique pure, aucune dépendance de scène.

const CANDIDATE_COUNT := 3
# Repli si le pool tiré est vide pour la race (ex. pas encore de Legendary
# implémentée) : on retombe sur la rareté immédiatement inférieure.
const RARITY_FALLBACK := {
	"Legendary": "Epic",
	"Epic": "Rare",
	"Rare": "Common",
}

static func roll_rarity(rng: RandomNumberGenerator, weights: Dictionary = CurrencyManager.RARITY_WEIGHTS_DISPLAY) -> String:
	var total := 0
	for w in weights.values():
		total += w
	var roll := rng.randi_range(1, total)
	var acc := 0
	for rarity in weights:
		acc += weights[rarity]
		if roll <= acc:
			return rarity
	return "Common"

static func pick_three(race: int, rng: RandomNumberGenerator, weights: Dictionary = CurrencyManager.RARITY_WEIGHTS_DISPLAY) -> Array[CardData]:
	var result: Array[CardData] = []
	for i in range(CANDIDATE_COUNT):
		var card := _pick_one(race, roll_rarity(rng, weights), rng)
		if card != null:
			result.append(card)
	return result

const RARITY_ORDER := ["Legendary", "Epic", "Rare", "Common"]

## Une Relique aléatoire imposée (Enchantement/Rituel), sans choix — voir
## CAMPAIGN.md « Reliques ». Repli en cascade vers le bas depuis la rareté
## tirée, puis — contrairement à pick_three/_pick_one — un dernier repli
## parcourt TOUTES les raretés : les Enchantements/Rituels sont bien plus
## rares que les Serviteurs (une seule poignée par race), un simple repli
## vers le bas depuis un tirage Commun laisserait souvent aucune Relique
## disponible alors que la race en a bel et bien (à une rareté supérieure).
static func pick_relic(race: int, rng: RandomNumberGenerator, weights: Dictionary = CurrencyManager.RARITY_WEIGHTS_DISPLAY) -> CardData:
	var rarity := roll_rarity(rng, weights)
	var current_rarity := rarity
	while current_rarity != "":
		var found := _relic_pool(race, current_rarity)
		if not found.is_empty():
			return found[rng.randi_range(0, found.size() - 1)]
		current_rarity = RARITY_FALLBACK.get(current_rarity, "")
	for fallback_rarity in RARITY_ORDER:
		var found := _relic_pool(race, fallback_rarity)
		if not found.is_empty():
			return found[rng.randi_range(0, found.size() - 1)]
	return null

static func _relic_pool(race: int, rarity: String) -> Array[CardData]:
	return CampaignCardFilter.filter_compatible(
		CardLibrary.get_cards_by_race_and_rarity(race, rarity).filter(
			func(c: CardData) -> bool: return c.card_type == "Enchantment" or c.card_type == "Ritual"))

static func _pick_one(race: int, rarity: String, rng: RandomNumberGenerator) -> CardData:
	var current_rarity := rarity
	while current_rarity != "":
		# Enchantements/Rituels exclus du tirage standard : ce sont les
		# Reliques de CAMPAIGN.md, obtenues uniquement via le nœud Relique ou
		# la Boutique, jamais via un choix 1-parmi-3 classique. Incantations
		# (Instant) exclues aussi : le plateau de Campagne est un
		# auto-battler, seules des créatures peuvent y être posées. Cartes à
		# effet incompatible (pioche/mana/main, sans intérêt en Campagne)
		# exclues aussi.
		var pool: Array[CardData] = CampaignCardFilter.filter_compatible(
			CardLibrary.get_cards_by_race_and_rarity(race, current_rarity).filter(
				func(c: CardData) -> bool: return c.card_type == "Minion"))
		if not pool.is_empty():
			return pool[rng.randi_range(0, pool.size() - 1)]
		current_rarity = RARITY_FALLBACK.get(current_rarity, "")
	return null
