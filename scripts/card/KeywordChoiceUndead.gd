# KeywordChoiceUndead.gd — miroir de KeywordChoiceHuman.gd pour la race Mort-Vivant
extends Resource
class_name KeywordChoiceUndead
@export var keyword_type: KeywordUndead.Type
# Durée d'Infection (le "X" de "MORSURE X") : uniquement pertinent pour
# keyword_type == MORSURE. Même principe que KeywordChoiceDemon.value pour
# PACTE X. Voir CombatSystem.resolve_attack.
@export var value: int = 0
