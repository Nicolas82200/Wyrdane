extends GutTest

# Instance locale plutôt que l'autoload CardLibrary : évite de dépendre de
# l'ordre d'initialisation des autoloads dans le runner de tests, et isole
# ces tests de l'état global du jeu.
var library

func before_all() -> void:
	library = load("res://scripts/loading/CardLibrary.gd").new()
	library.load_all_cards()

func after_all() -> void:
	library.free()

func test_library_loads_cards() -> void:
	assert_true(library.is_loaded)
	assert_gt(library.all_cards.size(), 0, "la bibliothèque de cartes ne doit pas être vide")

func test_every_card_has_a_name() -> void:
	for card in library.all_cards:
		assert_ne(card.card_name, "", "carte sans card_name : %s" % card.resource_path)

func test_every_card_has_non_negative_cost() -> void:
	for card in library.all_cards:
		assert_true(card.cost >= 0, "coût négatif sur %s" % card.card_name)

func test_minion_cards_have_positive_health() -> void:
	for card in library.all_cards:
		if card.card_type == "Minion":
			assert_gt(card.health, 0, "serviteur sans HP : %s" % card.card_name)

func test_non_minion_cards_have_no_combat_stats() -> void:
	for card in library.all_cards:
		if card.card_type != "Minion":
			assert_eq(card.attack, 0, "%s (%s) ne devrait pas avoir d'attaque" % [card.card_name, card.card_type])
			assert_eq(card.health, 0, "%s (%s) ne devrait pas avoir de HP" % [card.card_name, card.card_type])

func test_card_race_matches_resource_folder() -> void:
	for card in library.all_cards:
		var path: String = card.resource_path
		var expected_folder: String = ""
		match card.race:
			Race.Type.UNDEAD: expected_folder = "/undead/"
			Race.Type.HUMAN:  expected_folder = "/human/"
			Race.Type.DEMON:  expected_folder = "/demon/"
			Race.Type.ABOMINATION: expected_folder = "/abomination/"
			_: continue
		assert_true(path.contains(expected_folder), "%s : race %s ne correspond pas au dossier %s" % [path, card.race, path])

func test_no_duplicate_card_names() -> void:
	var seen: Dictionary = {}
	var duplicates: Array = []
	for card in library.all_cards:
		if seen.has(card.card_name):
			duplicates.append(card.card_name)
		seen[card.card_name] = true
	assert_eq(duplicates.size(), 0, "noms de carte dupliqués (cassent les clés de traduction) : %s" % str(duplicates))

func test_ritual_cards_have_a_duration() -> void:
	for card in library.all_cards:
		if card.card_type == "Ritual":
			assert_ne(card.ritual_duration, 0, "%s : un Rituel doit avoir ritual_duration != 0" % card.card_name)

func test_token_cards_are_excluded_from_library() -> void:
	for card in library.all_cards:
		assert_false(card.is_token, "%s : un jeton (is_token=true) ne doit pas apparaître dans CardLibrary.all_cards (deckbuilder/IA/pool aléatoire)" % card.resource_path)

func test_arena_only_cards_are_excluded_from_library_but_kept_separately() -> void:
	for card in library.all_cards:
		assert_false(card.arena_only, "%s : une carte arena_only=true ne doit pas apparaître dans all_cards (deckbuilder/IA/pool aléatoire)" % card.resource_path)
	assert_gt(library.arena_only_cards.size(), 0, "aucune carte arena_only trouvée, le scan a probablement échoué")
	for card in library.arena_only_cards:
		assert_true(card.arena_only)

func test_token_cards_have_no_chaining_effects() -> void:
	var token_paths: Array[String] = []
	_collect_token_paths("res://resources/cards", token_paths)
	assert_gt(token_paths.size(), 0, "aucun jeton trouvé, le scan a probablement échoué")
	for path in token_paths:
		var card: CardData = load(path)
		assert_true(card.is_token, "%s devrait avoir is_token=true" % path)
		assert_eq(card.effects.size(), 0, "%s : un jeton ne doit porter aucun effect (risque de réaction en chaîne)" % path)

func _collect_token_paths(path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := path + "/" + file_name
		if dir.current_is_dir():
			_collect_token_paths(full_path, out)
		elif file_name.ends_with(".tres"):
			var res := load(full_path)
			if res is CardData and (res as CardData).is_token:
				out.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
