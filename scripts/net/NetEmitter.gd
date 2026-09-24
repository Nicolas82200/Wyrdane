extends RefCounted
class_name NetEmitter

# Traduit les actions du JOUEUR LOCAL en commandes réseau et les envoie au pair.
# Présent uniquement en partie réseau (battle.net_emitter) ; en solo il est null
# et aucun point d'appel n'émet.
#
# Règle anti-écho : les hooks d'émission sont posés UNIQUEMENT sur les chemins
# d'entrée du joueur local (clic sur une carte, attaque initiée, choix de tour,
# bouton fin de tour). Le rejeu des commandes distantes (NetworkOpponent) passe
# par des méthodes plus bas niveau qui n'émettent pas, donc aucune boucle.
#
# Note : AfkGuard.notify_local_action (preuve de présence) est appelé directement
# par CardSystem/CombatSystem/SacrificeSystem/FusionSystem à la source de chaque
# action (solo ET réseau), pas ici — inutile de le redupliquer sur ce chemin
# réseau qui s'exécute toujours après.

var _net: NetworkManager
# Référence faible en pratique (Battle possède net_emitter, pas l'inverse) —
# uniquement pour l'instantané d'état de NetDebugLog après chaque émission.
var _battle

func _init(net: NetworkManager, battle = null) -> void:
	_net = net
	_battle = battle

# Envoie la commande puis journalise l'état local résultant (voir
# NetDebugLog) — factorisé ici pour que chaque méthode d'émission n'ait pas à
# le répéter.
func _send(command: Dictionary) -> void:
	_net.send_command(command)
	NetDebugLog.action_applied(_battle, "LOCAL", command)

# ids : net_id de tous les serviteurs créés par l'action (capturés via NetRegistry).
# target : cible choisie de l'effet — Minion, Hero, ou null si aucune (une
# cible CardData, ex. enchantement/rituel visé, n'est pas encore synchronisable
# faute d'id stable pour ce cas, voir CardSystem.gd).
func play_card(card_data: CardData, row: String, insert_index: int,
		ids: Array = [], target = null, discounts: Array = []) -> void:
	var target_id: int = NetCommand.TARGET_NONE
	if target is Minion:
		target_id = target.net_id
	elif target is Hero:
		target_id = NetCommand.TARGET_HERO
	_send(NetCommand.play_card(
		card_data.resource_path, row, insert_index, ids, target_id, discounts))

func attack(attacker: Minion, defender: Minion, ids: Array = []) -> void:
	_send(NetCommand.attack(attacker.net_id, defender.net_id, ids))

func attack_hero(attacker: Minion, ids: Array = []) -> void:
	_send(NetCommand.attack_hero(attacker.net_id, ids))

func end_turn(ids: Array = []) -> void:
	_send(NetCommand.end_turn(ids))

func turn_start(ids: Array = []) -> void:
	_send(NetCommand.turn_start(ids))

# Activation locale d'un Rituel de Sacrifice (victimes déjà choisies).
func activate_ritual(card_data: CardData, victim_ids: Array, ids: Array = []) -> void:
	_send(NetCommand.activate_ritual(card_data.resource_path, victim_ids, ids))

# Activation locale du mot-clé FUSION (victime et mot-clé déjà choisis).
func activate_fusion(source_id: int, victim_id: int, keyword_pool: String, keyword_name: String, ids: Array = []) -> void:
	_send(NetCommand.activate_fusion(source_id, victim_id, keyword_pool, keyword_name, ids))

# Emote cosmétique (voir EmoteWheel) — purement décoratif, aucun état à
# resynchroniser si le paquet se perdait (improbable, le transport est fiable
# par défaut).
func emote(emote_id: int) -> void:
	_net.send_command(NetCommand.emote(emote_id))

# Le joueur local a validé son mulligan (contenu privé, seule la fin est notifiée).
func mulligan_done() -> void:
	_net.send_command(NetCommand.mulligan_done())

# Défausse de fin de tour (limite 10 cartes) : contenu privé, seul le nombre
# de cartes défaussées est transmis (voir HandDiscardSystem).
func discard(count: int) -> void:
	_net.send_command(NetCommand.discard(count))
