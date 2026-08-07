extends RefCounted
class_name CampaignSaveService

# Sauvegarde locale de la run de campagne en cours (CAMPAIGN.md « Sauvegarde
# de run persistante ») : fichier ConfigFile sur user://, pattern repris de
# SettingsManager.gd. Déclenchée juste avant d'engager un combat (adversaire
# déjà figé, voir CampaignMapScreen._select_node) et juste après une victoire
# (voir CampaignBattle._finish_combat). Portée locale uniquement — la run est
# éphémère par nature, pas de progression durable à synchroniser au backend.

const SAVE_PATH := "user://campaign_run.cfg"

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

static func clear() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)

static func save(run: CampaignRun) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("run", "race", run.race)
	cfg.set_value("run", "hero_health", run.hero_health)
	cfg.set_value("run", "hero_max_health", run.hero_max_health)
	cfg.set_value("run", "gold", run.gold)
	cfg.set_value("run", "current_node_id", run.current_node_id)
	cfg.set_value("run", "depth", run.depth)
	cfg.set_value("run", "tier_race", run.tier_race)
	cfg.set_value("run", "tier_index", run.tier_index)
	cfg.set_value("run", "elite_wins", run.elite_wins)
	cfg.set_value("run", "boss_wins", run.boss_wins)
	cfg.set_value("run", "discard_count", run.discard_count)
	cfg.set_value("run", "rng_seed", run.rng_seed)
	cfg.set_value("run", "rng_state", run.rng.state)
	cfg.set_value("run", "board_paths", _paths(run.board))
	cfg.set_value("run", "pending_enemy_board_paths", _paths(run.pending_enemy_board))
	cfg.set_value("run", "pending_reward_paths", _paths(run.pending_reward_cards))
	cfg.set_value("run", "start_node_ids", run.start_node_ids)

	cfg.set_value("map", "count", run.map.size())
	for i in range(run.map.size()):
		var node := run.map[i]
		cfg.set_value("map", "id_%d" % i, node.id)
		cfg.set_value("map", "type_%d" % i, node.type)
		cfg.set_value("map", "depth_%d" % i, node.depth)
		cfg.set_value("map", "next_ids_%d" % i, node.next_ids)
		cfg.set_value("map", "cleared_%d" % i, node.cleared)
		cfg.set_value("map", "x_hint_%d" % i, node.x_hint)

	cfg.save(SAVE_PATH)

static func load_run() -> CampaignRun:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return null

	var run := CampaignRun.new()
	run.race = cfg.get_value("run", "race", Race.Type.NONE)
	run.hero_health = cfg.get_value("run", "hero_health", 30)
	run.hero_max_health = cfg.get_value("run", "hero_max_health", 30)
	run.gold = cfg.get_value("run", "gold", 0)
	run.current_node_id = cfg.get_value("run", "current_node_id", -1)
	run.depth = cfg.get_value("run", "depth", 0)
	run.tier_race = cfg.get_value("run", "tier_race", Race.Type.NONE)
	run.tier_index = cfg.get_value("run", "tier_index", -1)
	run.elite_wins = cfg.get_value("run", "elite_wins", 0)
	run.boss_wins = cfg.get_value("run", "boss_wins", 0)
	run.discard_count = cfg.get_value("run", "discard_count", 0)
	run.rng_seed = cfg.get_value("run", "rng_seed", 0)
	run.rng.state = cfg.get_value("run", "rng_state", 0)
	run.board = _cards(cfg.get_value("run", "board_paths", []))
	run.pending_enemy_board = _cards(cfg.get_value("run", "pending_enemy_board_paths", []))
	run.pending_reward_cards = _cards(cfg.get_value("run", "pending_reward_paths", []))
	run.start_node_ids = _typed_int_array(cfg.get_value("run", "start_node_ids", []))

	var count: int = cfg.get_value("map", "count", 0)
	var map: Array[CampaignMapNode] = []
	for i in range(count):
		var node := CampaignMapNode.new(
			cfg.get_value("map", "id_%d" % i, 0),
			cfg.get_value("map", "type_%d" % i, 0),
			cfg.get_value("map", "depth_%d" % i, 0),
			cfg.get_value("map", "x_hint_%d" % i, 0.5),
		)
		node.cleared = cfg.get_value("map", "cleared_%d" % i, false)
		node.next_ids = _typed_int_array(cfg.get_value("map", "next_ids_%d" % i, []))
		map.append(node)
	run.map = map
	return run

static func _paths(cards: Array[CardData]) -> Array[String]:
	var result: Array[String] = []
	for card in cards:
		result.append(card.resource_path)
	return result

static func _cards(paths: Array) -> Array[CardData]:
	var result: Array[CardData] = []
	for path in paths:
		var card := load(path) as CardData
		if card != null:
			result.append(card)
	return result

static func _typed_int_array(values: Array) -> Array[int]:
	var result: Array[int] = []
	for v in values:
		result.append(v)
	return result
