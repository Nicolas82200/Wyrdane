extends RefCounted
class_name ArenaSeatController

# Abstraction "qui pilote ce siège Arena" — même rôle qu'OpponentDriver.gd
# pour le 1v1 (scripts/net/OpponentDriver.gd) : ArenaBattle ne devrait
# dépendre que de cette interface pour faire jouer un siège, sans savoir si
# c'est un bot local (ArenaBotSeatController) ou, plus tard, un joueur réseau
# distant (ArenaNetworkSeatController, à venir avec l'extension réseau à 8
# joueurs — voir README « Réseau & Visibilité »).
#
# Le siège du joueur humain local reste pour l'instant piloté directement par
# ArenaBattle (drag & drop, boutons UI) plutôt que par une implémentation de
# cette interface : introduire un LocalHumanSeatController n'aurait d'intérêt
# que lorsque plusieurs sièges pourront être "locaux" à des clients
# différents (réseau), pas avant.

var player: ArenaPlayerState

func _init(p: ArenaPlayerState) -> void:
	player = p

# Joue l'intégralité de la phase Boutique de ce siège (achats/reroll/XP,
# positionnement, lancer des Incantations) puis rend la main. Coroutine :
# les implémentations réseau devront attendre les commandes du pair distant.
func take_shop_turn(_match: ArenaMatch) -> void:
	pass
