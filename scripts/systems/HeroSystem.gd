extends Node
class_name HeroSystem

var battle

# ─── Dégâts auto-infligés (mécanique cœur des Démons) ─────────────────────────
# "Ton héros perd X HP" : dégâts causés par les PROPRES cartes du camp, qui
# passent par self_damage() et non damage(), afin de gérer :
#  - le blocage total (Le Gardien du Pacte Brisé : CardData.blocks_self_damage,
#    Absolution Écarlate : self_damage_blocked "ce tour")
#  - la réduction d'aura (Sceau de Préservation : AuraSelfDamageReduction)
#  - le garde-fou : ces dégâts ne réduisent JAMAIS le héros sous 1 HP
#  - les réactions SANG NOIR (+1 ATK permanent) et le trigger OnSelfDamage
#    (Autel de la Souffrance).

# Blocage "ce tour" par camp (Absolution Écarlate). Expiré par TurnSystem.
var self_damage_blocked: Dictionary = { true: false, false: false }
# Réduction par occurrence par camp, recalculée par AuraSystem (Sceau de Préservation).
var self_damage_reduction: Dictionary = { true: 0, false: 0 }
# Anti-boucle : un enchantement déclenché par OnSelfDamage qui perdrait lui-même
# des HP ne redéclenche pas une nouvelle vague OnSelfDamage.
var _firing_self_damage: bool = false

func init(_battle) -> void:
	battle = _battle

func get_owner_hero(minion: Minion) -> Hero:
	if minion == null:
		return battle.player_hero
	return battle.player_hero if minion.owner_is_player else battle.enemy_hero

func get_enemy_hero(minion: Minion) -> Hero:
	if minion == null:
		return battle.enemy_hero
	return battle.enemy_hero if minion.owner_is_player else battle.player_hero

func damage(hero: Hero, amount: int) -> void:
	hero.take_damage(amount)
	# RANG INFERNAL dépend des HP manquants du héros : recalcul immédiat
	battle.aura_system.recompute_all()
	# Une aura peut faire chuter des HP (perte d'un bonus de rangée...) : vérifier
	# les morts avant de mettre à jour l'UI, sinon un serviteur à 0 HP resterait
	# affiché en jeu jusqu'à une prochaine action sans rapport.
	await battle.death_system.process_deaths()
	update_ui()
	battle.check_game_end()

# Applique `amount` dégâts auto-infligés au héros du camp `is_player`.
# Retourne les dégâts réellement subis (après blocages/réductions/garde-fou).
func self_damage(is_player: bool, amount: int) -> int:
	if amount <= 0:
		return 0
	var hero: Hero = battle.player_hero if is_player else battle.enemy_hero
	var camp: Array = battle.player_minions if is_player else battle.enemy_minions
	# Le Gardien du Pacte Brisé : annule la catégorie entière tant qu'il est en jeu
	for minion in camp:
		if minion.card_data != null and minion.card_data.blocks_self_damage:
			return 0
	# Absolution Écarlate : annulé pour ce camp jusqu'à la fin du tour
	if self_damage_blocked.get(is_player, false):
		return 0
	# Sceau de Préservation : -N par occurrence, minimum 0
	amount = max(0, amount - int(self_damage_reduction.get(is_player, 0)))
	if amount == 0:
		return 0
	# Garde-fou : les dégâts auto-infligés ne peuvent jamais tuer son propre héros
	var dealt: int = min(amount, hero.health - 1)
	if dealt <= 0:
		return 0
	hero.take_damage(dealt)
	battle.combat_log.self_damage(is_player, dealt)
	await _on_self_damage_dealt(is_player)
	update_ui()
	return dealt

# Réactions à une perte de HP auto-infligée : SANG NOIR (+1 ATK permanent sur
# chaque serviteur allié qui le porte) puis trigger OnSelfDamage des
# enchantements du camp (Autel de la Souffrance). RANG INFERNAL est recalculé
# dans la foulée puisque les HP manquants du héros ont changé.
func _on_self_damage_dealt(is_player: bool) -> void:
	var camp: Array = battle.player_minions if is_player else battle.enemy_minions
	for minion in camp:
		if minion.has_demon_keyword(KeywordDemon.Type.SANG_NOIR):
			minion.base_attack += 1
			var visual: BoardMinion = battle.board_visual_system.get_visual(minion)
			if visual:
				battle.animation_system.play_sang_noir_buff(visual)
	if not _firing_self_damage:
		_firing_self_damage = true
		await battle.trigger_system.fire("OnSelfDamage", null, is_player)
		_firing_self_damage = false
	battle.aura_system.recompute_all()
	await battle.death_system.process_deaths()
	battle.board_visual_system.refresh_board()

# Accessibilité : au-dessous de ce ratio de HP max, un symbole "⚠" est ajouté
# devant le nombre de HP du héros — ne pas dépendre uniquement d'une couleur
# pour signaler un danger (voir _hp_label_text).
const LOW_HP_RATIO := 0.3

func update_ui() -> void:
	battle.get_node("PlayerHeroPanel/HealthLabel").text = _hp_label_text(battle.player_hero)
	battle.get_node("EnemyHeroPanel/HealthLabel").text  = _hp_label_text(battle.enemy_hero)

func _hp_label_text(hero: Hero) -> String:
	var hp: int = maxi(hero.health, 0)
	if hero.max_health > 0 and float(hp) / float(hero.max_health) <= LOW_HP_RATIO and hp > 0:
		return "⚠ " + str(hp)
	return str(hp)
