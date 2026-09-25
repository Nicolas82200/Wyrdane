# BackendClient.gd
extends Node

# Client HTTP vers wyrdane-backend (voir E:\wyrdane-backend). Gère l'auth
# Steam par ticket de session (POST /api/auth/steam) et porte le cookie de
# session sur toutes les requêtes suivantes — Godot ne gère pas les cookies
# comme un navigateur, donc on doit le lire dans Set-Cookie et le renvoyer
# nous-mêmes en header Cookie sur chaque appel.
#
const API_URL = "https://api.wyrdane.com"
# Sans timeout, un backend qui ne répond jamais laisse request_completed ne
# jamais se déclencher : l'appelant (ex. QuestsPanel, GameOverScreen) reste
# bloqué indéfiniment et le HTTPRequest orphelin n'est jamais libéré.
const REQUEST_TIMEOUT_SECONDS := 15.0

# Bypass dev uniquement (voir DEV_SKIP_STEAM_VERIFY côté backend) : envoie le
# steamid local directement au lieu d'un vrai ticket. Utile pour tester en
# local sans backend joignable ; le backend n'accepte ce ticket que si
# NODE_ENV != production, donc laisser à false désormais que le vrai flow
# (AuthenticateUserTicket via api.steampowered.com + AppID Spacewar 480)
# fonctionne avec une clé Web API personnelle.
const DEV_SKIP_STEAM_VERIFY := false

signal login_succeeded(user: Dictionary)
signal login_failed(reason: String)

var _session_cookie: String = ""
var _pending_ticket_id: int = 0
var _pending_ticket_buffer: PackedByteArray = PackedByteArray()
# Id utilisateur backend local, extrait de la réponse de login (voir
# _on_login_response) : sert à rapporter les matchs réseau (NetHandshake) et
# récupérer son propre profil. Reste à 0 tant qu'aucun login n'a réussi.
var _user_id: int = 0

func local_user_id() -> int:
	return _user_id

# Les callbacks Steamworks (dont get_auth_session_ticket_response) ne sont
# livrés que si Steam.run_callbacks() est pompé régulièrement. SteamTransport
# le fait déjà pendant le multijoueur, mais l'auth doit marcher dès le menu
# principal — donc on pompe nous-mêmes tant qu'une session Steam est active.
func _process(_delta: float) -> void:
	SteamService.run_callbacks()

func is_authenticated() -> bool:
	return _session_cookie != ""

# Lance le flow d'auth Steam : récupère un ticket de session Steamworks et
# l'envoie au backend pour vérification. Émet login_succeeded/login_failed.
func login_with_steam() -> void:
	if not SteamService.ensure_init():
		login_failed.emit("Steam indisponible")
		return

	if DEV_SKIP_STEAM_VERIFY:
		var steam_id := SteamService.local_steam_id()
		if steam_id == "":
			login_failed.emit("Steam id indisponible")
			return
		_send_ticket_to_backend("DEV:%s" % steam_id)
		return

	var s := SteamService.steam()
	if not s.get_auth_session_ticket_response.is_connected(_on_auth_ticket_response):
		s.get_auth_session_ticket_response.connect(_on_auth_ticket_response)

	var result: Dictionary = s.getAuthSessionTicket()
	_pending_ticket_id = result.get("id", 0)
	_pending_ticket_buffer = result.get("buffer", PackedByteArray())

# result == 1 correspond à k_EResultOK côté Steamworks.
func _on_auth_ticket_response(auth_ticket: int, result: int) -> void:
	if auth_ticket != _pending_ticket_id:
		return
	if result != 1:
		login_failed.emit("Ticket Steam invalide (code %d)" % result)
		return
	_send_ticket_to_backend(_pending_ticket_buffer.hex_encode())

func _send_ticket_to_backend(ticket_hex: String) -> void:
	var body := JSON.stringify({"ticket": ticket_hex})
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = REQUEST_TIMEOUT_SECONDS
	http.request_completed.connect(_on_login_response.bind(http))
	var err := http.request(
		API_URL + "/api/auth/steam",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		body,
	)
	if err != OK:
		http.queue_free()
		login_failed.emit("Impossible de contacter le backend (%d)" % err)

func _on_login_response(_result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()

	if response_code != 200:
		login_failed.emit("Échec de connexion (HTTP %d)" % response_code)
		return

	_session_cookie = _extract_cookie(headers)
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	var user: Dictionary = parsed.get("users", {}) if parsed is Dictionary else {}
	_user_id = int(user.get("id", 0))
	login_succeeded.emit(user)

func _extract_cookie(headers: PackedStringArray) -> String:
	for header in headers:
		if header.begins_with("Set-Cookie:"):
			return header.substr(len("Set-Cookie:")).strip_edges().split(";")[0]
	return ""

# Appel générique vers l'API, cookie de session attaché automatiquement.
# on_complete est appelé avec (response_code: int, parsed_body: Variant).
func request(method: HTTPClient.Method, path: String, body: Dictionary = {}, on_complete: Callable = Callable()) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = REQUEST_TIMEOUT_SECONDS

	# X-Requested-With : exigé par le backend (middleware/csrf.ts) sur toute
	# route authentifiée par cookie, pour forcer un préflight CORS qu'un
	# formulaire/fetch externe ne peut pas satisfaire (protection CSRF, le
	# cookie de session étant posé en SameSite=None en production).
	var headers := ["Content-Type: application/json", "X-Requested-With: XMLHttpRequest"]
	if _session_cookie != "":
		headers.append("Cookie: %s" % _session_cookie)

	var body_str := "" if body.is_empty() else JSON.stringify(body)

	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, response_body: PackedByteArray) -> void:
		http.queue_free()
		if on_complete.is_valid():
			var parsed = null
			if response_body.size() > 0:
				var text := response_body.get_string_from_utf8()
				# Certaines routes répondent 200 avec un corps texte brut (ex.
				# res.sendStatus(200) -> "OK", voir POST /api/reports) plutôt
				# que du JSON : ne tenter le parse que si ça y ressemble, pour
				# éviter le spam d'erreur "Parse JSON failed" côté moteur —
				# parsed reste null dans les deux cas, comportement inchangé
				# pour les appelants (déjà tous tolérants à un null/non-Dictionary).
				var trimmed := text.strip_edges()
				if trimmed.begins_with("{") or trimmed.begins_with("["):
					parsed = JSON.parse_string(text)
			on_complete.call(response_code, parsed)
	)

	var err := http.request(API_URL + path, headers, method, body_str)
	if err != OK:
		http.queue_free()
		if on_complete.is_valid():
			on_complete.call(-1, null)

# Profil agrégé du joueur connecté (GET /api/profile) : date de création de
# compte, nombre de cartes en collection, stats solo/ranked — voir
# MainMenu._show_info_view(PROFILE). on_profile est appelé avec (success: bool, data: Dictionary).
func get_profile(on_profile: Callable) -> void:
	request(HTTPClient.METHOD_GET, "/api/profile", {}, func(code: int, parsed: Variant):
		if code == 200 and parsed is Dictionary:
			on_profile.call(true, parsed)
		else:
			on_profile.call(false, {})
	)

# Profil d'un AUTRE joueur (GET /api/profile/:userId) : même format que
# get_profile ci-dessus, mais restreint côté backend aux amis acceptés (403
# sinon — voir ProfilePanel.open_for_user côté client). on_profile appelé
# avec (success: bool, data: Dictionary).
func get_friend_profile(user_id: int, on_profile: Callable) -> void:
	request(HTTPClient.METHOD_GET, "/api/profile/%d" % user_id, {}, func(code: int, parsed: Variant):
		if code == 200 and parsed is Dictionary:
			on_profile.call(true, parsed)
		else:
			on_profile.call(false, {})
	)

# Rapporte le résultat d'un match réseau (POST /api/ranked/matches/report) —
# voir NetHandshake pour client_match_id/opponent_id. Chaque camp rapporte
# indépendamment ; le backend ne valide (MMR, historique) que si les deux
# rapports concordent (double-report, voir rankedController côté backend).
# match_session_token : preuve d'appariement classé émise par le backend au
# matchmaking (voir MatchmakingOverlay._on_queue_matched, TODO.md P9) — vide
# pour une Partie rapide/Contre un ami, dans quel cas le champ est simplement
# omis du payload plutôt qu'envoyé vide.
# is_ranked : reflète Battle.is_ranked_match — seul "ranked" fait gagner/perdre
# des points de classement (MMR public) côté backend ; toute autre partie
# réseau (Normal, Contre un ami) est rapportée "normal" et ne touche jamais à
# ce MMR public (voir rankedModel.confirmMatch côté wyrdane-backend — un MMR
# caché distinct est mis à jour pour Normal, jamais exposé au client).
func report_ranked_match(client_match_id: String, opponent_id: int, winner_id: int,
		cards_played_by_race: Dictionary = {}, deck_races: Array = [], on_complete: Callable = Callable(),
		match_session_token: String = "", cards_played_names: Array = [], is_ranked: bool = false,
		duration_sec: int = 0) -> void:
	var payload := {
		"clientMatchId": client_match_id,
		"opponentId": opponent_id,
		"winnerId": winner_id,
		"cardsPlayedByRace": cards_played_by_race,
		"deckRaces": deck_races,
		"cardsPlayed": cards_played_names,
		"mode": "ranked" if is_ranked else "normal",
		"durationSec": duration_sec,
	}
	if match_session_token != "":
		payload["matchSessionToken"] = match_session_token
	request(HTTPClient.METHOD_POST, "/api/ranked/matches/report", payload, on_complete)

# Historique des dernières parties réseau (ranked + partie rapide, voir
# rankedModel.getMatchHistory côté backend) du joueur connecté — alimente
# l'onglet "Historique" du profil (voir MatchHistoryPanel.gd). Chaque entrée :
# {client_match_id, played_at, duration_sec, winner_id, mmr_change,
# opponent_username, opponent_deck_races}. on_complete(success: bool, entries: Array).
func get_match_history(limit: int, on_complete: Callable) -> void:
	request(HTTPClient.METHOD_GET, "/api/ranked/matches/history?limit=%d" % limit, {}, func(code: int, parsed: Variant):
		if code == 200 and parsed is Array:
			on_complete.call(true, parsed)
		else:
			on_complete.call(false, [])
	)

# Même chose que get_match_history mais pour un AUTRE joueur (GET
# /api/ranked/matches/history/:userId), restreint aux amis acceptés côté
# backend — voir MatchHistoryPanel.open_for_user.
func get_friend_match_history(user_id: int, limit: int, on_complete: Callable) -> void:
	request(HTTPClient.METHOD_GET, "/api/ranked/matches/history/%d?limit=%d" % [user_id, limit], {}, func(code: int, parsed: Variant):
		if code == 200 and parsed is Array:
			on_complete.call(true, parsed)
		else:
			on_complete.call(false, [])
	)

# ─── Classement ──────────────────────────────────────────────────────────────
# GET /api/ranked/leaderboard?limit=&offset=&minMmr=&maxMmr= — renvoie
# désormais une enveloppe { total, players } (players = lignes { user_id, mmr,
# wins, losses, season, username, steam_id, rank }, rank calculé côté serveur
# donc valide même filtré par palier). min_mmr/max_mmr optionnels (-1 = pas de
# borne) servent à ne demander qu'un palier (voir RankTier.THRESHOLDS côté
# client — le backend ne connaît pas les paliers, juste des bornes de MMR).
# on_complete(success: bool, total: int, players: Array).
func get_leaderboard(limit: int, offset: int, min_mmr: int, max_mmr: int, on_complete: Callable) -> void:
	var path := "/api/ranked/leaderboard?limit=%d&offset=%d" % [limit, offset]
	if min_mmr >= 0:
		path += "&minMmr=%d" % min_mmr
	if max_mmr >= 0:
		path += "&maxMmr=%d" % max_mmr
	request(HTTPClient.METHOD_GET, path, {}, func(code: int, parsed: Variant):
		if code == 200 and parsed is Dictionary and parsed.get("players") is Array:
			on_complete.call(true, int(parsed.get("total", 0)), parsed["players"])
		else:
			on_complete.call(false, 0, [])
	)

# Position du joueur connecté dans le classement de la saison courante.
# on_complete(success: bool, row: Dictionary) — row vide (succès faux) si le
# joueur n'a encore aucun match classé rapporté (404 côté backend).
func get_my_leaderboard_position(on_complete: Callable) -> void:
	request(HTTPClient.METHOD_GET, "/api/ranked/leaderboard/me", {}, func(code: int, parsed: Variant):
		if code == 200 and parsed is Dictionary:
			on_complete.call(true, parsed)
		else:
			on_complete.call(false, {})
	)

# Page de classement centrée sur la position du joueur connecté au sein d'un
# palier (min_mmr/max_mmr), calculée côté serveur (voir
# rankedModel.getLeaderboardAroundUser). on_complete(success, total, offset, players).
func get_leaderboard_around_me(limit: int, min_mmr: int, max_mmr: int, on_complete: Callable) -> void:
	var path := "/api/ranked/leaderboard/around-me?limit=%d" % limit
	if min_mmr >= 0:
		path += "&minMmr=%d" % min_mmr
	if max_mmr >= 0:
		path += "&maxMmr=%d" % max_mmr
	request(HTTPClient.METHOD_GET, path, {}, func(code: int, parsed: Variant):
		if code == 200 and parsed is Dictionary and parsed.get("players") is Array:
			on_complete.call(true, int(parsed.get("total", 0)), int(parsed.get("offset", 0)), parsed["players"])
		else:
			on_complete.call(false, 0, 0, [])
	)

# Recherche d'un joueur par pseudo (sous-chaîne, insensible à la casse) pour
# la barre de recherche du classement. on_complete(success: bool, results: Array).
func search_leaderboard(query: String, on_complete: Callable) -> void:
	request(HTTPClient.METHOD_GET, "/api/ranked/leaderboard/search?q=%s" % query.uri_encode(), {}, func(code: int, parsed: Variant):
		if code == 200 and parsed is Array:
			on_complete.call(true, parsed)
		else:
			on_complete.call(false, [])
	)

# ─── Matchmaking classé ─────────────────────────────────────────────────────
# Contrat détaillé (à implémenter côté wyrdane-backend) :
# docs/backend-contracts/ranked-matchmaking-and-retention.md
# Appariement par MMR, fenêtre élargie progressivement. Une fois deux tickets
# appariés, le backend désigne un hôte (déterministe, ex. plus petit user id)
# ; l'hôte crée un lobby Steam (voir MatchmakingOverlay._on_ranked_matched) et rapporte
# son lobby_id via queue_report_lobby — le camp invité le récupère au prochain
# poll de queue_status et le rejoint directement (NetTransport.join avec
# {"lobby_id": ...}), sans passer par la recherche de lobby publique.

# Rejoint la file d'attente. mode : "ranked" (apparié sur le MMR public,
# gagne/perd des points de classement) ou "normal" (apparié sur un MMR caché,
# jamais affiché ni modifié par le classé — voir MatchmakingOverlay.start_normal
# et rankedModel.confirmMatch côté wyrdane-backend). on_complete(success, {ticket_id}).
func queue_join(mode: String, on_complete: Callable) -> void:
	request(HTTPClient.METHOD_POST, "/api/matchmaking/queue", {"mode": mode}, func(code: int, parsed: Variant):
		if code == 200 and parsed is Dictionary:
			on_complete.call(true, parsed)
		else:
			on_complete.call(false, {})
	)

# Interroge l'état d'un ticket. on_complete(success, {status, role, opponent_id, steam_lobby_id}).
# status : "waiting" | "matched" | "cancelled" | "expired". role ("host"/"guest")
# et steam_lobby_id ne sont présents qu'une fois status == "matched".
func queue_status(ticket_id: String, on_complete: Callable) -> void:
	request(HTTPClient.METHOD_GET, "/api/matchmaking/queue/%s" % ticket_id, {}, func(code: int, parsed: Variant):
		if code == 200 and parsed is Dictionary:
			on_complete.call(true, parsed)
		else:
			on_complete.call(false, {})
	)

# Hôte uniquement : transmet le lobby Steam qu'il vient de créer, pour que
# l'invité puisse le rejoindre directement au prochain queue_status.
func queue_report_lobby(ticket_id: String, steam_lobby_id: int, on_complete: Callable = Callable()) -> void:
	request(HTTPClient.METHOD_POST, "/api/matchmaking/queue/%s/report-lobby" % ticket_id, {
		"steamLobbyId": steam_lobby_id,
	}, on_complete)

# Quitte la file d'attente (bouton Annuler, ou changement de scène).
func queue_cancel(ticket_id: String, on_complete: Callable = Callable()) -> void:
	request(HTTPClient.METHOD_DELETE, "/api/matchmaking/queue/%s" % ticket_id, {}, on_complete)

# ─── Quêtes quotidiennes & récompense de connexion ─────────────────────────
# Implémenté côté wyrdane-backend (voir questModel.ts/loginRewardModel.ts).

# on_data appelé avec (success, {quests: [{id, description_key, progress,
# target, reward_currency, claimed}], resets_at}).
func get_daily_quests(on_data: Callable) -> void:
	request(HTTPClient.METHOD_GET, "/api/quests/daily", {}, func(code: int, parsed: Variant):
		if code == 200 and parsed is Dictionary:
			on_data.call(true, parsed)
		else:
			on_data.call(false, {})
	)

# on_data appelé avec (success, {balance, reward_currency}).
func claim_quest(quest_id: int, on_data: Callable) -> void:
	request(HTTPClient.METHOD_POST, "/api/quests/%d/claim" % quest_id, {}, func(code: int, parsed: Variant):
		if code == 200 and parsed is Dictionary:
			on_data.call(true, parsed)
		else:
			on_data.call(false, {})
	)

# on_data appelé avec (success, {claimed_today, streak_day}).
func get_login_reward_status(on_data: Callable) -> void:
	request(HTTPClient.METHOD_GET, "/api/login-reward/status", {}, func(code: int, parsed: Variant):
		if code == 200 and parsed is Dictionary:
			on_data.call(true, parsed)
		else:
			on_data.call(false, {})
	)

# on_data appelé avec (success, {streak_day, reward_currency, balance}).
func claim_login_reward(on_data: Callable) -> void:
	request(HTTPClient.METHOD_POST, "/api/login-reward/claim", {}, func(code: int, parsed: Variant):
		if code == 200 and parsed is Dictionary:
			on_data.call(true, parsed)
		else:
			on_data.call(false, {})
	)

# ─── Récompenses de niveau (popup dédiée, voir LevelRewardsPopup) ──────────
# Contrat détaillé : voir « Popup de récompenses de niveau » dans le
# CLAUDE.md de wyrdane-backend.

# on_data appelé avec (success, {level, catalog: [{level, kind, rarity?,
# gold?}], rewards: [{level, type, gold, claimed}]}).
func get_level_rewards(on_data: Callable) -> void:
	request(HTTPClient.METHOD_GET, "/api/level/rewards", {}, func(code: int, parsed: Variant):
		if code == 200 and parsed is Dictionary:
			on_data.call(true, parsed)
		else:
			on_data.call(false, {})
	)

# on_data appelé avec (success, {claimed: Array[int]}).
func claim_level_rewards(levels: Array, on_data: Callable) -> void:
	request(HTTPClient.METHOD_POST, "/api/level/rewards/claim", {"levels": levels}, func(code: int, parsed: Variant):
		if code == 200 and parsed is Dictionary:
			on_data.call(true, parsed)
		else:
			on_data.call(false, {})
	)

# ─── Quêtes hebdomadaires & parrainage ──────────────────────────────────────
# Contrat détaillé (à implémenter côté wyrdane-backend) :
# docs/backend-contracts/weekly-quests-and-referral.md

# on_data appelé avec (success, {quests: [{id, description_key, progress,
# target, reward_pack, claimed}], resets_at}).
func get_weekly_quests(on_data: Callable) -> void:
	request(HTTPClient.METHOD_GET, "/api/quests/weekly", {}, func(code: int, parsed: Variant):
		if code == 200 and parsed is Dictionary:
			on_data.call(true, parsed)
		else:
			on_data.call(false, {})
	)

# on_data appelé avec (success, {free_packs, reward_pack}).
func claim_weekly_quest(quest_id: String, on_data: Callable) -> void:
	request(HTTPClient.METHOD_POST, "/api/quests/weekly/%s/claim" % quest_id, {}, func(code: int, parsed: Variant):
		if code == 200 and parsed is Dictionary:
			on_data.call(true, parsed)
		else:
			on_data.call(false, {})
	)

# ─── Quêtes mensuelles ───────────────────────────────────────────────────────
# Implémenté côté wyrdane-backend (voir monthlyQuestModel.ts) : même principe
# que les hebdomadaires mais objectifs plus longs et récompense double
# (or ET packs) pour une grosse récompense mensuelle.

# on_data appelé avec (success, {quests: [{id, description_key, progress,
# target, reward_currency, reward_pack, claimed}], resets_at}).
func get_monthly_quests(on_data: Callable) -> void:
	request(HTTPClient.METHOD_GET, "/api/quests/monthly", {}, func(code: int, parsed: Variant):
		if code == 200 and parsed is Dictionary:
			on_data.call(true, parsed)
		else:
			on_data.call(false, {})
	)

# on_data appelé avec (success, {balance, free_packs, reward_currency, reward_pack}).
func claim_monthly_quest(quest_id: int, on_data: Callable) -> void:
	request(HTTPClient.METHOD_POST, "/api/quests/monthly/%d/claim" % quest_id, {}, func(code: int, parsed: Variant):
		if code == 200 and parsed is Dictionary:
			on_data.call(true, parsed)
		else:
			on_data.call(false, {})
	)

# ─── Quêtes uniques (one-shot, jamais reset) ────────────────────────────────
# Implémenté côté wyrdane-backend (voir uniqueQuestModel.ts).

# on_data appelé avec (success, {quests: [{id, description_key, progress,
# target, reward_currency, reward_pack, claimed}]}) — pas de resets_at,
# ces quêtes ne resettent jamais.
func get_unique_quests(on_data: Callable) -> void:
	request(HTTPClient.METHOD_GET, "/api/quests/unique", {}, func(code: int, parsed: Variant):
		if code == 200 and parsed is Dictionary:
			on_data.call(true, parsed)
		else:
			on_data.call(false, {})
	)

# on_data appelé avec (success, {balance, free_packs, reward_currency, reward_pack}).
func claim_unique_quest(quest_id: int, on_data: Callable) -> void:
	request(HTTPClient.METHOD_POST, "/api/quests/unique/%d/claim" % quest_id, {}, func(code: int, parsed: Variant):
		if code == 200 and parsed is Dictionary:
			on_data.call(true, parsed)
		else:
			on_data.call(false, {})
	)

# on_data appelé avec (success, {code}). Génère le code au premier appel côté
# serveur (idempotent ensuite) — voir contrat.
func get_referral_code(on_data: Callable) -> void:
	request(HTTPClient.METHOD_GET, "/api/referral/code", {}, func(code: int, parsed: Variant):
		if code == 200 and parsed is Dictionary:
			on_data.call(true, parsed)
		else:
			on_data.call(false, {})
	)

# on_data appelé avec (success, {code, referred_username, status, reward_granted}).
# status : "none" | "pending" | "completed".
func get_referral_status(on_data: Callable) -> void:
	request(HTTPClient.METHOD_GET, "/api/referral/status", {}, func(code: int, parsed: Variant):
		if code == 200 and parsed is Dictionary:
			on_data.call(true, parsed)
		else:
			on_data.call(false, {})
	)

# on_data appelé avec (success, error_code). error_code vide si succès, sinon
# une des clés REFERRAL_INVALID_CODE / REFERRAL_SELF / REFERRAL_ALREADY_REFERRED
# / REFERRAL_CODE_USED (traduites côté appelant).
func redeem_referral_code(code: String, on_data: Callable) -> void:
	request(HTTPClient.METHOD_POST, "/api/referral/redeem", {"code": code}, func(response_code: int, parsed: Variant):
		if response_code == 200:
			on_data.call(true, "")
		else:
			# str() plutôt que String() : le constructeur String() plante sur un
			# type non-String (ex. un nombre JSON, toujours désérialisé en float
			# par JSON.parse_string) — voir QuestsPanel._get_str pour le même
			# correctif appliqué au même risque côté quêtes.
			var raw_error = parsed.get("error", "") if parsed is Dictionary else ""
			var error_code := "" if raw_error == null else str(raw_error)
			on_data.call(false, error_code)
	)

# Signale un bug ou un joueur pour triche (POST /api/reports) — voir
# ReportDialog. Pas de table dédiée côté backend : le signalement part par
# mail à l'équipe (même mécanisme que le formulaire de contact du site).
func report_issue(type: String, description: String, reported_user_id: int = 0, match_id: String = "", on_complete: Callable = Callable()) -> void:
	var body := {"type": type, "description": description}
	if reported_user_id > 0:
		body["reportedUserId"] = reported_user_id
	if match_id != "":
		body["matchId"] = match_id
	request(HTTPClient.METHOD_POST, "/api/reports", body, on_complete)

# ─── Amis Wyrdane (voir FriendsPanel.gd) ────────────────────────────────────
# Système d'amis propre à Wyrdane, distinct de la liste d'amis Steam (overlay
# natif, voir SteamService.open_friends_overlay) — voir CLAUDE.md « Système
# d'amis Wyrdane + chat » côté wyrdane-backend.

func search_friends(query: String, on_data: Callable) -> void:
	request(HTTPClient.METHOD_GET, "/api/friends/search?q=" + query.uri_encode(), {}, func(code: int, parsed: Variant):
		on_data.call(code == 200 and parsed is Array, parsed if parsed is Array else [])
	)

# Envoie les SteamID64 des amis Steam locaux (voir SteamService.
# get_steam_friend_ids) — le backend ajoute DIRECTEMENT en amis Wyrdane
# (déjà "acceptés") ceux qui ont un compte, sans étape manuelle ni acceptation
# (voir FriendsPanel._sync_steam_friends, demande utilisateur du 2026-09-25 :
# "je ne veux pas qu'on ait à les rajouter en jeu"). Idempotent, rappelable
# sans risque à chaque ouverture du panneau Amis.
func resolve_steam_friends(steam_ids: Array, on_data: Callable) -> void:
	request(HTTPClient.METHOD_POST, "/api/friends/resolve-steam-ids", {"steamIds": steam_ids}, func(code: int, parsed: Variant):
		on_data.call(code == 200 and parsed is Array, parsed if parsed is Array else [])
	)

# Chaque entrée : {friendship_id, id, username, steam_id, presence}, presence
# déjà résolue côté serveur ("online"/"in_game"/"offline" — voir
# friendModel.getFriends côté backend).
func get_friends(on_data: Callable) -> void:
	request(HTTPClient.METHOD_GET, "/api/friends", {}, func(code: int, parsed: Variant):
		on_data.call(code == 200 and parsed is Array, parsed if parsed is Array else [])
	)

func get_incoming_friend_requests(on_data: Callable) -> void:
	request(HTTPClient.METHOD_GET, "/api/friends/requests", {}, func(code: int, parsed: Variant):
		on_data.call(code == 200 and parsed is Array, parsed if parsed is Array else [])
	)

# on_data(success: bool, status: String) — status parmi "sent"/"already_friends"/
# "already_pending"/"auto_accepted" (voir friendModel.sendFriendRequest côté backend).
func send_friend_request(target_user_id: int, on_data: Callable) -> void:
	request(HTTPClient.METHOD_POST, "/api/friends/requests", {"userId": target_user_id}, func(code: int, parsed: Variant):
		var status: String = parsed.get("status", "") if parsed is Dictionary else ""
		on_data.call(code == 200, status)
	)

func accept_friend_request(friendship_id: int, on_complete: Callable = Callable()) -> void:
	request(HTTPClient.METHOD_POST, "/api/friends/requests/%d/accept" % friendship_id, {}, on_complete)

# Sert à la fois à refuser une demande reçue, annuler une demande envoyée, et
# supprimer un ami existant — voir friendModel.deleteFriendship côté backend.
func remove_friendship(friendship_id: int, on_complete: Callable = Callable()) -> void:
	request(HTTPClient.METHOD_DELETE, "/api/friends/%d" % friendship_id, {}, on_complete)

# ─── Invitation de partie entre amis (voir MatchmakingOverlay.gd) ──────────
# Remplace l'ancien flux "Contre un ami" par overlay Steam natif
# (SteamTransport.invite_friends, retiré). L'expéditeur a déjà hébergé son
# lobby Steam (steam_lobby_id = session_id de NetworkManager.session_ready)
# avant d'appeler ceci — ce endpoint ne fait que relayer l'invitation au
# destinataire via le backend, celui-ci la découvrant par polling.

# on_data(success: bool, data: Dictionary) — data = {message: "not_friends"|
# "recipient_unavailable"} sur échec (409), {id, status} sur succès.
func send_game_invite(recipient_id: int, steam_lobby_id: int, on_data: Callable) -> void:
	request(HTTPClient.METHOD_POST, "/api/invites", {"recipientId": recipient_id, "steamLobbyId": steam_lobby_id}, func(code: int, parsed: Variant):
		var data: Dictionary = parsed if parsed is Dictionary else {}
		on_data.call(code == 200, data)
	)

# Invitations pending reçues par le joueur connecté (pollé par
# MatchmakingOverlay pour afficher la popup de choix de deck). Chaque entrée :
# {id, sender_id, sender_username, steam_lobby_id, created_at}.
func get_incoming_invites(on_data: Callable) -> void:
	request(HTTPClient.METHOD_GET, "/api/invites/incoming", {}, func(code: int, parsed: Variant):
		on_data.call(code == 200 and parsed is Array, parsed if parsed is Array else [])
	)

# Pollé côté expéditeur pendant l'attente. on_data(success: bool, status: String)
# — "pending"/"accepted"/"declined"/"cancelled"/"expired".
func get_invite_status(invite_id: int, on_data: Callable) -> void:
	request(HTTPClient.METHOD_GET, "/api/invites/%d/status" % invite_id, {}, func(code: int, parsed: Variant):
		var status: String = parsed.get("status", "") if parsed is Dictionary else ""
		on_data.call(code == 200, status)
	)

# on_data(success: bool, steam_lobby_id: int) — lobby à rejoindre côté destinataire.
func accept_game_invite(invite_id: int, on_data: Callable) -> void:
	request(HTTPClient.METHOD_POST, "/api/invites/%d/accept" % invite_id, {}, func(code: int, parsed: Variant):
		var lobby_id: int = int(parsed.get("steamLobbyId", 0)) if parsed is Dictionary else 0
		on_data.call(code == 200, lobby_id)
	)

func decline_game_invite(invite_id: int, on_complete: Callable = Callable()) -> void:
	request(HTTPClient.METHOD_POST, "/api/invites/%d/decline" % invite_id, {}, on_complete)

# Bouton "Annuler" côté expéditeur, ou timeout local sans réponse.
func cancel_game_invite(invite_id: int, on_complete: Callable = Callable()) -> void:
	request(HTTPClient.METHOD_POST, "/api/invites/%d/cancel" % invite_id, {}, on_complete)

# ─── Présence (voir PresenceService.gd) ─────────────────────────────────────
func send_presence_heartbeat(in_game: bool, on_complete: Callable = Callable()) -> void:
	request(HTTPClient.METHOD_POST, "/api/presence/heartbeat", {"inGame": in_game}, on_complete)

# ─── Chat privé entre amis (voir ChatWindow.gd) ─────────────────────────────

func send_message(recipient_id: int, body: String, on_data: Callable) -> void:
	request(HTTPClient.METHOD_POST, "/api/messages", {"recipientId": recipient_id, "body": body}, func(code: int, parsed: Variant):
		on_data.call(code == 200 and parsed is Dictionary, parsed if parsed is Dictionary else {})
	)

# Historique le plus récent en tête (le client réaffiche dans l'ordre inverse)
# — before_id (0 = pas de curseur) permet de remonter plus loin (infinite scroll).
func get_conversation(friend_id: int, limit: int = 50, before_id: int = 0, on_data: Callable = Callable()) -> void:
	var path := "/api/messages/%d?limit=%d" % [friend_id, limit]
	if before_id > 0:
		path += "&beforeId=%d" % before_id
	request(HTTPClient.METHOD_GET, path, {}, func(code: int, parsed: Variant):
		on_data.call(code == 200 and parsed is Array, parsed if parsed is Array else [])
	)

# Conversations ayant au moins un message échangé, la plus récente en tête —
# un ami jamais contacté n'y apparaît pas (voir ChatPanel.gd).
func get_conversations(on_data: Callable) -> void:
	request(HTTPClient.METHOD_GET, "/api/messages/conversations", {}, func(code: int, parsed: Variant):
		on_data.call(code == 200 and parsed is Array, parsed if parsed is Array else [])
	)

func mark_conversation_read(friend_id: int, on_complete: Callable = Callable()) -> void:
	request(HTTPClient.METHOD_POST, "/api/messages/%d/read" % friend_id, {}, on_complete)

# on_data(total: int) — alimente le badge du bouton Chat du menu principal.
func get_unread_message_total(on_data: Callable) -> void:
	request(HTTPClient.METHOD_GET, "/api/messages/unread-total", {}, func(code: int, parsed: Variant):
		on_data.call(int(parsed.get("total", 0)) if code == 200 and parsed is Dictionary else 0)
	)
