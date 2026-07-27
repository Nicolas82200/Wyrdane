extends GutTest

# Couvre TooltipData (scripts/systems/TooltipData.gd), la partie données
# (dictionnaires de description) plutôt que la fabrique de panels UI : chaque
# valeur des enums de mots-clés (communs + par race) doit avoir une entrée
# correspondante, sans quoi son tooltip resterait vide en jeu. Pas de classe
# nommée dans le script source (autoload chargé par chemin) : chargé par
# chemin, sans dépendance à battle.

var tooltip_data

func before_each() -> void:
	tooltip_data = load("res://scripts/systems/TooltipData.gd").new()

func _all_enum_values(a_dict: Dictionary) -> Array:
	return a_dict.keys()

# ─── Complétude des dictionnaires de mots-clés ─────────────────────────────────

func test_every_common_keyword_has_a_description() -> void:
	for value in Keyword.Type.values():
		assert_true(tooltip_data.KEYWORD_DESCRIPTIONS.has(value),
			"Keyword.Type %s n'a pas d'entrée dans KEYWORD_DESCRIPTIONS" % Keyword.Type.keys()[value])

func test_every_human_keyword_has_a_description() -> void:
	for value in KeywordHuman.Type.values():
		assert_true(tooltip_data.KEYWORD_HUMAN_DESCRIPTIONS.has(value),
			"KeywordHuman.Type %s n'a pas d'entrée dans KEYWORD_HUMAN_DESCRIPTIONS" % KeywordHuman.Type.keys()[value])

func test_every_undead_keyword_has_a_description() -> void:
	for value in KeywordUndead.Type.values():
		assert_true(tooltip_data.KEYWORD_UNDEAD_DESCRIPTIONS.has(value),
			"KeywordUndead.Type %s n'a pas d'entrée dans KEYWORD_UNDEAD_DESCRIPTIONS" % KeywordUndead.Type.keys()[value])

func test_every_demon_keyword_has_a_description() -> void:
	for value in KeywordDemon.Type.values():
		assert_true(tooltip_data.KEYWORD_DEMON_DESCRIPTIONS.has(value),
			"KeywordDemon.Type %s n'a pas d'entrée dans KEYWORD_DEMON_DESCRIPTIONS" % KeywordDemon.Type.keys()[value])

func test_every_abomination_keyword_has_a_description() -> void:
	for value in KeywordAbomination.Type.values():
		assert_true(tooltip_data.KEYWORD_ABOMINATION_DESCRIPTIONS.has(value),
			"KeywordAbomination.Type %s n'a pas d'entrée dans KEYWORD_ABOMINATION_DESCRIPTIONS" % KeywordAbomination.Type.keys()[value])

func test_every_keyword_description_has_title_and_desc_keys() -> void:
	var all_dicts: Array = [
		tooltip_data.KEYWORD_DESCRIPTIONS, tooltip_data.KEYWORD_HUMAN_DESCRIPTIONS,
		tooltip_data.KEYWORD_UNDEAD_DESCRIPTIONS, tooltip_data.KEYWORD_DEMON_DESCRIPTIONS,
		tooltip_data.KEYWORD_ABOMINATION_DESCRIPTIONS,
	]
	for a_dict in all_dicts:
		for info in a_dict.values():
			assert_true(info.has("title") and not info["title"].is_empty())
			assert_true(info.has("desc") and not info["desc"].is_empty())

func test_every_real_race_has_a_description_key() -> void:
	# NONE n'est pas une race jouable (carte neutre/générique) : pas de
	# description attendue pour elle.
	for value in Race.Type.values():
		if value == Race.Type.NONE:
			continue
		assert_true(tooltip_data.RACE_DESCRIPTIONS.has(value),
			"Race.Type %s n'a pas d'entrée dans RACE_DESCRIPTIONS" % Race.Type.keys()[value])

# ─── describe_effect ────────────────────────────────────────────────────────────

func _effect(effect_id: String) -> CardEffect:
	var effect := CardEffect.new()
	effect.effect_id = effect_id
	return effect

func test_describe_effect_returns_non_empty_for_known_ids() -> void:
	var known_ids := ["Freeze", "InfectEnemy", "InfectAdjacent", "Transform",
		"Silence", "StealMinion", "Corrupt", "StealMinionThenDestroy"]
	for effect_id in known_ids:
		var desc: String = tooltip_data.describe_effect(_effect(effect_id))
		assert_false(desc.is_empty(), "describe_effect(%s) ne devrait pas être vide" % effect_id)

func test_describe_effect_returns_empty_for_unknown_id() -> void:
	assert_eq(tooltip_data.describe_effect(_effect("SomeUnhandledEffect")), "")

# ─── build_panels_for_card ──────────────────────────────────────────────────────

func test_build_panels_for_card_creates_one_panel_per_recognized_keyword() -> void:
	var card := CardData.new()
	var kw := KeywordChoice.new()
	kw.name_fr = "Frénésie"  # -> Keyword.Type.FURY
	card.keywords = [kw]
	var parent := Node.new()
	var panels: Array = tooltip_data.build_panels_for_card(card, parent)
	assert_eq(panels.size(), 1)
	parent.free()

func test_build_panels_for_card_returns_empty_for_a_vanilla_card() -> void:
	var card := CardData.new()
	var parent := Node.new()
	var panels: Array = tooltip_data.build_panels_for_card(card, parent)
	assert_eq(panels.size(), 0)
	parent.free()
