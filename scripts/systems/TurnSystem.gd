extends Node
class_name TurnSystem

var battle

# Garde de réentrée : le bouton Fin du tour et l'expiration du turn_timer
# peuvent tous deux appeler end_turn() sans se voir mutuellement désactivés
# tant que battle.enemy_turn_active n'est pas encore passé à true (ce flag
# n'est levé qu'à l'intérieur d'opponent.take_turn(), après plusieurs await
# de ce tour — déclencheurs de fin de tour, Infection, effets temporaires).
# Un clic juste avant l'expiration du minuteur peut donc déclencher deux
# end_turn() qui se chevauchent (double tour IA, double pioche du joueur).
var _ending_turn: bool = false

func init(_battle) -> void:
	battle = _battle

func end_turn() -> void:
	if _ending_turn:
		return
	_ending_turn = true
	# Capture les ids des serviteurs créés par les déclencheurs de fin de tour
	# (ex. Dernier Souffle), pour que le pair les rejoue avec les mêmes ids.
	if battle.net_emitter != null:
		battle.net_registry.begin_capture()
	await run_turn_end_triggers()
	await battle.temp_effect_system.expire_end_of_player_turn()
	battle.cost_system.expire_end_of_player_turn()  # remises "ce tour"
	battle.counter_offensive[true] = false  # "ce tour" : la Contre-Offensive expire
	battle.hero_system.self_damage_blocked[true] = false  # Absolution Écarlate expire
	# Émission réseau : dernière commande du tour local (porte les ids de triggers).
	if battle.net_emitter != null:
		var ids: Array = battle.net_registry.end_capture()
		battle.net_emitter.end_turn(ids)
	await battle.opponent.take_turn()
	if battle.game_over:
		_ending_turn = false
		return
	await battle.temp_effect_system.expire_end_of_enemy_turn()
	battle.counter_offensive[false] = false  # "ce tour" : la Contre-Offensive expire
	battle.hero_system.self_damage_blocked[false] = false
	await _begin_player_turn()
	_ending_turn = false

# Phase de fin de tour (Infection). is_local_turn : true si c'est le tour du
# joueur local. Le déclencheur "fin de tour" côté cartes est porté par Déclin
# (OnDecline, déclenché juste après pour le camp dont le tour vient de finir).
func run_turn_end_triggers(is_local_turn: bool = true) -> void:
	# Blocage de soin (Rituel de la Terreur) : expire à la fin du tour du héros
	# dont c'est le tour ("jusqu'à la fin de son prochain tour").
	var turn_hero: Hero = battle.player_hero if is_local_turn else battle.enemy_hero
	turn_hero.heal_block_turns = max(turn_hero.heal_block_turns - 1, 0)

	await _apply_infection_damage()

func _begin_player_turn() -> void:
	# Capture les ids des serviteurs créés par les déclencheurs de début de tour.
	if battle.net_emitter != null:
		battle.net_registry.begin_capture()
	await run_turn_start_triggers(true)
	# Émission réseau : le pair rejoue la même phase pour le tour qui commence.
	if battle.net_emitter != null:
		var ids: Array = battle.net_registry.end_capture()
		battle.net_emitter.turn_start(ids)
	_finish_turn_start()
	battle.deck_system.draw_card()
	if battle.tutorial_active:
		if battle.tutorial_manager:
			await battle.tutorial_manager.notify_player_turn_began()
	else:
		battle.turn_timer.start()

# Phase de début de tour. is_local_turn : true si c'est le tour du joueur local.
# OnAwaken vise le camp dont c'est le tour, OnDecline le camp adverse (dont le
# tour vient de finir) — d'où le paramétrage pour le rejeu.
func run_turn_start_triggers(is_local_turn: bool) -> void:
	battle.aura_system.recompute_all()
	await battle.death_system.process_deaths()
	battle.cost_system.on_turn_started(is_local_turn)
	battle.trigger_system.reset_once_per_turn(is_local_turn)
	battle.resource_played_this_turn[is_local_turn] = false
	battle.undead_ally_deaths_this_turn[is_local_turn] = 0
	# Réarmé par Ordre de Tenir (OnAwaken) si le rituel est encore actif.
	battle.front_line_protected[is_local_turn] = false
	var turn_minions: Array = battle.player_minions if is_local_turn else battle.enemy_minions
	var other_minions: Array = battle.enemy_minions if is_local_turn else battle.player_minions
	for minion in turn_minions.duplicate():
		minion.refresh_attacks()
	var acted := false
	# Ordre relatif au joueur du tour (identique sur les deux clients) plutôt que
	# player/enemy relatif au client, pour un tirage RNG déterministe.
	acted = await _trigger_minions_paced(turn_minions, "OnAwaken", acted)
	acted = await battle.trigger_system.fire("OnAwaken", null, is_local_turn, {}, true, acted)
	acted = await _trigger_minions_paced(other_minions, "OnDecline", acted)
	acted = await battle.trigger_system.fire("OnDecline", null, not is_local_turn, {}, true, acted)

# Déclenche un trigger sur chaque serviteur de la liste, avec une pause AVANT
# chaque déclenchement sauf le premier de la file. Retourne l'état "acted"
# pour chaîner le pacing sur la suite de la phase.
func _trigger_minions_paced(minions: Array, trigger_name: String, already_acted: bool) -> bool:
	var acted := already_acted
	for minion in minions.duplicate():
		if not battle.effect_manager.has_trigger(minion, trigger_name):
			continue
		if acted:
			await battle.pace_actions()
		await battle.effect_manager.trigger_effects(battle, minion, trigger_name)
		acted = true
	return acted

func _apply_infection_damage() -> void:
	var any_infected := false
	for minion in (battle.player_minions + battle.enemy_minions).duplicate():
		if minion.infected:
			any_infected = true
			var dealt: int = minion.take_damage(1)
			if dealt > 0:
				battle.combat_log.infection_tick(minion)
				var visual: BoardMinion = battle.board_visual_system.get_visual(minion)
				if visual:
					battle.animation_system.play_infection_tick(visual, dealt)
				await battle.effect_manager.notify_damaged(battle, minion)
	await battle.death_system.process_deaths()
	battle.board_visual_system.refresh_board()
	if any_infected:
		await battle.pace_actions()

func _finish_turn_start() -> void:
	battle.refill_mana_pool(true)
	battle.update_mana_ui()
	battle.board_visual_system.refresh_board()

# ─── Démarrage de partie ────────────────────────────────────────────────────
# Chargement du deck, distribution de la main d'ouverture, mulligan, puis
# lancement du premier tour (local ou distant). Appelé une fois par Battle._ready.

func start_match() -> void:
	battle.update_mana_ui()
	battle.hero_system.update_ui()
	if battle.tutorial_active:
		battle.deck.clear()
		battle.deck.append_array(TutorialDeck.player_deck_padding())
	else:
		battle.deck_system.load_deck()
	battle.deck_system.update_deck_ui()
	battle.board_visual_system.refresh_board()
	battle.hero_system.update_turn_halo()
	for minion in battle.player_minions:
		battle.board_visual_system.spawn_minion_visual(minion, true)
	for minion in battle.enemy_minions:
		battle.board_visual_system.spawn_minion_visual(minion, false)
	if battle.tutorial_active or NetContext.active:
		battle.opponent.setup()
	else:
		battle.ai_system.setup()
	if battle.tutorial_active:
		battle.hand_cards = TutorialDeck.player_hand()
	else:
		battle.deck_system.deal_opening_hand()
	var deck_origin: Vector2 = battle.deck_button.global_position + battle.deck_button.size / 2.0
	await battle.hand.play_opening_draw(battle.hand_cards, deck_origin)
	if battle.tutorial_active:
		await battle.tutorial_manager.intro_mulligan()
	await run_mulligan()
	if NetContext.active:
		var local_first: bool = battle.net_local_first
		NetContext.clear()
		# Si le joueur distant commence, on lui passe la main avant notre 1er tour.
		if not local_first:
			await run_remote_first_turn()
			return
	# Le joueur local ouvre la partie : annonce de son premier tour (sauf en
	# tutoriel, où les popups pédagogiques s'en chargent déjà).
	if not battle.tutorial_active:
		battle.turn_banner.show_banner(SettingsManager.t("battle.turn_player"))
	battle.update_end_turn_hint()
	if battle.tutorial_active:
		# Pas de pression du temps pendant le tutoriel obligatoire.
		TutorialContext.clear()
		battle.tutorial_manager.start()
	else:
		battle.turn_timer.start()

# Phase de mulligan précédant le tour 1 : la main de départ est déjà affichée
# normalement ; cliquer une carte la remplace directement (voir Hand.flip_replace).
# Le bouton Fin du tour devient "Commencer" et confirme la fin du mulligan.
# En réseau, chaque camp mulligan indépendamment (le contenu reste privé) ; on
# attend juste que le pair ait fini avant de lancer le tour 1.
func run_mulligan() -> void:
	battle._mulligan_active = true
	battle._mulligan_swap_count = 0
	battle._mulligan_swapped_indices.clear()
	# Transition étalée réservée à la partie normale : le tutoriel guidé mesure
	# la position des cartes très tôt (voir TutorialManager.guided_mulligan) et
	# a besoin qu'elles soient déjà stables à cet instant.
	battle.hand.set_mulligan_mode(true, -1.0 if battle.tutorial_active else Hand.MULLIGAN_TRANSITION_DURATION)
	battle.hand.mulligan_card_clicked.connect(_on_mulligan_card_clicked)
	battle.mulligan_dim_overlay.visible = true
	battle.turn_banner.show_banner_persistent(
		SettingsManager.t("mulligan.banner"), SettingsManager.t("mulligan.hint"),
		TurnBanner.MULLIGAN_Y_RATIO)
	battle._retranslate_battle()
	battle.end_turn_button.disabled = false
	battle.end_turn_button.set_ready_hint(true)
	# Pas de pression du temps pendant le tutoriel obligatoire (voir start_match) :
	# le joueur lit la popup d'introduction avant de pouvoir même cliquer.
	if not battle.tutorial_active:
		battle.turn_timer.start(battle.MULLIGAN_DURATION)
	else:
		# Étape guidée : surligne les cartes-ressource et force réellement
		# l'échange d'au moins l'une d'elles avant de laisser le joueur
		# confirmer, pour que le mulligan soit enseigné comme les autres
		# mécaniques (pas juste une popup de narration qui se ferme au clic).
		await battle.tutorial_manager.guided_mulligan()
	await battle.mulligan_confirmed
	battle.turn_timer.stop()
	battle.turn_banner.hide_banner()
	battle.end_turn_button.disabled = true
	battle.end_turn_button.set_ready_hint(false)
	battle.mulligan_dim_overlay.visible = false
	battle.hand.mulligan_card_clicked.disconnect(_on_mulligan_card_clicked)
	battle.hand.set_mulligan_mode(false)
	battle._mulligan_active = false
	if battle.net_emitter != null:
		battle.net_emitter.mulligan_done()
	await battle.opponent.await_mulligan()
	battle.end_turn_button.disabled = false
	battle._retranslate_battle()
	battle.update_end_turn_hint()

func _on_mulligan_card_clicked(index: int, _card_data: CardData) -> void:
	if index in battle._mulligan_swapped_indices or battle._mulligan_swap_count >= battle.MULLIGAN_MAX_SWAPS:
		return
	if battle.tutorial_active and not TutorialDeck.is_swappable_during_tutorial(_card_data):
		return
	var new_data: CardData = battle.deck_system.mulligan_replace_one(index)
	if new_data == null:
		return
	battle._mulligan_swap_count += 1
	battle._mulligan_swapped_indices.append(index)
	AudioManager.play(AudioManager.DRAW)
	battle.hand.flip_replace_at(index, new_data)
	battle.hand.set_card_mulligan_swapped(index, true)
	if battle.tutorial_active:
		battle.tutorial_manager.notify_mulligan_swap(_card_data)

# Attend et rejoue le tour d'ouverture du joueur distant, puis démarre le nôtre.
func run_remote_first_turn() -> void:
	battle.opponent.take_turn()
	if battle.game_over:
		return
	await _begin_player_turn()
