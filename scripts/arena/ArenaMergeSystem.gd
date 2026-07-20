extends RefCounted
class_name ArenaMergeSystem

# Fusion automatique de 3 copies identiques (même carte, même star_level) en
# une carte 2★ (voir README « Upgrade de cartes »). Détection passive : à
# appeler après tout ajout de carte en main (achat, vente déclenchant une
# libération de suspens...) via ArenaMatch.merge_hook.

# Fusionne toutes les 3-copies disponibles chez `player`, en boucle (une
# fusion peut elle-même produire une nouvelle 3-copie si le joueur en a
# déjà deux autres 2★ identiques en réserve).
func try_merge_all(player: ArenaPlayerState) -> void:
	var group := _find_group_of_three(player)
	while not group.is_empty():
		_merge_group(player, group)
		group = _find_group_of_three(player)

func _find_group_of_three(player: ArenaPlayerState) -> Array:
	var groups: Dictionary = {}  # "path|star" -> Array[Minion]
	for minion in player.all_owned_minions():
		var key: String = "%s|%d" % [minion.card_data.resource_path, minion.star_level]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(minion)
	for key in groups:
		var list: Array = groups[key]
		if list.size() >= 3:
			return list.slice(0, 3)
	return []

func _merge_group(player: ArenaPlayerState, group: Array) -> Minion:
	var total_attack := 0
	var total_health := 0
	for m in group:
		total_attack += (m as Minion).base_attack
		total_health += (m as Minion).base_max_health
	var star_level: int = (group[0] as Minion).star_level + 1
	var card_data: CardData = (group[0] as Minion).card_data

	for m in group:
		_remove_wherever_it_is(player, m as Minion)

	var merged := Minion.new(card_data, true, "Front")
	merged.base_attack = total_attack
	merged.base_max_health = total_health
	merged.star_level = star_level
	# Toujours en main, même si une ou plusieurs sources étaient sur le
	# plateau (exception explicite à "jamais de retour en main", README).
	player.add_to_hand(merged)
	return merged

func _remove_wherever_it_is(player: ArenaPlayerState, minion: Minion) -> void:
	if player.hand.has(minion):
		player.hand.erase(minion)
	elif player.suspended.has(minion):
		player.suspended.erase(minion)
	else:
		player.remove_from_board(minion)
