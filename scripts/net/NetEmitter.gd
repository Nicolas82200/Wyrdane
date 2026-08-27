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

var _net: NetworkManager

func _init(net: NetworkManager) -> void:
	_net = net

# ids : net_id de tous les serviteurs créés par l'action (capturés via NetRegistry).
# target : cible choisie de l'effet, null si aucune.
func play_card(card_data: CardData, row: String, insert_index: int,
		ids: Array = [], target: Minion = null) -> void:
	var target_id: int = target.net_id if target != null else NetCommand.TARGET_NONE
	_net.send_command(NetCommand.play_card(
		card_data.resource_path, row, insert_index, ids, target_id))

func attack(attacker: Minion, defender: Minion, ids: Array = []) -> void:
	_net.send_command(NetCommand.attack(attacker.net_id, defender.net_id, ids))

func attack_hero(attacker: Minion, ids: Array = []) -> void:
	_net.send_command(NetCommand.attack_hero(attacker.net_id, ids))

func end_turn(ids: Array = []) -> void:
	_net.send_command(NetCommand.end_turn(ids))

func turn_start(ids: Array = []) -> void:
	_net.send_command(NetCommand.turn_start(ids))

# Activation locale d'un Rituel de Sacrifice (victimes déjà choisies).
func activate_ritual(card_data: CardData, victim_ids: Array, ids: Array = []) -> void:
	_net.send_command(NetCommand.activate_ritual(card_data.resource_path, victim_ids, ids))

# Activation locale du mot-clé FUSION (victime et mot-clé déjà choisis).
func activate_fusion(source_id: int, victim_id: int, keyword_pool: String, keyword_name: String, ids: Array = []) -> void:
	_net.send_command(NetCommand.activate_fusion(source_id, victim_id, keyword_pool, keyword_name, ids))

# Le joueur local a validé son mulligan (contenu privé, seule la fin est notifiée).
func mulligan_done() -> void:
	_net.send_command(NetCommand.mulligan_done())

# Défausse de fin de tour (limite 10 cartes) : contenu privé, seul le nombre
# de cartes défaussées est transmis (voir HandDiscardSystem).
func discard(count: int) -> void:
	_net.send_command(NetCommand.discard(count))
