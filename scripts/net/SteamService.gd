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
# 4. L'AppID Wyrdane (5052390) est utilisé ci-dessous. La page Steam est en
#    attente de validation par Valve : en attendant, seuls les comptes ajoutés
#    comme testeurs dans Steamworks (onglet « Users with access ») peuvent
#    s'authentifier avec cet AppID — les autres comptes doivent temporairement
#    repasser sur l'AppID de test public 480 (Spacewar) pour développer.
#
# ⚠ Le backend Steam NE PEUT PAS se tester avec deux instances locales du jeu :
# elles partagent le même compte Steam, or les lobbies/P2P Steamworks exigent
# deux comptes distincts (l'hôte ne voit jamais « entrer » son propre compte).
# SteamTransport détecte ce cas et affiche NET_STEAM_SAME_ACCOUNT. Le
# multijoueur ne peut donc se tester qu'avec deux machines/sessions et deux
# comptes Steam distincts (plus de mode IP/LAN de secours pour tester en local).
#
# Le singleton n'existant pas à la compilation, tous les appels sont dynamiques
# (aucun typage Steam ici ni dans SteamTransport).

const APP_ID := 5052390  # AppID Wyrdane (page en attente de validation Valve)

static var _initialized := false
static var _join_requested_callback := Callable()
static var _join_signal_connected := false

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
	# Autorise explicitement le relais Steam (TURN-like) en secours quand la
	# connexion P2P directe échoue (NAT strict, pare-feu). Normalement activé
	# par défaut, mais on le force pour ne laisser aucun doute.
	if s.has_method("allowP2PPacketRelay"):
		s.allowP2PPacketRelay(true)
	# Requis par l'API Networking Sockets (voir SteamTransport) : initialise la
	# connexion au réseau de relais Steam avant la première tentative P2P, pour
	# ne pas perdre de temps à l'établir seulement au moment du premier connectP2P.
	if s.has_method("initRelayNetworkAccess"):
		s.initRelayNetworkAccess()
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

# SteamID64 du joueur local sous forme de chaîne (vide si indisponible).
static func local_steam_id() -> String:
	var s := steam()
	if not _initialized or s == null:
		return ""
	return str(s.getSteamID())

# Avatar Steam du joueur local (résolution moyenne, 64×64), ou null si
# indisponible (Steam absent, ou avatar pas encore mis en cache par le
# client Steam — dans ce cas on ne l'attend pas, on affiche juste sans).
static func local_avatar_texture() -> ImageTexture:
	var s := steam()
	if not _initialized or s == null:
		return null
	var steam_id: int = s.getSteamID()
	var handle: int = s.getMediumFriendAvatar(steam_id)
	if handle <= 0:
		return null
	var size: Dictionary = s.getImageSize(handle)
	if not size.get("success", false):
		return null
	var rgba: Dictionary = s.getImageRGBA(handle)
	if not rgba.get("success", false):
		return null
	var image := Image.create_from_data(size["width"], size["height"], false, Image.FORMAT_RGBA8, rgba["buffer"])
	return ImageTexture.create_from_image(image)

# Écoute les demandes de rejoindre un lobby via ami Steam (overlay « Rejoindre
# la partie », invitation acceptée) — indépendamment de tout host()/join() déjà
# en cours côté SteamTransport. À appeler dès l'arrivée sur l'écran multijoueur
# pour capter une invitation même avant que le joueur ait cliqué un bouton :
# initialise Steam si besoin (idempotent) et pompe les callbacks à chaque appel
# de run_callbacks(), qu'une session de jeu soit active ou non.
# Callback appelé avec (lobby_id: int) quand une demande arrive.
static func watch_join_requests(on_join_requested: Callable) -> bool:
	if not ensure_init():
		return false
	_join_requested_callback = on_join_requested
	var s := steam()
	if not _join_signal_connected:
		s.connect("join_requested", _on_join_requested)
		_join_signal_connected = true
	return true

static func _on_join_requested(lobby_id: int, _friend_id: int = 0) -> void:
	if _join_requested_callback.is_valid():
		_join_requested_callback.call(lobby_id)
