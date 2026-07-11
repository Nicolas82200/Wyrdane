extends Node
class_name OpponentDriver

# "Cerveau" qui pilote le camp adverse. Battle ne connaît que cette interface,
# sans savoir si l'adversaire est l'IA ou un joueur distant. Deux implémentations :
#   - AISystem        : décide ses actions localement (solo)
#   - NetworkOpponent : attend et rejoue les commandes d'un joueur distant (à venir)
#
# C'est le point de branchement du multijoueur : TurnSystem.end_turn() appelle
# battle.opponent.take_turn() sans se soucier de l'implémentation.

var battle
# Ressource du camp adverse, affichée côté joueur local (cristaux de mana).
# Gérée par chaque implémentation : l'IA en solo, le rejeu des TURN_CHOICE en réseau.
var mana: int = 0
var max_mana: int = 0

func init(_battle) -> void:
	battle = _battle

# Prépare le camp adverse en début de partie (deck, main de départ...).
func setup() -> void:
	pass

# Joue le tour adverse EN ENTIER (ou l'attend et le rejoue), puis rend la main.
func take_turn() -> void:
	pass

# Rafraîchit l'affichage du camp adverse (dos de cartes, compteurs).
func refresh_ui() -> void:
	pass

# Attend que le camp adverse ait terminé son mulligan. L'IA a déjà décidé de
# façon synchrone dans setup() : rien à attendre. NetworkOpponent surcharge
# pour attendre le MULLIGAN_DONE du pair distant.
func await_mulligan() -> void:
	pass

# Compteurs affichés côté joueur local (dos de deck / main adverse). Surchargés
# par chaque implémentation (l'IA lit ses tableaux ; le réseau suit des compteurs).
func get_deck_count() -> int:
	return 0

func get_hand_count() -> int:
	return 0
