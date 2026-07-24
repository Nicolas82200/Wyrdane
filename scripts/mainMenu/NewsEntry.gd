# NewsEntry.gd
# Une entrée d'actualité affichée dans le panneau du menu principal.
# title/body sont le texte FR brut, utilisé aussi comme clé de traduction
# (même convention que CardData : voir CardData.display_description()).
extends Resource
class_name NewsEntry

@export var date: String = ""
@export var title: String = ""
@export_multiline var body: String = ""

func display_title() -> String:
	return TranslationServer.translate(title)

func display_body() -> String:
	return TranslationServer.translate(body)
