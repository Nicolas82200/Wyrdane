extends GutTest

# Couvre le garde headless de SteamService.ensure_init
# (scripts/net/SteamService.gd).
#
# Contexte : initialiser l'API Steamworks déclare l'AppID 5052390 « en cours
# d'exécution » auprès du client Steam, qui affiche alors le joueur « en jeu »
# tant que le PROCESSUS vit. Un run headless (cette suite, ou une scène de
# vérification syntaxique temporaire) n'a pas de fenêtre pour signaler qu'il
# tourne encore, et ne se termine pas toujours de lui-même : un processus
# oublié laissait le joueur affiché en jeu indéfiniment, bien après avoir
# fermé le vrai jeu.

func test_never_initialises_steam_in_a_headless_process() -> void:
	if DisplayServer.get_name() != "headless":
		# Lancée depuis l'éditeur, la suite tourne avec un vrai serveur
		# d'affichage : le garde ne s'applique pas et on ne va SURTOUT pas
		# initialiser Steam pour le vérifier.
		pending("Ce test ne vaut que sur un run headless (--headless).")
		return
	assert_false(SteamService.ensure_init(),
		"un run headless ne doit jamais se déclarer à Steam comme une session de jeu")

func test_steam_stays_unavailable_to_the_rest_of_the_code_in_headless() -> void:
	if DisplayServer.get_name() != "headless":
		pending("Ce test ne vaut que sur un run headless (--headless).")
		return
	# Conséquence attendue du garde pour tous les appelants (BackendClient,
	# SteamTransport, AchievementManager...) : ils voient exactement la même
	# chose qu'avec l'extension GodotSteam absente, cas déjà géré partout.
	assert_false(SteamService.ensure_init(),
		"l'appel doit rester false même répété, sans jamais mémoriser un init")
