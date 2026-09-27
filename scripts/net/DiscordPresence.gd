# DiscordPresence.gd
extends Node

# Rich Presence Discord : publie l'état du joueur ("Dans le menu principal",
# "Recherche une partie classée", "En partie" + chrono) sur son profil Discord,
# via le client Discord installé sur la machine — pas via le bot
# (E:\wyrdane-discord-bot) : un bot ne peut PAS écrire la présence d'un
# utilisateur, seul le client Discord local le peut, par IPC.
#
# Implémenté en pur GDScript sur le pipe nommé local de Discord
# (`\.\pipe\discord-ipc-N`), volontairement sans GDExtension : aucun binaire à
# compiler par plateforme, aucune dépendance de build supplémentaire. Détails
# du protocole (trames, opcodes) dans `DiscordActivity`.
#
# WINDOWS UNIQUEMENT pour l'instant, et c'est structurel : sur Linux/macOS
# Discord expose un socket de domaine Unix, que `FileAccess` ne sait pas
# ouvrir (il faudrait une extension). Le seul preset d'export actuel étant
# Windows (voir `export_presets.cfg`), le service se met simplement en veille
# ailleurs.
#
# Tout l'IPC tourne dans un THREAD dédié, et ce n'est pas une optimisation :
# une lecture sur un pipe nommé vide BLOQUE (vérifié — Godot se fige
# indéfiniment sur `get_buffer()` tant que Discord n'a rien envoyé). Le thread
# principal ne fait donc jamais que déposer l'activité à envoyer.

# Identifiant de l'application Discord dédiée au JEU (portail développeur
# Discord > New Application, nommée exactement "Wyrdane" : c'est ce nom que
# Discord affiche en « Joue à ... »). Distinct de l'application du bot
# communautaire. Laisser vide désactive proprement la fonctionnalité.
const CLIENT_ID := ""

# Discord expose jusqu'à 10 pipes (un par client Discord lancé : stable, PTB,
# Canary...). On prend le premier qui répond.
const PIPE_PATH_FORMAT := "\\.\\pipe\\discord-ipc-%d"
const PIPE_INDEX_MAX := 9

# Discord limite les mises à jour de présence (~1 toutes les 15 s). Les
# changements plus rapprochés sont coalescés : seul le dernier état est envoyé.
const MIN_SEND_INTERVAL_MSEC := 15000

# Anti-rebond systématique, même quand le quota ci-dessus est disponible : une
# entrée en partie enchaîne plusieurs états en moins d'une seconde (fin de file
# d'attente -> menu -> bataille) et seul le dernier a un intérêt. Évite aussi
# de gaspiller le quota sur un état qui ne durera pas.
const SEND_DEBOUNCE_MSEC := 2000

# Une tentative de connexion ratée (Discord pas lancé) ne doit pas être
# retentée à chaque changement d'écran.
const RECONNECT_DELAY_MSEC := 60000

# Garde-fou sur les lectures : au-delà, on considère le client Discord perdu et
# on se déconnecte plutôt que d'attendre une réponse qui ne viendra jamais.
const READ_TIMEOUT_MSEC := 3000
const READ_POLL_INTERVAL_MSEC := 10

var _enabled := false

# --- État courant (thread principal uniquement) -------------------------------
var _state := ""
var _ctx: Dictionary = {}
var _state_started_unix := 0
var _last_send_msec := 0
var _flush_timer: Timer

# --- Partagé entre threads (toujours sous _mutex) -----------------------------
var _mutex := Mutex.new()
var _semaphore := Semaphore.new()
var _thread: Thread
var _pending_activity: Dictionary = {}
var _has_pending := false
var _exiting := false

# --- Thread IPC uniquement ----------------------------------------------------
var _pipe: FileAccess
var _next_connect_attempt_msec := 0
var _nonce_counter := 0

func _ready() -> void:
	_enabled = CLIENT_ID != "" and OS.get_name() == "Windows"
	if not _enabled:
		return
	_flush_timer = Timer.new()
	_flush_timer.one_shot = true
	_flush_timer.timeout.connect(_flush)
	add_child(_flush_timer)
	# Le libellé dépend de la langue : un changement en cours de session doit
	# republier l'état courant (même principe que les `_retranslate()` de l'UI).
	SettingsManager.language_changed.connect(_on_language_changed)
	_thread = Thread.new()
	_thread.start(_ipc_loop)

func _exit_tree() -> void:
	if not _enabled:
		return
	_mutex.lock()
	_exiting = true
	_mutex.unlock()
	_semaphore.post()
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()

# Publie un nouvel état. Ré-appeler avec le même état et le même contexte est
# un no-op : indispensable, plusieurs appelants légitimes (retour de scène,
# annulation de file d'attente) repassent par le même état, et redémarrer le
# chrono à chaque fois donnerait un temps de partie faux.
#
# `ctx` : voir `DiscordActivity.details_key` (`ranked`, `vs_ai`, `tutorial`).
func set_state(state: String, ctx: Dictionary = {}) -> void:
	if not _enabled:
		return
	if state == _state and ctx == _ctx:
		return
	_state = state
	_ctx = ctx.duplicate(true)
	# Le chrono affiché par Discord repart au changement d'état : c'est
	# exactement le "temps de jeu" attendu en partie (durée du match), et le
	# temps passé dans le menu / la file d'attente ailleurs.
	_state_started_unix = int(Time.get_unix_time_from_system())
	_queue_update()

# Efface la présence (sortie de jeu propre). Discord l'efface aussi de lui-même
# à la fermeture du pipe, donc c'est surtout utile pour un arrêt explicite.
func clear_state() -> void:
	if not _enabled:
		return
	_state = ""
	_ctx = {}
	_state_started_unix = 0
	_mutex.lock()
	_pending_activity = {}
	_has_pending = true
	_mutex.unlock()
	_semaphore.post()

func _on_language_changed(_locale: String) -> void:
	if _state != "":
		_queue_update()

func _queue_update() -> void:
	# Le dernier état déposé avant l'échéance est celui qui sera envoyé
	# (coalescence) : pas besoin de replanifier si un flush est déjà armé.
	if not _flush_timer.is_stopped():
		return
	var delay_msec := SEND_DEBOUNCE_MSEC
	if _last_send_msec != 0:
		var remaining := MIN_SEND_INTERVAL_MSEC - (Time.get_ticks_msec() - _last_send_msec)
		delay_msec = maxi(delay_msec, remaining)
	_flush_timer.start(float(delay_msec) / 1000.0)

func _flush() -> void:
	if _state == "":
		return
	var details := SettingsManager.t(DiscordActivity.details_key(_state, _ctx))
	var activity := DiscordActivity.build_activity(details, _state_started_unix)
	_mutex.lock()
	_pending_activity = activity
	_has_pending = true
	_mutex.unlock()
	_last_send_msec = Time.get_ticks_msec()
	_semaphore.post()

# ─── Thread IPC ───────────────────────────────────────────────────────────────

func _ipc_loop() -> void:
	while true:
		_semaphore.wait()
		_mutex.lock()
		var exiting := _exiting
		var has_pending := _has_pending
		var activity: Dictionary = _pending_activity.duplicate(true)
		_has_pending = false
		_mutex.unlock()
		if exiting:
			break
		if not has_pending:
			continue
		if _pipe == null:
			if Time.get_ticks_msec() < _next_connect_attempt_msec:
				continue
			if not _connect():
				_next_connect_attempt_msec = Time.get_ticks_msec() + RECONNECT_DELAY_MSEC
				continue
		if not _send_activity(activity):
			_disconnect()
			_next_connect_attempt_msec = Time.get_ticks_msec() + RECONNECT_DELAY_MSEC
	_disconnect()

func _connect() -> bool:
	for index in PIPE_INDEX_MAX + 1:
		var pipe := FileAccess.open(PIPE_PATH_FORMAT % index, FileAccess.READ_WRITE)
		if pipe == null:
			continue
		_pipe = pipe
		if _write_frame(DiscordActivity.OP_HANDSHAKE, DiscordActivity.handshake_payload(CLIENT_ID)):
			var reply := _read_frame()
			if reply.get("evt", "") == "READY":
				return true
		_disconnect()
	return false

func _send_activity(activity: Dictionary) -> bool:
	_nonce_counter += 1
	var payload: Dictionary
	if activity.is_empty():
		# Une activité nulle est la façon documentée d'effacer la présence.
		payload = DiscordActivity.set_activity_payload({}, OS.get_process_id(), str(_nonce_counter))
		payload["args"]["activity"] = null
	else:
		payload = DiscordActivity.set_activity_payload(activity, OS.get_process_id(), str(_nonce_counter))
	if not _write_frame(DiscordActivity.OP_FRAME, payload):
		return false
	# Discord répond exactement une trame par requête : la lire est ce qui
	# garde le tampon entrant du pipe vide (sinon il finit par se remplir) et
	# ce qui permet de détecter un client Discord fermé.
	return not _read_frame().is_empty()

func _write_frame(opcode: int, payload: Dictionary) -> bool:
	if _pipe == null:
		return false
	_pipe.store_buffer(DiscordActivity.encode_frame(opcode, payload))
	_pipe.flush()
	return _pipe.get_error() == OK

# Lit une trame complète. Retourne le corps JSON décodé, ou un dictionnaire
# vide en cas d'échec (pipe fermé, délai dépassé, JSON invalide).
func _read_frame() -> Dictionary:
	var header := _read_exactly(DiscordActivity.HEADER_SIZE)
	var parsed_header := DiscordActivity.decode_header(header)
	if parsed_header.is_empty():
		return {}
	var length := int(parsed_header["length"])
	if length <= 0:
		return {}
	var body := _read_exactly(length)
	if body.size() < length:
		return {}
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	return parsed if parsed is Dictionary else {}

# `get_buffer()` peut rendre moins d'octets que demandé (trame livrée en
# plusieurs morceaux) ; une lecture sur pipe vide bloque, donc cette boucle
# n'attend activement que dans le cas d'une trame partielle.
func _read_exactly(size: int) -> PackedByteArray:
	var out := PackedByteArray()
	var deadline := Time.get_ticks_msec() + READ_TIMEOUT_MSEC
	while out.size() < size:
		if _pipe == null:
			return out
		var chunk := _pipe.get_buffer(size - out.size())
		if chunk.size() > 0:
			out.append_array(chunk)
			continue
		if _pipe.get_error() != OK or _pipe.eof_reached():
			return out
		if Time.get_ticks_msec() >= deadline:
			return out
		OS.delay_msec(READ_POLL_INTERVAL_MSEC)
	return out

func _disconnect() -> void:
	if _pipe != null:
		_pipe.close()
		_pipe = null
