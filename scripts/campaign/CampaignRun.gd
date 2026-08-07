extends RefCounted
class_name CampaignRun

# État complet d'une run de campagne en cours (RefCounted, pas de scène).
# Instancié une fois au lancement (CampaignRaceSelect), muté tout au long de la
# run (sans fin, voir CAMPAIGN.md), sauvegardé/rechargé localement
# (CampaignSaveService) et détruit uniquement à la mort du héros
# (CampaignContext.clear()).

var race: int = Race.Type.NONE
# Plateau du joueur : liste plate de CardData, la rangée (Avant/Arrière) est
# déduite de CardData.board_position à la pose (voir board_with_rows()). Les
# Reliques (card_type Enchantment/Ritual) y sont mélangées comme n'importe
# quelle autre carte — pas de structure séparée, voir relic_cards().
var board: Array[CardData] = []
var hero_health: int = 30
var hero_max_health: int = 30
var gold: int = 0
var map: Array[CampaignMapNode] = []
var start_node_ids: Array[int] = []
var current_node_id: int = -1
# Palier atteint (0 = aucun palier encore franchi, paliers de la carte
# numérotés à partir de 1), sert au scaling des adversaires Normaux, à la
# génération de la carte (fenêtre glissante) et à la récompense de consolation.
var depth: int = 0
# Race adverse de la tranche de 10 paliers en cours (tirée au premier palier
# de chaque tranche, voir CampaignOpponentFactory.ensure_tier_race). tier_index
# = -1 force le premier tirage à la génération du premier adversaire.
var tier_race: int = Race.Type.NONE
var tier_index: int = -1
# Compteurs de victoires séparés : le scaling Élite/Boss suit le nombre de
# victoires contre CE type, pas le palier (voir CAMPAIGN.md « Scaling »).
var elite_wins: int = 0
var boss_wins: int = 0
# Coût du prochain retrait en Boutique (+10 or à chaque retrait, ne redescend
# jamais sur la durée de la run).
var discard_count: int = 0
var rng_seed: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
# Adversaire déjà tiré et figé pour le nœud en cours d'engagement, sauvegardé
# juste avant d'entrer en combat (CAMPAIGN.md « Sauvegarde de run » : l'IA doit
# rester identique en cas de relance après une fermeture du jeu). Vidé une
# fois le combat commencé.
var pending_enemy_board: Array[CardData] = []
# Les 3 cartes de récompense proposées après une victoire non encore choisie
# (le joueur a fermé le jeu sur l'écran de récompense) — sauvegardé juste
# après la victoire, vidé une fois le choix fait.
var pending_reward_cards: Array[CardData] = []

func add_card_to_board(card: CardData) -> void:
	board.append(card)

func remove_card_from_board(card: CardData) -> void:
	board.erase(card)

## Cartes Enchantement/Rituel présentes sur le plateau (= les Reliques
## obtenues, voir CAMPAIGN.md « Reliques » : ce sont littéralement des cartes
## du plateau, pas une structure de bonus séparée).
func relic_cards() -> Array[CardData]:
	return board.filter(func(c: CardData) -> bool: return c.card_type == "Enchantment" or c.card_type == "Ritual")

## Plateau du joueur avec la rangée déduite de CardData.board_position.
## "Hybrid" retombe sur Avant (pas de choix manuel en Campagne, voir
## CAMPAIGN.md — seul le placement adverse est explicitement aléatoire).
func board_with_rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card in board:
		var row := "Back" if card.board_position == "Back" else "Front"
		result.append({"card": card, "row": row})
	return result

func heal(amount: int) -> void:
	hero_health = min(hero_max_health, hero_health + amount)

func current_node() -> CampaignMapNode:
	for node in map:
		if node.id == current_node_id:
			return node
	return null

func node_by_id(node_id: int) -> CampaignMapNode:
	for node in map:
		if node.id == node_id:
			return node
	return null

func mark_node_cleared(node_id: int) -> void:
	var node := node_by_id(node_id)
	if node:
		node.cleared = true
		depth = max(depth, node.depth)

# Nœuds accessibles depuis la position actuelle (racines de la carte si la run
# vient de commencer, sinon les next_ids du nœud courant).
func accessible_node_ids() -> Array[int]:
	if current_node_id == -1:
		return start_node_ids
	var node := current_node()
	return node.next_ids if node else []
