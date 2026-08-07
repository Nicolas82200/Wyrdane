extends RefCounted
class_name CampaignMapNode

# Nœud de la carte de run de campagne (structure de graphe à embranchements).
# Généré par CampaignMapGenerator, ne dépend d'aucun état de Battle/scène.

enum NodeType { COMBAT, ELITE, EVENT, SHOP, REST, BOSS, RELIC }

var id: int
var type: int = NodeType.COMBAT
var depth: int = 0
var next_ids: Array[int] = []
var cleared: bool = false
# Position horizontale indicative (0.0-1.0) dans sa rangée, pour l'affichage de la carte.
var x_hint: float = 0.5

func _init(p_id: int, p_type: int, p_depth: int, p_x_hint: float = 0.5) -> void:
	id = p_id
	type = p_type
	depth = p_depth
	x_hint = p_x_hint
