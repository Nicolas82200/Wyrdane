extends RefCounted
class_name SteamService

# Accès centralisé au singleton GodotSteam.
#
# L'extension GodotSteam N'EST PAS une dépendance obligatoire du projet : tout
# passe par Engine.has_singleton("Steam") / Engine.get_singleton("Steam"), donc
# le jeu compile et tourne sans elle (les boutons Steam sont simplement cachés).
#
# ── Installation pour tester le backend Steam ────────────────────────────────
# 1. Télécharger GodotSteam GDExtension (version 4.11+ pour Godot 4.x) :
#    https://github.com/GodotSteam/GodotSteam/releases (asset "gdextension")
# 2. Extraire le dossier `addons/godotsteam/` à la racine du projet
# 3. Lancer le client Steam et être connecté
# 4. L'AppID de test 480 (Spacewar) est utilisé par défaut ci-dessous —
#    à remplacer par le vrai AppID FateBound une fois la page Steam créée
#
# Le singleton n'existant pas à la compilation, tous les appels sont dynamiques
# (aucun typage Steam ici ni dans SteamTransport).

const APP_ID := 480  # Spacewar (AppID de test public Steam)

static var _initialized := false

static func is_available() -> bool:
	return Engine.has_singleton("Steam")

static func steam() -> Object:
	return Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null

# Initialise l'API Steamworks (idempotent). Retourne false si l'extension est
# absente, si le client Steam n'est pas lancé, ou si l'init échoue.
static func ensure_init() -> bool:
	if _initialized:
		return true
	var s := steam()
	if s == null:
		return false
	# Équivalent de steam_appid.txt : permet de lancer depuis l'éditeur sans
	# passer par le client Steam.
	OS.set_environment("SteamAppId", str(APP_ID))
	OS.set_environment("SteamGameId", str(APP_ID))
	# Signature GodotSteam 4.11+ : steamInitEx(app_id, embed_callbacks).
	# embed_callbacks=false : c'est SteamTransport.poll() qui pompe les callbacks.
	var result: Dictionary = s.steamInitEx(APP_ID, false)
	if result.get("status", 1) != 0:
		push_warning("SteamService : init Steam échouée — %s" % [result.get("verbal", "raison inconnue")])
		return false
	_initialized = true
	return true

# À appeler chaque frame tant qu'une session Steam est active : fait avancer
# les callbacks Steamworks (lobby, P2P...).
static func run_callbacks() -> void:
	if _initialized:
		steam().run_callbacks()

# Pseudo Steam du joueur local (chaîne vide si indisponible).
static func local_persona_name() -> String:
	var s := steam()
	return s.getPersonaName() if _initialized and s != null else ""
