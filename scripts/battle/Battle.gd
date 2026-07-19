extends Control

const _BoardSystemScript     = preload("res://scripts/systems/BoardSystem.gd")
const _CombatSystemScript    = preload("res://scripts/systems/CombatSystem.gd")
const _CardSystemScript      = preload("res://scripts/systems/CardSystem.gd")
const _TurnSystemScript      = preload("res://scripts/systems/TurnSystem.gd")
const _SelectionSystemScript = preload("res://scripts/systems/SelectionSystem.gd")
const _DropSystemScript      = preload("res://scripts/systems/DropSystem.gd")
const _BoardVisualSystemScript = preload("res://scripts/systems/BoardVisualSystem.gd")
const _DeathSystemScript     = preload("res://scripts/systems/DeathSystem.gd")
const _DeckSystemScript      = preload("res://scripts/systems/DeckSystem.gd")
const _GraveyardSystemScript = preload("res://scripts/systems/GraveyardSystem.gd")
const _AnimationSystemScript = preload("res://scripts/systems/AnimationSystem.gd")
const _HeroSystemScript      = preload("res://scripts/systems/HeroSystem.gd")
const _TargetingSystemScript = preload("res://scripts/systems/TargetingSystem.gd")
const _AISystemScript        = preload("res://scripts/systems/AISystem.gd")

const BOARD_MINION_SCENE = preload("res://scenes/minion/BoardMinion.tscn")
const CARD_BACK          = preload("res://assets/card_back/card-back.png")
const MAIN_MENU_SCENE    := "res://scenes/mainMenu/MainMenu.tscn"
const MAX_STACK_VISUAL   := 8
const ROW_FRONT          := "Front"
const ROW_BACK           := "Back"
const MAX_MINIONS_PER_ROW := 10
const BOARD_MINION_SIZE  := Vector2(100, 150)
const DROP_HIGHLIGHT_COLOR        := Color(1.0, 0.45, 0.05, 0.28)
const DROP_HIGHLIGHT_BORDER_COLOR := Color(1.0, 0.58, 0.12, 0.9)
const ACTION_PACE                 := 1.0
const ATTACK_PACE                 := 0.5
# Pose visuelle des cartes-ressource dans leur zone dédiée (bande de droite) :
# désactivée pour l'instant (feature repoussée). Le système est conservé tel
# quel (EnchantmentSystem.add_resource, zones Player/EnemyResourceZone) pour
# être réactivé plus tard ; en attendant, une carte-ressource jouée disparaît
# simplement de la partie (voir play_resource_card) au lieu d'être posée.
const RESOURCE_ZONE_ENABLED       := false
const MULLIGAN_DURATION           := 30.0

# Godot affichera une erreur claire si le noeud est absent, plutôt qu'un null silencieux
@onready var hand: Hand                                = $Hand
@onready var mana_display: ManaDisplay                 = $ManaDisplay
@onready var enemy_mana_display: ManaDisplay           = $EnemyManaDisplay
@onready var end_turn_button: EndTurnButton            = $EndTurnButton
@onready var player_front_container: Control           = $Board/PlayerFrontLine
@onready var player_back_container: Control            = $Board/PlayerBackLine
@onready var enemy_front_container: Control            = $Board/EnemyFrontLine
@onready var enemy_back_container: Control             = $Board/EnemyBackLine
@onready var player_enchantment_zone: HBoxContainer    = $Board/PlayerEnchantmentZone
@onready var enemy_enchantment_zone: HBoxContainer     = $Board/EnemyEnchantmentZone
@onready var player_ritual_zone: HBoxContainer         = $Board/PlayerRitualZone
@onready var enemy_ritual_zone: HBoxContainer          = $Board/EnemyRitualZone
@onready var player_resource_zone: HBoxContainer       = $Board/PlayerResourceZone
@onready var enemy_resource_zone: HBoxContainer        = $Board/EnemyResourceZone
@onready var player_graveyard_btn: Button              = $PlayerGraveyardButton
@onready var enemy_graveyard_btn: Button               = $EnemyGraveyardButton
@onready var player_graveyard_preview: Card            = $PlayerGraveyardButton/CardPreview
@onready var enemy_graveyard_preview: Card             = $EnemyGraveyardButton/CardPreview
@onready var graveyard_view: GraveyardView             = $GraveyardView
@onready var deck_button                               = $DeckButton
@onready var deck_count_label                          = $DeckButton/CountLabel
@onready var enemy_deck_button: Button                 = $EnemyDeckButton
@onready var enemy_deck_count_label: Label             = $EnemyDeckButton/CountLabel
@onready var enemy_hand_display: EnemyHandDisplay      = $EnemyHandDisplay
@onready var settings_menu: Control                    = $SettingsMenu
@onready var settings_button: Button                   = $SettingsButton
@onready var game_over_screen: GameOverScreen          = $GameOverScreen

var combat_system       := _CombatSystemScript.new()
var board_system        := _BoardSystemScript.new()
var card_system         := _CardSystemScript.new()
var turn_system         := _TurnSystemScript.new()
var selection_system    := _SelectionSystemScript.new()
var drop_system         := _DropSystemScript.new()
var board_visual_system := _BoardVisualSystemScript.new()
var death_system        := _DeathSystemScript.new()
var deck_system         := _DeckSystemScript.new()
var graveyard_system    := _GraveyardSystemScript.new()
var animation_system    := _AnimationSystemScript.new()
var hero_system         := _HeroSystemScript.new()
var targeting_system    := _TargetingSystemScript.new()
var ai_system           := _AISystemScript.new()
# Pilote du camp adverse (IA en solo, joueur distant en réseau). Pointe sur
# ai_system par défaut ; sera réassigné en mode multijoueur.
var opponent: OpponentDriver
var net_registry := NetRegistry.new()
# Émetteur des actions du joueur local vers le pair distant. null en solo :
# aucun point d'appel n'émet alors quoi que ce soit.
var net_emitter: NetEmitter = null
# En mode réseau : true si c'est le joueur local qui commence la partie.
var net_local_first: bool = true
# Référence au transport réseau, pour le fermer proprement en quittant le match.
var network_manager: NetworkManager = null
var enchantment_system  = load("res://scripts/systems/EnchantmentSystem.gd").new()
var card_popup_system: CardPopupSystem
var trigger_system: TriggerSystem
var aura_system := AuraSystem.new()
var temp_effect_system := TempEffectSystem.new()
var cost_system := CostSystem.new()
var sacrifice_system := SacrificeSystem.new()
var combat_log := CombatLogSystem.new()
# Bannière de transition de tour (« À vous de jouer » / « Tour adverse »),
# créée en code pour ne pas toucher Battle.tscn.
var turn_banner: TurnBanner
# Journal de combat repliable, créé en code pour ne pas toucher Battle.tscn
# (voir CombatLogPanel).
var combat_log_panel: CombatLogPanel
# Décompte du temps de tour du joueur local, créé en code (voir TurnTimer).
var turn_timer: TurnTimer
# Voile de pause affiché lors d'une coupure réseau transitoire, créé en code
# (voir ReconnectOverlay). Reste inutilisé/masqué en solo.
var reconnect_overlay: ReconnectOverlay

var effect_manager := EffectManager.new()
# Tutoriel obligatoire du nouveau joueur (voir TutorialContext/TutorialManager) :
# adversaire scripté, deck fixe, popups pédagogiques. tutorial_manager reste
# nul en partie normale — tous les points d'accroche le vérifient avant
# d'appeler quoi que ce soit.
var tutorial_active: bool = false
var tutorial_manager: TutorialManager = null
# RNG dédié à l'aléatoire de JEU (cibles/invocations aléatoires). En réseau il est
# seedé par le handshake pour que les deux clients tirent la même séquence ;
# en solo il est simplement aléatoire.
var game_rng := RandomNumberGenerator.new()
var player_minions: Array[Minion] = []
var enemy_minions: Array[Minion]  = []
var player_graveyard: Graveyard   = Graveyard.new()
var enemy_graveyard: Graveyard    = Graveyard.new()

var pending_card: CardData       = null
var pending_row: String          = ROW_FRONT
var pending_insert_index: int    = -1
var waiting_for_target: bool     = false
var deck: Array[CardData]        = []
var hand_cards: Array[CardData]  = []
# Pools de ressource par race (clé = Race.Type). Alimentés uniquement en jouant
# une carte-ressource (Âme/Sceau/Pacte...) dans sa zone dédiée — voir
# `play_resource_card` et README « Système de Ressources par Race ».
var race_mana: Dictionary        = {}
var race_max_mana: Dictionary    = {}
# Une seule carte-ressource jouable par tour et par camp (comme un "land drop").
var resource_played_this_turn: Dictionary = {true: false, false: false}
var player_hero: Hero
var enemy_hero: Hero
var game_over: bool              = false
var enemy_turn_active: bool      = false
# Coupure réseau transitoire en cours (voir NetworkManager.connection_lost) :
# le match est mis en pause, les inputs sont bloqués, en attendant une
# reconnexion ou l'expiration du délai de grâce.
var reconnecting: bool           = false
var _is_dragging_card: bool      = false
# Contre-Offensive active ce tour, par camp (clé = owner_is_player) : chaque
# Humain de ce camp qui tue un ennemi gagne une attaque supplémentaire.
var counter_offensive: Dictionary = {true: false, false: false}
# Phase de mulligan en cours (avant le tour 1) : le bouton Fin du tour devient
# "Commencer" et un clic sur une carte de la main la remplace au lieu de la jouer.
var _mulligan_active: bool = false
signal mulligan_confirmed
# Nombre maximum d'échanges pendant le mulligan, et suivi des index déjà
# échangés (une carte reçue en remplacement ne peut pas être re-mulligan).
const MULLIGAN_MAX_SWAPS := 2
var _mulligan_swap_count: int = 0
var _mulligan_swapped_indices: Array[int] = []

# ─── Setup ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	AudioManager.play_battle_music()
	_init_data()
	_init_systems()
	_connect_signals()
	_start_game()

func _init_data() -> void:
	tutorial_active = TutorialContext.active
	player_hero = Hero.new(30)
	# HP réduits en tutoriel : l'adversaire scripté ne joue que 2 serviteurs et
	# n'attaque jamais, la victoire doit rester atteignable en quelques tours.
	enemy_hero  = Hero.new(8 if tutorial_active else 30)
	game_rng.randomize()  # solo : aléatoire ; écrasé par le seed réseau si besoin

func _init_systems() -> void:
	hand.can_play_check      = can_play_card
	hand.create_drag_preview = _create_card_drag_preview
	trigger_system = TriggerSystem.new()
	trigger_system.init(self)
	deck_system.init(self)
	graveyard_system.init(self)
	animation_system.init(self)
	hero_system.init(self)
	combat_system.init(self)
	board_system.init(self)
	card_system.init(self)
	turn_system.init(self)
	selection_system.init(self)
	drop_system.init(self)
	board_visual_system.init(self)
	death_system.init(self)
	targeting_system.init(self)
	ai_system.init(self)
	opponent = ai_system
	if tutorial_active:
		var tut_opponent := TutorialOpponent.new()
		add_child(tut_opponent)
		tut_opponent.init(self)
		opponent = tut_opponent
		tutorial_manager = TutorialManager.new()
		add_child(tutorial_manager)
		tutorial_manager.init(self)
	elif NetContext.active:
		_setup_network()
	enchantment_system.init(self)
	card_popup_system = CardPopupSystem.new()
	card_popup_system.init(self)
	aura_system.init(self)
	temp_effect_system.init(self)
	cost_system.init(self)
	sacrifice_system.init(self)
	turn_banner = TurnBanner.new()
	add_child(turn_banner)
	combat_log.init(self)
	combat_log_panel = CombatLogPanel.new()
	combat_log_panel.init(self, combat_log)
	add_child(combat_log_panel)
	reconnect_overlay = ReconnectOverlay.new()
	add_child(reconnect_overlay)
	turn_timer = TurnTimer.new()
	turn_timer.timeout.connect(_on_turn_timer_timeout)
	# Enfant du bouton lui-même (comme le halo "ready hint" de EndTurnButton) :
	# sa bordure suit le bouton sans logique de positionnement séparée.
	end_turn_button.add_child(turn_timer)
	add_child(enchantment_system)
	add_child(trigger_system)
	add_child(targeting_system)
	add_child(sacrifice_system)
	hand.display_cost = get_card_cost

# Bascule la bataille en mode réseau : l'adversaire devient un joueur distant
# (NetworkOpponent), les actions locales sont émises (NetEmitter), et le
# NetRegistry / la graine RNG sont alignés sur le handshake.
func _setup_network() -> void:
	var net: NetworkManager = NetContext.net
	var setup: Dictionary = NetContext.setup
	network_manager = net
	# RNG de jeu déterministe et partagé entre les deux clients.
	game_rng.seed = setup.get("seed", 0)
	net_registry.configure(setup.get("parity_start", 1), setup.get("parity_stride", 1))
	net_local_first = setup.get("local_first", true)
	net_emitter = NetEmitter.new(net)
	net.connection_lost.connect(_on_net_connection_lost)
	net.connection_restored.connect(_on_net_connection_restored)
	net.peer_disconnected.connect(_on_net_peer_disconnected)
	var netopp := NetworkOpponent.new(net)
	add_child(netopp)
	netopp.init(self)
	opponent = netopp

# Coupure réseau transitoire détectée (Wifi, P2P Steam) : on met le match en
# pause (fige le décompte de tour et bloque les inputs) sans l'arrêter — une
# reconnexion est tentée en arrière-plan par NetworkManager pendant son délai
# de grâce. Si elle échoue, _on_net_peer_disconnected prend le relais.
func _on_net_connection_lost(_reason: String) -> void:
	if game_over:
		return
	reconnecting = true
	turn_timer.stop()
	reconnect_overlay.show_overlay(NetworkManager.RECONNECT_GRACE_SECONDS)

# Reconnexion réussie dans le délai de grâce : le match reprend là où il en était.
func _on_net_connection_restored() -> void:
	if game_over:
		return
	reconnecting = false
	reconnect_overlay.hide_overlay()
	if not enemy_turn_active and not _mulligan_active:
		turn_timer.start()

# Pair définitivement perdu (délai de grâce de reconnexion expiré, ou coupure
# non transitoire) : on stoppe le match et on affiche l'écran de fin en mode
# déconnexion (retour au menu uniquement, rejouer n'a pas de sens sans le pair).
func _on_net_peer_disconnected(_reason: String) -> void:
	if game_over:
		return
	game_over = true
	reconnecting = false
	reconnect_overlay.hide_overlay()
	enemy_turn_active = false
	turn_timer.stop()
	_show_game_over("disconnect")

func _connect_signals() -> void:
	hand.card_played.connect(_on_card_played)
	hand.drag_started.connect(_on_hand_drag_started)
	hand.drag_ended.connect(_on_hand_drag_ended)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	SettingsManager.language_changed.connect(func(_l): _retranslate_battle())
	_retranslate_battle()
	$EnemyHeroPanel.hero_clicked.connect(selection_system.on_enemy_hero_clicked)
	$EnemyHeroPanel.hero_clicked.connect(targeting_system.on_enemy_hero_clicked)
	targeting_system.targeting_cancelled.connect(_on_targeting_cancelled)
	settings_button.pressed.connect(settings_menu.open)
	settings_menu.concede_requested.connect(_on_quit_match)
	game_over_screen.menu_requested.connect(_on_quit_match)
	game_over_screen.replay_requested.connect(_on_replay_match)
	# Cliquer sur un deck n'a pas d'action : pas de son de clic
	deck_button.set_meta("no_click_sound", true)
	enemy_deck_button.set_meta("no_click_sound", true)

func _start_game() -> void:
	update_mana_ui()
	hero_system.update_ui()
	if tutorial_active:
		deck.clear()
		deck.append_array(TutorialDeck.player_deck_padding())
	else:
		deck_system.load_deck()
	deck_system.update_deck_ui()
	board_visual_system.refresh_board()
	update_hero_turn_halo()
	for minion in player_minions:
		board_visual_system.spawn_minion_visual(minion, true)
	for minion in enemy_minions:
		board_visual_system.spawn_minion_visual(minion, false)
	if tutorial_active or NetContext.active:
		opponent.setup()
	else:
		ai_system.setup()
	if tutorial_active:
		hand_cards = TutorialDeck.player_hand()
	else:
		deck_system.deal_opening_hand()
	hand.set_hand(hand_cards, false)
	if not tutorial_active:
		await _run_mulligan()
	if NetContext.active:
		var local_first: bool = net_local_first
		NetContext.clear()
		# Si le joueur distant commence, on lui passe la main avant notre 1er tour.
		if not local_first:
			await _run_remote_first_turn()
			return
	# Le joueur local ouvre la partie : annonce de son premier tour (sauf en
	# tutoriel, où les popups pédagogiques s'en chargent déjà).
	if not tutorial_active:
		turn_banner.show_banner(SettingsManager.t("battle.turn_player"))
	update_end_turn_hint()
	if tutorial_active:
		# Pas de pression du temps pendant le tutoriel obligatoire.
		TutorialContext.clear()
		tutorial_manager.start()
	else:
		turn_timer.start()

# Phase de mulligan précédant le tour 1 : la main de départ est déjà affichée
# normalement ; cliquer une carte la remplace directement (voir Hand.flip_replace).
# Le bouton Fin du tour devient "Commencer" et confirme la fin du mulligan.
# En réseau, chaque camp mulligan indépendamment (le contenu reste privé) ; on
# attend juste que le pair ait fini avant de lancer le tour 1.
func _run_mulligan() -> void:
	_mulligan_active = true
	_mulligan_swap_count = 0
	_mulligan_swapped_indices.clear()
	hand.set_mulligan_mode(true)
	hand.mulligan_card_clicked.connect(_on_mulligan_card_clicked)
	turn_banner.show_banner(SettingsManager.t("mulligan.banner"))
	_retranslate_battle()
	end_turn_button.disabled = false
	end_turn_button.set_ready_hint(true)
	turn_timer.start(MULLIGAN_DURATION)
	await mulligan_confirmed
	turn_timer.stop()
	end_turn_button.disabled = true
	end_turn_button.set_ready_hint(false)
	hand.mulligan_card_clicked.disconnect(_on_mulligan_card_clicked)
	hand.set_mulligan_mode(false)
	_mulligan_active = false
	if net_emitter != null:
		net_emitter.mulligan_done()
	await opponent.await_mulligan()
	end_turn_button.disabled = false
	_retranslate_battle()
	update_end_turn_hint()

func _on_mulligan_card_clicked(index: int, _card_data: CardData) -> void:
	if index in _mulligan_swapped_indices or _mulligan_swap_count >= MULLIGAN_MAX_SWAPS:
		return
	var new_data: CardData = deck_system.mulligan_replace_one(index)
	if new_data == null:
		return
	_mulligan_swap_count += 1
	_mulligan_swapped_indices.append(index)
	AudioManager.play(AudioManager.DRAW)
	hand.flip_replace_at(index, new_data)
	hand.set_card_mulligan_swapped(index, true)

# Attend et rejoue le tour d'ouverture du joueur distant, puis démarre le nôtre.
func _run_remote_first_turn() -> void:
	opponent.take_turn()
	if game_over:
		return
	await turn_system._begin_player_turn()

# ─── Process ──────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if targeting_system.is_targeting():
		targeting_system.update_arrow()

# ─── Input ────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if sacrifice_system.is_active():
		if event is InputEventMouseButton \
				and event.button_index == MOUSE_BUTTON_RIGHT \
				and event.pressed:
			sacrifice_system.cancel()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_cancel"):
			sacrifice_system.cancel()
			get_viewport().set_input_as_handled()
			return

	if targeting_system.is_targeting() and not targeting_system.is_trigger_targeting():
		if event is InputEventMouseButton \
				and event.button_index == MOUSE_BUTTON_RIGHT \
				and event.pressed:
			targeting_system.cancel()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_cancel"):
			targeting_system.cancel()
			get_viewport().set_input_as_handled()
			return

	# Raccourcis clavier (fin de tour, cimetières, Échap)
	if _handle_shortcut(event):
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed \
			and not Input.is_key_pressed(KEY_CTRL):
		if selection_system.is_multi_selecting:
			selection_system.clear_multi_selection()

# ─── Raccourcis clavier ───────────────────────────────────────────────────────

# Traite un raccourci clavier. Retourne true si l'événement a été consommé.
func _handle_shortcut(event: InputEvent) -> bool:
	# Échap "intelligent" : annule/ferme le contexte prioritaire ouvert
	if event.is_action_pressed("ui_cancel"):
		return _handle_cancel()

	# Fin de tour
	if event.is_action_pressed("end_turn"):
		_on_end_turn_pressed()
		return true

	if event.is_action_pressed("toggle_graveyard"):
		_toggle_graveyard(player_graveyard)
		return true
	if event.is_action_pressed("toggle_enemy_graveyard"):
		_toggle_graveyard(enemy_graveyard)
		return true

	return false

# Échap : ferme un overlay ouvert par ordre de priorité, sinon ouvre les réglages.
func _handle_cancel() -> bool:
	# L'écran de fin ne se ferme pas : le joueur doit choisir Rejouer ou Menu.
	if game_over_screen.visible:
		return true
	if graveyard_view.visible:
		graveyard_view.close()
		return true
	if settings_menu.visible:
		settings_menu.close()
		return true
	settings_menu.open()
	return true

# Quitte la partie en cours et revient au menu principal.
func _on_quit_match() -> void:
	settings_menu.close()
	# En réseau : ferme la connexion et libère le transport reparenté sous la racine.
	if network_manager != null:
		# Départ délibéré : prévient le pair pour qu'il ne poursuive pas
		# inutilement le délai de grâce de reconnexion (voir NetCommand.leave_match).
		network_manager.send_command(NetCommand.leave_match())
		network_manager.close()
		network_manager.queue_free()
		network_manager = null
	NetContext.clear()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

# Relance une bataille depuis l'écran de fin (solo uniquement : le bouton
# Rejouer est masqué en réseau, mais on nettoie le transport par sécurité).
func _on_replay_match() -> void:
	if network_manager != null:
		network_manager.send_command(NetCommand.leave_match())
		network_manager.close()
		network_manager.queue_free()
		network_manager = null
	NetContext.clear()
	get_tree().reload_current_scene()

# Ouvre le cimetière demandé, ou le referme s'il est déjà visible.
func _toggle_graveyard(target_graveyard: Graveyard) -> void:
	if graveyard_view.visible:
		graveyard_view.close()
	else:
		graveyard_view.open(target_graveyard)

# ─── Trigger centralisé ───────────────────────────────────────────────────────

func trigger_effects(minion: Minion, trigger_name: String) -> void:
	effect_manager.trigger_effects(self, minion, trigger_name)

# Pause commune entre deux actions visibles (effets déclenchés, enchantements,
# infections, actions de l'IA) pour laisser le temps de lire ce qui se passe.
# À insérer uniquement ENTRE deux actions : jamais avant la première ni après
# la dernière — une action isolée ne doit subir aucun délai
func pace_actions(delay: float = ACTION_PACE) -> void:
	if game_over:
		return
	await get_tree().create_timer(delay).timeout

# ─── Mana ─────────────────────────────────────────────────────────────────────
# Un pool par race (voir README « Système de Ressources par Race ») : plus de
# mana générique unique. `race_mana`/`race_max_mana` appartiennent au joueur ;
# `opponent.race_mana`/`opponent.race_max_mana` au camp adverse (IA ou réseau).

func race_mana_pool(is_player: bool) -> Dictionary:
	return race_mana if is_player else opponent.race_mana

func race_max_mana_pool(is_player: bool) -> Dictionary:
	return race_max_mana if is_player else opponent.race_max_mana

func total_mana(is_player: bool = true) -> int:
	var total := 0
	for v in race_mana_pool(is_player).values():
		total += int(v)
	return total

func total_max_mana(is_player: bool = true) -> int:
	var total := 0
	for v in race_max_mana_pool(is_player).values():
		total += int(v)
	return total

# Recharge le pool courant de chaque race à son maximum (début de tour) et
# efface tout mana temporaire hors-race (GainMana) : "le surplus non dépensé
# est perdu au tour suivant" (Vortex des Âmes).
func refill_mana_pool(is_player: bool = true) -> void:
	var pool: Dictionary = race_mana_pool(is_player)
	var max_pool: Dictionary = race_max_mana_pool(is_player)
	pool.clear()
	for r in max_pool:
		pool[r] = max_pool[r]

func update_mana_ui() -> void:
	mana_display.set_mana_pools(race_mana_pool(true), race_max_mana_pool(true))
	update_end_turn_hint()
	if hand != null:
		hand.refresh_playable_highlights()

func update_enemy_mana_ui() -> void:
	enemy_mana_display.set_mana_pools(race_mana_pool(false), race_max_mana_pool(false))

func update_enemy_hand_ui() -> void:
	enemy_hand_display.set_count(opponent.get_hand_count())

# Une carte-ressource jouée est consommée : +1 (actuel et max) au pool de sa
# race, action à part qui ne consomme pas le droit de jouer une carte normale
# mais limitée à une par tour et par camp. La carte est ensuite simplement
# retirée de la partie (déjà sortie de la main par l'appelant) : aucune zone
# ne la garde, elle n'est donc récupérable par aucun effet. La pose visuelle
# en zone dédiée (EnchantmentSystem.add_resource) est conservée mais
# désactivée pour l'instant — voir RESOURCE_ZONE_ENABLED.
func play_resource_card(card_data: CardData, is_player: bool = true) -> void:
	if resource_played_this_turn.get(is_player, false):
		return
	resource_played_this_turn[is_player] = true
	var pool: Dictionary = race_mana_pool(is_player)
	var max_pool: Dictionary = race_max_mana_pool(is_player)
	max_pool[card_data.race] = int(max_pool.get(card_data.race, 0)) + 1
	pool[card_data.race]     = int(pool.get(card_data.race, 0)) + 1
	if RESOURCE_ZONE_ENABLED:
		enchantment_system.add_resource(card_data, is_player)
	combat_log.card_played(card_data, is_player)
	if is_player:
		update_mana_ui()
		mana_display.pulse_max()
	else:
		update_enemy_mana_ui()
		enemy_mana_display.pulse_max()

# ─── Serviteurs ───────────────────────────────────────────────────────────────

func get_owner_minions(minion: Minion) -> Array[Minion]:
	if minion == null:
		return player_minions
	return player_minions if minion.owner_is_player else enemy_minions

func get_enemy_minions(minion: Minion) -> Array[Minion]:
	if minion == null:
		return enemy_minions
	return enemy_minions if minion.owner_is_player else player_minions

func get_row_minions(is_player: bool, row: String) -> Array[Minion]:
	var source: Array[Minion] = player_minions if is_player else enemy_minions
	return source.filter(func(m: Minion): return m.board_row == row)

func get_front_minions(is_player: bool) -> Array[Minion]:
	return get_row_minions(is_player, ROW_FRONT)

func get_back_minions(is_player: bool) -> Array[Minion]:
	return get_row_minions(is_player, ROW_BACK)

func can_summon_to_row(is_player: bool, row: String) -> bool:
	return get_row_minions(is_player, row).size() < MAX_MINIONS_PER_ROW

func _normalized_row(row: String) -> String:
	return ROW_BACK if row == ROW_BACK else ROW_FRONT

# La logique d'insertion vit désormais dans BoardSystem._insert()

func get_allowed_rows_for_card(card_data: CardData) -> Array[String]:
	if card_data == null or card_data.card_type != "Minion":
		return [ROW_FRONT, ROW_BACK]
	match card_data.board_position:
		ROW_FRONT: return [ROW_FRONT]
		ROW_BACK:  return [ROW_BACK]
		_:         return [ROW_FRONT, ROW_BACK]

func can_play_card_on_row(card_data: CardData, row: String) -> bool:
	return row in get_allowed_rows_for_card(card_data)

func has_enemy_taunt(attacker: Minion) -> bool:
	var attackable: Array[Minion] = get_attackable_enemy_minions(attacker)
	for minion in attackable:
		if minion.has_keyword(Keyword.Type.TAUNT):
			return true
	return false

func get_attackable_enemy_minions(attacker: Minion) -> Array[Minion]:
	if attacker and attacker.has_keyword(Keyword.Type.BLACK_WINGS):
		return enemy_minions
	var front: Array[Minion] = get_front_minions(false)
	if not front.is_empty():
		return front
	return enemy_minions

func destroy_minion(target: Minion) -> void:
	await death_system.destroy(target)

# ─── Carte jouée ──────────────────────────────────────────────────────────────

func _on_card_played(card_data: CardData, row: String = ROW_FRONT, insert_index: int = -1) -> void:
	if game_over or reconnecting or enemy_turn_active or not can_afford_card(card_data):
		return
	# Pas de jeu de carte pendant le choix d'une victime de Sacrifice
	if sacrifice_system.is_active():
		return
	row = _normalized_row(row)
	await card_system.handle_card_played(card_data, row, insert_index)

func summon_minion(card_data: CardData, is_player: bool, row := "Front", insert_index := -1, skip_onplay := false) -> void:
	await board_system.summon_minion(card_data, is_player, row, insert_index, skip_onplay)

func _on_targeting_cancelled() -> void:
	waiting_for_target   = false
	pending_card         = null
	pending_row          = ROW_FRONT
	pending_insert_index = -1
	hand.set_hand(hand_cards)

func reset_targeting_state() -> void:
	waiting_for_target   = false
	pending_card         = null
	pending_row          = ROW_FRONT
	pending_insert_index = -1
# ─── Tours ────────────────────────────────────────────────────────────────────

func _on_end_turn_pressed() -> void:
	if game_over or reconnecting or enemy_turn_active:
		return
	if _mulligan_active:
		mulligan_confirmed.emit()
		return
	if tutorial_manager:
		await tutorial_manager.notify_end_turn_pressed()
	turn_system.end_turn()

# Expiration du décompte : pendant le mulligan, garde la main actuelle telle
# quelle (comme un clic sur "Commencer"). En tour normal, termine le tour
# comme un clic normal sur Fin du tour.
func _on_turn_timer_timeout() -> void:
	if game_over or reconnecting:
		return
	if _mulligan_active:
		mulligan_confirmed.emit()
		return
	if enemy_turn_active:
		return
	turn_system.end_turn()

# Bascule l'UI entre tour local et tour adverse : flag d'inputs, état du bouton
# Fin de tour et bannière de transition. Appelé par AISystem / NetworkOpponent.
func set_enemy_turn(active: bool) -> void:
	enemy_turn_active = active
	end_turn_button.disabled = active
	_retranslate_battle()
	update_hero_turn_halo()
	if hand != null:
		hand.refresh_playable_highlights()
	if active:
		turn_timer.stop()
	if game_over:
		# Partie terminée pendant le tour adverse : pas d'annonce de tour
		end_turn_button.set_ready_hint(false)
		return
	# En tutoriel, les popups pédagogiques narrent déjà les transitions de
	# tour : la bannière ferait doublon et se superposerait à la popup.
	if active:
		end_turn_button.set_ready_hint(false)
		if not tutorial_active:
			turn_banner.show_banner(SettingsManager.t("battle.turn_enemy"))
	else:
		if not tutorial_active:
			turn_banner.show_banner(SettingsManager.t("battle.turn_player"))
		update_end_turn_hint()

# Couleur/largeur de bordure du halo doré par défaut sur les panneaux héros
# (voir StyleBoxFlat_vbfmk / StyleBoxFlat_nyp61 dans Battle.tscn).
const _HERO_BORDER_COLOR := Color(0.72, 0.55, 0.26, 1.0)
const _HERO_BORDER_WIDTH := 3
const _HERO_SHADOW_COLOR := Color(0.72, 0.55, 0.26, 0.2)
const _HERO_SHADOW_SIZE := 8
# Halo jaune signalant le joueur (humain ou IA) dont c'est le tour.
const _HERO_TURN_BORDER_COLOR := Color(1.0, 0.85, 0.15, 1.0)
const _HERO_TURN_BORDER_WIDTH := 5
const _HERO_TURN_SHADOW_COLOR := Color(1.0, 0.85, 0.15, 0.85)
const _HERO_TURN_SHADOW_SIZE := 20

# Met à jour le halo doré des panneaux héros pour refléter qui est en train
# de jouer : le camp actif reçoit une bordure/lueur jaune, l'autre repasse
# au style doré discret par défaut.
func update_hero_turn_halo() -> void:
	_apply_hero_turn_style($PlayerHeroPanel, not enemy_turn_active)
	_apply_hero_turn_style($EnemyHeroPanel, enemy_turn_active)

func _apply_hero_turn_style(panel: Panel, active: bool) -> void:
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
	if style == null:
		return
	var border_color := _HERO_TURN_BORDER_COLOR if active else _HERO_BORDER_COLOR
	var border_width := _HERO_TURN_BORDER_WIDTH if active else _HERO_BORDER_WIDTH
	var shadow_color := _HERO_TURN_SHADOW_COLOR if active else _HERO_SHADOW_COLOR
	var shadow_size := _HERO_TURN_SHADOW_SIZE if active else _HERO_SHADOW_SIZE
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.shadow_color = shadow_color
	style.shadow_size = shadow_size

# Halo sur « Fin du tour » quand il ne reste plus aucune action possible.
func update_end_turn_hint() -> void:
	end_turn_button.set_ready_hint(_player_has_no_actions())

func _player_has_no_actions() -> bool:
	if game_over or reconnecting or enemy_turn_active:
		return false
	for card in hand_cards:
		if can_play_card(card):
			return false
	for minion in player_minions:
		if minion.can_attack():
			return false
	return true

# Met à jour les libellés fixes de la bataille dans la langue courante.
func _retranslate_battle() -> void:
	if _mulligan_active:
		end_turn_button.text = SettingsManager.t("mulligan.start_button")
		return
	var key := "battle.enemy_turn" if enemy_turn_active else "battle.end_turn"
	end_turn_button.text = SettingsManager.t(key)

# ─── Cimetière ────────────────────────────────────────────────────────────────

# ─── Règles d'attaque ─────────────────────────────────────────────────────────

func _can_attack_minion_target(attacker: Minion, target: Minion) -> bool:
	if target not in get_attackable_enemy_minions(attacker):
		return false
	if has_enemy_taunt(attacker) and not target.has_keyword(Keyword.Type.TAUNT):
		return false
	return true

func _can_attack_hero(attacker: Minion) -> bool:
	if attacker.card_data != null and attacker.card_data.cannot_attack_hero:
		return false
	if has_enemy_taunt(attacker):
		return false
	return attacker.has_keyword(Keyword.Type.BLACK_WINGS) or get_front_minions(false).is_empty()

# ─── Fin de partie ────────────────────────────────────────────────────────────

func check_game_end() -> void:
	if game_over:
		return
	if enemy_hero.is_dead() or player_hero.is_dead():
		game_over = true
		turn_timer.stop()
		_show_game_over("defeat" if player_hero.is_dead() else "victory")

# Laisse les dernières animations (mort, dégâts) se terminer avant d'afficher
# l'écran de fin par-dessus le plateau. Rejouer n'est proposé qu'en solo.
func _show_game_over(result: String) -> void:
	await get_tree().create_timer(1.0).timeout
	if tutorial_active and result == "victory":
		await tutorial_manager.notify_victory()
		return
	game_over_screen.show_result(result, network_manager == null)

# ─── Drag ─────────────────────────────────────────────────────────────────────

func _on_hand_drag_started() -> void:
	_is_dragging_card = true
	hand.set_compact(true)

func _on_hand_drag_ended() -> void:
	_is_dragging_card = false
	hand.set_compact(false)

# Répartition race/générique du coût effectif d'une carte de la main du joueur
# (remises comprises) : {"race": int, "generic": int}. Voir CostSystem pour le
# détail du calcul (Système de Ressources par Race).
func get_card_cost(card_data: CardData) -> Dictionary:
	var total: int = cost_system.get_cost(card_data, true)
	var race_cost: int = cost_system.get_race_cost(card_data, true)
	return {"race": race_cost, "generic": total - race_cost}

func can_afford_card(card_data: CardData) -> bool:
	if card_data == null:
		return false
	if card_data.card_type == "Resource":
		return not resource_played_this_turn.get(true, false)
	return cost_system.can_afford(card_data, true)

# Jouabilité complète : mana + conditions du sort (cibles valides, cimetière...)
func can_play_card(card_data: CardData) -> bool:
	return can_afford_card(card_data) and card_system.conditions_met(card_data)

func _create_card_drag_preview(card_data: CardData) -> Control:
	var preview: BoardMinion = BOARD_MINION_SCENE.instantiate() as BoardMinion
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.z_index = 200
	add_child(preview)
	preview.set_minion(Minion.new(card_data, true, ROW_FRONT))
	# Attaque/Santé n'ont de sens que pour un serviteur — masquées pour les sorts
	if card_data.card_type != "Minion":
		preview.attack_label.visible = false
		preview.health_label.visible = false
	preview.scale    = Vector2.ONE
	preview.modulate = Color(1, 1, 1, 0.85)
	return preview

func is_dragging_card() -> bool:
	return _is_dragging_card
