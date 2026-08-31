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

const ACH_FLAWLESS_VICTORY := "ACH_FLAWLESS_VICTORY"     # Victoire sans perdre le moindre PV de héros
const ACH_MEGA_DECK := "ACH_MEGA_DECK"                   # Deck sauvegardé avec plus de 100 cartes jouables
const ACH_MINIMALIST := "ACH_MINIMALIST"                 # Victoire avec moins de 10 cartes-ressource jouées
const ACH_COMEBACK := "ACH_COMEBACK"                     # Victoire après être passé à 5 PV ou moins
const ACH_GUARDIAN_STREAK := "ACH_GUARDIAN_STREAK"       # 2 victoires d'affilée sans jamais passer sous 20 PV
const ACH_EXECUTIONER := "ACH_EXECUTIONER"               # 5 serviteurs ennemis tués en un seul tour
const ACH_FRONT_ONLY := "ACH_FRONT_ONLY"                 # Victoire sans jamais poser de serviteur en Arrière
const ACH_PLAGUE := "ACH_PLAGUE"                         # Victoire avec 15+ dégâts d'Infection cumulés infligés
const ACH_BLACK_BLOOD := "ACH_BLACK_BLOOD"               # Réaction Sang Noir déclenchée 10 fois dans une partie
const ACH_COMMANDEMENT := "ACH_COMMANDEMENT"             # Victoire deck 100% Humain, Commandement activé 5 fois
const ACH_MUTATION_MAX := "ACH_MUTATION_MAX"             # Un serviteur atteint 5 mutations ou plus
const ACH_COLLECTOR := "ACH_COLLECTOR"                   # Toutes les cartes jouables d'une race possédées
const ACH_MONO_RACE := "ACH_MONO_RACE"                   # Victoire avec un deck mono-race
const ACH_NO_LEGENDARY := "ACH_NO_LEGENDARY"             # Victoire avec un deck sans carte Légendaire
const ACH_FIRST_RANKED_WIN := "ACH_FIRST_RANKED_WIN"     # Première victoire en partie classée
const ACH_RANK_GOLD := "ACH_RANK_GOLD"                   # Palier Or (ou supérieur) atteint en classé
const ACH_VETERAN := "ACH_VETERAN"                       # 100 victoires cumulées
const ACH_GRADUATE := "ACH_GRADUATE"                     # Tutoriel terminé

const MEGA_DECK_THRESHOLD := 100
const MINIMALIST_RESOURCE_THRESHOLD := 10
const COMEBACK_HP_THRESHOLD := 5
const GUARDIAN_STREAK_HP_FLOOR := 20
const GUARDIAN_STREAK_TARGET := 2
const EXECUTIONER_KILLS := 5
const PLAGUE_DAMAGE_THRESHOLD := 15
const BLACK_BLOOD_TRIGGERS := 10
const COMMANDEMENT_TRIGGERS := 5
const MUTATION_MAX_STACKS := 5
const VETERAN_WINS := 100

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

# À appeler depuis Battle._show_game_over quand result == "victory" (hors
# tutoriel), une fois tous les compteurs de la partie disponibles sur `battle`.
static func on_victory(battle) -> void:
	var hero: Hero = battle.player_hero
	if hero != null and hero.health >= hero.max_health:
		unlock(ACH_FLAWLESS_VICTORY)
	if battle.player_resource_cards_played < MINIMALIST_RESOURCE_THRESHOLD:
		unlock(ACH_MINIMALIST)
	if battle.player_was_low_hp_this_match:
		unlock(ACH_COMEBACK)
	if not battle.player_used_back_row_this_match:
		unlock(ACH_FRONT_ONLY)
	if battle.player_infection_damage_dealt >= PLAGUE_DAMAGE_THRESHOLD:
		unlock(ACH_PLAGUE)
	if battle.deck_races.size() == 1:
		unlock(ACH_MONO_RACE)
		if battle.deck_races[0] == "Human" and battle.player_commandement_triggers_this_match >= COMMANDEMENT_TRIGGERS:
			unlock(ACH_COMMANDEMENT)
	if not battle.deck_has_legendary:
		unlock(ACH_NO_LEGENDARY)
	if battle.is_ranked_match:
		unlock(ACH_FIRST_RANKED_WIN)
	if SettingsManager.match_wins >= VETERAN_WINS:
		unlock(ACH_VETERAN)
	_update_guardian_streak(hero != null and battle.player_min_hp_this_match >= GUARDIAN_STREAK_HP_FLOOR)

# À appeler depuis Battle._show_game_over quand result == "defeat" : une
# défaite casse la série de victoires "sans passer sous 20 PV" au même titre
# qu'une victoire qui ne remplit pas la condition.
static func on_defeat() -> void:
	_update_guardian_streak(false)

static func _update_guardian_streak(qualifies: bool) -> void:
	var streak := SettingsManager.record_high_hp_win_streak(qualifies)
	if streak >= GUARDIAN_STREAK_TARGET:
		unlock(ACH_GUARDIAN_STREAK)

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

# À appeler quand un serviteur ennemi vient de mourir pendant le tour du
# joueur local (voir DeathSystem.process_deaths) — kills_this_turn est déjà
# incrémenté par l'appelant.
static func on_enemy_kills_this_turn(kills_this_turn: int) -> void:
	if kills_this_turn >= EXECUTIONER_KILLS:
		unlock(ACH_EXECUTIONER)

# À appeler quand la réaction Sang Noir vient de se déclencher pour le camp
# joueur (voir HeroSystem._on_self_damage_dealt) — triggers déjà incrémenté.
static func on_black_blood_trigger(triggers_this_match: int) -> void:
	if triggers_this_match >= BLACK_BLOOD_TRIGGERS:
		unlock(ACH_BLACK_BLOOD)

# À appeler quand un serviteur du joueur vient de muter (voir
# EffectManager.roll_mutation).
static func on_minion_mutated(minion: Minion) -> void:
	if minion != null and minion.owner_is_player and minion.mutation_stacks >= MUTATION_MAX_STACKS:
		unlock(ACH_MUTATION_MAX)

# À appeler après chaque sync/achat de collection (CollectionManager.collection_loaded).
static func check_collector() -> void:
	for race in Race.get_implemented_races():
		var cards := CardLibrary.get_cards_by_race(race)
		if cards.is_empty():
			continue
		var all_owned := true
		for card in cards:
			if not CollectionManager.is_owned(card):
				all_owned = false
				break
		if all_owned:
			unlock(ACH_COLLECTOR)
			return

# À appeler quand le badge de palier ranked est recalculé (voir
# ProfilePanel.apply_rank_badge).
static func check_rank_tier(tier: int) -> void:
	if tier >= RankTier.Type.GOLD:
		unlock(ACH_RANK_GOLD)
