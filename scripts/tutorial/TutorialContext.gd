extends RefCounted
class_name TutorialContext

# Passe-plat entre MainMenu et la scène Battle, à travers le changement de
# scène (même pattern que NetContext). MainMenu positionne `active = true`
# avant de charger Battle.tscn quand le joueur n'a pas encore terminé le
# tutoriel obligatoire ; Battle le consomme dans son _ready() puis appelle
# clear().

static var active: bool = false

static func clear() -> void:
	active = false
