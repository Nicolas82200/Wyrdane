extends GutTest

# Couvre les helpers purs de CardData (scripts/card/CardData.gd) : résolution
# i18n (display_name/description/flavour) et aplatissement des tableaux de
# KeywordChoice*/TriggerTypeChoice en valeurs d'enum/String brutes, utilisés
# par Minion._init() pour peupler ses propres tableaux de mots-clés.

var card: CardData

func before_each() -> void:
	card = CardData.new()

# ─── Textes localisés ────────────────────────────────────────────────────────
# TranslationServer.translate() renvoie la clé telle quelle si aucune
# traduction n'existe pour la locale active : un texte qui n'est pas une clé
# CSV connue (garanti par construction ici) sert donc de repli déterministe,
# indépendant du chargement réel de translations/game.csv dans ce runner.

func test_display_name_falls_back_to_the_raw_card_name() -> void:
	card.card_name = "__UNKNOWN_TEST_KEY_NAME__"
	assert_eq(card.display_name(), "__UNKNOWN_TEST_KEY_NAME__")

func test_display_description_falls_back_to_the_raw_description() -> void:
	card.description = "__UNKNOWN_TEST_KEY_DESC__"
	assert_eq(card.display_description(), "__UNKNOWN_TEST_KEY_DESC__")

func test_display_flavour_falls_back_to_the_raw_flavour_text() -> void:
	card.flavour_text = "__UNKNOWN_TEST_KEY_FLAVOUR__"
	assert_eq(card.display_flavour(), "__UNKNOWN_TEST_KEY_FLAVOUR__")

# ─── get_keyword_values (base, via KeywordChoice.name_fr) ───────────────────

func test_get_keyword_values_resolves_name_fr_to_the_matching_enum() -> void:
	var infiltration := KeywordChoice.new()
	infiltration.name_fr = "Infiltration"
	var egide := KeywordChoice.new()
	egide.name_fr = "Égide"
	card.keywords = [infiltration, egide]
	assert_eq(card.get_keyword_values(), [Keyword.Type.BLACK_WINGS, Keyword.Type.AEGIS])

func test_get_keyword_values_is_empty_by_default() -> void:
	assert_eq(card.get_keyword_values(), [])

# ─── get_human/undead/demon/abomination_keyword_values ──────────────────────

func test_get_human_keyword_values_reads_keyword_type_directly() -> void:
	var kw := KeywordChoiceHuman.new()
	kw.keyword_type = KeywordHuman.Type.COMMANDEMENT
	card.human_keywords = [kw]
	assert_eq(card.get_human_keyword_values(), [KeywordHuman.Type.COMMANDEMENT])

func test_get_undead_keyword_values_reads_keyword_type_directly() -> void:
	var kw := KeywordChoiceUndead.new()
	kw.keyword_type = KeywordUndead.Type.NECROPHAGE
	card.undead_keywords = [kw]
	assert_eq(card.get_undead_keyword_values(), [KeywordUndead.Type.NECROPHAGE])

func test_get_demon_keyword_values_reads_keyword_type_directly() -> void:
	var kw := KeywordChoiceDemon.new()
	kw.keyword_type = KeywordDemon.Type.CORRUPTION
	card.demon_keywords = [kw]
	assert_eq(card.get_demon_keyword_values(), [KeywordDemon.Type.CORRUPTION])

func test_get_abomination_keyword_values_reads_keyword_type_directly() -> void:
	var kw := KeywordChoiceAbomination.new()
	kw.keyword_type = KeywordAbomination.Type.MUTATION
	card.abomination_keywords = [kw]
	assert_eq(card.get_abomination_keyword_values(), [KeywordAbomination.Type.MUTATION])

# ─── get_trigger_names ───────────────────────────────────────────────────────

func test_get_trigger_names_extracts_type_strings_in_order() -> void:
	var t1 := TriggerTypeChoice.new()
	t1.type = "OnSummon"
	var t2 := TriggerTypeChoice.new()
	t2.type = "OnGrief"
	card.trigger_types = [t1, t2]
	assert_eq(card.get_trigger_names(), ["OnSummon", "OnGrief"])

func test_get_trigger_names_is_empty_by_default() -> void:
	assert_eq(card.get_trigger_names(), [])
