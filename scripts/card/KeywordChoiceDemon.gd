# KeywordChoiceDemon.gd — miroir de KeywordChoiceHuman.gd pour la race Démon
extends Resource
class_name KeywordChoiceDemon
@export var keyword_type: KeywordDemon.Type
# Coût en PV du Pacte (le "X" de "Pacte X") : uniquement pertinent pour
# keyword_type == PACTE. Le joueur choisit à l'arrivée de payer cette valeur
# pour activer l'effet d'Arrivée (ONPLAY) de la carte, ou de la poser sans payer
# ni effet. Voir BoardSystem.summon_minion_return / CardSystem.handle_card_played.
@export var value: int = 0
