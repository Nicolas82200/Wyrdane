## Exporte le rendu complet de chaque carte (illustration + cadre + nom +
## coût + stats + description), tel qu'affiché en jeu, en PNG haute
## résolution — pas seulement l'illustration brute (voir
## tools/export_card_art_png.py pour ça).
##
## Usage (depuis la racine du projet) :
##   godot --headless --path . res://scenes/tools/CardFullPngExporter.tscn
##
## Doit être lancé comme une scène (et non via --script) pour que les
## autoloads du projet (SettingsManager, etc., requis par Card.gd) soient
## bien initialisés.
##
## Écrit dans export/card_full_png/<race>/<slug>.png, un fichier par carte
## trouvée sous resources/cards/. Le rendu est fait à SCALE fois la taille
## d'affichage de la carte (voir scenes/card/Card.tscn) pour rester net.
extends Node

const SCALE := 4.0
const CARD_W := 250.0
const CARD_H := 375.0
# Marges du cadre noir (BorderFrameBlack dans Card.tscn), légèrement plus
# grand que la carte elle-même : à inclure dans le viewport pour ne pas le
# couper au rendu.
const MARGIN_L := 8.0
const MARGIN_T := 9.0
const MARGIN_R := 8.0
const MARGIN_B := 8.0
const VIEWPORT_W := CARD_W + MARGIN_L + MARGIN_R
const VIEWPORT_H := CARD_H + MARGIN_T + MARGIN_B

const CARD_SCENE := preload("res://scenes/card/Card.tscn")
const SOURCE_DIR := "res://resources/cards"
const OUTPUT_DIR := "res://export/card_full_png"

var _viewport: SubViewport
var _card: Card


func _ready() -> void:
	# Laisser le premier _ready()/update_display() de la carte se stabiliser
	# (polices, thèmes) avant la première capture.
	await get_tree().process_frame
	_setup_viewport()
	await get_tree().process_frame
	await get_tree().process_frame
	var count := await _export_all()
	print("\n%d carte(s) exportée(s) en PNG." % count)
	get_tree().quit()


func _setup_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(roundi(VIEWPORT_W * SCALE), roundi(VIEWPORT_H * SCALE))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	add_child(_viewport)

	var scaler := Control.new()
	scaler.scale = Vector2(SCALE, SCALE)
	_viewport.add_child(scaler)

	_card = CARD_SCENE.instantiate()
	_card.position = Vector2(MARGIN_L, MARGIN_T)
	_card.set_non_interactive()
	scaler.add_child(_card)


func _export_all() -> int:
	var dir := DirAccess.open(SOURCE_DIR)
	if dir == null:
		push_error("Dossier introuvable : %s" % SOURCE_DIR)
		return 0

	var races: Array[String] = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			races.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	races.sort()

	var exported := 0
	for race in races:
		exported += await _export_race(race)
	return exported


func _export_race(race: String) -> int:
	var race_dir := "%s/%s" % [SOURCE_DIR, race]
	var out_dir := "%s/%s" % [OUTPUT_DIR, race]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	var files: Array[String] = []
	var dir := DirAccess.open(race_dir)
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".tres"):
			files.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	files.sort()

	var exported := 0
	for file_name in files:
		var card_data := load("%s/%s" % [race_dir, file_name]) as CardData
		if card_data == null:
			push_warning("Ressource ignorée (pas une CardData) : %s/%s" % [race, file_name])
			continue

		_card.set_data(card_data)
		await get_tree().process_frame
		await get_tree().process_frame

		var image := _viewport.get_texture().get_image()
		var out_path := "%s/%s.png" % [out_dir, file_name.get_basename()]
		var err := image.save_png(out_path)
		if err != OK:
			push_error("Échec de sauvegarde : %s (code %d)" % [out_path, err])
			continue

		exported += 1
		print("  %s/%s -> %s" % [race, file_name, out_path])

	return exported
