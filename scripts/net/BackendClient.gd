# BackendClient.gd
extends Node

# Client HTTP vers wyrdane-backend (voir E:\wyrdane-backend). Gère l'auth
# Steam par ticket de session (POST /api/auth/steam) et porte le cookie de
# session sur toutes les requêtes suivantes — Godot ne gère pas les cookies
# comme un navigateur, donc on doit le lire dans Set-Cookie et le renvoyer
# nous-mêmes en header Cookie sur chaque appel.
#
const API_URL := "https://wyrdane-backend.onrender.com"

# Bypass dev uniquement (voir DEV_SKIP_STEAM_VERIFY côté backend) : tant qu'on
# n'a pas d'accès Steamworks Partner, AuthenticateUserTicket refuse notre clé
# Web API personnelle (403 Forbidden côté Steam). Envoie le steamid local
# directement au lieu d'un vrai ticket. Le backend doit avoir
# DEV_SKIP_STEAM_VERIFY=true, sinon ce ticket est simplement rejeté (401) et
# on retombe sur le vrai flow. À retirer une fois l'accès Partner obtenu.
const DEV_SKIP_STEAM_VERIFY := true

signal login_succeeded(user: Dictionary)
signal login_failed(reason: String)

var _session_cookie: String = ""
var _pending_ticket_id: int = 0
var _pending_ticket_buffer: PackedByteArray = PackedByteArray()

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
	login_succeeded.emit(parsed.get("users", {}) if parsed is Dictionary else {})

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
