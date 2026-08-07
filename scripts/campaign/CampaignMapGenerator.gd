extends RefCounted
class_name CampaignMapGenerator

# Génère la carte de run à embranchements (graphe de CampaignMapNode), sans
# fin (voir CAMPAIGN.md « Structure de la run ») : générée par fenêtre
# glissante plutôt qu'en un seul graphe illimité — generate() construit la
# première fenêtre au lancement de la run, extend() en ajoute d'autres à la
# volée quand le joueur s'approche du bord (voir CampaignMapScreen). Logique
# pure, ne dépend d'aucun état de Battle/scène — testable en isolation.

const WINDOW_SIZE := 15
# Un Boss apparaît tous les BOSS_INTERVAL paliers (10, 20, 30...), seul nœud
# de son palier — plus une fin de run, un jalon récurrent (CAMPAIGN.md).
const BOSS_INTERVAL := 10
const MIN_PATHS := 1
const MAX_PATHS := 3

# Poids de tirage de type pour un palier normal (hors Boss). REST/SHOP restent
# stables avec la profondeur (CAMPAIGN.md : "la fréquence de Repos et de
# Boutique reste stable, pour ne pas punir doublement la difficulté déjà
# croissante"). RELIC : fréquence non tranchée dans CAMPAIGN.md (point
# ouvert) — poids modeste choisi arbitrairement, à ajuster en playtest.
const BASE_WEIGHTS := {
	CampaignMapNode.NodeType.COMBAT: 50,
	CampaignMapNode.NodeType.REST: 12,
	CampaignMapNode.NodeType.SHOP: 10,
	CampaignMapNode.NodeType.RELIC: 6,
}
# Poids ÉLITE/ÉVÉNEMENT croissants avec la profondeur (CAMPAIGN.md : "plus
# d'Élites et d'Événements à mesure que la run avance"), plafonnés pour ne
# jamais écraser le reste du pool à très haute profondeur.
const ELITE_BASE := 8
const ELITE_GROWTH_PER_DEPTH := 1
const ELITE_WEIGHT_CAP := 35
const EVENT_BASE := 10
const EVENT_GROWTH_PER_DEPTH := 1
const EVENT_WEIGHT_CAP := 30

# Première fenêtre de la carte (paliers 1..WINDOW_SIZE), pour le lancement
# d'une run. Retourne {"nodes": Array[CampaignMapNode], "start_ids": Array[int]}.
static func generate(rng: RandomNumberGenerator) -> Dictionary:
	var nodes: Array[CampaignMapNode] = []
	var start_ids: Array[int] = []
	var previous_layer: Array[CampaignMapNode] = []
	var next_id := 0
	for depth in range(1, WINDOW_SIZE + 1):
		var layer := _generate_layer(rng, depth, next_id)
		next_id += layer.size()
		nodes.append_array(layer)
		if depth == 1:
			for node in layer:
				start_ids.append(node.id)
		else:
			_link_layers(rng, previous_layer, layer)
		previous_layer = layer
	return {"nodes": nodes, "start_ids": start_ids}

# Ajoute `additional_paliers` paliers de plus à la carte d'une run existante,
# reliés au dernier palier déjà généré. Mute run.map directement.
static func extend(run: CampaignRun, additional_paliers: int = WINDOW_SIZE) -> void:
	var max_depth := 0
	var next_id := 0
	for node in run.map:
		max_depth = max(max_depth, node.depth)
		next_id = max(next_id, node.id + 1)
	var previous_layer: Array[CampaignMapNode] = run.map.filter(
		func(n: CampaignMapNode) -> bool: return n.depth == max_depth)
	var new_nodes: Array[CampaignMapNode] = []
	for depth in range(max_depth + 1, max_depth + additional_paliers + 1):
		var layer := _generate_layer(run.rng, depth, next_id)
		next_id += layer.size()
		_link_layers(run.rng, previous_layer, layer)
		new_nodes.append_array(layer)
		previous_layer = layer
	run.map.append_array(new_nodes)

static func _generate_layer(rng: RandomNumberGenerator, depth: int, start_id: int) -> Array[CampaignMapNode]:
	var layer: Array[CampaignMapNode] = []
	if depth % BOSS_INTERVAL == 0:
		layer.append(CampaignMapNode.new(start_id, CampaignMapNode.NodeType.BOSS, depth, 0.5))
		return layer
	var count := rng.randi_range(MIN_PATHS, MAX_PATHS)
	for i in range(count):
		var node_type := _roll_type(rng, depth)
		layer.append(CampaignMapNode.new(start_id + i, node_type, depth, _x_hint(i, count)))
	# Repos garanti au palier juste avant chaque Boss.
	if (depth + 1) % BOSS_INTERVAL == 0:
		var has_rest := false
		for node in layer:
			if node.type == CampaignMapNode.NodeType.REST:
				has_rest = true
				break
		if not has_rest:
			layer[0].type = CampaignMapNode.NodeType.REST
	return layer

static func _roll_type(rng: RandomNumberGenerator, depth: int) -> int:
	var weights: Dictionary = BASE_WEIGHTS.duplicate()
	weights[CampaignMapNode.NodeType.ELITE] = min(ELITE_BASE + depth * ELITE_GROWTH_PER_DEPTH, ELITE_WEIGHT_CAP)
	weights[CampaignMapNode.NodeType.EVENT] = min(EVENT_BASE + depth * EVENT_GROWTH_PER_DEPTH, EVENT_WEIGHT_CAP)
	var total := 0
	for w in weights.values():
		total += w
	var roll := rng.randi_range(1, total)
	var acc := 0
	for node_type in weights:
		acc += weights[node_type]
		if roll <= acc:
			return node_type
	return CampaignMapNode.NodeType.COMBAT

static func _x_hint(index: int, count: int) -> float:
	if count <= 1:
		return 0.5
	return float(index) / float(count - 1)

# Relie chaque nœud du palier précédent à 1-2 nœuds du palier suivant (les
# plus proches en x), puis vérifie qu'aucun nœud du palier suivant ne reste
# orphelin (repêché par le nœud le plus proche en x du palier précédent).
static func _link_layers(rng: RandomNumberGenerator, previous_layer: Array[CampaignMapNode], layer: Array[CampaignMapNode]) -> void:
	for node in previous_layer:
		var link_count: int = 1 if layer.size() <= 1 else rng.randi_range(1, min(2, layer.size()))
		for target in _closest_by_x(node.x_hint, layer, link_count):
			if not node.next_ids.has(target.id):
				node.next_ids.append(target.id)
	var reached: Dictionary = {}
	for node in previous_layer:
		for target_id in node.next_ids:
			reached[target_id] = true
	for target in layer:
		if not reached.has(target.id):
			var closest := _closest_by_x(target.x_hint, previous_layer, 1)
			if not closest.is_empty():
				closest[0].next_ids.append(target.id)

static func _closest_by_x(x: float, layer: Array[CampaignMapNode], count: int) -> Array:
	var sorted_layer: Array = layer.duplicate()
	sorted_layer.sort_custom(func(a: CampaignMapNode, b: CampaignMapNode) -> bool:
		return abs(a.x_hint - x) < abs(b.x_hint - x))
	return sorted_layer.slice(0, min(count, sorted_layer.size()))
