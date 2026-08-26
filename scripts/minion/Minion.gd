extends RefCounted
class_name Minion

var owner_is_player: bool
var card_data: CardData

# Identifiant réseau stable, partagé entre les deux clients en multijoueur.
# 0 = non enregistré (proxies d'effet, aperçus de drag). Attribué par NetRegistry.
var net_id: int = 0

# Stats permanentes : base de la carte + tous les buffs "définitifs" appliqués (Buff, Commandement...)
var base_attack: int
var base_max_health: int
var damage_taken: int = 0

# Bonus d'aura, recalculés ENTIÈREMENT à chaque update — jamais incrémentés à la main ailleurs
var aura_attack_bonus: int = 0
var aura_health_bonus: int = 0
# Réduction de dégâts : part inhérente à la carte + part d'aura (Pacte de
# Résistance...). L'aura est remise à zéro puis recalculée par AuraSystem.
var aura_damage_reduction: int = 0
# Immunité à l'Infection accordée par une aura (Aegis de l'Empire). Remise à zéro
# puis recalculée par AuraSystem.
var infection_immune_aura: bool = false

var attacks_remaining: int = 0
# Verrou de ré-entrance : posé pendant la résolution d'une attaque (CombatSystem)
# pour empêcher qu'un effet déclenché en chaîne (ex. OnAttack, attaque immédiate)
# ne relance une attaque avec ce serviteur avant que la précédente soit terminée.
var is_attacking: bool = false
var keywords: Array[int] = []
var human_keywords: Array[int] = []
var undead_keywords: Array[int] = []
var demon_keywords: Array[int] = []
var abomination_keywords: Array[int] = []
var board_row: String = "Front"

var formation_active: bool = false
var silenced: bool = false
# Intargetable par les sorts ennemis. Vrai en permanence tant que non retiré
# (Assassin Décharné : levé à la 1ère attaque ; Éclaireur Infiltré : accordé
# temporairement à des cibles adverses par GrantSpellImmunity/TempEffectSystem).
var spell_immune: bool = false
# Vrai si ce serviteur a été ramené du cimetière (Résurrection/ResurrectLast),
# distinct de sa carte d'origine. Lu par Brise-Mort.
var was_resurrected: bool = false
var frozen_turns: int = 0
# TERREUR : tours pendant lesquels ce serviteur ne peut pas attaquer. Séparé de
# frozen_turns (Gel) pour ne pas mélanger les visuels/immunités des deux mécaniques.
var terror_turns: int = 0
# Corruption (Démon) : marqueurs cumulables, chaque marqueur = -1 ATK permanent.
# La perte d'ATK est appliquée sur base_attack au moment de la pose (apply_corruption).
var corruption_stacks: int = 0
# Mutation (Abomination) : nombre de mutations gagnées par ce serviteur, pour
# l'affichage. Les effets des mutations (Croissance/Renforcement/Dégénérescence)
# sont appliqués directement sur base_attack/base_max_health par roll_mutation.
var mutation_stacks: int = 0
var mutations: Array[String] = []
# Infection cumulable : chaque pose ajoute une marque, chacune infligeant 1
# dégât au début du tour adverse (voir TurnSystem._apply_infection_damage) —
# un serviteur touché 5 fois perd 5 PV/tour, pas 1. CHAIR MORTE ou une
# immunité d'aura (Aegis de l'Empire) bloque toute nouvelle marque.
var infection_stacks: int = 0
# Compat/lisibilité : `infected = true` ajoute une marque (bloqué par
# l'immunité), `infected = false` retire toutes les marques (guérison
# complète, voir CureInfection/Aegis de l'Empire) ; `infected` se lit comme un
# simple booléen partout ailleurs dans le code (combat, ciblage, VFX...).
var infected: bool:
	get: return infection_stacks > 0
	set(value):
		if value:
			if is_infection_immune():
				return
			infection_stacks += 1
		else:
			infection_stacks = 0
var death_rage_triggered: bool = false  # Mort-rage : une seule fois par serviteur
var revenant_triggered: bool = false    # REVENANT : une seule fois par partie
var awakened: bool = false
var declined: bool = false
var sacrificed: bool = false
# Voisins capturés juste avant le retrait du plateau (DeathSystem), pour que
# les rituels/enchantements à Deuil (Serment du Sang) puissent buffer "le
# serviteur adjacent" du mort alors que celui-ci n'est déjà plus dans
# player_minions/enemy_minions au moment où OnGrief se déclenche.
var grief_adjacent_hint: Array[Minion] = []
# Attaque bonus déjà accordée ce tour (Rongeur de Chair). Réinitialisée par refresh_attacks.
var extra_attack_used_this_turn: bool = false
var buffs: Array = []

# ─── Mode Arena uniquement (voir scripts/arena/) ──────────────────────────────
# Niveau d'étoile après fusion de 3 copies identiques (ArenaMergeSystem).
var star_level: int = 1
# Verrouillée en boutique : ne sera pas re-proposée au reroll suivant.
var locked: bool = false

func _init(data: CardData, is_player: bool = true, row: String = "Front") -> void:
	owner_is_player = is_player
	card_data = data
	board_row = row
	base_attack       = data.attack
	base_max_health   = data.health
	damage_taken      = 0
	keywords          = data.get_keyword_values()
	human_keywords    = data.get_human_keyword_values()
	undead_keywords   = data.get_undead_keyword_values()
	demon_keywords    = data.get_demon_keyword_values()
	abomination_keywords = data.get_abomination_keyword_values()
	attacks_remaining = 1 if has_keyword(Keyword.Type.CHARGE) else 0
	spell_immune = data.spell_immune_until_attack

# ─── Stats calculées (lecture seule — passe par base_* pour modifier) ─────────
var attack: int:
	get: return max(0, base_attack + aura_attack_bonus)

var max_health: int:
	get: return max(1, base_max_health + aura_health_bonus)

var health: int:
	get: return max(0, max_health - damage_taken)
	set(value):
		damage_taken = max_health - value

# ─── Combat (inchangé) ──────────────────────────────────────────────────────
func can_attack() -> bool:
	return attacks_remaining > 0 and frozen_turns == 0 and terror_turns == 0 and not is_attacking

func refresh_attacks() -> void:
	extra_attack_used_this_turn = false
	if frozen_turns > 0 or terror_turns > 0:
		frozen_turns = max(frozen_turns - 1, 0)
		terror_turns = max(terror_turns - 1, 0)
		attacks_remaining = 0
		return
	attacks_remaining = 2 if has_keyword(Keyword.Type.FURY) else 1

func consume_attack() -> void:
	attacks_remaining = max(attacks_remaining - 1, 0)
	if card_data.spell_immune_until_attack:
		spell_immune = false

var damage_reduction: int:
	get: return max(0, card_data.damage_reduction + aura_damage_reduction)

func take_damage(amount: int) -> int:
	if has_keyword(Keyword.Type.AEGIS):
		remove_keyword(Keyword.Type.AEGIS)
		return 0
	# Réduction de dégâts : un coup qui touche inflige toujours au moins 1.
	if amount > 0 and damage_reduction > 0:
		amount = max(1, amount - damage_reduction)
	var before: int = health
	health = max(health - amount, 0)
	return before - health

func heal(amount: int) -> void:
	if is_heal_immune():
		return
	health = min(health + amount, max_health)

func is_dead() -> bool:
	return health <= 0

# ─── Keywords (inchangé + pool Humain) ────────────────────────────────────────
func has_keyword(keyword: int) -> bool:
	return keyword in keywords
func add_keyword(keyword: int) -> void:
	if keyword not in keywords:
		keywords.append(keyword)
func remove_keyword(keyword: int) -> void:
	keywords.erase(keyword)

func has_human_keyword(keyword: int) -> bool:
	return keyword in human_keywords

func add_human_keyword(keyword: int) -> void:
	if keyword not in human_keywords:
		human_keywords.append(keyword)

func remove_human_keyword(keyword: int) -> void:
	human_keywords.erase(keyword)

func is_infection_immune() -> bool:
	return has_undead_keyword(KeywordUndead.Type.CHAIR_MORTE) or infection_immune_aura

func has_undead_keyword(keyword: int) -> bool:
	return keyword in undead_keywords

func has_demon_keyword(keyword: int) -> bool:
	return keyword in demon_keywords

func add_demon_keyword(keyword: int) -> void:
	if keyword not in demon_keywords:
		demon_keywords.append(keyword)

func remove_demon_keyword(keyword: int) -> void:
	demon_keywords.erase(keyword)

func has_abomination_keyword(keyword: int) -> bool:
	return keyword in abomination_keywords

func add_abomination_keyword(keyword: int) -> void:
	if keyword not in abomination_keywords:
		abomination_keywords.append(keyword)

func remove_abomination_keyword(keyword: int) -> void:
	abomination_keywords.erase(keyword)

# INSTABLE : ne peut pas être ciblé par des effets de soin, alliés ou ennemis.
func is_heal_immune() -> bool:
	return has_abomination_keyword(KeywordAbomination.Type.INSTABLE)

# ─── Corruption / immunités Démon ─────────────────────────────────────────────

# CHAIR DE SOUFRE : immunisé à Corruption, à la peur (TERREUR) et au contrôle mental.
func is_corruption_immune() -> bool:
	return has_demon_keyword(KeywordDemon.Type.CHAIR_DE_SOUFRE)

# Peur : CHAIR MORTE (Mort-Vivant), DISCIPLINE (Humain) et CHAIR DE SOUFRE (Démon)
# y sont tous trois immunisés d'après leurs définitions.
func is_fear_immune() -> bool:
	return has_undead_keyword(KeywordUndead.Type.CHAIR_MORTE) \
		or has_human_keyword(KeywordHuman.Type.DISCIPLINE) \
		or has_demon_keyword(KeywordDemon.Type.CHAIR_DE_SOUFRE)

func is_mind_control_immune() -> bool:
	return has_human_keyword(KeywordHuman.Type.DISCIPLINE) \
		or has_demon_keyword(KeywordDemon.Type.CHAIR_DE_SOUFRE)

# Pose `stacks` marqueur(s) de Corruption : -1 ATK permanent par marqueur, cumulable.
func apply_corruption(stacks: int = 1) -> void:
	if stacks <= 0 or is_corruption_immune():
		return
	corruption_stacks += stacks
	base_attack = max(0, base_attack - stacks)
