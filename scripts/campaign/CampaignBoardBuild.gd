extends RefCounted
class_name CampaignBoardBuild

# Construction du plateau de départ du joueur : 5 choix successifs, chacun
# proposant 3 cartes Commune de la race choisie (CAMPAIGN.md « Constitution
# du plateau »). Logique pure (tirage des candidats), l'écran
# CampaignBoardBuildScreen orchestre la boucle des 5 choix et l'affichage.

const CHOICE_COUNT := 5
const CANDIDATES_PER_CHOICE := 3

## 3 cartes Commune candidates pour un choix, hors ressources/jetons (pas de
## ressource/pioche en Campagne, voir CAMPAIGN.md) et hors Enchantement/Rituel
## (ce sont les Reliques, "jamais via un choix" — CAMPAIGN.md « Reliques » —
## obtenues uniquement via le nœud Relique/la Boutique, même exclusion que
## CampaignRewardPicker pour la récompense de combat) et hors doublon avec les
## cartes déjà proposées dans les choix précédents de cette même run (pour
## éviter de re-proposer 5 fois la même poignée de cartes vues plus tôt).
static func pick_candidates(race: int, rng: RandomNumberGenerator, already_chosen: Array[CardData] = []) -> Array[CardData]:
	var pool: Array[CardData] = CampaignCardFilter.filter_compatible(
		CardLibrary.get_cards_by_race_and_rarity(race, "Common").filter(
			func(c: CardData) -> bool: return c.card_type != "Resource" and c.card_type != "Enchantment" \
				and c.card_type != "Ritual" and not c.is_token))
	var available := pool.filter(func(c: CardData) -> bool: return not already_chosen.has(c))
	# Repli si la race n'a pas assez de cartes Common uniques restantes : on
	# retombe sur le pool complet (autorise des doublons plutôt que de
	# proposer moins de 3 candidats).
	if available.size() < CANDIDATES_PER_CHOICE:
		available = pool
	if available.is_empty():
		return []
	_shuffle(available, rng)
	return available.slice(0, min(CANDIDATES_PER_CHOICE, available.size()))

# Array.shuffle() s'appuie sur le RNG global de Godot (non-déterministe) —
# on mélange manuellement avec le RandomNumberGenerator seedé de la run pour
# rester reproductible (voir CampaignRun.rng).
static func _shuffle(array: Array, rng: RandomNumberGenerator) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = array[i]
		array[i] = array[j]
		array[j] = tmp
