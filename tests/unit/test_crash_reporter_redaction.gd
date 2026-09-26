extends GutTest

# Couvre le masquage appliqué avant tout envoi d'un rapport de plantage
# (CrashReporter._redact_sensitive) : un log de session part en pièce jointe sur
# un salon Discord, il ne doit contenir ni SteamID64 ni nom de compte système
# (sous Windows, c'est très souvent le prénom/nom réel du joueur).
#
# Le script est chargé directement (load(...).new()) plutôt que via l'autoload
# CrashReporter : conformément à la convention GUT du projet, un test ne dépend
# pas des autoloads globaux, que le runner n'initialise pas de façon fiable.

var reporter

func before_each() -> void:
	reporter = load("res://scripts/systems/CrashReporter.gd").new()

func after_each() -> void:
	if reporter != null:
		reporter.free()

# ─── SteamID64 ───────────────────────────────────────────────────────────────

func test_masks_steam_id64() -> void:
	var redacted: String = reporter._redact_sensitive("Caching Steam ID: 76561198012345678 [API loaded no]")
	assert_false(redacted.contains("76561198012345678"), "le SteamID64 ne doit jamais partir")
	assert_true(redacted.contains("[SteamID masqué]"), "le SteamID doit être remplacé par le marqueur")

func test_keeps_shorter_numbers_intact() -> void:
	# Un SteamID fait exactement 17 chiffres : masquer plus large amputerait des
	# nombres utiles au diagnostic (horodatages, tailles, identifiants courts).
	var redacted: String = reporter._redact_sensitive("frame 1234567 rendered in 16 ms")
	assert_eq(redacted, "frame 1234567 rendered in 16 ms")

# ─── Chemins personnels ──────────────────────────────────────────────────────

func test_masks_windows_user_folder() -> void:
	var redacted: String = reporter._redact_sensitive(
		"Godot Engine v4.6 - user data: C:\\Users\\jean.dupont\\AppData\\Roaming\\Godot"
	)
	assert_false(redacted.contains("jean.dupont"), "le nom de compte Windows ne doit jamais partir")
	assert_true(redacted.contains("[utilisateur]"), "le nom de compte doit être remplacé")
	# Le reste du chemin reste lisible : c'est ce qui rend le log exploitable.
	assert_true(redacted.contains("AppData"), "la suite du chemin doit survivre au masquage")
	assert_true(redacted.contains("C:\\Users\\"), "le préfixe du chemin doit être conservé")

func test_masks_windows_user_folder_with_forward_slashes() -> void:
	# Godot normalise souvent les chemins en slashs avant, y compris sur Windows.
	var redacted: String = reporter._redact_sensitive("loading C:/Users/jean.dupont/Desktop/Wyrdane/game.log")
	assert_false(redacted.contains("jean.dupont"))
	assert_true(redacted.contains("Desktop"))

func test_masks_macos_and_linux_home() -> void:
	var mac: String = reporter._redact_sensitive("path: /Users/marie/Library/Application Support/Wyrdane")
	assert_false(mac.contains("marie"))
	assert_true(mac.contains("Library"))

	var linux: String = reporter._redact_sensitive("path: /home/marie/.local/share/Wyrdane")
	assert_false(linux.contains("marie"))
	assert_true(linux.contains(".local"))

func test_masks_every_occurrence_not_just_the_first() -> void:
	var redacted: String = reporter._redact_sensitive(
		"A C:\\Users\\jean\\a.log B C:\\Users\\jean\\b.log C 76561198012345678 D 76561198087654321"
	)
	assert_false(redacted.contains("jean"), "toutes les occurrences doivent être masquées")
	assert_false(redacted.contains("7656119801234567"), "y compris plusieurs SteamID différents")
	assert_false(redacted.contains("76561198087654321"))

func test_leaves_regular_paths_untouched() -> void:
	# Un chemin de ressource du projet ne contient aucune donnée personnelle et
	# doit rester intact, sinon le log perd sa valeur de diagnostic.
	var original := "res://scripts/battle/Battle.gd:147 - erreur"
	assert_eq(reporter._redact_sensitive(original), original)
