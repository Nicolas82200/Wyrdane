extends RefCounted
class_name MatchResultReporter

# Rapporte le résultat d'un match terminé au backend, appelé depuis
# Battle._show_game_over une fois l'écran de fin affiché. Un match
# réseau/ranked est crédité côté serveur uniquement quand les deux rapports
# concordent (voir rankedModel.confirmMatch côté backend) : chaque camp
# rapporte indépendamment son propre résultat. Un match solo/IA n'a pas de
# second client pour faire foi : le client déclare directement son résultat,
# plafonné par jour côté serveur contre l'abus.

# Nombre de tentatives supplémentaires si le rapport local arrive avant celui
# du pair (statut "pending" tant que les deux rapports ne concordent pas côté
# backend) et délai entre deux tentatives — les deux clients rapportent en
# général à quelques secondes d'écart (chacun détecte la fin de partie de son
# côté), donc cette fenêtre suffit dans l'immense majorité des cas.
const RANKED_REPORT_RETRIES     := 4
const RANKED_REPORT_RETRY_DELAY := 2.5

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
		_report_ranked(net_client_match_id, net_opponent_backend_id, winner_id,
				cards_played_by_race, deck_races, game_over_screen, RANKED_REPORT_RETRIES)

# Seul le vainqueur est crédité côté backend (pas de récompense de défaite en
# classé, contrairement au solo) : reward vaut 0 pour le perdant, et
# game_over_screen.show_reward() n'est alors jamais appelé.
static func _report_ranked(client_match_id: String, opponent_id: int, winner_id: int,
		cards_played_by_race: Dictionary, deck_races: Array, game_over_screen: GameOverScreen,
		retries_left: int) -> void:
	BackendClient.report_ranked_match(client_match_id, opponent_id, winner_id, cards_played_by_race, deck_races,
		func(code: int, parsed):
			if code == 200 and parsed is Dictionary:
				if parsed.has("balance"):
					CurrencyManager.apply_balance_update(int(parsed["balance"]))
				var reward := int(parsed.get("reward", 0))
				if reward > 0:
					game_over_screen.show_reward(reward)
			elif code == 202 and retries_left > 0 and is_instance_valid(game_over_screen):
				# "pending" : le pair n'a pas encore rapporté son propre
				# résultat pour ce match, on réessaie un peu plus tard.
				await game_over_screen.get_tree().create_timer(RANKED_REPORT_RETRY_DELAY).timeout
				if is_instance_valid(game_over_screen):
					_report_ranked(client_match_id, opponent_id, winner_id, cards_played_by_race,
							deck_races, game_over_screen, retries_left - 1)
	)
