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
@onready var mulligan_dim_overlay: ColorRect           = $MulliganDimOverlay
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
@onready var help_button: Button                       = $HelpButton
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
var net_session_system  := NetSessionSystem.new()
var input_system        := InputSystem.new()
# Pilote du camp adverse (IA en solo, joueur distant en réseau). Pointe sur
# ai_system par défaut ; sera réassigné en mode multijoueur.
var opponent: OpponentDriver
var net_registry := NetRegistry.new()
# Émetteur des actions du joueur local vers le pair distant. null en solo :
# aucun point d'appel n'émet alors quoi que ce soit.
var net_emitter: NetEmitter = null
# En mode réseau : true si c'est le joueur local qui commence la partie.
var net_local_first: bool = true
# En mode réseau : id backend de l'adversaire et identifiant de match partagé,
# utilisés pour rapporter le résultat au backend (voir _show_game_over). 0/""
# si l'un des deux camps n'était pas authentifié au moment du handshake.
var net_opponent_backend_id: int = 0
var net_client_match_id: String = ""
# Référence au transport réseau, pour le fermer proprement en quittant le match.
var network_manager: NetworkManager = null
var enchantment_system  = load("res://scripts/systems/EnchantmentSystem.gd").new()
var card_popup_system: CardPopupSystem
var pact_choice_system: PactChoiceSystem
var trigger_system: TriggerSystem
var aura_system := AuraSystem.new()
var temp_effect_system := TempEffectSystem.new()
var cost_system := CostSystem.new()
var sacrifice_system := SacrificeSystem.new()
var fusion_system := FusionSystem.new()
var hand_discard_system := HandDiscardSystem.new()
var combat_log := CombatLogSystem.new()
# Overlay de VFX 3D (impacts de coup, projectiles de sort), créé en code (voir
# VFXManager) — pas de nœud dans Battle.tscn.
var vfx_manager: VFXManager
# Bannière de transition de tour (« À vous de jouer » / « Tour adverse »),
# créée en code pour ne pas toucher Battle.tscn.
var turn_banner: TurnBanner
# Journal de combat repliable, créé en code pour ne pas toucher Battle.tscn
# (voir CombatLogPanel).
var combat_log_panel: CombatLogPanel
# Glossaire des mots-clés/déclencheurs consultable via le bouton "?", créé en
# code pour ne pas toucher Battle.tscn (voir KeywordGlossaryPanel).
var glossary_panel: KeywordGlossaryPanel
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
# Suivi des quêtes quotidiennes de race (voir README « Économie »/CLAUDE.md) :
# deck_races est figé au chargement du deck (DeckSystem.load_deck), avant
# tirage, pour refléter la composition du deck entier — pas seulement les
# cartes piochées. cards_played_by_race n'incrémente que sur les cartes
# jouées par le joueur local (voir CardSystem.gd/play_resource_card), jamais
# celles de l'IA/adversaire. Reportés une fois au backend en fin de match par
# MatchResultReporter.
var deck_races: Array[String] = []
var cards_played_by_race: Dictionary = {}
# Compteurs de succès Steam (voir AchievementManager) accumulés au fil du
# match courant, consultés/déclenchés depuis Battle._show_game_over.
var player_resource_cards_played: int = 0
var player_min_hp_this_match: int = 30
var player_was_low_hp_this_match: bool = false
var player_kills_this_turn: int = 0
var player_infection_damage_dealt: int = 0
var player_used_back_row_this_match: bool = false
var player_commandement_triggers_this_match: int = 0
var player_black_blood_triggers_this_match: int = 0
var deck_has_legendary: bool = false
# Ce match provient-il de la file d'appariement classé (bouton "Partie
# classée" de NetLobby) plutôt que d'une "Partie rapide" ? Le backend ne fait
# lui-même aucune distinction entre les deux (voir CLAUDE.md § Ranked) : ce
# flag n'existe que côté client, propagé via NetContext.setup.
var is_ranked_match: bool = false

func track_card_played_for_quests(card_data: CardData) -> void:
	if card_data.race == Race.Type.NONE:
		return
	var race_name := Race.get_race_name(card_data.race)
	cards_played_by_race[race_name] = cards_played_by_race.get(race_name, 0) + 1
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
# Rangée Avant protégée du renvoi/déplacement ennemi, par camp (Ordre de Tenir).
var front_line_protected: Dictionary = {true: false, false: false}
# Nombre de Morts-Vivants alliés morts ce tour, par camp (clé = owner_is_player)
# — Dernier Soupir : "pioche 1 carte par Mort-Vivant allié mort ce tour".
var undead_ally_deaths_this_turn: Dictionary = {true: 0, false: 0}
# Phase de mulligan en cours (avant le tour 1) : le bouton Fin du tour devient
# "Commencer" et un clic sur une carte de la main la remplace au lieu de la jouer.
var _mulligan_active: bool = false
signal mulligan_confirmed
# Nombre maximum d'échanges pendant le mulligan, et suivi des index déjà
# échangés (une carte reçue en remplacement ne peut pas être re-mulligan).
const MULLIGAN_MAX_SWAPS := 4
var _mulligan_swap_count: int = 0
var _mulligan_swapped_indices: Array[int] = []

# ─── Setup ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	AudioManager.play_battle_music()
	_init_data()
	_init_systems()
	_connect_signals()
	turn_system.start_match()

func _init_data() -> void:
	tutorial_active = TutorialContext.active
	player_hero = Hero.new(30)
	player_min_hp_this_match = player_hero.health
	# HP réduits en tutoriel : l'adversaire scripté ne joue que 2 serviteurs et
	# n'attaque jamais, la victoire doit rester atteignable en quelques tours.
	enemy_hero  = Hero.new(8 if tutorial_active else 30)
	game_rng.randomize()  # solo : aléatoire ; écrasé par le seed réseau si besoin

func _init_systems() -> void:
	# Injecté explicitement plutôt que laissé à Hand._ready() qui se résout lui-
	# même via get_tree().current_scene : Hand est un enfant STATIQUE de
	# Battle.tscn (contrairement à BoardMinion, instancié dynamiquement bien
	# après la fin de la transition de scène) — ses enfants sont notifiés
	# _ready() AVANT le nœud racine Battle, potentiellement avant que
	# current_scene ne pointe effectivement vers cette scène. Une résolution
	# ratée à ce moment-là laissait `hand._battle` invalide pour toute la
	# partie : la carte se soulève toujours au survol (logique locale à Hand),
	# mais aucun tooltip de mot-clé ne s'affiche jamais (bloqué par les gardes
	# `is_instance_valid(_battle)`), sans la moindre erreur visible.
	hand.set_battle(self)
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
	input_system.init(self)
	net_session_system.init(self)
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
		is_ranked_match = bool(NetContext.setup.get("is_ranked", false))
		net_session_system.setup()
	enchantment_system.init(self)
	card_popup_system = CardPopupSystem.new()
	card_popup_system.init(self)
	pact_choice_system = PactChoiceSystem.new()
	pact_choice_system.init(self)
	aura_system.init(self)
	temp_effect_system.init(self)
	cost_system.init(self)
	sacrifice_system.init(self)
	fusion_system.init(self)
	hand_discard_system.init(self)
	turn_banner = TurnBanner.new()
	# Doit rester au-dessus du MulliganDimOverlay (z_index 90, Battle.tscn) : le
	# bandeau "Choisissez votre main" est l'élément d'interaction du mulligan au
	# même titre que la main, il ne doit pas être assombri comme le reste du plateau.
	turn_banner.z_index = 91
	add_child(turn_banner)
	vfx_manager = VFXManager.new()
	add_child(vfx_manager)
	combat_log.init(self)
	combat_log_panel = CombatLogPanel.new()
	combat_log_panel.init(self, combat_log)
	add_child(combat_log_panel)
	glossary_panel = KeywordGlossaryPanel.new()
	add_child(glossary_panel)
	help_button.pressed.connect(glossary_panel.toggle)
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
	add_child(fusion_system)
	hand.display_cost = get_card_cost

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
	_style_settings_button()
	settings_menu.report_requested.connect(_on_report_pressed)
	settings_menu.concede_requested.connect(_on_quit_match)
	game_over_screen.menu_requested.connect(_on_quit_match)
	game_over_screen.replay_requested.connect(_on_replay_match)
	# Cliquer sur un deck n'a pas d'action : pas de son de clic
	deck_button.set_meta("no_click_sound", true)
	enemy_deck_button.set_meta("no_click_sound", true)

# Remplace le texte "S" par la même icône engrenage dessinée à la volée que
# le bouton Réglages de l'Arena (ArenaIcon.Kind.GEAR, voir ArenaBattle.gd
# _style_button) : cohérence visuelle entre les deux modes, et un glyphe
# vectoriel garanti au lieu d'un rendu dépendant de la police active.
func _style_settings_button() -> void:
	settings_button.custom_minimum_size = Vector2(36, 36)
	settings_button.text = ""
	var gear := ArenaIcon.make(ArenaIcon.Kind.GEAR, 22.0)
	gear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gear.anchor_left = 0.5
	gear.anchor_top = 0.5
	gear.anchor_right = 0.5
	gear.anchor_bottom = 0.5
	gear.offset_left = -11.0
	gear.offset_top = -11.0
	gear.offset_right = 11.0
	gear.offset_bottom = 11.0
	settings_button.add_child(gear)

# ─── Process ──────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if targeting_system.is_targeting():
		targeting_system.update_arrow()

# ─── Input ────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	input_system.handle_unhandled_input(event)

# Signaler un bug ou l'adversaire (triche), depuis le menu Échap (voir
# SettingsMenu.report_requested) — l'option "Triche" n'apparaît que si la
# partie est en réseau et que l'id backend de l'adversaire est connu (voir
# net_opponent_backend_id, alimenté par NetHandshake). Le formulaire s'affiche
# à même le menu Échap (SettingsMenu.show_report_view), pas dans une nouvelle
# fenêtre.
func _on_report_pressed() -> void:
	var allow_cheating := network_manager != null and net_opponent_backend_id > 0
	settings_menu.show_report_view(allow_cheating, net_opponent_backend_id, net_client_match_id)

# Quitte la partie en cours et revient au menu principal.
func _on_quit_match() -> void:
	settings_menu.close()
	net_session_system.close()
	SceneTransition.change_scene(MAIN_MENU_SCENE)

# Relance une bataille depuis l'écran de fin (solo uniquement : le bouton
# Rejouer est masqué en réseau, mais on nettoie le transport par sécurité).
func _on_replay_match() -> void:
	net_session_system.close()
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

# ─── Animations de l'adversaire (IA ou réseau) ─────────────────────────────────
# La main adverse n'affiche que des dos de carte (EnemyHandDisplay), jamais leur
# contenu — ces animations restent donc de simples dos de carte qui voyagent,
# sans le retournement recto/verso de Hand._fly_ghost_card (réservé à la vraie
# main du joueur local).
const ENEMY_CARD_FLIGHT_DURATION := 0.35

func animate_enemy_draw() -> void:
	if enemy_deck_button == null or enemy_hand_display == null \
			or not is_instance_valid(enemy_deck_button) or not is_instance_valid(enemy_hand_display):
		return
	var ghost := _spawn_enemy_card_ghost(enemy_deck_button.global_position + enemy_deck_button.size * 0.5)
	var target: Vector2 = enemy_hand_display.global_position + enemy_hand_display.size * 0.5
	var duration: float = ENEMY_CARD_FLIGHT_DURATION * SettingsManager.motion_scale()
	var tween := create_tween()
	tween.tween_property(ghost, "global_position", target - ghost.size * 0.5, duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ghost, "modulate:a", 0.0, duration).set_delay(duration * 0.6)
	await tween.finished
	if is_instance_valid(ghost):
		ghost.queue_free()

# Petit envol depuis la main adverse vers le plateau, joué juste avant qu'un
# serviteur/sort adverse ne se résolve réellement (l'IA n'a pas de main
# individuellement cliquable à faire "glisser" comme le joueur).
func animate_enemy_card_played() -> void:
	if enemy_hand_display == null or not is_instance_valid(enemy_hand_display):
		return
	var origin: Vector2 = enemy_hand_display.global_position + enemy_hand_display.size * 0.5
	var ghost := _spawn_enemy_card_ghost(origin)
	var target: Vector2 = origin + Vector2(0, get_viewport_rect().size.y * 0.22)
	var duration: float = ENEMY_CARD_FLIGHT_DURATION * SettingsManager.motion_scale()
	var tween := create_tween()
	tween.tween_property(ghost, "global_position", target - ghost.size * 0.5, duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(ghost, "modulate:a", 0.0, duration).set_delay(duration * 0.5)
	tween.parallel().tween_property(ghost, "scale", ghost.scale * 0.7, duration)
	await tween.finished
	if is_instance_valid(ghost):
		ghost.queue_free()

func _spawn_enemy_card_ghost(at_global_pos: Vector2) -> TextureRect:
	var ghost := TextureRect.new()
	ghost.texture = CARD_BACK
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.custom_minimum_size = EnemyHandDisplay.CARD_SIZE
	ghost.size = EnemyHandDisplay.CARD_SIZE
	ghost.pivot_offset = ghost.size * 0.5
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.z_index = 100
	add_child(ghost)
	ghost.global_position = at_global_pos - ghost.size * 0.5
	return ghost

# ─── Mana ─────────────────────────────────────────────────────────────────────
# Un pool par race (voir README « Système de Ressources par Race ») : plus de
# mana générique unique. `race_mana`/`race_max_mana` appartiennent au joueur ;
# `opponent.race_mana`/`opponent.race_max_mana` au camp adverse (IA ou réseau).

func race_mana_pool(is_player: bool) -> Dictionary:
	return cost_system.race_mana_pool(is_player)

func race_max_mana_pool(is_player: bool) -> Dictionary:
	return cost_system.race_max_mana_pool(is_player)

func refill_mana_pool(is_player: bool = true) -> void:
	cost_system.refill_mana_pool(is_player)

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
# mais limitée à une par tour et par camp. Voir CostSystem.play_resource_card.
func play_resource_card(card_data: CardData, is_player: bool = true) -> void:
	cost_system.play_resource_card(card_data, is_player)
	if is_player:
		track_card_played_for_quests(card_data)
		player_resource_cards_played += 1

# ─── Serviteurs ───────────────────────────────────────────────────────────────

func get_owner_minions(minion: Minion) -> Array[Minion]:
	return board_system.get_owner_minions(minion)

func get_enemy_minions(minion: Minion) -> Array[Minion]:
	return board_system.get_enemy_minions(minion)

func get_row_minions(is_player: bool, row: String) -> Array[Minion]:
	return board_system.get_row_minions(is_player, row)

func get_front_minions(is_player: bool) -> Array[Minion]:
	return board_system.get_front_minions(is_player)

func get_back_minions(is_player: bool) -> Array[Minion]:
	return board_system.get_back_minions(is_player)

func can_summon_to_row(is_player: bool, row: String) -> bool:
	return board_system.can_summon_to_row(is_player, row)

func _normalized_row(row: String) -> String:
	return ROW_BACK if row == ROW_BACK else ROW_FRONT

# La logique d'insertion vit désormais dans BoardSystem._insert()

func get_allowed_rows_for_card(card_data: CardData) -> Array[String]:
	return board_system.get_allowed_rows_for_card(card_data)

func can_play_card_on_row(card_data: CardData, row: String) -> bool:
	return board_system.can_play_card_on_row(card_data, row)

func has_enemy_taunt(attacker: Minion) -> bool:
	return board_system.has_enemy_taunt(attacker)

func get_attackable_enemy_minions(attacker: Minion) -> Array[Minion]:
	return board_system.get_attackable_enemy_minions(attacker)

func destroy_minion(target: Minion) -> void:
	await death_system.destroy(target)

# ─── Carte jouée ──────────────────────────────────────────────────────────────

func _on_card_played(card_data: CardData, row: String = ROW_FRONT, insert_index: int = -1) -> void:
	if game_over or reconnecting or enemy_turn_active or not can_afford_card(card_data):
		return
	# Pas de jeu de carte pendant le choix d'une victime de Sacrifice/FUSION
	if sacrifice_system.is_active() or fusion_system.is_active():
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
	hero_system.update_turn_halo()
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
	settings_button.tooltip_text = SettingsManager.t("settings.title")
	help_button.tooltip_text = SettingsManager.t("GLOSSARY_TITLE")
	if _mulligan_active:
		end_turn_button.text = SettingsManager.t("mulligan.start_button")
		return
	var key := "battle.enemy_turn" if enemy_turn_active else "battle.end_turn"
	end_turn_button.text = SettingsManager.t(key)

# ─── Cimetière ────────────────────────────────────────────────────────────────

# ─── Règles d'attaque ─────────────────────────────────────────────────────────

func _can_attack_minion_target(attacker: Minion, target: Minion) -> bool:
	return board_system.can_attack_minion_target(attacker, target)

# Généralisé pour un attaquant de n'importe quel camp : utilisé par
# SelectionSystem (joueur local), AISystem et NetworkOpponent (revalidation
# des commandes distantes).
func _can_attack_hero(attacker: Minion) -> bool:
	return board_system.can_attack_hero(attacker)

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
	if result == "victory" or result == "defeat":
		SettingsManager.record_match_result(result == "victory")
	if result == "victory":
		AchievementManager.on_victory(self)
	elif result == "defeat":
		AchievementManager.on_defeat()
	game_over_screen.show_result(result, network_manager == null)
	MatchResultReporter.report(result, network_manager, net_client_match_id, net_opponent_backend_id, game_over_screen,
			cards_played_by_race, deck_races)

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
	Card.add_drag_shadow(preview)
	return preview

func is_dragging_card() -> bool:
	return _is_dragging_card
