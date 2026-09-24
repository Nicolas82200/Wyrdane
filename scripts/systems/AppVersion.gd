class_name AppVersion
extends RefCounted

## Source unique de vérité pour le numéro de version affiché en jeu et
## dans les métadonnées de l'exe (voir tools/bump_version.ps1).
const VERSION_FILE := "res://VERSION.txt"

const FALLBACK_VERSION := "0.0.0"

static func get_version() -> String:
	var file := FileAccess.open(VERSION_FILE, FileAccess.READ)
	if file == null:
		return FALLBACK_VERSION
	var text := file.get_as_text().strip_edges()
	file.close()
	return text if not text.is_empty() else FALLBACK_VERSION

static func get_display_string() -> String:
	return "v" + get_version()
