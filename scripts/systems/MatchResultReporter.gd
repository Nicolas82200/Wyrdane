extends RefCounted
class_name MatchResultReporter

# Rapporte le résultat d'un match terminé au backend, appelé depuis
# Battle._show_game_over une fois l'écran de fin affiché. Un match
# réseau/ranked est crédité côté serveur uniquement quand les deux rapports
# concordent (voir rankedModel.confirmMatch côté backend) : chaque camp
# rapporte indépendamment son propre résultat. Un match solo/IA n'a pas de
# second client pour faire foi : le client déclare directement son résultat,
# plafonné par jour côté serveur contre l'abus.
static func report(result: String, network_manager: NetworkManager, net_client_match_id: String,
		net_opponent_backend_id: int, game_over_screen: GameOverScreen,
		cards_played_by_race: Dictionary = {}, deck_races: Array = []) -> void:
	if network_manager == null:
		var won := result == "victory"
		CurrencyManager.report_solo_match_result(won, cards_played_by_race, deck_races, func(credited: bool, reward: int):
			if credited:
				game_over_screen.show_reward(reward)
		)
	elif (result == "victory" or result == "defeat") and net_client_match_id != "" and net_opponent_backend_id > 0 and BackendClient.local_user_id() > 0:
		var winner_id := BackendClient.local_user_id() if result == "victory" else net_opponent_backend_id
		BackendClient.report_ranked_match(net_client_match_id, net_opponent_backend_id, winner_id,
				cards_played_by_race, deck_races)
