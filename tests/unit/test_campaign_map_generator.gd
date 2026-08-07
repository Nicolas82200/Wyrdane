extends GutTest

func _generate(seed_value: int = 12345) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return CampaignMapGenerator.generate(rng)

func test_first_window_covers_window_size_paliers() -> void:
	var result := _generate()
	var nodes: Array = result["nodes"]
	var max_depth := 0
	for node in nodes:
		max_depth = max(max_depth, node.depth)
	assert_eq(max_depth, CampaignMapGenerator.WINDOW_SIZE)

func test_boss_paliers_are_single_boss_nodes() -> void:
	for seed_value in [1, 2, 3, 42, 999]:
		var result := _generate(seed_value)
		var nodes: Array = result["nodes"]
		var by_depth: Dictionary = {}
		for node in nodes:
			if not by_depth.has(node.depth):
				by_depth[node.depth] = []
			by_depth[node.depth].append(node)
		for depth in by_depth:
			if depth % CampaignMapGenerator.BOSS_INTERVAL != 0:
				continue
			var layer: Array = by_depth[depth]
			assert_eq(layer.size(), 1, "seed %d palier %d : le palier Boss doit être un nœud unique" % [seed_value, depth])
			assert_eq(layer[0].type, CampaignMapNode.NodeType.BOSS)

func test_no_orphan_node_beyond_the_start_layer() -> void:
	for seed_value in [1, 2, 3, 42, 999]:
		var result := _generate(seed_value)
		var nodes: Array = result["nodes"]
		var start_ids: Array = result["start_ids"]
		var reached: Dictionary = {}
		for node in nodes:
			for target_id in node.next_ids:
				reached[target_id] = true
		for node in nodes:
			if node.id in start_ids:
				continue
			assert_true(reached.has(node.id), "seed %d : nœud %d orphelin (aucun lien entrant)" % [seed_value, node.id])

func test_a_rest_node_exists_just_before_each_boss_palier() -> void:
	for seed_value in [1, 2, 3, 42, 999]:
		var result := _generate(seed_value)
		var nodes: Array = result["nodes"]
		var pre_boss_depth := CampaignMapGenerator.BOSS_INTERVAL - 1
		var pre_boss_nodes: Array = nodes.filter(func(n): return n.depth == pre_boss_depth)
		var has_rest := false
		for node in pre_boss_nodes:
			if node.type == CampaignMapNode.NodeType.REST:
				has_rest = true
				break
		assert_true(has_rest, "seed %d : aucun nœud REST juste avant le premier Boss (palier %d)" % [seed_value, pre_boss_depth])

func test_path_count_per_normal_palier_is_one_to_three() -> void:
	var result := _generate()
	var nodes: Array = result["nodes"]
	var by_depth: Dictionary = {}
	for node in nodes:
		if not by_depth.has(node.depth):
			by_depth[node.depth] = 0
		by_depth[node.depth] += 1
	for depth in by_depth:
		if depth % CampaignMapGenerator.BOSS_INTERVAL == 0:
			continue
		var count: int = by_depth[depth]
		assert_true(count >= CampaignMapGenerator.MIN_PATHS and count <= CampaignMapGenerator.MAX_PATHS,
			"palier %d : %d chemins, hors de la plage [%d,%d]" % [depth, count, CampaignMapGenerator.MIN_PATHS, CampaignMapGenerator.MAX_PATHS])

func test_generation_is_deterministic_given_the_same_seed() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 777
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 777
	var result_a := CampaignMapGenerator.generate(rng_a)
	var result_b := CampaignMapGenerator.generate(rng_b)
	var nodes_a: Array = result_a["nodes"]
	var nodes_b: Array = result_b["nodes"]
	assert_eq(nodes_a.size(), nodes_b.size(), "même seed -> même nombre de nœuds")
	for i in range(nodes_a.size()):
		assert_eq(nodes_a[i].type, nodes_b[i].type, "même seed -> même type de nœud à l'index %d" % i)

func test_extend_adds_more_paliers_linked_to_the_previous_edge() -> void:
	var run := CampaignRun.new()
	run.rng.seed = 55
	var generated := CampaignMapGenerator.generate(run.rng)
	run.map = generated["nodes"]
	run.start_node_ids = generated["start_ids"]
	var size_before := run.map.size()
	var max_depth_before := CampaignMapGenerator.WINDOW_SIZE
	CampaignMapGenerator.extend(run, 5)
	assert_gt(run.map.size(), size_before, "extend() doit ajouter des nœuds")
	var max_depth_after := 0
	for node in run.map:
		max_depth_after = max(max_depth_after, node.depth)
	assert_eq(max_depth_after, max_depth_before + 5)
	var last_old_layer: Array = run.map.filter(func(n): return n.depth == max_depth_before)
	var reached: Dictionary = {}
	for node in last_old_layer:
		for target_id in node.next_ids:
			reached[target_id] = true
	assert_gt(reached.size(), 0, "le palier suivant l'extension doit être relié au dernier palier existant")

func test_extend_produces_no_orphan_in_the_new_paliers() -> void:
	var run := CampaignRun.new()
	run.rng.seed = 21
	var generated := CampaignMapGenerator.generate(run.rng)
	run.map = generated["nodes"]
	run.start_node_ids = generated["start_ids"]
	CampaignMapGenerator.extend(run, 10)
	var reached: Dictionary = {}
	for node in run.map:
		for target_id in node.next_ids:
			reached[target_id] = true
	for node in run.map:
		if node.id in run.start_node_ids:
			continue
		assert_true(reached.has(node.id), "nœud %d orphelin après extend()" % node.id)
