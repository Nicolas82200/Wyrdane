extends RefCounted
class_name NetDebugLog

# Journal de debug ultra-détaillé pour une partie réseau : trace CHAQUE
# commande envoyée/reçue et un instantané complet de l'état de jeu après
# chaque action, sur les DEUX clients. But : pouvoir comparer les deux
# godot.log d'une même partie côte à côte pour repérer le PREMIER point où
# les deux plateaux divergent (voir CLAUDE.md « Vérification Godot CLI » /
# les nombreux bugs de désync réseau trouvés par cette méthode).
#
# Tout passe par print() (capturé dans godot.log, voir CrashReporter) avec le
# préfixe "[NETDBG]" pour un grep facile : `grep NETDBG godot.log`.
#
# Normalisation Hôte/Invité : "player_minions"/"enemy_minions" désignent des
# camps DIFFÉRENTS selon le client qui regarde (mes serviteurs vs les siens).
# Pour que les deux logs soient directement comparables ligne à ligne, chaque
# instantané est reformulé en "Hôte"/"Invité" (rôle IDENTIQUE des deux côtés,
# voir NetworkManager.is_host) plutôt qu'en "joueur local"/"adverse".
#
# Toujours actif dès qu'une partie réseau est en cours (battle.network_manager
# != null) — coût négligeable (quelques lignes de texte par action, jamais en
# solo) au regard de la valeur en debug. Pour désactiver temporairement,
# mettre ENABLED à false ci-dessous.
const ENABLED := true

static func command_sent(command: Dictionary) -> void:
	if not ENABLED:
		return
	print("[NETDBG] >> ENVOYÉ  %s" % _format_command(command))

static func command_received(command: Dictionary) -> void:
	if not ENABLED:
		return
	print("[NETDBG] << REÇU    %s" % _format_command(command))

# À appeler juste après qu'une action (locale ÉMISE, ou distante REJOUÉE) ait
# fini de modifier l'état du jeu — label : "LOCAL" (nous venons d'émettre) ou
# "DISTANT" (nous venons de rejouer la commande du pair).
static func action_applied(battle, label: String, command: Dictionary) -> void:
	if not ENABLED or not is_instance_valid(battle):
		return
	print("[NETDBG] == %s appliqué : %s" % [label, _format_command(command)])
	print("[NETDBG]    état -> %s" % snapshot_line(battle))

static func _format_command(command: Dictionary) -> String:
	return str(command)

# Trace CHAQUE effet de carte réellement résolu par EffectManager (Damage,
# Buff, SummonMinion...) — appelé pour les DEUX camps, sur les DEUX clients
# (EffectManager tourne identiquement pour une carte locale ou rejouée depuis
# le réseau), donc directement comparable ligne à ligne entre les deux
# godot.log : si un des deux ne voit pas la même ligne "EFFET" au même
# endroit de la séquence, l'effet n'a pas été résolu pareil des deux côtés.
# `executed` distingue un effet réellement appliqué d'un effet ignoré par sa
# condition (CardEffect.condition_type) — une condition qui s'évalue
# différemment d'un client à l'autre (ex. dépendant d'un compteur pas encore
# synchronisé) serait sinon invisible dans ce log.
static func effect_resolved(battle, source_minion, effect, selected_target, executed: bool) -> void:
	# battle.get(...) plutôt que battle.network_manager : cette fonction est
	# appelée depuis EffectManager, exercé par de nombreux doubles de test
	# légers (et SimulatedBattle en mode Arena) qui ne déclarent pas cette
	# propriété — un accès direct y lèverait une erreur d'exécution ("Invalid
	# get index"), avortant l'effet en cours de résolution (régression
	# constatée : 79 tests en échec/pending après l'introduction de ce log).
	if not ENABLED or not is_instance_valid(battle) or battle.get("network_manager") == null:
		return
	var source_name: String = "(sort)"
	if source_minion != null and source_minion.card_data != null:
		source_name = "%s(#%d)" % [source_minion.card_data.card_name, source_minion.net_id]
	var status: String = "exécuté" if executed else "IGNORÉ (condition non remplie)"
	print("[NETDBG] EFFET %s : %s -> effect_id=%s cible=%s valeur=%d/%d" % [
		source_name, status, effect.effect_id,
		_format_target(battle, selected_target), effect.value, effect.value_2,
	])

static func _format_target(battle, target) -> String:
	if target == null:
		return "(aucune)"
	if target is Minion:
		var name: String = target.card_data.card_name if target.card_data != null else "?"
		return "%s(#%d)" % [name, target.net_id]
	if target is Hero:
		return "Héros(%s)" % ("joueur" if target == battle.player_hero else "adversaire")
	if target is CardData:
		return "Carte:%s" % target.card_name
	return str(target)

# Instantané compact et déterministe de l'état de jeu, normalisé Hôte/Invité.
static func snapshot_line(battle) -> String:
	if battle.network_manager == null:
		return "(hors ligne)"
	var is_host: bool = battle.network_manager.is_host
	var host_is_local: bool = is_host
	return "%s | %s" % [
		_side_snapshot(battle, "Hôte", host_is_local),
		_side_snapshot(battle, "Invité", not host_is_local),
	]

# is_local : ce côté (Hôte ou Invité) correspond-il au joueur LOCAL de CE
# client (battle.player_*) ou à l'adversaire (battle.enemy_*) ?
static func _side_snapshot(battle, side_name: String, is_local: bool) -> String:
	var hero: Hero = battle.player_hero if is_local else battle.enemy_hero
	var minions: Array = battle.player_minions if is_local else battle.enemy_minions
	var mana: Dictionary = battle.race_mana_pool(is_local)
	var hand_size: int = battle.hand_cards.size() if is_local else battle.opponent.get_hand_count()
	var hero_hp: String = "%d/%d" % [hero.health, hero.max_health] if hero != null else "?"
	return "%s[hp=%s mana=%s main=%d plateau=%s]" % [
		side_name, hero_hp, _format_mana(mana), hand_size, _format_minions(minions),
	]

static func _format_mana(mana: Dictionary) -> String:
	if mana.is_empty():
		return "{}"
	var parts: Array[String] = []
	var races: Array = mana.keys()
	races.sort()
	for race in races:
		parts.append("%s:%d" % [Race.get_race_name(int(race)), int(mana[race])])
	return "{%s}" % ", ".join(parts)

static func _format_minions(minions: Array) -> String:
	if minions.is_empty():
		return "[]"
	var sorted_minions: Array = minions.duplicate()
	sorted_minions.sort_custom(func(a: Minion, b: Minion) -> bool: return a.net_id < b.net_id)
	var parts: Array[String] = []
	for m in sorted_minions:
		var minion: Minion = m
		var name: String = minion.card_data.card_name if minion.card_data != null else "?"
		parts.append("#%d %s(%d/%d)" % [minion.net_id, name, minion.attack, minion.health])
	return "[%s]" % ", ".join(parts)
