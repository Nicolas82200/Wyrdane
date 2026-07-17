extends OpponentDriver
class_name TutorialOpponent

# Adversaire du tutoriel obligatoire : un script fixe et déterministe (pas
# l'AISystem normal) pour garantir que le plateau adverse évolue toujours de
# la même façon, quel que soit ce que fait le joueur — condition nécessaire
# pour que les popups du tutoriel (TutorialManager) restent cohérents avec
# ce qui se passe réellement en jeu.
#
# Tour 1 : pose un Zombie (1/1) en Avant.
# Tour 2 : pose un Pestilent (1/2) en Arrière (le laisse en cible pour le
#          sort du joueur, sans jamais bloquer sa rangée Avant).
# Tours suivants : ne joue plus rien, n'attaque jamais — le joueur termine
#          le tutoriel à son rythme contre un plateau figé.

var _turn: int = 0

# Délais volontairement généreux (contrairement à AISystem) : un nouveau
# joueur doit avoir le temps de voir ce qui se passe côté adverse, pas juste
# un flash entre deux tours.
const PRE_ACTION_DELAY  := 1.0
const POST_ACTION_DELAY := 1.5
const IDLE_DELAY        := 0.8

# Filet de sécurité : quoi qu'il arrive dans _run_turn_actions (un await
# imprévu qui traînerait plus longtemps que prévu), le tour adverse ne doit
# JAMAIS laisser le bouton Fin du tour désactivé indéfiniment. take_turn()
# n'attend donc pas directement _run_turn_actions : il la lance et sonde son
# état, avec une limite haute au-delà de laquelle il rend la main de force.
const MAX_TURN_SAFETY := 6.0

func setup() -> void:
	# Pas de démonstration du système de ressource côté adversaire (déjà
	# enseigné côté joueur) : mana directement disponible.
	race_mana[Race.Type.UNDEAD]     = 5
	race_max_mana[Race.Type.UNDEAD] = 5

func take_turn() -> void:
	if battle.game_over:
		return
	battle.set_enemy_turn(true)
	_turn += 1
	var finished := false
	_run_turn_actions(func(): finished = true)
	var elapsed := 0.0
	while not finished and elapsed < MAX_TURN_SAFETY:
		await battle.get_tree().process_frame
		elapsed += battle.get_process_delta_time()
	if not finished:
		push_warning("TutorialOpponent: le tour adverse n'a pas terminé dans le délai prévu, on rend quand même la main pour ne jamais bloquer le bouton Fin du tour.")
	battle.set_enemy_turn(false)

func _run_turn_actions(on_done: Callable) -> void:
	await battle.pace_actions(PRE_ACTION_DELAY)
	match _turn:
		1:
			await battle.board_system.summon_minion(TutorialDeck.enemy_zombie_card(), false, "Front")
			await battle.pace_actions(POST_ACTION_DELAY)
		2:
			await battle.board_system.summon_minion(TutorialDeck.enemy_pestilent_card(), false, "Back")
			await battle.pace_actions(POST_ACTION_DELAY)
		_:
			await battle.pace_actions(IDLE_DELAY)
	on_done.call()

func refresh_ui() -> void:
	battle.update_enemy_mana_ui()
