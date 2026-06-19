@tool
extends EditorScript

func _run() -> void:
	var cards_dir = "res://resources/cards/undead"
	var dir = DirAccess.open(cards_dir)

	if dir == null:
		print("❌ Could not open directory: ", cards_dir)
		return

	# Keyword mappings
	var keyword_names = {
		0: "Rempart",
		1: "Assaut",
		2: "Protection",
		3: "Moisson",
		4: "Frénésie",
		5: "Venin mortel",
		6: "Ravage",
		7: "Ailes noires",
		8: "Égide",
	}

	var trigger_map = {
		"INVOCATION": "BATTLECRY",
		"DERNIER SOUFFLE": "DEATHRATTLE",
		"ASSAUT": "OnAttack",
		"BLESSURE": "OnDamaged",
		"ÉVEIL": "OnAwaken",
		"DÉCLIN": "OnDecline",
		"RALLIEMENT": "RALLY",
		"DEUIL": "MOURNING",
		"SORTILÈGE": "SPELLCAST",
		"SACRIFICE": "SACRIFICE",
		"EXÉCUTION": "OnExecution",
		"CARNAGE": "CARNAGE",
		"MORT-RAGE": "DEATHRATTLE",
	}

	var keyword_idx_map = {
		"REMPART": 0,
		"ASSAUT": 1,
		"PROTECTION": 2,
		"MOISSON": 3,
		"FRÉNÉSIE": 4,
		"VENIN MORTEL": 5,
		"RAVAGE": 6,
		"AILES NOIRES": 7,
		"ÉGIDE": 8,
	}

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var converted = 0

	print("🔄 Converting all .tres files...")

	while file_name != "":
		if file_name.ends_with(".tres"):
			var file_path = cards_dir + "/" + file_name
			var card_data = load(file_path) as CardData

			if card_data != null:
				# Extract keywords from description
				var keywords_to_add: Array[KeywordChoice] = []
				var desc_upper = card_data.description.to_upper()
				for kw_name: String in keyword_idx_map.keys():
					if kw_name in desc_upper:
						var kw = KeywordChoice.new()
						kw.name_fr = keyword_names[keyword_idx_map[kw_name]]
						if kw not in keywords_to_add:
							keywords_to_add.append(kw)

				# Extract triggers from description
				var triggers_to_add: Array[TriggerTypeChoice] = []
				for trigger_name: String in trigger_map.keys():
					if trigger_name in desc_upper:
						var trigger = TriggerTypeChoice.new()
						trigger.type = trigger_map[trigger_name]
						if trigger not in triggers_to_add:
							triggers_to_add.append(trigger)

				# Update card data
				card_data.keywords = keywords_to_add
				card_data.trigger_types = triggers_to_add

				# Save
				if ResourceSaver.save(card_data, file_path) == OK:
					converted += 1
					print("✅ ", file_name)
				else:
					print("❌ ", file_name, " (save failed)")
			else:
				print("❌ ", file_name, " (load failed)")

		file_name = dir.get_next()

	print("\n✅ Converted: ", converted, " files")
