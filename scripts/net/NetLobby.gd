extends Control

# Point d'entrée du multijoueur, entièrement backend Steam (lobby + P2P
# Steamworks — voir SteamTransport/SteamService). Sans l'extension GodotSteam
# installée ou sans client Steam lancé, les boutons restent affichés mais
# échouent proprement avec un message (voir NET_STEAM_UNAVAILABLE) plutôt que
# de disparaître : mieux vaut un échec explicite qu'un écran vide.
#
# « Héberger » crée un lobby public tagué Wyrdane et attend un adversaire.
# « Partie rapide » est un vrai matchmaking : elle cherche un lobby existant
# et, si aucun n'est trouvé, héberge automatiquement à la place (le joueur n'a
# qu'un bouton à presser, pas besoin de coordonner qui héberge).
# « Inviter un ami » ouvre l'overlay Steam pour le lobby en cours (hôte
# uniquement). Dès l'arrivée sur cet écran, on écoute aussi les demandes de
# rejoindre reçues via une invitation Steam acceptée (overlay ami, lien
# « Rejoindre la partie ») : le jeu doit déjà tourner et être sur cet écran —
# le cas « jeu pas encore lancé » (+connect_lobby en ligne de commande) n'est
# pas géré ici.
#
# UI reprise du même habillage que MainMenu (fond vidéo, vignette, panneau
# doré) : voir scenes/net/NetLobby.tscn.

const BATTLE_SCENE := "res://scenes/battle/Battle.tscn"
const MAIN_MENU_SCENE := "res://scenes/mainMenu/MainMenu.tscn"

@onready var host_button:        Button = $NavPanel/NavMargin/VBoxContainer/HostButton
@onready var quick_match_button: Button = $NavPanel/NavMargin/VBoxContainer/QuickMatchButton
@onready var invite_button:      Button = $NavPanel/NavMargin/VBoxContainer/InviteButton
@onready var back_button:        Button = $NavPanel/NavMargin/VBoxContainer/BackButton
@onready var title_label:        Label  = $TitleLabel
@onready var subtitle_label:     Label  = $SubtitleLabel
@onready var status_title_label: Label  = $StatusPanel/StatusMargin/StatusVBox/StatusTitleLabel
@onready var _log:               RichTextLabel = $StatusPanel/StatusMargin/StatusVBox/LogPanel/Log

var _net: NetworkManager
var _handshake: NetHandshake
var _battle_sync: NetBattleSync
var _quick_matching := false  # bascule join→host en cours ; voir _on_peer_disconnected

func _ready() -> void:
	_net = NetworkManager.new()
	add_child(_net)
	_net.peer_connected.connect(_on_peer_connected)
	_net.peer_disconnected.connect(_on_peer_disconnected)
	_net.status.connect(_log_line)
	host_button.pressed.connect(_on_steam_host_pressed)
	quick_match_button.pressed.connect(_on_steam_quick_pressed)
	invite_button.pressed.connect(_on_steam_invite_pressed)
	back_button.pressed.connect(_on_back_pressed)
	SettingsManager.language_changed.connect(func(_l): _retranslate())
	_retranslate()
	if SteamService.is_available():
		SteamService.watch_join_requests(_on_steam_join_requested)

func _process(_delta: float) -> void:
	# Pompe les callbacks Steam même hors session active, pour capter une
	# invitation reçue pendant qu'on est simplement sur cet écran (voir
	# SteamService.watch_join_requests). Sans effet si Steam pas initialisé.
	if SteamService.is_available():
		SteamService.run_callbacks()

func _log_line(text: String) -> void:
	_log.append_text(text + "\n")

func _retranslate() -> void:
	title_label.text        = SettingsManager.t("MENU_MULTIPLAYER")
	subtitle_label.text     = SettingsManager.t("NET_LOBBY_SUBTITLE")
	status_title_label.text = SettingsManager.t("NET_STATUS_TITLE")
	host_button.text        = SettingsManager.t("NET_STEAM_HOST")
	quick_match_button.text = SettingsManager.t("NET_STEAM_QUICK")
	invite_button.text      = SettingsManager.t("NET_STEAM_INVITE")
	back_button.text        = SettingsManager.t("NET_BACK")

# ─── Actions UI ───────────────────────────────────────────────────────────────

func _on_steam_host_pressed() -> void:
	_quick_matching = false
	var err := _net.host_game_with(TransportFactory.Backend.STEAM)
	if err == OK:
		_log_line(SettingsManager.t("NET_STEAM_HOSTING"))
	else:
		_log_line(SettingsManager.t("NET_STEAM_UNAVAILABLE"))

func _on_steam_quick_pressed() -> void:
	_quick_matching = true
	var err := _net.join_game_with(TransportFactory.Backend.STEAM)
	if err == OK:
		_log_line(SettingsManager.t("NET_STEAM_SEARCHING"))
	else:
		_quick_matching = false
		_log_line(SettingsManager.t("NET_STEAM_UNAVAILABLE"))

func _on_steam_invite_pressed() -> void:
	_net.invite_friends()

func _on_back_pressed() -> void:
	# Coupe une éventuelle connexion en cours avant de revenir au menu.
	_net.close()
	AudioManager.play(AudioManager.CLOSE_MENU)
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

# ─── Connexion → handshake → bataille ─────────────────────────────────────────

func _on_peer_connected() -> void:
	_quick_matching = false
	print("[NetLobby] _on_peer_connected  self=%s  handshake_deja_present=%s" % [self, _handshake != null])
	_log_line("✓ Pair connecté — handshake…")
	_set_actions_enabled(false)
	_handshake = NetHandshake.new(_net, _local_deck_paths(), _net.is_host)
	add_child(_handshake)
	_handshake.completed.connect(_on_handshake_ready)
	_handshake.progress.connect(_log_line)
	_handshake.start()

# Boutons de lancement de partie désactivés dès qu'une connexion pair-à-pair
# est en cours (handshake/synchronisation) : les relancer casserait l'état de
# _net. Le bouton Retour reste actif pour permettre d'annuler.
func _set_actions_enabled(enabled: bool) -> void:
	host_button.disabled = not enabled
	quick_match_button.disabled = not enabled
	invite_button.disabled = not enabled

func _on_peer_disconnected(reason: String) -> void:
	match reason:
		"steam_same_account":
			_quick_matching = false
			_set_actions_enabled(true)
			_log_line(SettingsManager.t("NET_STEAM_SAME_ACCOUNT"))
		"steam_no_lobby_found":
			if _quick_matching:
				_log_line(SettingsManager.t("NET_STEAM_NO_LOBBY_HOSTING"))
				_start_quick_match_host()
			else:
				_set_actions_enabled(true)
				_log_line(SettingsManager.t("NET_STEAM_NO_LOBBY"))
		_:
			_quick_matching = false
			_set_actions_enabled(true)
			_log_line("✗ Pair déconnecté (%s)" % [reason])

# Partie rapide sans adversaire trouvé : on héberge à la place plutôt que de
# laisser le joueur relancer manuellement (voir _on_steam_quick_pressed).
func _start_quick_match_host() -> void:
	_quick_matching = false
	var err := _net.host_game_with(TransportFactory.Backend.STEAM)
	if err == OK:
		_log_line(SettingsManager.t("NET_STEAM_HOSTING"))
	else:
		_log_line(SettingsManager.t("NET_STEAM_UNAVAILABLE"))

# Invitation Steam acceptée (overlay ami / lien « Rejoindre la partie ») alors
# que le joueur est déjà sur cet écran : on rejoint directement ce lobby.
func _on_steam_join_requested(lobby_id: int) -> void:
	_quick_matching = false
	_log_line(SettingsManager.t("NET_STEAM_INVITE_RECEIVED"))
	var err := _net.join_game_with(TransportFactory.Backend.STEAM, {"lobby_id": lobby_id})
	if err == OK:
		_log_line(SettingsManager.t("NET_STEAM_SEARCHING"))
	else:
		_log_line(SettingsManager.t("NET_STEAM_UNAVAILABLE"))

# Deck local mélangé, sous forme de resource_path (identifiant partagé).
func _local_deck_paths() -> Array:
	var active := DeckManager.get_active_deck()
	if active == null:
		return []
	var paths: Array = active.card_paths.duplicate()
	paths.shuffle()
	return paths

func _on_handshake_ready(setup: Dictionary) -> void:
	print("[NetLobby] _on_handshake_ready  self=%s  in_tree=%s" % [self, is_inside_tree()])
	_log_line(SettingsManager.t("NET_WAITING_OPPONENT"))
	status_title_label.text = SettingsManager.t("NET_STATUS_SYNCING")
	NetContext.active = true
	NetContext.net = _net
	NetContext.is_host = _net.is_host
	NetContext.setup = setup
	# Sans cette étape, chaque client basculerait sur Battle.tscn dès que SON
	# handshake local est fini, indépendamment du pair — un joueur pouvait
	# démarrer son mulligan pendant que l'autre était encore au lobby. On
	# n'entre en bataille qu'une fois les deux prêts (voir NetBattleSync).
	_battle_sync = NetBattleSync.new(_net)
	add_child(_battle_sync)
	_battle_sync.completed.connect(_on_battle_sync_ready)
	_battle_sync.progress.connect(_log_line)
	_battle_sync.start()

func _on_battle_sync_ready() -> void:
	_log_line("Adversaire prêt — lancement de la bataille réseau…")
	# Le NetworkManager doit survivre au changement de scène : on le reparente
	# sous la racine de l'arbre avant de charger Battle.
	_net.get_parent().remove_child(_net)
	get_tree().root.add_child(_net)
	get_tree().change_scene_to_file(BATTLE_SCENE)
