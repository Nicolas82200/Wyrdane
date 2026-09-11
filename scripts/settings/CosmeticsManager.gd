extends RefCounted
class_name CosmeticsManager

# Cosmétiques de dos de carte débloqués par le niveau de compte LOCAL (voir
# SettingsManager.account_level) — pas une vraie boutique cosmétique au sens
# du doc UX (aucun asset de card back dédié n'existe, ni infra de paiement
# cosmétique côté backend) : un déblocage progressif réel mais implémenté par
# simple teinte de la texture de dos de carte déjà existante
# (res://assets/card_back/card-back.png), sans nouvel asset requis. N'affecte
# jamais le gameplay (voir CLAUDE.md, "éviter le Pay-to-Win").
# Classe statique, pas un autoload (même pattern que SteamService/AchievementManager).

const CARD_BACKS := [
	{"key": "COSMETIC_CARD_BACK_DEFAULT", "level": 1, "tint": Color(1.0, 1.0, 1.0, 1.0)},
	{"key": "COSMETIC_CARD_BACK_GOLD",    "level": 2, "tint": Color(1.25, 1.05, 0.55, 1.0)},
	{"key": "COSMETIC_CARD_BACK_CRIMSON", "level": 4, "tint": Color(1.35, 0.55, 0.55, 1.0)},
	{"key": "COSMETIC_CARD_BACK_EMERALD", "level": 6, "tint": Color(0.55, 1.35, 0.75, 1.0)},
	{"key": "COSMETIC_CARD_BACK_VIOLET",  "level": 9, "tint": Color(0.85, 0.6, 1.4, 1.0)},
]

static func is_unlocked(index: int) -> bool:
	if index < 0 or index >= CARD_BACKS.size():
		return false
	return int(CARD_BACKS[index]["level"]) <= SettingsManager.account_level()

# Teinte à appliquer à la texture de dos de carte pour le choix courant du
# joueur — Color.WHITE (aucune teinte) si le choix sauvegardé n'est pas/plus
# valide (index hors bornes, ou débloqué puis reverrouillé — ne peut pas
# arriver aujourd'hui, le niveau ne redescend jamais, mais reste défensif).
static func card_back_tint() -> Color:
	var index: int = SettingsManager.selected_card_back
	if not is_unlocked(index):
		return Color.WHITE
	return CARD_BACKS[index]["tint"]

static func select_card_back(index: int) -> void:
	if not is_unlocked(index):
		return
	SettingsManager.set_selected_card_back(index)
