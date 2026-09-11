extends RefCounted
class_name CustomMatchContext

# Passe-plat entre MainMenu et la scène Battle, à travers le changement de
# scène (même pattern que TutorialContext/NetContext) : porte le réglage de
# difficulté IA choisi ponctuellement pour une "Partie personnalisée" (voir
# MainMenu._on_launch_pressed), sans jamais toucher au réglage global
# persistant SettingsManager.ai_difficulty. Chaîne vide = pas de
# surcharge, l'IA utilise le réglage global comme d'habitude.

static var ai_difficulty_override: String = ""

static func clear() -> void:
	ai_difficulty_override = ""
