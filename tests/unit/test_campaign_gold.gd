extends GutTest

func test_base_gold_matches_campaign_md_table() -> void:
	var expected := {
		1: 10, 5: 10,
		6: 13, 10: 13,
		11: 17, 15: 17,
		16: 22, 20: 22,
		21: 28, 25: 28,
		26: 35, 30: 35,
		31: 44, 35: 44,
		36: 55, 40: 55,
	}
	for depth in expected:
		assert_eq(CampaignGold.base_gold_for_depth(depth), expected[depth], "palier %d" % depth)

func _node(node_type: int, depth: int) -> CampaignMapNode:
	return CampaignMapNode.new(0, node_type, depth)

func test_normal_reward_equals_base_gold() -> void:
	assert_eq(CampaignGold.reward_for_node(_node(CampaignMapNode.NodeType.COMBAT, 6)), 13)

func test_elite_reward_applies_1_5x_multiplier() -> void:
	assert_eq(CampaignGold.reward_for_node(_node(CampaignMapNode.NodeType.ELITE, 1)), 15)

func test_boss_reward_applies_3x_multiplier() -> void:
	assert_eq(CampaignGold.reward_for_node(_node(CampaignMapNode.NodeType.BOSS, 1)), 30)
