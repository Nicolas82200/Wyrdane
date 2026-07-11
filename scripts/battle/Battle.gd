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
@onready var turn_choice_panel                         = $TurnChoicePanel
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

var effect_manager := EffectManager.new()
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
var mana: int                    = 1
var max_mana: int                = 1
var player_hero: Hero
var enemy_hero: Hero
var game_over: bool              = false
var enemy_turn_active: bool      = false
var _is_dragging_card: bool      = false
# Contre-Offensive active ce tour, par camp (clé = owner_is_player) : chaque
# Humain de ce camp qui tue un ennemi gagne une attaque supplémentaire.
var counter_offensive: Dictionary = {true: false, false: false}
# Phase de mulligan en cours (avant le tour 1) : le bouton Fin du tour devient
# "Commencer" et un clic sur une carte de la main la remplace au lieu de la jouer.
var _mulligan_active: bool = false
signal mulligan_confirmed

# ─── Setup ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	AudioManager.play_battle_music()
	_init_data()
	_init_systems()
	_connect_signals()
	_start_game()

func _init_data() -> void:
	player_hero = Hero.new(30)
	enemy_hero  = Hero.new(30)
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
	if NetContext.active:
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
	# Sous TurnChoicePanel : la bannière ne masque jamais un panneau de décision.
	move_child(turn_banner, turn_choice_panel.get_index())
	combat_log.init(self)
	combat_log_panel = CombatLogPanel.new()
	combat_log_panel.init(self, combat_log)
	add_child(combat_log_panel)
	turn_timer = TurnTimer.new()
	turn_timer.timeout.connect(_on_turn_timer_timeout)
	add_child(turn_timer)
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
	net.peer_disconnected.connect(_on_net_peer_disconnected)
	var netopp := NetworkOpponent.new(net)
	add_child(netopp)
	netopp.init(self)
	opponent = netopp

# Pair déconnecté en cours de partie : on stoppe le match (débloque l'attente du
# tour distant et fige les inputs) et on affiche l'écran de fin en mode
# déconnexion (retour au menu uniquement, rejouer n'a pas de sens sans le pair).
func _on_net_peer_disconnected(_reason: String) -> void:
	if game_over:
		return
	game_over = true
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
	turn_choice_panel.draw_selected.connect(_on_draw_selected)
	turn_choice_panel.mana_selected.connect(_on_mana_selected)
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
	deck_system.load_deck()
	deck_system.update_deck_ui()
	board_visual_system.refresh_board()
	for minion in player_minions:
		board_visual_system.spawn_minion_visual(minion, true)
	for minion in enemy_minions:
		board_visual_system.spawn_minion_visual(minion, false)
	if NetContext.active:
		opponent.setup()
	else:
		ai_system.setup()
	deck_system.deal_opening_hand()
	hand.set_hand(hand_cards, false)
	await _run_mulligan()
	if NetContext.active:
		var local_first: bool = net_local_first
		NetContext.clear()
		# Si le joueur distant commence, on lui passe la main avant notre 1er tour.
		if not local_first:
			await _run_remote_first_turn()
			return
	# Le joueur local ouvre la partie : annonce de son premier tour.
	turn_banner.show_banner(SettingsManager.t("battle.turn_player"))
	update_end_turn_hint()
	turn_timer.start()

# Phase de mulligan précédant le tour 1 : la main de départ est déjà affichée
# normalement ; cliquer une carte la remplace directement (voir Hand.flip_replace).
# Le bouton Fin du tour devient "Commencer" et confirme la fin du mulligan.
# En réseau, chaque camp mulligan indépendamment (le contenu reste privé) ; on
# attend juste que le pair ait fini avant de lancer le tour 1.
func _run_mulligan() -> void:
	_mulligan_active = true
	hand.set_mulligan_mode(true)
	hand.mulligan_card_clicked.connect(_on_mulligan_card_clicked)
	turn_banner.show_banner(SettingsManager.t("mulligan.banner"))
	_retranslate_battle()
	end_turn_button.disabled = false
	end_turn_button.set_ready_hint(true)
	await mulligan_confirmed
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
	var new_data: CardData = deck_system.mulligan_replace_one(index)
	if new_data == null:
		return
	AudioManager.play(AudioManager.DRAW)
	hand.flip_replace_at(index, new_data)

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

	# Raccourcis clavier (fin de tour, choix mana/pioche, cimetières, Échap)
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

	# Choix mana/pioche : uniquement quand le panneau attend une décision
	if event.is_action_pressed("choose_mana"):
		if turn_choice_panel.is_active():
			turn_choice_panel.select_mana()
		return true
	if event.is_action_pressed("choose_draw"):
		if turn_choice_panel.is_active():
			turn_choice_panel.select_draw()
		return true

	# Fin de tour : neutralisée tant qu'un choix de début de tour est en attente
	if event.is_action_pressed("end_turn"):
		if not turn_choice_panel.is_active():
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
		network_manager.close()
		network_manager.queue_free()
		network_manager = null
	NetContext.clear()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

# Relance une bataille depuis l'écran de fin (solo uniquement : le bouton
# Rejouer est masqué en réseau, mais on nettoie le transport par sécurité).
func _on_replay_match() -> void:
	if network_manager != null:
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

func update_mana_ui() -> void:
	mana_display.set_mana(mana, max_mana)
	update_end_turn_hint()

func update_enemy_mana_ui() -> void:
	enemy_mana_display.set_mana(opponent.mana, opponent.max_mana)

func update_enemy_hand_ui() -> void:
	enemy_hand_display.set_count(opponent.get_hand_count())

func _pay_mana(cost: int) -> void:
	mana -= cost
	update_mana_ui()

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
	if game_over or enemy_turn_active or get_card_cost(card_data) > mana:
		return
	# Pas de jeu de carte pendant le choix d'une victime de Sacrifice
	if sacrifice_system.is_active():
		return
	row = _normalized_row(row)
	await card_system.handle_card_played(card_data, row, insert_index)

func summon_minion(card_data: CardData, is_player: bool, row := "Front", insert_index := -1) -> void:
	await board_system.summon_minion(card_data, is_player, row, insert_index)

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
	if game_over or enemy_turn_active:
		return
	if _mulligan_active:
		mulligan_confirmed.emit()
		return
	turn_system.end_turn()

# Expiration du décompte de tour : résout le choix Mana/Pioche s'il est encore
# en attente (la Mana est le choix par défaut, sans perte d'information contrairement
# à la Pioche qui révèle une carte), puis termine le tour comme un clic normal.
func _on_turn_timer_timeout() -> void:
	if game_over or enemy_turn_active:
		return
	if turn_choice_panel.is_active():
		turn_choice_panel.select_mana()
	else:
		turn_system.end_turn()

# Bascule l'UI entre tour local et tour adverse : flag d'inputs, état du bouton
# Fin de tour et bannière de transition. Appelé par AISystem / NetworkOpponent.
func set_enemy_turn(active: bool) -> void:
	enemy_turn_active = active
	end_turn_button.disabled = active
	_retranslate_battle()
	if active:
		turn_timer.stop()
	if game_over:
		# Partie terminée pendant le tour adverse : pas d'annonce de tour
		end_turn_button.set_ready_hint(false)
		return
	if active:
		end_turn_button.set_ready_hint(false)
		turn_banner.show_banner(SettingsManager.t("battle.turn_enemy"))
	else:
		turn_banner.show_banner(SettingsManager.t("battle.turn_player"))
		update_end_turn_hint()

# Halo sur « Fin du tour » quand il ne reste plus aucune action possible.
func update_end_turn_hint() -> void:
	end_turn_button.set_ready_hint(_player_has_no_actions())

func _player_has_no_actions() -> bool:
	if game_over or enemy_turn_active or turn_choice_panel.is_active():
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

func draw_card() -> void:
	turn_system.draw_card()

func _on_draw_selected() -> void:
	turn_system.choose_draw()

func _on_mana_selected() -> void:
	turn_system.choose_mana()

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
	game_over_screen.show_result(result, network_manager == null)

# ─── Drag ─────────────────────────────────────────────────────────────────────

func _on_hand_drag_started() -> void:
	_is_dragging_card = true
	hand.set_compact(true)

func _on_hand_drag_ended() -> void:
	_is_dragging_card = false
	hand.set_compact(false)

# Coût effectif d'une carte de la main du joueur (remises comprises).
func get_card_cost(card_data: CardData) -> int:
	return cost_system.get_cost(card_data, true)

func can_afford_card(card_data: CardData) -> bool:
	return card_data != null and mana >= get_card_cost(card_data)

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
