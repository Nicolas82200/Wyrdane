extends RefCounted
class_name ArenaBoardSnapshot

# Sérialise/désérialise l'état PUBLIC d'un plateau Arena pour le réseau (voir
# ArenaGameCommand.BOARD_SYNC). Un Minion n'est pas un type de base
# (var_to_bytes ne sérialise jamais d'objets arbitraires, voir
# ArenaNetworkManager) — on ne transmet donc que ce qu'il faut pour
# reconstruire un Minion équivalent côté réception : sa carte (retrouvée par
# resource_path via NetCardResolver, même mécanisme que le 1v1), ses stats de
# base ACTUELLES, son niveau d'étoile (fusion) et les dégâts déjà subis.
#
# base_attack/base_max_health sont transmis explicitement et ne doivent
# JAMAIS être recalculés depuis card_data.attack/health côté réception : une
# fusion (ArenaMergeSystem, 2★) les fait DIVERGER des valeurs brutes de la
# carte (somme des 3 copies fusionnées, voir ArenaMergeSystem._merge_group) —
# reconstruire un Minion sans les transmettre lui redonnerait silencieusement
# les stats 1★ de base malgré un star_level correct.
#
# Ne transmet PAS les mots-clés/bonus temporaires acquis en combat
# (TempEffectSystem) : hors de portée de cette étape de fondation, un
# plateau Arena revient de toute façon à un état "propre" entre deux combats
# (voir ArenaPlayerState.reset_after_combat) hormis les dégâts, déjà couverts.

static func serialize_row(row: Array) -> Array:
	var out: Array = []
	for minion in row:
		out.append({
			"resource_path": minion.card_data.resource_path,
			"star_level": minion.star_level,
			"base_attack": minion.base_attack,
			"base_max_health": minion.base_max_health,
			"damage_taken": minion.damage_taken,
		})
	return out

# `is_front` fixe la rangée logique (Minion.board_row) des serviteurs
# reconstruits — indépendante du board_position propre à la carte (Hybride
# compris), déjà tranchée par l'expéditeur au moment de l'envoi.
static func deserialize_row(entries: Array, is_front: bool) -> Array[Minion]:
	var row: Array[Minion] = []
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var resource_path: String = str(entry.get("resource_path", ""))
		if resource_path == "":
			continue
		var card_data: CardData = NetCardResolver.resolve(resource_path)
		if card_data == null:
			continue
		var minion := Minion.new(card_data, true, "Front" if is_front else "Back")
		minion.star_level = int(entry.get("star_level", 1))
		minion.base_attack = int(entry.get("base_attack", card_data.attack))
		minion.base_max_health = int(entry.get("base_max_health", card_data.health))
		minion.damage_taken = int(entry.get("damage_taken", 0))
		row.append(minion)
	return row
