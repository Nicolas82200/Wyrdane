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
# Validé dès réception de MULLIGAN_DONE, même avant que await_mulligan() soit
# appelé (le pair peut finir avant nous) : on ne doit pas attendre dans le vide.
var _remote_mulligan_done: bool = false

func _init(network_manager: NetworkManager) -> void:
	net = network_manager
	net.command_received.connect(_on_command_received)

# ─── OpponentDriver ───────────────────────────────────────────────────────────

const STARTING_HAND := 5  # cartes piochées au début (voir DeckSystem.start_game)

# Compteurs cosmétiques du camp distant (dos de deck / main), suivis via les
# commandes reçues faute de connaître les cartes réelles de l'adversaire.
var _deck_count: int = 0
var _hand_count: int = 0

func setup() -> void:
	# Pools de ressource initiaux du camp adverse : vides tant qu'aucune carte-
	# ressource n'a été posée (plus de mana de départ, voir README).
	race_mana = {}
	race_max_mana = {}
	# Compteurs initiaux d'après le deck reçu au handshake, moins la main de départ.
	var deck_size: int = NetContext.setup.get("opponent_deck", []).size()
	_hand_count = min(STARTING_HAND, deck_size)
	_deck_count = max(0, deck_size - _hand_count)
	battle.update_enemy_mana_ui()
	battle.update_enemy_hand_ui()
	battle.deck_system.update_enemy_deck_ui()

func get_deck_count() -> int:
	return _deck_count

func get_hand_count() -> int:
	return _hand_count

# Effet local (ex. Autel des Damnés côté ennemi) déclenché en miroir sur les
# deux clients : le pair distant pioche déjà sa vraie carte de son côté, on se
# contente ici de refléter le changement dans les compteurs cosmétiques.
func draw_card() -> void:
	if _deck_count > 0:
		_deck_count -= 1
		_hand_count += 1
	battle.update_enemy_hand_ui()
	battle.deck_system.update_enemy_deck_ui()

# Attend le MULLIGAN_DONE du pair distant (déjà reçu, ou à recevoir).
func await_mulligan() -> void:
	while not _remote_mulligan_done:
		await battle.get_tree().process_frame

# Attend et rejoue le tour du joueur distant, commande par commande, jusqu'à
# recevoir END_TURN, puis rend la main à TurnSystem.
func take_turn() -> void:
	# Bloque les inputs locaux pendant le tour distant (comme l'IA en solo).
	battle.set_enemy_turn(true)
	_turn_over = false
	while not _turn_over:
		# Sortie de secours : partie terminée ou pair déconnecté.
		if battle.game_over:
			break
		while not _queue.is_empty():
			var cmd: Dictionary = _queue.pop_front()
			if NetCommand.type_of(cmd) == NetCommand.END_TURN:
				# Rejoue la phase de fin de tour distante (OnTurnEnd + Infection)
				# avec les ids imposés pour d'éventuelles invocations de triggers.
				battle.net_registry.set_imposed_ids(cmd.get("ids", []))
				await battle.turn_system.run_turn_end_triggers(false)
				battle.net_registry.set_imposed_ids([])
				_turn_over = true
				break
			await _apply(cmd)
			await battle.pace_actions()
		if not _turn_over:
			# Rien à rejouer pour l'instant : on attend le prochain paquet.
			await battle.get_tree().process_frame
	battle.set_enemy_turn(false)

func refresh_ui() -> void:
	pass

# ─── Réception ────────────────────────────────────────────────────────────────

func _on_command_received(command: Dictionary) -> void:
	if not NetCommand.is_valid(command):
		return
	match NetCommand.type_of(command):
		NetCommand.HELLO:
			# HELLO tardif : notre handshake est terminé mais le pair renvoie le
			# sien, donc notre HELLO_ACK s'est perdu et il attend encore au
			# lobby. On répond pour le débloquer (voir NetHandshake).
			net.send_command(NetCommand.hello_ack())
		NetCommand.HELLO_ACK:
			# Résidu de handshake (doublon) : rien à rejouer.
			pass
		NetCommand.MULLIGAN_DONE:
			# Ne pas mettre en file : ce n'est pas une action de tour à rejouer.
			_remote_mulligan_done = true
		_:
			_queue.append(command)

# ─── Rejeu ────────────────────────────────────────────────────────────────────

# Applique une commande distante au camp ennemi. Chaque branche réutilisera les
# systèmes existants (BoardSystem, CombatSystem, TurnSystem) en désignant les
# serviteurs par net_id via battle.net_registry.resolve().
func _apply(cmd: Dictionary) -> void:
	match NetCommand.type_of(cmd):
		NetCommand.TURN_START:
			# Rejoue la phase de début du tour distant (is_local_turn = false) :
			# recharge les pools de ressource à leur maximum et pioche une carte
			# automatiquement, comme le tour local (plus de choix Mana/Pioche).
			battle.net_registry.set_imposed_ids(cmd.get("ids", []))
			await battle.turn_system.run_turn_start_triggers(false)
			battle.net_registry.set_imposed_ids([])
			battle.refill_mana_pool(false)
			battle.update_enemy_mana_ui()
			if _deck_count > 0:
				_deck_count -= 1
				_hand_count += 1
			battle.update_enemy_hand_ui()
			battle.deck_system.update_enemy_deck_ui()
		NetCommand.PLAY_CARD:
			await _apply_play_card(cmd)
		NetCommand.ATTACK:
			var attacker: Minion = battle.net_registry.resolve(cmd.get("attacker", 0))
			var defender: Minion = battle.net_registry.resolve(cmd.get("defender", 0))
			# L'attaquant rejoué doit appartenir au camp distant et la cible au
			# camp local : sans ce contrôle, un pair pourrait désigner un net_id
			# appartenant à NOTRE camp et nous forcer à attaquer nous-mêmes.
			if attacker != null and defender != null \
					and not attacker.owner_is_player and defender.owner_is_player:
				# ids imposés : voir CombatSystem.resolve_combat (capture des
				# serviteurs invoqués par un Dernier Souffle déclenché en combat).
				battle.net_registry.set_imposed_ids(cmd.get("ids", []))
				await battle.combat_system.resolve_combat(attacker, defender)
				battle.net_registry.set_imposed_ids([])
			else:
				push_warning("NetworkOpponent : ATTACK invalide (propriété incohérente)")
		NetCommand.ATTACK_HERO:
			var attacker: Minion = battle.net_registry.resolve(cmd.get("attacker", 0))
			# Revalide la règle "Rangée Avant vide"/Rempart côté réception (battle._can_attack_hero
			# est généralisé pour n'importe quel camp attaquant) : un pair distant désynchronisé
			# ou modifié ne doit pas pouvoir forcer une attaque du héros local à tort, même si
			# perform_hero_attack lui-même n'effectue aucune validation.
			if attacker != null and not attacker.owner_is_player and battle._can_attack_hero(attacker):
				battle.net_registry.set_imposed_ids(cmd.get("ids", []))
				await battle.combat_system.perform_hero_attack(attacker)
				battle.net_registry.set_imposed_ids([])
			elif attacker != null:
				push_warning("NetworkOpponent : ATTACK_HERO invalide (propriété ou règle non respectée)")
		NetCommand.ACTIVATE_RITUAL:
			await _apply_activate_ritual(cmd)
		NetCommand.ACTIVATE_FUSION:
			await _apply_activate_fusion(cmd)
		_:
			push_warning("NetworkOpponent : commande non gérée '%s'" % NetCommand.type_of(cmd))

# Charge une carte désignée par son resource_path reçu du réseau. Restreint au
# dossier des ressources de carte et exclut les jetons d'invocation (jamais
# censés être joués depuis une main) pour empêcher un pair de faire charger un
# chemin arbitraire du projet.
const CARDS_RESOURCE_PREFIX := "res://resources/cards/"

func _load_remote_card(path: String) -> CardData:
	if not path.begins_with(CARDS_RESOURCE_PREFIX) or not path.ends_with(".tres"):
		push_warning("NetworkOpponent : chemin de carte refusé '%s'" % path)
		return null
	var card: CardData = load(path) as CardData
	if card == null:
		push_warning("NetworkOpponent : carte introuvable '%s'" % path)
		return null
	if card.is_token:
		push_warning("NetworkOpponent : jeton refusé '%s'" % path)
		return null
	return card

# Rejoue une carte jouée par le pair, côté ENNEMI. Les serviteurs créés (carte +
# jetons d'effet) reçoivent les ids imposés capturés par l'émetteur, dans l'ordre.
# Limité aux serviteurs pour l'instant : les sorts distants demandent un
# EffectManager conscient du propriétaire (brique suivante).
func _apply_play_card(cmd: Dictionary) -> void:
	var card: CardData = _load_remote_card(cmd.get("card", ""))
	if card == null:
		return
	# Un pair ne peut pas jouer plus de cartes qu'il n'en a en main (compteur
	# cosmétique mais fiable : il suit exactement les PLAY_CARD/TURN_START reçus).
	if _hand_count <= 0:
		push_warning("NetworkOpponent : PLAY_CARD rejeté (main distante vide)")
		return
	if card.card_type == "Resource":
		# Carte-ressource : pas de coût, +1 au pool de sa race (voir Battle.play_resource_card).
		_hand_count -= 1
		battle.update_enemy_hand_ui()
		battle.play_resource_card(card, false)
		return
	# Coût réel du camp distant : refuse si le pair n'a pas les ressources
	# affichées pour cette carte (sinon un client modifié pourrait poser
	# n'importe quoi gratuitement et faire passer les pools en négatif).
	if not battle.cost_system.can_afford(card, false):
		push_warning("NetworkOpponent : PLAY_CARD rejeté (coût non couvert) '%s'" % card.card_name)
		return
	battle.net_registry.set_imposed_ids(cmd.get("ids", []))
	battle.cost_system.pay(card, false)
	battle.update_enemy_mana_ui()
	await battle.cost_system.on_card_played(card, false)
	# La carte jouée quitte la main adverse (compteur cosmétique).
	if _hand_count > 0:
		_hand_count -= 1
		battle.update_enemy_hand_ui()
	if card.card_type == "Minion":
		var row: String = cmd.get("row", "Front")
		var index: int = cmd.get("index", -1)
		# Jeu ciblé (résolu via resolve_with_target chez l'émetteur) : la cible est
		# résolue par net_id puis transmise directement au déclenchement ONPLAY,
		# comme côté émetteur (voir CardSystem.resolve_with_target).
		var target_id: int = cmd.get("target", NetCommand.TARGET_NONE)
		var target: Minion = battle.net_registry.resolve(target_id) if target_id != NetCommand.TARGET_NONE else null
		await battle.board_system.summon_minion_return(card, false, row, index, false, target)
	else:
		await _apply_enemy_spell(card, cmd.get("target", NetCommand.TARGET_NONE))
	# Purge tout id imposé résiduel (ex. effet aléatoire ayant créé moins de
	# serviteurs que prévu) pour ne pas contaminer les invocations suivantes.
	battle.net_registry.set_imposed_ids([])

# Rejoue l'activation d'un Rituel de Sacrifice distant côté ENNEMI : le rituel
# est retrouvé par resource_path parmi les rituels adverses en jeu, les victimes
# par net_id ; l'exécution passe par le même chemin que côté émetteur.
func _apply_activate_ritual(cmd: Dictionary) -> void:
	var card: CardData = _load_remote_card(cmd.get("card", ""))
	if card == null:
		return
	var victims: Array = []
	for victim_id in cmd.get("victims", []):
		var victim: Minion = battle.net_registry.resolve(victim_id)
		if victim != null:
			victims.append(victim)
	battle.net_registry.set_imposed_ids(cmd.get("ids", []))
	await battle.trigger_system.activate_sacrifice_ritual(card, false, victims)
	battle.net_registry.set_imposed_ids([])

# Rejoue l'activation distante du mot-clé FUSION côté ENNEMI : source et
# victime doivent toutes deux appartenir au camp distant (comme ATTACK), sans
# quoi un pair malveillant pourrait désigner un net_id de notre propre camp.
func _apply_activate_fusion(cmd: Dictionary) -> void:
	var source: Minion = battle.net_registry.resolve(cmd.get("source", 0))
	var victim: Minion = battle.net_registry.resolve(cmd.get("victim", 0))
	if source == null or victim == null or source.owner_is_player or victim.owner_is_player:
		push_warning("NetworkOpponent : ACTIVATE_FUSION invalide (propriété incohérente)")
		return
	var pool: String = cmd.get("pool", "")
	var keyword: int = FusionSystem.keyword_from_name(pool, cmd.get("keyword", "")) if pool != "" else -1
	battle.net_registry.set_imposed_ids(cmd.get("ids", []))
	await battle.fusion_system.apply_fusion(source, victim, pool, keyword)
	battle.net_registry.set_imposed_ids([])

# Rejoue un sort / rituel / enchantement du pair côté ENNEMI. Un proxy
# owner_is_player=false sert de lanceur pour que EffectManager résolve les cibles
# du bon camp (ex. « tous les ennemis » = les serviteurs du joueur local).
func _apply_enemy_spell(card: CardData, target_id: int) -> void:
	battle.combat_log.card_played(card, false)
	var early_target: Minion = null
	if target_id != NetCommand.TARGET_NONE:
		early_target = battle.net_registry.resolve(target_id)
	var shows_popup: bool = card.card_type != "Enchantment" \
		and not (card.card_type == "Ritual" and card.ritual_duration != 0)
	if shows_popup:
		await battle.card_popup_system.show_card_popup(card)
	if card.card_type == "Instant" or card.card_type == "Ritual":
		AudioManager.play_spell_cast(card)
		battle.vfx_manager.spawn_for_spell(battle, card, false, early_target)
	if card.card_type == "Enchantment":
		battle.trigger_system.register_enchantment(card, false, -1)
		battle.enchantment_system.add_enchantment(card, false)
		battle.aura_system.recompute_all()
		await battle.death_system.process_deaths()
	elif card.card_type == "Ritual" and card.ritual_duration != 0:
		battle.trigger_system.register_enchantment(card, false, card.ritual_duration)
		battle.enchantment_system.add_ritual(card, false, card.ritual_duration)
		battle.aura_system.recompute_all()
		await battle.death_system.process_deaths()
	else:
		battle.enemy_graveyard.add_spell(card)
		var target: Minion = early_target
		# Annulation de sort (Rituel de l'Éclipse Rouge) : même vérification que
		# CardSystem côté émetteur, pour que les deux clients restent synchrones.
		if target != null and await battle.trigger_system.try_cancel_spell(false, target):
			battle.board_visual_system.refresh_board()
			return
		# Sortilège allié : les serviteurs du lanceur (côté ennemi) réagissent
		# AVANT les effets du sort, comme dans CardSystem, pour garder l'ordre
		# d'attribution des ids identique entre les deux clients.
		await battle.trigger_system.fire("OnSpell", null, true)
		for ally in battle.enemy_minions.duplicate():
			await battle.effect_manager.trigger_effects(battle, ally, "OnSpell")
		var proxy := Minion.new(card, false, "")
		for effect in card.effects:
			await battle.effect_manager.execute_effect(battle, proxy, effect, target)
	battle.board_visual_system.refresh_board()
