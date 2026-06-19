@tool
extends EditorScript

func _run() -> void:
	var cards_dir = "res://resources/cards/undead"
	var dir = DirAccess.open(cards_dir)

	if dir == null:
		print("❌ Could not open directory: ", cards_dir)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var converted = 0
	var errors = []

	print("🔄 Starting .tres conversion...")

	while file_name != "":
		if file_name.ends_with(".tres"):
			var file_path = cards_dir + "/" + file_name
			var card_data = load(file_path) as CardData

			if card_data != null:
				# Convert keywords Array[int] to Array[KeywordChoice]
				var new_keywords: Array[KeywordChoice] = []
				for old_kw in card_data.keywords:
					var kw_choice = KeywordChoice.new()
					match old_kw:
						Keyword.Type.TAUNT: kw_choice.name_fr = "Rempart"
						Keyword.Type.CHARGE: kw_choice.name_fr = "Assaut"
						Keyword.Type.PROTECTION: kw_choice.name_fr = "Protection"
						Keyword.Type.LIFESTEAL: kw_choice.name_fr = "Moisson"
						Keyword.Type.FURY: kw_choice.name_fr = "Frénésie"
						Keyword.Type.DEADLY_POISON: kw_choice.name_fr = "Venin mortel"
						Keyword.Type.RAVAGE: kw_choice.name_fr = "Ravage"
						Keyword.Type.BLACK_WINGS: kw_choice.name_fr = "Ailes noires"
						Keyword.Type.AEGIS: kw_choice.name_fr = "Égide"
					new_keywords.append(kw_choice)

				# Convert trigger_types Array[String] to Array[TriggerTypeChoice]
				var new_triggers: Array[TriggerTypeChoice] = []
				for old_trigger in card_data.trigger_types:
					var trigger_choice = TriggerTypeChoice.new()
					trigger_choice.type = old_trigger
					new_triggers.append(trigger_choice)

				# Update the card data
				card_data.keywords = new_keywords
				card_data.trigger_types = new_triggers

				# Save the converted file
				if ResourceSaver.save(card_data, file_path) == OK:
					converted += 1
					print("✅ ", file_name)
				else:
					errors.append(file_name + " (save failed)")
					print("❌ ", file_name, " (save failed)")
			else:
				errors.append(file_name + " (load failed)")
				print("❌ ", file_name, " (load failed)")

		file_name = dir.get_next()

	print("\n📊 Results:")
	print("✅ Converted: ", converted)
	if errors.size() > 0:
		print("❌ Errors: ", errors.size())
		for error in errors:
			print("  - ", error)
