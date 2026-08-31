extends RefCounted
class_name AchievementManager

# Succès Steam (Steamworks Stats & Achievements), via GodotSteam.
#
# Même pattern que SteamService : l'extension n'est pas une dépendance
# obligatoire, tous les appels passent par SteamService.steam() et sont
# no-op si l'extension/le client Steam est absent (ex. build hors Steam,
# éditeur sans overlay). Les "API Name" ci-dessous DOIVENT être créés à
# l'identique (casse comprise) dans le dashboard Steamworks (Achievements)
# avant de pouvoir se débloquer en jeu.

const ACH_FLAWLESS_VICTORY := "ACH_FLAWLESS_VICTORY"   # Victoire sans perdre le moindre PV de héros
const ACH_MEGA_DECK := "ACH_MEGA_DECK"                 # Deck sauvegardé avec plus de 100 cartes jouables
const ACH_MINIMALIST := "ACH_MINIMALIST"               # Victoire avec moins de 10 cartes-ressource jouées

const MEGA_DECK_THRESHOLD := 100
const MINIMALIST_RESOURCE_THRESHOLD := 10

# Débloque un succès (idempotent : ne fait rien s'il l'est déjà). Sans effet
# si Steam est indisponible.
static func unlock(achievement_id: String) -> void:
	if not SteamService.ensure_init():
		return
	var s := SteamService.steam()
	if s == null or not s.has_method("setAchievement"):
		return
	var current: Dictionary = s.getAchievement(achievement_id) if s.has_method("getAchievement") else {}
	if current.get("achieved", false):
		return
	s.setAchievement(achievement_id)
	if s.has_method("storeStats"):
		s.storeStats()

# À appeler à la fin d'une partie gagnée (hors tutoriel) avec les infos de la
# bataille qui vient de se terminer.
static func on_victory(player_hero: Hero, resource_cards_played: int) -> void:
	if player_hero != null and player_hero.health >= player_hero.max_health:
		unlock(ACH_FLAWLESS_VICTORY)
	if resource_cards_played < MINIMALIST_RESOURCE_THRESHOLD:
		unlock(ACH_MINIMALIST)

# À appeler après la sauvegarde d'un deck (DeckBuilder._on_save).
static func on_deck_saved(deck: DeckData) -> void:
	if deck == null:
		return
	var playable := 0
	for card in deck.get_cards():
		if card.card_type != "Resource":
			playable += 1
	if playable > MEGA_DECK_THRESHOLD:
		unlock(ACH_MEGA_DECK)
