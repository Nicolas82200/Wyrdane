extends GutTest

func test_compute_scales_linearly_with_depth_reached() -> void:
	var run := CampaignRun.new()
	run.depth = 4
	assert_eq(CampaignConsolationReward.compute(run), 4 * CampaignConsolationReward.REWARD_PER_DEPTH)

func test_compute_is_zero_without_reaching_any_palier() -> void:
	var run := CampaignRun.new()
	assert_eq(CampaignConsolationReward.compute(run), 0)
