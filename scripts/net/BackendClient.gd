# BackendClient.gd
extends Node

# Client HTTP vers wyrdane-backend (voir E:\wyrdane-backend). Gère l'auth
# Steam par ticket de session (POST /api/auth/steam) et porte le cookie de
# session sur toutes les requêtes suivantes — Godot ne gère pas les cookies
# comme un navigateur, donc on doit le lire dans Set-Cookie et le renvoyer
# nous-mêmes en header Cookie sur chaque appel.
#
const API_URL = "https://api.wyrdane.com"

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

	var headers := ["Content-Type: application/json"]
	if _session_cookie != "":
		headers.append("Cookie: %s" % _session_cookie)

	var body_str := "" if body.is_empty() else JSON.stringify(body)

	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, response_body: PackedByteArray) -> void:
		http.queue_free()
		if on_complete.is_valid():
			var parsed = null
			if response_body.size() > 0:
				parsed = JSON.parse_string(response_body.get_string_from_utf8())
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

# Rapporte le résultat d'un match réseau (POST /api/ranked/matches/report) —
# voir NetHandshake pour client_match_id/opponent_id. Chaque camp rapporte
# indépendamment ; le backend ne valide (MMR, historique) que si les deux
# rapports concordent (double-report, voir rankedController côté backend).
func report_ranked_match(client_match_id: String, opponent_id: int, winner_id: int, on_complete: Callable = Callable()) -> void:
	request(HTTPClient.METHOD_POST, "/api/ranked/matches/report", {
		"clientMatchId": client_match_id,
		"opponentId": opponent_id,
		"winnerId": winner_id,
	}, on_complete)

# ─── Matchmaking classé ─────────────────────────────────────────────────────
# Contrat détaillé (à implémenter côté wyrdane-backend) :
# docs/backend-contracts/ranked-matchmaking-and-retention.md
# Appariement par MMR, fenêtre élargie progressivement. Une fois deux tickets
# appariés, le backend désigne un hôte (déterministe, ex. plus petit user id)
# ; l'hôte crée un lobby Steam (voir NetLobby._on_ranked_matched) et rapporte
# son lobby_id via queue_report_lobby — le camp invité le récupère au prochain
# poll de queue_status et le rejoint directement (NetTransport.join avec
# {"lobby_id": ...}), sans passer par la recherche de lobby publique.

# Rejoint la file d'attente classée. on_complete(success, {ticket_id}).
func queue_join(on_complete: Callable) -> void:
	request(HTTPClient.METHOD_POST, "/api/matchmaking/queue", {}, func(code: int, parsed: Variant):
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
