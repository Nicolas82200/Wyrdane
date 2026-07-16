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
# Pools de ressource par race (clé = Race.Type) du camp adverse, affichés côté
# joueur local. Gérés par chaque implémentation : l'IA en solo, le rejeu des
# cartes-ressource (PLAY_CARD) du pair distant en réseau.
var race_mana: Dictionary = {}
var race_max_mana: Dictionary = {}

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

# Pioche 1 carte pour le camp adverse (effets déclenchés côté ennemi, ex.
# Autel des Damnés). Surchargé par chaque implémentation : l'IA pioche
# réellement dans son propre deck, le réseau se contente de mettre à jour ses
# compteurs cosmétiques (le pair distant pioche la vraie carte de son côté).
func draw_card() -> void:
	pass
