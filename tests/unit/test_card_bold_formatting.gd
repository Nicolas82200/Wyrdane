extends GutTest

# Couvre bold_keywords_and_triggers (scripts/card/Card.gd) : mise en gras du
# nom de declencheur en debut de ligne ("Trigger : ...") et des mots-cles
# tout en majuscules, utilisee par Card.update_display() pour le bbcode de
# DescLabel. Fonctions statiques et pures : pas besoin d'instancier la scene.

var CardScript := load("res://scripts/card/Card.gd")

func test_bolds_trigger_name_before_colon() -> void:
	var result: String = CardScript.bold_keywords_and_triggers("Arrivee : Inflige 2 degats a un serviteur ennemi ciblé.")
	assert_eq(result, "[b]Arrivee[/b] : Inflige 2 degats a un serviteur ennemi ciblé.")

func test_bolds_multiword_trigger_name() -> void:
	var result: String = CardScript.bold_keywords_and_triggers("Dernier Souffle : Invoque un Zombie 1/1.")
	assert_eq(result, "[b]Dernier Souffle[/b] : Invoque un Zombie 1/1.")

func test_bolds_leading_keyword_line_without_colon() -> void:
	var result: String = CardScript.bold_keywords_and_triggers("REMPART, ÉGIDE")
	assert_eq(result, "[b]REMPART[/b], [b]ÉGIDE[/b]")

func test_bolds_multiword_keyword() -> void:
	var result: String = CardScript.bold_keywords_and_triggers("Gagne VENIN MORTEL jusqu'à la fin du tour.")
	assert_eq(result, "Gagne [b]VENIN MORTEL[/b] jusqu'à la fin du tour.")

func test_does_not_bold_short_all_caps_acronym() -> void:
	var result: String = CardScript.bold_keywords_and_triggers("Detruit un serviteur ennemi ayant 2 ATK ou moins.")
	assert_eq(result, "Detruit un serviteur ennemi ayant 2 ATK ou moins.")

func test_handles_multiple_lines_independently() -> void:
	var result: String = CardScript.bold_keywords_and_triggers("REMPART
Dernier Souffle : Invoque un Zombie 1/1.")
	assert_eq(result, "[b]REMPART[/b]
[b]Dernier Souffle[/b] : Invoque un Zombie 1/1.")

func test_bolds_keyword_inside_trigger_effect_text() -> void:
	var result: String = CardScript.bold_keywords_and_triggers("Arrivee : Ce serviteur gagne RANG INFERNAL de facon permanente.")
	assert_eq(result, "[b]Arrivee[/b] : Ce serviteur gagne [b]RANG INFERNAL[/b] de facon permanente.")
