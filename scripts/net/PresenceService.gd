# PresenceService.gd
extends Node

# Heartbeat périodique de présence (voir POST /api/presence/heartbeat côté
# backend) — alimente le statut en ligne/en jeu/hors ligne affiché aux amis
# (voir FriendsPanel.gd). Tourne tant qu'une session Steam authentifiée existe,
# du menu principal jusqu'en bataille (Battle.gd bascule `in_battle`, voir plus
# bas) : pas besoin de heartbeat une fois le jeu fermé, l'absence de heartbeat
# récent suffit à faire passer le joueur hors ligne côté serveur (fenêtre de
# tolérance ONLINE_WINDOW_SECONDS, voir friendModel.gd côté backend).
const HEARTBEAT_INTERVAL_SECONDS := 45.0

# Mis à jour directement par Battle.gd (_ready/_exit_tree) et MainMenu.gd
# (_ready) plutôt que déduit de la scène courante : plus simple et fiable que
# d'inspecter get_tree().current_scene à chaque battement.
var in_battle: bool = false

var _timer: Timer

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = HEARTBEAT_INTERVAL_SECONDS
	_timer.autostart = true
	_timer.timeout.connect(_send_heartbeat)
	add_child(_timer)
	# Premier battement immédiat (sans attendre le premier tick du timer) dès
	# qu'une session existe — sinon un joueur qui vient de se connecter
	# resterait "hors ligne" aux yeux de ses amis jusqu'à 45s.
	_send_heartbeat()

func _send_heartbeat() -> void:
	if not BackendClient.is_authenticated():
		return
	BackendClient.send_presence_heartbeat(in_battle)
