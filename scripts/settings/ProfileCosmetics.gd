extends RefCounted
class_name ProfileCosmetics

# Titres et cadres de profil débloqués par le niveau de compte LOCAL (voir
# SettingsManager.account_level) — purement cosmétique, aucun impact
# gameplay. Titres : texte simple (aucun asset requis). Cadres : bordure
# colorée procédurale autour de l'avatar (aucun asset requis non plus).

const TITLES := [
	{"key": "TITLE_NOVICE",   "level": 1},
	{"key": "TITLE_VETERAN",  "level": 3},
	{"key": "TITLE_CHAMPION", "level": 6},
	{"key": "TITLE_LEGEND",   "level": 10},
]

const FRAMES := [
	{"key": "FRAME_NONE",   "level": 1, "color": Color(0, 0, 0, 0)},
	{"key": "FRAME_BRONZE", "level": 2, "color": Color(0.72, 0.48, 0.19, 1.0)},
	{"key": "FRAME_SILVER", "level": 4, "color": Color(0.75, 0.78, 0.82, 1.0)},
	{"key": "FRAME_GOLD",   "level": 7, "color": Color(0.92, 0.72, 0.28, 1.0)},
]

static func title_unlocked(index: int) -> bool:
	if index < 0 or index >= TITLES.size():
		return false
	return int(TITLES[index]["level"]) <= SettingsManager.account_level()

static func frame_unlocked(index: int) -> bool:
	if index < 0 or index >= FRAMES.size():
		return false
	return int(FRAMES[index]["level"]) <= SettingsManager.account_level()

# Texte du titre courant (traduit), vide si aucun titre valide sélectionné.
static func current_title_text() -> String:
	var index: int = SettingsManager.selected_title
	if not title_unlocked(index):
		return ""
	return SettingsManager.t(TITLES[index]["key"])

# Couleur de bordure du cadre courant (alpha 0 = pas de cadre visible).
static func current_frame_color() -> Color:
	var index: int = SettingsManager.selected_frame
	if not frame_unlocked(index):
		return Color(0, 0, 0, 0)
	return FRAMES[index]["color"]

static func select_title(index: int) -> void:
	if title_unlocked(index):
		SettingsManager.set_selected_title(index)

static func select_frame(index: int) -> void:
	if frame_unlocked(index):
		SettingsManager.set_selected_frame(index)
