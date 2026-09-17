extends Node

# Détecte qu'une session précédente s'est terminée anormalement (plantage réel,
# ou gel forcé à fermer via le gestionnaire des tâches — les deux ont la même
# signature de ce point de vue : aucune sortie propre n'a eu lieu) et propose
# d'envoyer le dernier log au prochain lancement (voir MainMenu, popup
# CrashReportPopup). Aucune détection "en direct" pendant le plantage lui-même
# (le processus est déjà mort) : tout se joue au lancement SUIVANT, en
# comparant un marqueur écrit sur disque à chaque session.
#
# Marqueur : user://crash_marker.cfg — clean_exit=false dès le début de CHAQUE
# session, remis à true uniquement à une sortie propre (bouton Quitter, ou
# fermeture de la fenêtre, voir _notification ci-dessous). Un heartbeat
# périodique met aussi à jour last_heartbeat, pour dater approximativement un
# plantage/gel même sans sortie propre.

const MARKER_PATH := "user://crash_marker.cfg"
const HEARTBEAT_INTERVAL_SECONDS := 10.0
# Nombre de caractères de fin de log envoyés (le crash/gel est toujours la
# dernière chose écrite avant l'arrêt) ; le backend retronque de toute façon
# à ~950 caractères pour tenir dans un field Discord, cette marge sert juste
# à ne pas lire un fichier de log entier en mémoire si énorme.
const LOG_TAIL_CHARS := 20000

var _pending_report: bool = false
var _pending_timestamp: float = 0.0
var _dismissed: bool = false

func _ready() -> void:
	_check_previous_session()
	_write_marker(false)
	var timer := Timer.new()
	timer.wait_time = HEARTBEAT_INTERVAL_SECONDS
	timer.autostart = true
	timer.timeout.connect(func(): _write_marker(false))
	add_child(timer)

# Fermeture par la croix de la fenêtre / Alt+F4 : la seule sortie qui ne passe
# pas par un bouton "Quitter" explicite dans le jeu (voir MainMenu._on_quit,
# qui appelle mark_clean_exit_and_quit ci-dessous).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		mark_clean_exit_and_quit()

func mark_clean_exit_and_quit() -> void:
	_write_marker(true)
	get_tree().quit()

func _check_previous_session() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(MARKER_PATH) != OK:
		return  # Premier lancement, ou fichier absent/corrompu : rien à signaler.
	var clean_exit: bool = cfg.get_value("session", "clean_exit", true)
	if clean_exit:
		return
	_pending_report = true
	_pending_timestamp = cfg.get_value("session", "last_heartbeat", 0.0)

func _write_marker(clean_exit: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("session", "clean_exit", clean_exit)
	cfg.set_value("session", "last_heartbeat", Time.get_unix_time_from_system())
	cfg.save(MARKER_PATH)

func has_pending_report() -> bool:
	return _pending_report and not _dismissed

# Appelé une fois la popup traitée (envoyée ou ignorée), pour qu'elle ne
# réapparaisse pas à chaque écran tant que le jeu tourne.
func dismiss_pending_report() -> void:
	_dismissed = true

func get_pending_timestamp() -> float:
	return _pending_timestamp

# Repère le fichier de log de la session précédente : Godot a déjà tourné
# godot.log vers un fichier horodaté (godotYYYY-MM-DDTHH.MM.SS.log, voir
# logs/) au moment où CE lancement démarre — godot.log courant est donc déjà
# celui de la session EN COURS, pas celui qui a planté. On prend le fichier
# horodaté le plus récent du dossier.
func _find_previous_log_path() -> String:
	var logs_dir := "user://logs/"
	var dir := DirAccess.open(logs_dir)
	if dir == null:
		return ""
	var best_path := ""
	var best_time := 0
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.begins_with("godot") and file_name != "godot.log" and file_name.ends_with(".log"):
			var full_path := logs_dir + file_name
			var mtime := FileAccess.get_modified_time(full_path)
			if mtime > best_time:
				best_time = mtime
				best_path = full_path
		file_name = dir.get_next()
	dir.list_dir_end()
	return best_path

func get_previous_log_tail() -> String:
	var path := _find_previous_log_path()
	if path == "":
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var content := file.get_as_text()
	file.close()
	if content.length() > LOG_TAIL_CHARS:
		content = content.substr(content.length() - LOG_TAIL_CHARS)
	return content

# crash_type : "crash" ou "freeze" (choix fait par le joueur dans la popup,
# cette détection ne peut pas distinguer les deux automatiquement).
func send_report(crash_type: String, on_complete: Callable = Callable()) -> void:
	var log_tail := get_previous_log_tail()
	var steam_name := SteamService.local_persona_name()
	var reporter_name := steam_name if steam_name != "" else "anonyme"
	var body := {
		"crashType": crash_type,
		"platform": "%s %s" % [OS.get_name(), OS.get_version()],
		"gameVersion": Engine.get_version_info().get("string", "inconnue"),
		"reporterName": reporter_name,
		"log": log_tail,
	}
	BackendClient.request(HTTPClient.METHOD_POST, "/api/crash-report", body, func(code: int, _parsed: Variant):
		if on_complete.is_valid():
			on_complete.call(code == 200)
	)
