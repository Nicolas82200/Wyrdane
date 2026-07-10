extends RefCounted
class_name NetContext

# Passe-plat entre le lobby réseau et la scène Battle, à travers le changement de
# scène. Le lobby y dépose le NetworkManager (reparenté sous la racine de l'arbre
# pour survivre au changement de scène) et le résultat du handshake ; Battle les
# consomme dans son _ready() puis appelle clear().

static var active: bool = false
static var net: NetworkManager = null
static var is_host: bool = false
static var setup: Dictionary = {}

static func clear() -> void:
	active = false
	net = null
	is_host = false
	setup = {}
