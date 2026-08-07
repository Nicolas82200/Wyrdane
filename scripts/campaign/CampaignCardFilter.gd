extends RefCounted
class_name CampaignCardFilter

# Filtre les cartes dont un effet dépend d'un concept absent du mode Campagne
# (pas de main, pas de deck/pioche, pas de mana en combat — voir
# CampaignBattle.gd) : ces cartes seraient "sans intérêt" pour le joueur
# (EffectManager les neutralise en no-op, voir ses commentaires "Mode
# Campagne") plutôt que de les lui proposer comme choix (plateau de départ,
# récompense, boutique). Ne s'applique qu'aux POOLS DE CHOIX du joueur — pas
# à la génération du plateau adverse (CampaignOpponentFactory), qui filtre
# séparément avec la même liste pour éviter de faire perdre un tour à l'IA
# sur un effet neutralisé, sans lien avec l'expérience du joueur.

const INCOMPATIBLE_EFFECT_IDS := [
	"DrawCard",
	"DrawCardPerAllyDeathThisTurn",
	"DrawCardDiscount",
	"GainMana",
	"ReturnToHand",
	"ReturnFromGrave",
]

static func is_compatible(card: CardData) -> bool:
	for effect in card.effects:
		if effect.effect_id in INCOMPATIBLE_EFFECT_IDS:
			return false
	return true

static func filter_compatible(cards: Array[CardData]) -> Array[CardData]:
	return cards.filter(func(c: CardData) -> bool: return is_compatible(c))
