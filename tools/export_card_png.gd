extends SceneTree
# Exporte une carte complète (illustration, mana, nom, description...) en PNG.
# Usage : godot --path . -s tools/export_card_png.gd -- res://resources/cards/<race>/<carte>.tres [sortie.png]
# Important : NE PAS passer --headless, le driver de rendu "dummy" qu'il
# active ne sait pas rasteriser le SubViewport (texture_2d_get renvoie null,
# PNG vide) — il faut le vrai rendu Vulkan, donc une fenêtre (même si elle ne
# reste affichée qu'une fraction de seconde avant que le script ne quitte).

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Usage: -- <res://chemin/carte.tres> [sortie.png]")
		quit(1)
		return

	var card_path: String = args[0]
	var out_path: String = args[1] if args.size() > 1 else card_path.get_file().get_basename() + ".png"

	var data: CardData = load(card_path)
	if data == null:
		push_error("Carte introuvable ou invalide: %s" % card_path)
		quit(1)
		return

	var viewport := SubViewport.new()
	viewport.size = Vector2i(250, 375)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var card: Control = load("res://scenes/card/Card.tscn").instantiate()
	viewport.add_child(card)
	card.set_data(data)

	# Laisse le viewport effectuer au moins deux rendus (le fit du texte dans
	# _fit_name_label/_fit_desc_label dépend de tailles calculées au premier frame).
	await process_frame
	await process_frame
	# Le tout premier chargement de CardData/Race via -s peut échouer une fois
	# (autoloads pas encore prêts lors du parsing initial du script) : refaire
	# update_display() une fois les frames passées répare l'affichage.
	card.update_display()
	await process_frame

	var img: Image = viewport.get_texture().get_image()
	var err := img.save_png(out_path)
	if err != OK:
		push_error("Échec de l'export PNG (%s): %d" % [out_path, err])
		quit(1)
		return

	print("Carte exportée: %s" % out_path)
	quit(0)
