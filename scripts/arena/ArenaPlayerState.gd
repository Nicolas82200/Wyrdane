extends RefCounted
class_name ArenaPlayerState

# État persistant d'un participant Arena entre les rounds (voir README
# « Mode Battle Royale »). Les cartes possédées (main/plateau) sont des
# `Minion` (pas des `CardData` bruts) : Minion sépare déjà stats permanentes
# (base_attack/base_max_health) et état de combat temporaire (damage_taken),
# ce qui permet de "reset l'état de vie, jamais les stats permanentes" entre
# rounds en ne remettant à zéro que damage_taken.

var display_name: String
var is_bot: bool = false
var is_eliminated: bool = false

var hero_hp: int = ArenaConstants.STARTING_HERO_HP
var gold: int = ArenaConstants.STARTING_GOLD
var xp: int = 0
var level: int = 1

var hand: Array[Minion] = []
var board_front: Array[Minion] = []
var board_back: Array[Minion] = []
# Cartes en attente d'une place en main libre (fusion produite main pleine).
var suspended: Array[Minion] = []

var shop_offer: Array[CardData] = []
# Parallèle à shop_offer : une case verrouillée n'est pas re-tirée au reroll.
var shop_locked: Array[bool] = []

func _init(name: String, bot: bool = false) -> void:
	display_name = name
	is_bot = bot

func is_alive() -> bool:
	return not is_eliminated and hero_hp > 0

func all_owned_minions() -> Array[Minion]:
	var result: Array[Minion] = []
	result.append_array(hand)
	result.append_array(board_front)
	result.append_array(board_back)
	return result

func hand_count() -> int:
	return hand.size() + suspended.size()

# Places physiques en main occupées (les cartes suspendues n'occupent aucune
# place tant qu'elles n'ont pas rejoint la main).
func is_hand_full() -> bool:
	return hand.size() >= ArenaConstants.HAND_MAX

# Ajoute une carte en main, ou en suspens si la main est pleine ; libère
# automatiquement les cartes suspendues dès qu'une place se libère.
func add_to_hand(minion: Minion) -> void:
	if is_hand_full():
		suspended.append(minion)
	else:
		hand.append(minion)
	_release_suspended()

func _release_suspended() -> void:
	while not suspended.is_empty() and not is_hand_full():
		hand.append(suspended.pop_front())

func remove_from_hand(minion: Minion) -> void:
	hand.erase(minion)
	suspended.erase(minion)
	_release_suspended()

# Défausse aléatoire de l'excédent si main+suspens dépassent HAND_MAX
# (appelé en fin de phase Positionnement, voir README).
func discard_overflow(rng: RandomNumberGenerator) -> Array[Minion]:
	var discarded: Array[Minion] = []
	while hand_count() > ArenaConstants.HAND_MAX:
		var pool: Array[Minion] = hand if not hand.is_empty() else suspended
		var index := rng.randi() % pool.size()
		discarded.append(pool[index])
		pool.remove_at(index)
	return discarded

func board_row(is_front: bool) -> Array[Minion]:
	return board_front if is_front else board_back

func can_place_on_row(is_front: bool) -> bool:
	return board_row(is_front).size() < ArenaConstants.BOARD_ROW_MAX

# Pose gratuite (déjà payée en boutique) : retire de la main, ajoute au plateau.
func place_on_board(minion: Minion, is_front: bool) -> bool:
	if not can_place_on_row(is_front):
		return false
	if not hand.has(minion):
		return false
	hand.erase(minion)
	minion.board_row = "Front" if is_front else "Back"
	board_row(is_front).append(minion)
	return true

func remove_from_board(minion: Minion) -> void:
	board_front.erase(minion)
	board_back.erase(minion)

# Reset entre rounds : l'état de vie (dégâts, morts temporaires) est effacé,
# jamais les stats permanentes (base_attack/base_max_health/star_level).
func reset_after_combat() -> void:
	for minion in all_owned_minions():
		minion.damage_taken = 0
		minion.attacks_remaining = 0
