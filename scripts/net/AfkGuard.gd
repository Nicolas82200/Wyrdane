extends RefCounted
class_name AfkGuard

# Garde d'inactivité de tour, solo ET réseau : le décompte visuel (TurnTimer,
# la bordure du bouton Fin du tour) reste invisible tant que le joueur agit
# normalement. Il n'apparaît (VISIBLE_DURATION secondes, puis fin de tour
# forcée à 0) que dans deux cas :
# - Inactivité : IDLE_BEFORE_VISIBLE secondes sans la moindre action locale
#   (carte jouée, attaque, Rituel de Sacrifice/FUSION activés). Toute action
#   ultérieure annule ce décompte et referme le timer (voir notify_local_action).
# - Tour trop long : TURN_CAP_BEFORE_VISIBLE secondes écoulées depuis le début
#   du tour, MÊME si le joueur reste actif entre-temps — plafond absolu, non
#   réinitialisé par notify_local_action, pour éviter les tours interminables.
# battle.afk_guard.update(delta) est appelé chaque frame par Battle._process
# pendant le tour local (voir _tracking_enabled) pour faire progresser ces
# deux décomptes invisibles.
#
# Le forfait (LEAVE_MATCH + défaite) après MAX_AFK_STREAK tours consécutifs
# sans action reste RÉSEAU UNIQUEMENT (perdre contre une IA qui ne partira
# jamais n'aurait aucun sens) : en solo, l'expiration du timer se contente de
# terminer le tour, comme un clic normal sur Fin du tour.

const IDLE_BEFORE_VISIBLE     := 30.0
const TURN_CAP_BEFORE_VISIBLE := 60.0
const VISIBLE_DURATION        := 30.0
const NO_ACTION_TIMEOUT       := 10.0
const MAX_AFK_STREAK          := 3

enum Reason { NONE, IDLE, CAP }

var battle
var consecutive_afk_turns: int = 0
var _acted_this_turn: bool = false
var _no_action_forced: bool = false
var _visible_reason: int = Reason.NONE
var _turn_elapsed: float = 0.0
var _idle_elapsed: float = 0.0

func init(_battle) -> void:
	battle = _battle

func _is_network() -> bool:
	return battle.net_emitter != null

# Tour local en cours, hors tutoriel/mulligan/reconnexion/fin de partie : seule
# fenêtre où les décomptes d'inactivité et de plafond de tour progressent.
func _tracking_enabled() -> bool:
	return not battle.tutorial_active and not battle.game_over \
		and not battle.enemy_turn_active and not battle._mulligan_active \
		and not battle.reconnecting

# Appelé par Battle._process chaque frame : fait progresser les décomptes
# invisibles et ne montre le timer (TurnTimer) qu'une fois l'un des deux
# seuils atteint.
func update(delta: float) -> void:
	if not _tracking_enabled():
		return
	if battle.turn_timer.running:
		return
	_turn_elapsed += delta
	_idle_elapsed += delta
	if _idle_elapsed >= IDLE_BEFORE_VISIBLE:
		_visible_reason = Reason.IDLE
		battle.turn_timer.start(VISIBLE_DURATION)
	elif _turn_elapsed >= TURN_CAP_BEFORE_VISIBLE:
		_visible_reason = Reason.CAP
		battle.turn_timer.start(VISIBLE_DURATION)

# Appelé par TurnSystem au début du tour local : repart sur des décomptes
# vierges, timer masqué.
func begin_turn() -> void:
	_acted_this_turn = false
	_no_action_forced = false
	_visible_reason = Reason.NONE
	_turn_elapsed = 0.0
	_idle_elapsed = 0.0
	battle.turn_timer.stop()

# Reprise après une coupure réseau transitoire (voir NetSessionSystem) : on ne
# sait plus où en était le décompte d'inactivité pendant la coupure, donc on
# réaffiche directement le timer par prudence plutôt que de risquer une
# inactivité silencieuse trop longue.
func resume_turn_timer() -> void:
	_visible_reason = Reason.IDLE
	battle.turn_timer.start(VISIBLE_DURATION)

# Toute action de jeu locale (carte jouée, attaque, Rituel/Fusion activés) :
# preuve de présence, remet le décompte d'inactivité à zéro et referme le
# timer visible s'il n'était affiché que pour cause d'inactivité (le plafond
# de tour, lui, n'est jamais annulé par une action : voir _turn_elapsed).
# Les emotes n'en font volontairement PAS partie — sinon il suffirait d'en
# spammer une toutes les 25s pour simuler indéfiniment une présence sans
# jamais jouer.
func notify_local_action() -> void:
	if not _tracking_enabled():
		return
	_acted_this_turn = true
	_no_action_forced = false
	_idle_elapsed = 0.0
	if _visible_reason == Reason.IDLE:
		battle.turn_timer.stop()
		_visible_reason = Reason.NONE

# Clic explicite sur Fin du tour : preuve de présence même sans avoir rien
# joué (le joueur a simplement choisi de passer), casse la série AFK réseau.
func notify_manual_end_turn() -> void:
	if not _is_network():
		return
	consecutive_afk_turns = 0

# Reflète Battle._player_has_no_actions() à chaque rafraîchissement de l'état
# (voir Battle.update_end_turn_hint) : si le joueur n'a plus rien à jouer,
# affiche/resserre le timer à NO_ACTION_TIMEOUT au plus, pour nudger vers la
# fin de tour sans attendre le seuil d'inactivité normal.
func set_no_action_state(no_actions: bool) -> void:
	if not _tracking_enabled():
		return
	if no_actions and not _no_action_forced:
		_no_action_forced = true
		if not battle.turn_timer.running:
			_visible_reason = Reason.IDLE
			battle.turn_timer.start(NO_ACTION_TIMEOUT)
		elif battle.turn_timer.time_left > NO_ACTION_TIMEOUT:
			battle.turn_timer.start(NO_ACTION_TIMEOUT)
	elif not no_actions:
		_no_action_forced = false

# Expiration du décompte visible : en solo, se contente de terminer le tour.
# En réseau, met à jour la série AFK et déclenche le forfait le cas échéant.
# Retourne true si TurnSystem doit enchaîner sur une fin de tour normale,
# false si le forfait a déjà pris le relais (partie terminée).
func handle_timeout() -> bool:
	_visible_reason = Reason.NONE
	if not _is_network():
		return true
	if _acted_this_turn or _no_action_forced:
		consecutive_afk_turns = 0
	else:
		consecutive_afk_turns += 1
	if consecutive_afk_turns >= MAX_AFK_STREAK:
		await _forfeit()
		return false
	return true

func _forfeit() -> void:
	battle.game_over = true
	battle.turn_timer.stop()
	battle.enemy_turn_active = false
	battle.net_session_system.close()
	await battle._show_game_over("defeat")
