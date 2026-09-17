extends RefCounted
class_name AfkGuard

# Anti-AFK réseau (1v1 uniquement, jamais en solo/tutoriel — l'IA ne traîne
# jamais) : décompte d'inactivité de IDLE_TIMEOUT secondes, remis à zéro par
# toute action de jeu locale, qui termine le tour tout seul s'il expire. Ceci
# remplace, pour le camp réseau, le délai fixe TurnTimer.DEFAULT_DURATION
# (jamais modifié ici, toujours utilisé tel quel en solo).
#
# Après MAX_AFK_STREAK tours d'affilée terminés SANS aucune action, le joueur
# local est déclaré perdant : LEAVE_MATCH est envoyé immédiatement (l'adversaire
# n'attend pas le délai de grâce de reconnexion) puis l'écran de fin s'affiche
# localement comme une défaite normale (même report ranked/achievements).
#
# Un tour où le joueur n'a simplement plus aucune action possible (voir
# Battle._player_has_no_actions, déjà utilisé pour le halo doré du bouton Fin
# du tour) ne compte JAMAIS comme un tour AFK : le décompte y est seulement
# resserré à NO_ACTION_TIMEOUT, pour empêcher un joueur à court de coups de
# faire volontairement traîner la partie en pariant que l'adversaire quittera
# de lassitude — la fin de tour forcée qui en résulte est un simple coup de
# pouce d'UX, pas une punition.

const IDLE_TIMEOUT      := 30.0
const NO_ACTION_TIMEOUT := 10.0
const MAX_AFK_STREAK     := 3

var battle
var consecutive_afk_turns: int = 0
var _acted_this_turn: bool = false
var _no_action_forced: bool = false

func init(_battle) -> void:
	battle = _battle

func active() -> bool:
	return battle.net_emitter != null and not battle.tutorial_active

# Appelé par TurnSystem à la place d'un battle.turn_timer.start() direct au
# début du tour local : démarre le bon décompte selon le mode (idle réseau,
# sinon délai fixe solo inchangé) et repart sur un tour "vierge".
func begin_turn() -> void:
	_acted_this_turn = false
	_no_action_forced = false
	if active():
		battle.turn_timer.start(IDLE_TIMEOUT)
	else:
		battle.turn_timer.start()

# Reprise après une coupure réseau transitoire (voir NetSessionSystem) :
# redémarre le décompte sans toucher à _acted_this_turn/_no_action_forced —
# une action jouée avant la coupure reste acquise.
func resume_turn_timer() -> void:
	if active():
		battle.turn_timer.start(IDLE_TIMEOUT)
	else:
		battle.turn_timer.start()

# Toute action de jeu locale (carte jouée, attaque, Rituel/Fusion activés,
# voir NetEmitter) : preuve de présence, remet le décompte à zéro. Les emotes
# n'en font volontairement PAS partie — sinon il suffirait d'en spammer une
# toutes les 25s pour simuler indéfiniment une présence sans jamais jouer.
func notify_local_action() -> void:
	if not active() or battle.enemy_turn_active:
		return
	_acted_this_turn = true
	_no_action_forced = false
	battle.turn_timer.start(IDLE_TIMEOUT)

# Clic explicite sur Fin du tour : preuve de présence même sans avoir rien
# joué (le joueur a simplement choisi de passer), casse la série AFK.
func notify_manual_end_turn() -> void:
	if not active():
		return
	consecutive_afk_turns = 0

# Reflète Battle._player_has_no_actions() à chaque rafraîchissement de l'état
# (voir Battle.update_end_turn_hint) : si le joueur n'a plus rien à jouer,
# resserre le décompte en cours à NO_ACTION_TIMEOUT au plus.
func set_no_action_state(no_actions: bool) -> void:
	if not active() or battle.enemy_turn_active or battle._mulligan_active:
		return
	if not battle.turn_timer.running:
		return
	if no_actions and not _no_action_forced:
		_no_action_forced = true
		if battle.turn_timer.time_left > NO_ACTION_TIMEOUT:
			battle.turn_timer.start(NO_ACTION_TIMEOUT)
	elif not no_actions:
		_no_action_forced = false

# Expiration du décompte : met à jour la série AFK et déclenche le forfait le
# cas échéant. Retourne true si TurnSystem doit enchaîner sur une fin de tour
# normale, false si le forfait a déjà pris le relais (partie terminée).
func handle_timeout() -> bool:
	if not active():
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
