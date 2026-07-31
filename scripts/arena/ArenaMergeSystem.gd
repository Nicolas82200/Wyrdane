extends RefCounted
class_name ArenaMergeSystem

# Fusion automatique de 3 copies identiques en une carte 2★ dorée (voir
# README « Upgrade de cartes ») — un seul palier de fusion, il n'existe pas
# de carte 3★ : une 2★ est déjà la version maximale, 3 copies d'une 2★ (cas
# rare mais possible) ne fusionnent donc jamais entre elles. Détection
# passive : à appeler après tout ajout de carte en main (achat, vente
# déclenchant une libération de suspens...) via ArenaMatch.merge_hook.

# Fusionne toutes les 3-copies (1★ uniquement) disponibles chez `player` :
# en boucle, car _find_group_of_three ne renvoie qu'un seul groupe à la
# fois — nécessaire si le joueur a simultanément 3-copies de plusieurs
# cartes différentes à fusionner.
func try_merge_all(player: ArenaPlayerState) -> void:
	var group := _find_group_of_three(player)
	while not group.is_empty():
		_merge_group(player, group)
		group = _find_group_of_three(player)

func _find_group_of_three(player: ArenaPlayerState) -> Array:
	var groups: Dictionary = {}  # resource_path -> Array[Minion], 1★ seulement
	for minion in player.all_owned_minions():
		if minion.star_level > 1:
			continue  # déjà 2★ (version maximale) : ne fusionne plus jamais
		var key: String = minion.card_data.resource_path
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
	var star_level := 2
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
