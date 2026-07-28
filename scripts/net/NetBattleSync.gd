extends Node
class_name NetBattleSync

# Salle d'attente entre la fin du handshake (NetHandshake) et le chargement de
# Battle.tscn : sans elle, chaque client appelle change_scene_to_file dès que
# SON handshake local est fini, indépendamment du rythme de l'autre — un
# joueur peut donc se retrouver en bataille (et dérouler son mulligan) pendant
# que l'autre est encore au lobby.
#
# Fonctionne comme NetHandshake (renvoi périodique tant que le pair n'a pas
# confirmé) mais sans accusé de réception dédié : chaque camp renvoie son
# propre BATTLE_READY jusqu'à avoir reçu celui du pair, ce qui suffit à
# garantir la livraison malgré la fenêtre de course où l'un des deux peut
# émettre avant que l'autre ait connecté son écouteur.

signal completed
signal progress(message: String)

const RESEND_INTERVAL := 1.0

var _net: NetworkManager
var _local_ready := false
var _remote_ready := false
var _finished := false
var _resend_clock := 0.0
var _resend_count := 0

func _init(net: NetworkManager) -> void:
	_net = net
	_net.command_received.connect(_on_command_received)

func start() -> void:
	if _local_ready:
		return
	_local_ready = true
	_send_ready()
	_try_finish()

func _process(delta: float) -> void:
	if _finished or not _local_ready or _remote_ready:
		return
	_resend_clock += delta
	if _resend_clock < RESEND_INTERVAL:
		return
	_resend_clock = 0.0
	_resend_count += 1
	_send_ready()
	progress.emit("Synchronisation : prêt renvoyé (%d) — en attente du pair…" % _resend_count)

func _send_ready() -> void:
	_net.send_command(NetCommand.battle_ready())

func _on_command_received(command: Dictionary) -> void:
	if NetCommand.type_of(command) == NetCommand.BATTLE_READY:
		_remote_ready = true
		_try_finish()

func _try_finish() -> void:
	if _local_ready and _remote_ready and not _finished:
		_finished = true
		set_process(false)
		_net.command_received.disconnect(_on_command_received)
		completed.emit()
