extends RefCounted
class_name CampaignGold

# Or gagné après un combat de campagne (CAMPAIGN.md « Monnaie de run et gains
# d'or »). Logique pure, aucune dépendance de scène.

const BASE_GOLD := 10
const BASE_TIER_INTERVAL := 5  # paliers par palier d'or (x1,25 cumulatif)
const BASE_GROWTH_MULTIPLIER := 1.25

const NODE_MULTIPLIERS := {
	CampaignMapNode.NodeType.ELITE: 1.5,
	CampaignMapNode.NodeType.BOSS: 3.0,
}

static func base_gold_for_depth(depth: int) -> int:
	var tier: int = max(0, depth - 1) / BASE_TIER_INTERVAL
	var gold: float = BASE_GOLD
	for i in range(tier):
		gold = ceil(gold * BASE_GROWTH_MULTIPLIER)
	return int(gold)

static func reward_for_node(node: CampaignMapNode) -> int:
	var base := base_gold_for_depth(node.depth)
	var multiplier: float = NODE_MULTIPLIERS.get(node.type, 1.0)
	return int(ceil(base * multiplier))
