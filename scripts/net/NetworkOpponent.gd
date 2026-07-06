extends OpponentDriver
class_name NetworkOpponent

# Implémentation réseau d'OpponentDriver : le camp adverse est un joueur distant.
# On ne DÉCIDE rien ici — on reçoit ses commandes via NetworkManager et on les
# REJOUE localement sur le plateau, dans l'ordre, jusqu'à END_TURN.
#
# Interchangeable avec AISystem : TurnSystem.end_turn() appelle
# battle.opponent.take_turn() sans savoir si l'adversaire est l'IA ou le réseau.

var net: NetworkManager
# Commandes du tour distant reçues mais pas encore rejouées (FIFO).
var _queue: Array[Dictionary] = []
var _turn_over: bool = false

func _init(network_manager: NetworkManager) -> void:
	net = network_manager
	net.command_received.connect(_on_command_received)

# ─── OpponentDriver ───────────────────────────────────────────────────────────

const MANA_CAP := 10

func setup() -> void:
	# Mana initial du camp adverse, miroir du 1er tour du joueur local.
	mana = 1
	max_mana = 1
	battle.update_enemy_mana_ui()

# Attend et rejoue le tour du joueur distant, commande par commande, jusqu'à
# recevoir END_TURN, puis rend la main à TurnSystem.
func take_turn() -> void:
	# Bloque les inputs locaux pendant le tour distant (comme l'IA en solo).
	battle.enemy_turn_active = true
	_turn_over = false
	while not _turn_over:
		while not _queue.is_empty():
			var cmd: Dictionary = _queue.pop_front()
			if NetCommand.type_of(cmd) == NetCommand.END_TURN:
				_turn_over = true
				break
			await _apply(cmd)
			await battle.pace_actions()
		if not _turn_over:
			# Rien à rejouer pour l'instant : on attend le prochain paquet.
			await battle.get_tree().process_frame
	battle.enemy_turn_active = false

func refresh_ui() -> void:
	pass

# ─── Réception ────────────────────────────────────────────────────────────────

func _on_command_received(command: Dictionary) -> void:
	if not NetCommand.is_valid(command):
		return
	match NetCommand.type_of(command):
		NetCommand.HELLO:
			# Handshake : traité hors de la file de tour (brique suivante).
			pass
		_:
			_queue.append(command)

# ─── Rejeu ────────────────────────────────────────────────────────────────────

# Applique une commande distante au camp ennemi. Chaque branche réutilisera les
# systèmes existants (BoardSystem, CombatSystem, TurnSystem) en désignant les
# serviteurs par net_id via battle.net_registry.resolve().
func _apply(cmd: Dictionary) -> void:
	match NetCommand.type_of(cmd):
		NetCommand.TURN_CHOICE:
			# Choix de début de tour distant : mana augmente la réserve, pioche non.
			# Affichage cosmétique côté joueur local (les plays sont déjà validés
			# chez l'émetteur).
			if cmd.get("choice", "mana") == "mana":
				max_mana = min(max_mana + 1, MANA_CAP)
			mana = max_mana
			battle.update_enemy_mana_ui()
		NetCommand.PLAY_CARD:
			await _apply_play_card(cmd)
		NetCommand.ATTACK:
			var attacker: Minion = battle.net_registry.resolve(cmd.get("attacker", 0))
			var defender: Minion = battle.net_registry.resolve(cmd.get("defender", 0))
			if attacker != null and defender != null:
				await battle.combat_system.resolve_combat(attacker, defender)
		NetCommand.ATTACK_HERO:
			var attacker: Minion = battle.net_registry.resolve(cmd.get("attacker", 0))
			if attacker != null:
				await battle.combat_system.perform_hero_attack(attacker)
		_:
			push_warning("NetworkOpponent : commande non gérée '%s'" % NetCommand.type_of(cmd))

# Rejoue une carte jouée par le pair, côté ENNEMI. Les serviteurs créés (carte +
# jetons d'effet) reçoivent les ids imposés capturés par l'émetteur, dans l'ordre.
# Limité aux serviteurs pour l'instant : les sorts distants demandent un
# EffectManager conscient du propriétaire (brique suivante).
func _apply_play_card(cmd: Dictionary) -> void:
	var card: CardData = load(cmd.get("card", "")) as CardData
	if card == null:
		push_warning("NetworkOpponent : carte introuvable '%s'" % cmd.get("card", ""))
		return
	battle.net_registry.set_imposed_ids(cmd.get("ids", []))
	if card.card_type == "Minion":
		var row: String = cmd.get("row", "Front")
		var index: int = cmd.get("index", -1)
		if card.requires_target and cmd.get("target", NetCommand.TARGET_NONE) != NetCommand.TARGET_NONE:
			push_warning("NetworkOpponent : effet d'invocation ciblé distant non encore rejoué")
		await battle.board_system.summon_minion_return(card, false, row, index)
	else:
		await _apply_enemy_spell(card, cmd.get("target", NetCommand.TARGET_NONE))
	# Purge tout id imposé résiduel (ex. effet aléatoire ayant créé moins de
	# serviteurs que prévu) pour ne pas contaminer les invocations suivantes.
	battle.net_registry.set_imposed_ids([])

# Rejoue un sort / rituel / enchantement du pair côté ENNEMI. Un proxy
# owner_is_player=false sert de lanceur pour que EffectManager résolve les cibles
# du bon camp (ex. « tous les ennemis » = les serviteurs du joueur local).
func _apply_enemy_spell(card: CardData, target_id: int) -> void:
	if card.card_type == "Enchantment":
		battle.trigger_system.register_enchantment(card, false, -1)
		battle.enchantment_system.add_enchantment(card, false)
		battle.aura_system.recompute_all()
	elif card.card_type == "Ritual" and card.ritual_duration != 0:
		battle.trigger_system.register_enchantment(card, false, card.ritual_duration)
		battle.enchantment_system.add_ritual(card, false, card.ritual_duration)
		battle.aura_system.recompute_all()
	else:
		battle.enemy_graveyard.add_spell(card)
		# Sortilège allié : les serviteurs du lanceur (côté ennemi) réagissent
		# AVANT les effets du sort, comme dans CardSystem, pour garder l'ordre
		# d'attribution des ids identique entre les deux clients.
		for ally in battle.enemy_minions.duplicate():
			await battle.effect_manager.trigger_effects(battle, ally, "OnSpell")
		var proxy := Minion.new(card, false, "")
		var target: Minion = null
		if target_id != NetCommand.TARGET_NONE:
			target = battle.net_registry.resolve(target_id)
		for effect in card.effects:
			await battle.effect_manager.execute_effect(battle, proxy, effect, target)
	battle.board_visual_system.refresh_board()
