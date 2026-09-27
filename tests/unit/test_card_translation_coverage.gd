extends GutTest

# Garde-fou i18n : chaque carte de resources/cards/ doit avoir sa clé FR + EN
# dans translations/game.csv (nom ET description). Une clé absente n'est pas une
# erreur visible en français — le texte s'affiche tel quel, voir « Une clé absente
# du CSV est affichée telle quelle en jeu » dans CLAUDE.md — mais la carte reste
# alors en français dans la version anglaise, sans que rien ne le signale.
#
# Trouvé par ce test à son écriture (2026-09-26) : les 12 cartes exclusives à
# l'Arena n'avaient aucune clé de nom, et 13 descriptions manquaient également,
# alors que CLAUDE.md affirmait que les 320 cartes étaient toutes traduites.

const CARDS_DIR := "res://resources/cards"
const CSV_PATH := "res://translations/game.csv"

var _keys: Dictionary = {}

func before_all() -> void:
	_keys = _load_csv_keys()
	assert_gt(_keys.size(), 100, "le CSV de traduction doit être lisible et non vide")

# Lit la première colonne de chaque ligne du CSV (la clé). Passe par
# FileAccess.get_csv_line pour suivre exactement les mêmes règles de guillemets
# que l'import Godot — un champ mal échappé ressortirait donc ici aussi.
func _load_csv_keys() -> Dictionary:
	var keys: Dictionary = {}
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	assert_not_null(file, "translations/game.csv doit être lisible")
	if file == null:
		return keys
	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		if line.size() > 0 and not line[0].is_empty():
			keys[line[0]] = line.size()
	file.close()
	return keys

func _collect_card_paths(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			_collect_card_paths(full, out)
		elif entry.ends_with(".tres"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()

func test_every_card_name_and_description_has_a_translation_key() -> void:
	var paths: Array[String] = []
	_collect_card_paths(CARDS_DIR, paths)
	assert_gt(paths.size(), 300, "toutes les cartes doivent être trouvées sur le disque")

	var missing: Array[String] = []
	for path in paths:
		var card: Resource = load(path)
		if card == null:
			continue
		var card_name := str(card.get("card_name"))
		var description := str(card.get("description"))
		if not card_name.is_empty() and not _keys.has(card_name):
			missing.append("%s → nom « %s »" % [path, card_name])
		if not description.is_empty() and not _keys.has(description):
			missing.append("%s → description « %s »" % [path, description.replace("\n", " / ")])

	assert_eq(missing, [] as Array[String],
		"ces textes de carte n'ont aucune clé dans translations/game.csv (ajouter la ligne FR + EN) : %s"
		% "\n  - ".join(missing))

func test_every_csv_row_has_exactly_three_columns() -> void:
	# Une ligne à 4 colonnes signifie un guillemet mal échappé (en CSV il se
	# double, il ne s'échappe pas par backslash) : le champ se ferme trop tôt et
	# la traduction est silencieusement tronquée en jeu. C'était le cas de
	# MENU_LEGAL_BODY (`\"as is\"` dans le texte anglais), corrigé le 2026-09-26.
	var wrong: Array[String] = []
	for key in _keys:
		if int(_keys[key]) != 3:
			wrong.append("%s (%d colonnes)" % [key, int(_keys[key])])
	assert_eq(wrong, [] as Array[String],
		"chaque ligne du CSV doit avoir exactement 3 colonnes (clé, fr, en) : %s" % ", ".join(wrong))
