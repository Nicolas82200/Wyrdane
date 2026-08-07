extends RefCounted
class_name CampaignEvents

# Table de données des événements de campagne (nœud EVENT) — v1 volontairement
# simple : pas de moteur d'effets générique façon CardEffect/EffectManager,
# ce serait de la sur-ingénierie pour une poignée d'événements. Chaque choix
# porte un `effect` interprété par apply_effect(), logique pure testable sans
# scène. Tous les textes passent par SettingsManager.t() (clés ci-dessous,
# entrées FR/EN dans translations/game.csv).

const EVENTS: Array[Dictionary] = [
	{
		"id": "forgotten_altar",
		"title_key": "CAMPAIGN_EVENT_ALTAR_TITLE",
		"body_key": "CAMPAIGN_EVENT_ALTAR_BODY",
		"choices": [
			{"label_key": "CAMPAIGN_EVENT_ALTAR_CHOICE_ACCEPT", "effect": "gain_max_hp_lose_hp"},
			{"label_key": "CAMPAIGN_EVENT_ALTAR_CHOICE_DECLINE", "effect": "nothing"},
		],
	},
	{
		"id": "wandering_merchant",
		"title_key": "CAMPAIGN_EVENT_MERCHANT_TITLE",
		"body_key": "CAMPAIGN_EVENT_MERCHANT_BODY",
		"choices": [
			{"label_key": "CAMPAIGN_EVENT_MERCHANT_CHOICE_ACCEPT", "effect": "gain_card_rare"},
			{"label_key": "CAMPAIGN_EVENT_MERCHANT_CHOICE_DECLINE", "effect": "nothing"},
		],
	},
	{
		"id": "trap",
		"title_key": "CAMPAIGN_EVENT_TRAP_TITLE",
		"body_key": "CAMPAIGN_EVENT_TRAP_BODY",
		"choices": [
			{"label_key": "CAMPAIGN_EVENT_TRAP_CHOICE_CONTINUE", "effect": "lose_hp"},
		],
	},
	{
		"id": "blessing",
		"title_key": "CAMPAIGN_EVENT_BLESSING_TITLE",
		"body_key": "CAMPAIGN_EVENT_BLESSING_BODY",
		"choices": [
			{"label_key": "CAMPAIGN_EVENT_BLESSING_CHOICE_CONTINUE", "effect": "heal_small"},
		],
	},
	{
		"id": "ritual_circle",
		"title_key": "CAMPAIGN_EVENT_RITUAL_TITLE",
		"body_key": "CAMPAIGN_EVENT_RITUAL_BODY",
		"choices": [
			{"label_key": "CAMPAIGN_EVENT_RITUAL_CHOICE_ACCEPT", "effect": "lose_hp_gain_card_rare"},
			{"label_key": "CAMPAIGN_EVENT_RITUAL_CHOICE_DECLINE", "effect": "nothing"},
		],
	},
]

const HEAL_SMALL_AMOUNT := 5
const TRAP_DAMAGE := 5
const RITUAL_DAMAGE := 8
const ALTAR_MAX_HP_GAIN := 5
const ALTAR_HP_COST := 3
# Un événement ne tue jamais le héros directement, contrairement à un combat :
# il descend au plus à 1 PV, laissant toujours une chance de continuer la run.
const MIN_HP_AFTER_EVENT := 1

static func random_event(rng: RandomNumberGenerator) -> Dictionary:
	return EVENTS[rng.randi_range(0, EVENTS.size() - 1)]

static func apply_effect(effect: String, run: CampaignRun) -> void:
	match effect:
		"heal_small":
			run.heal(HEAL_SMALL_AMOUNT)
		"lose_hp":
			run.hero_health = max(MIN_HP_AFTER_EVENT, run.hero_health - TRAP_DAMAGE)
		"gain_max_hp_lose_hp":
			run.hero_max_health += ALTAR_MAX_HP_GAIN
			run.hero_health = max(MIN_HP_AFTER_EVENT, run.hero_health - ALTAR_HP_COST)
		"gain_card_rare":
			_add_random_card(run, "Rare")
		"lose_hp_gain_card_rare":
			run.hero_health = max(MIN_HP_AFTER_EVENT, run.hero_health - RITUAL_DAMAGE)
			_add_random_card(run, "Rare")
		"nothing":
			pass

static func _add_random_card(run: CampaignRun, rarity: String) -> void:
	var pool: Array[CardData] = CampaignCardFilter.filter_compatible(
		CardLibrary.get_cards_by_race_and_rarity(run.race, rarity))
	if not pool.is_empty():
		run.add_card_to_board(pool[run.rng.randi_range(0, pool.size() - 1)])
