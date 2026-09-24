# PactChoiceSystem.gd
# Demande au joueur LOCAL s'il accepte de payer le coût en PV du mot-clé PACTE
# pour activer le bonus d'un effet (CardEffect.pact_bonus), à chaque
# déclenchement effectif du trigger concerné — Arrivée comprise, aucun
# traitement à part : `resolve_trigger()` est appelé identiquement par
# EffectManager.trigger_effects (serviteurs) et TriggerSystem
# (_fire_on_enchantments / activate_sacrifice_ritual / try_cancel_spell pour
# Rituels/Enchantements).
#
# En partie réseau, le propriétaire réel de la carte décide TOUJOURS (popup
# `ask()`), des deux côtés — plus de décision automatique par heuristique pour
# le joueur local. Deux façons pour le pair de connaître la décision distante,
# selon QUI résout le déclencheur en direct (voir `resolve_trigger`) :
#   - Cas courant (le propriétaire résout son propre déclencheur — Arrivée
#     d'un de ses serviteurs, Éveil de tour, etc.) : le propriétaire envoie
#     d'abord une annonce (PACT_ANNOUNCE, AVANT même d'ouvrir sa propre popup
#     `ask()`) puis sa décision (PACT_CHOICE) une fois choisie — les deux AVANT
#     même d'émettre la commande de l'action elle-même (PLAY_CARD/TURN_START/...),
#     puisque cette commande n'est émise par NetEmitter qu'une fois toute la
#     résolution locale terminée (voir NetEmitter.play_card/turn_start...).
#     Sans l'annonce, le pair n'aurait aucun moyen de savoir qu'une décision
#     est en cours tant que PLAY_CARD n'arrive pas — à ce moment-là la
#     décision serait déjà connue (déjà reçue via PACT_CHOICE), donnant
#     l'impression que la carte n'est jamais "en attente" (voir
#     `_handle_remote_announce`, qui affiche la popup d'attente dès l'annonce
#     et met la réponse en cache pour le rejeu ultérieur de la même action).
#   - Cas croisé (l'ADVERSAIRE résout en direct un déclencheur qui touche NOTRE
#     carte — ex. Blessure causée par SON attaque sur notre serviteur Pacte) :
#     à cet instant, nous ne savons même pas encore qu'une action est en cours
#     (sa commande n'arrivera qu'après sa résolution complète) — impossible
#     d'attendre passivement une décision qui n'existe pas encore. Le camp qui
#     résout en direct envoie alors une requête explicite (PACT_REQUEST) et
#     BLOQUE sa propre résolution en attendant la réponse (PACT_CHOICE) du
#     vrai propriétaire, qui répond hors-tour via `_on_command_received` dès
#     réception (popup affichée même si ce n'est pas son tour). Sa décision est
#     mise en cache (`_prefetched_own_answers`) pour que le rejeu ultérieur de
#     cette même action chez lui (une fois la commande reçue normalement) ne
#     la redemande pas une seconde fois.
extends RefCounted
class_name PactChoiceSystem

const SAFE_HEALTH_MARGIN := 6

var battle
# Non typé NetworkManager (plutôt que dupliquer ce test dans une scène Steam
# hors de portée — voir CLAUDE.md) : un faux réseau minimal (signal
# command_received + send_command) suffit dans les tests, voir
# test_pact_choice_system.gd.
var _connected_net = null
# Réponses reçues pour une carte du PAIR (consommées par _await_remote_answer,
# que la réponse ait été sollicitée via PACT_REQUEST ou envoyée par avance).
var _remote_answers: Array[bool] = []
# Décisions déjà données hors-tour pour NOS PROPRES cartes en répondant à un
# PACT_REQUEST distant : le rejeu normal de la même action ne doit pas
# redemander, seulement consommer cette valeur déjà transmise au pair.
var _prefetched_own_answers: Array[bool] = []
# Réponses pour une carte du PAIR déjà obtenues via une popup d'attente
# affichée par anticipation (PACT_ANNOUNCE, voir _handle_remote_announce) :
# le rejeu normal de resolve_trigger (déclenché par PLAY_CARD) ne doit pas
# réafficher une seconde popup, seulement consommer cette valeur.
var _prefetched_remote_answers: Array[bool] = []

func init(_battle) -> void:
	battle = _battle
	# Connexion immédiate (pas d'attente du premier resolve_trigger) : en
	# réseau, la décision du propriétaire (PACT_CHOICE) peut arriver AVANT le
	# premier appel local à resolve_trigger (elle est envoyée avant même la
	# commande d'action qui la déclenchera chez le pair, voir resolve_trigger).
	# Une connexion tardive manquait ce tout premier message — signal perdu,
	# _await_remote_answer() attendait alors indéfiniment une réponse déjà
	# passée, bloquant tout le rejeu du tour adverse (et donc la partie des
	# deux côtés, l'un attendant l'autre). Bug confirmé en partie réelle avec
	# le tout premier Pacte joué dans un match.
	_ensure_net_listener()

func resolve_trigger(card_data: CardData, is_player: bool) -> bool:
	var value: int = card_data.get_demon_keyword_value(KeywordDemon.Type.PACTE)
	if value <= 0:
		return true
	if battle.network_manager != null:
		_ensure_net_listener()
		if is_player:
			if not _prefetched_own_answers.is_empty():
				return _prefetched_own_answers.pop_front()
			# Annonce envoyée AVANT d'ouvrir notre propre popup de choix : le pair
			# affiche alors sa popup d'attente en direct, en même temps que la
			# nôtre, plutôt que de ne rien voir jusqu'au rejeu de PLAY_CARD (voir
			# le commentaire d'en-tête et _handle_remote_announce).
			if is_instance_valid(battle) and battle.network_manager != null:
				battle.network_manager.send_command(NetCommand.pact_announce(card_data.resource_path, value))
			var paid: bool = await ask(card_data, value)
			if is_instance_valid(battle) and battle.network_manager != null:
				battle.network_manager.send_command(NetCommand.pact_choice(paid))
			return paid
		# Réponse déjà obtenue par anticipation (popup d'attente affichée dès
		# l'annonce, voir _handle_remote_announce) : rien à réafficher, ce rejeu
		# ne fait que consommer la valeur déjà connue.
		if not _prefetched_remote_answers.is_empty():
			return _prefetched_remote_answers.pop_front()
		# battle.enemy_turn_active : false uniquement pendant NOTRE résolution
		# EN DIRECT (Battle.set_enemy_turn) — jamais vrai en même temps chez les
		# deux clients, le jeu étant strictement au tour par tour. Si c'est le
		# cas, cette carte du pair est touchée par NOTRE action en cours : il ne
		# sait pas encore qu'il doit décider, il faut le lui demander. Sinon,
		# nous sommes en train de rejouer SON action (NetworkOpponent) : sa
		# décision, prise chez lui avant l'envoi de cette même action, est déjà
		# en route ou déjà arrivée (ou sera captée par _handle_remote_announce
		# avant même ce rejeu, dans le cas courant d'un déclencheur Arrivée).
		if not battle.enemy_turn_active:
			battle.network_manager.send_command(NetCommand.pact_request(card_data.resource_path, value))
		return await _watch_remote_answer(card_data, value)
	if is_player:
		return await ask(card_data, value)
	return heuristic_decision(is_player, value)

# Décision déterministe (IA uniquement désormais — le joueur local a toujours
# la main via `ask()`, en solo comme en réseau).
func heuristic_decision(is_player: bool, value: int) -> bool:
	var hero: Hero = battle.player_hero if is_player else battle.enemy_hero
	return hero.health - value >= SAFE_HEALTH_MARGIN

# ─── Synchronisation réseau ───────────────────────────────────────────────────

func _ensure_net_listener() -> void:
	if battle.network_manager == null or _connected_net == battle.network_manager:
		return
	_connected_net = battle.network_manager
	_connected_net.command_received.connect(_on_net_command_received)

# Appelé par NetSessionSystem.close() : NetworkManager est une instance
# persistante réutilisée par toute la session (voir NetSessionSystem.gd),
# donc sans ce déconnect explicite, ce PactChoiceSystem (lié à une bataille
# désormais terminée) resterait abonné à command_received et continuerait à
# répondre aux PACT_REQUEST/PACT_CHOICE de parties suivantes.
func cleanup() -> void:
	if _connected_net != null and _connected_net.command_received.is_connected(_on_net_command_received):
		_connected_net.command_received.disconnect(_on_net_command_received)
	_connected_net = null

func _on_net_command_received(command: Dictionary) -> void:
	match NetCommand.type_of(command):
		NetCommand.PACT_REQUEST:
			_handle_remote_request(command)
		NetCommand.PACT_CHOICE:
			_remote_answers.append(bool(command.get("paid", false)))
		NetCommand.PACT_ANNOUNCE:
			_handle_remote_announce(command)

# Le pair résout EN DIRECT un déclencheur sur l'UNE DE NOS cartes et attend
# notre décision pour pouvoir continuer sa propre résolution : on répond tout
# de suite (popup affichée même hors de notre tour), sans passer par la file
# d'attente normale du rejeu de tour.
func _handle_remote_request(command: Dictionary) -> void:
	var card: CardData = NetCardResolver.resolve(command.get("card", ""))
	var value: int = int(command.get("value", 0))
	if card == null or value <= 0:
		if is_instance_valid(battle) and battle.network_manager != null:
			battle.network_manager.send_command(NetCommand.pact_choice(false))
		return
	var paid: bool = await ask(card, value)
	_prefetched_own_answers.append(paid)
	if is_instance_valid(battle) and battle.network_manager != null:
		battle.network_manager.send_command(NetCommand.pact_choice(paid))

# Le pair vient de commencer à décider pour SA PROPRE carte tout juste jouée
# (déclencheur Arrivée résolu avant même l'envoi de PLAY_CARD, voir
# resolve_trigger) : on affiche déjà la popup d'attente ICI, en même temps que
# sa propre popup de choix chez lui, plutôt que d'attendre le rejeu de
# PLAY_CARD — qui arrivera une fois sa décision déjà connue (PACT_CHOICE,
# envoyé juste après cette annonce) et ne donnerait alors plus aucune
# impression d'attente réelle. La réponse est mise en cache
# (_prefetched_remote_answers) pour que ce rejeu ultérieur de resolve_trigger
# la consomme directement sans réafficher une seconde popup.
func _handle_remote_announce(command: Dictionary) -> void:
	var card: CardData = NetCardResolver.resolve(command.get("card", ""))
	var value: int = int(command.get("value", 0))
	if card == null or value <= 0:
		return
	var paid: bool = await _watch_remote_answer(card, value)
	_prefetched_remote_answers.append(paid)

# Affiche la carte du Pacte (comme ask()) pendant qu'on attend la décision du
# VRAI propriétaire — sans bouton, juste un texte d'attente — pour que le
# joueur qui n'a pas la main sur la décision voie quand même la carte, le
# Pacte en jeu, et le résultat une fois connu. Avant ce correctif, ce joueur
# ne voyait strictement rien pendant l'attente (aucune popup, aucun indice
# qu'une décision de Pacte était en cours) : l'effet semblait se résoudre
# d'un coup une fois la réponse arrivée. Couvre les deux cas qui attendent une
# réponse (cas courant : rejeu du tour du pair ; cas croisé : notre action en
# direct touche sa carte, PACT_REQUEST déjà envoyé par l'appelant).
func _watch_remote_answer(card_data: CardData, value: int) -> bool:
	await battle.card_popup_system.show_targeting_popup(card_data)
	var card: Card = battle.card_popup_system.get_persistent_card()
	var layer: CanvasLayer = battle.card_popup_system.get_popup_layer()

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1a0e0eee")
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color("c9a227")
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = SettingsManager.t("PACT_WAITING_TEXT") % value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)

	layer.add_child(panel)
	if card != null and is_instance_valid(card):
		panel.custom_minimum_size.x = card.size.x
		await panel.get_tree().process_frame
		panel.position = card.position + Vector2(0.0, card.size.y + 12.0)

	var paid: bool = await _await_remote_answer()

	if is_instance_valid(panel):
		panel.queue_free()
	if is_instance_valid(battle):
		battle.card_popup_system.hide_targeting_popup()
	return paid

func _await_remote_answer() -> bool:
	while _remote_answers.is_empty():
		if not is_instance_valid(battle):
			return false
		await battle.get_tree().process_frame
	return _remote_answers.pop_front()

# Affiche la carte du Pacte via la popup persistante (CardPopupSystem, même
# emplacement que le ciblage), avec un panneau de choix Oui/Non ancré juste
# en dessous — pour que le joueur voie la carte (texte d'effet compris) en
# même temps que le choix qu'elle lui demande.
func ask(card_data: CardData, value: int) -> bool:
	await battle.card_popup_system.show_targeting_popup(card_data)
	var card: Card = battle.card_popup_system.get_persistent_card()
	var layer: CanvasLayer = battle.card_popup_system.get_popup_layer()

	# Bloqueur plein écran (mouse_filter STOP) : sans lui, un clic ailleurs
	# pendant l'attente (bouton Fin du tour, menu Échap...) reste possible et
	# peut mener à une fin de partie/changement de scène pendant que cette
	# popup attend encore le joueur — voir le garde-fou is_instance_valid(battle)
	# plus bas, qui protège contre ce cas mais ne devrait plus se produire une
	# fois l'interaction bloquée. Le panneau Oui/Non est ENFANT du bloqueur
	# (pas un frère) — même patron que FusionSystem._show_keyword_popup — pour
	# qu'il reçoive les clics en priorité sans dépendre de l'ordre des enfants
	# dans le calque.
	var blocker := Control.new()
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(blocker)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1a0e0eee")
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color("c9a227")
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var label := Label.new()
	label.text = SettingsManager.t("PACT_CONFIRM_TEXT") % value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)

	var yes_button := Button.new()
	yes_button.text = SettingsManager.t("PACT_CONFIRM_YES")
	hbox.add_child(yes_button)

	var no_button := Button.new()
	no_button.text = SettingsManager.t("PACT_CONFIRM_NO")
	hbox.add_child(no_button)

	blocker.add_child(panel)
	if card != null and is_instance_valid(card):
		panel.custom_minimum_size.x = card.size.x
		await panel.get_tree().process_frame
		panel.position = card.position + Vector2(0.0, card.size.y + 12.0)

	# ATTENTION : un Dictionary, PAS deux bool locaux. Une lambda GDScript
	# capture les variables locales PAR VALEUR (une copie), pas par référence —
	# `paid = true` / `done = true` dans les callbacks ci-dessous ne mutaient
	# donc RIEN dans la portée de cette fonction : la boucle d'attente plus bas
	# ne voyait jamais `done` passer à `true`, quel que soit le bouton cliqué.
	# C'est le bug "cliquer Oui/Non sur le Pacte ne fait rien" (confirmé par un
	# test isolé : voir la PR). Un Dictionary est un type par référence en
	# GDScript, donc `state["done"] = true` mute bien l'objet partagé — même
	# patron déjà utilisé (et fonctionnel) par FusionSystem._show_keyword_popup.
	var state := {"paid": false, "done": false}
	yes_button.pressed.connect(func() -> void:
		state["paid"] = true
		state["done"] = true
	)
	no_button.pressed.connect(func() -> void:
		state["paid"] = false
		state["done"] = true
	)
	# Garde-fou : si la scène de bataille est détruite pendant l'attente (ex. la
	# partie se termine puis le joueur retourne au menu, ou une reconnexion
	# échoue), `battle` devient une instance libérée — sans ce garde-fou,
	# `battle.get_tree()` plantait (voir le même correctif sur Hand.gd) et le
	# clic Oui/Non ne faisait alors plus rien de visible pour le joueur.
	while not state["done"] and is_instance_valid(battle):
		await battle.get_tree().process_frame
	if is_instance_valid(blocker):
		blocker.queue_free()  # libère aussi panel, qui en est désormais l'enfant
	if is_instance_valid(battle):
		battle.card_popup_system.hide_targeting_popup()
	return state["paid"]
