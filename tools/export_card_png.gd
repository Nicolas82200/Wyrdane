extends SceneTree
# Exporte les cartes (illustration, mana, nom, description...) en PNG, à la
# taille "zoomée" (comme au survol d'une carte en jeu), rangées par race dans
# exported-card/<race>/ (FR) et exported-card/<race>/en/ (EN).
#
# Usage : godot --path . -s tools/export_card_png.gd [-- res://resources/cards/<race>/<carte>.tres]
# Sans argument : exporte TOUTES les cartes trouvées sous resources/cards/.
# Avec un argument : n'exporte que cette carte (toujours FR + EN).
#
# Important : NE PAS passer --headless, le driver de rendu "dummy" qu'il
# active ne sait pas rasteriser le SubViewport (texture_2d_get renvoie null,
# PNG vide) — il faut le vrai rendu Vulkan, donc une fenêtre (même si elle ne
# reste affichée qu'une fraction de seconde avant que le script ne quitte).

const CARDS_ROOT := "res://resources/cards"
const OUT_ROOT := "res://exported-card"

# Bavure visuelle hors du rect 250x375 de la carte (bordure dorée qui déborde,
# voir BorderFrameBlack dans Card.tscn : offsets -8/-9/+8/+8) : marge de
# sécurité uniforme pour ne rien rogner au cadrage.
const BLEED := 9.0
# Copie de Card.HOVER_ZOOM_SCALE (scripts/card/Card.gd) : référencer la classe
# Card par son nom forcerait son compile eager avant que les autoloads soient
# prêts (même piège que CardData, voir plus bas) et casserait set_data().
const ZOOM_SCALE := 1.2375

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()

	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var card: Control = load("res://scenes/card/Card.tscn").instantiate()
	viewport.add_child(card)

	# Rendu à l'échelle du zoom au survol (ZOOM_SCALE) plutôt qu'à la taille
	# brute en main, pour une image lisible en gros plan.
	var scale: float = ZOOM_SCALE
	var base_w: float = card.custom_minimum_size.x + BLEED * 2.0
	var base_h: float = card.custom_minimum_size.y + BLEED * 2.0
	viewport.size = Vector2i(roundi(base_w * scale), roundi(base_h * scale))
	card.position = Vector2(BLEED, BLEED) * scale
	card.scale = Vector2(scale, scale)

	var jobs: Array = []
	if args.is_empty():
		jobs = _collect_all_cards()
		if jobs.is_empty():
			push_error("Aucune carte trouvée sous %s" % CARDS_ROOT)
			quit(1)
			return
	else:
		jobs = [args[0]]

	# Échauffement : le tout premier chargement de CardData/Race via -s peut
	# échouer une fois (autoloads pas encore prêts lors du parsing initial du
	# script), ce qui laisse l'affichage incomplet. Un premier passage à vide
	# avant la vraie boucle d'export absorbe ce raté.
	var warm_data: CardData = load(jobs[0])
	if warm_data != null:
		card.set_data(warm_data)
		await process_frame
		await process_frame
		card.update_display()
		await process_frame

	var exported := 0
	for card_path in jobs:
		var data: CardData = load(card_path)
		if data == null:
			push_warning("Carte introuvable ou invalide, ignorée: %s" % card_path)
			continue
		var race_dir: String = card_path.get_base_dir().get_file()
		var slug: String = card_path.get_file().get_basename()

		TranslationServer.set_locale("fr")
		card.set_data(data)
		await process_frame
		_capture(viewport, "%s/%s/%s.png" % [OUT_ROOT, race_dir, slug])

		TranslationServer.set_locale("en")
		card.update_display()
		await process_frame
		_capture(viewport, "%s/%s/en/%s.png" % [OUT_ROOT, race_dir, slug])

		exported += 1

	print("Cartes exportées: %d (dossier %s)" % [exported, ProjectSettings.globalize_path(OUT_ROOT)])
	quit(0)

func _collect_all_cards() -> Array:
	var paths: Array = []
	var root_dir := DirAccess.open(CARDS_ROOT)
	if root_dir == null:
		return paths
	root_dir.list_dir_begin()
	var race_entry := root_dir.get_next()
	while race_entry != "":
		if root_dir.current_is_dir() and not race_entry.begins_with("."):
			var race_path := "%s/%s" % [CARDS_ROOT, race_entry]
			var race_dir := DirAccess.open(race_path)
			if race_dir != null:
				race_dir.list_dir_begin()
				var file_entry := race_dir.get_next()
				while file_entry != "":
					if file_entry.ends_with(".tres"):
						paths.append("%s/%s" % [race_path, file_entry])
					file_entry = race_dir.get_next()
				race_dir.list_dir_end()
		race_entry = root_dir.get_next()
	root_dir.list_dir_end()
	paths.sort()
	return paths

func _capture(viewport: SubViewport, out_path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
	var img: Image = viewport.get_texture().get_image()
	var err := img.save_png(out_path)
	if err != OK:
		push_error("Échec de l'export PNG (%s): %d" % [out_path, err])
