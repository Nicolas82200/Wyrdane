extends Node
class_name CombatLogSystem

## Historique des évènements de bataille (cartes jouées, attaques, morts,
## Infection, dégâts auto-infligés) : les triggers d'effets s'exécutent en
## arrière-plan sans retour visuel dédié, ce système donne au joueur une trace
## consultable de ce qui vient de se passer. Chaque entrée est un badge
## d'icône coloré par camp + une poignée de courts segments (miniatures
## d'illustration de carte, cœur pour le héros, texte pour les nombres)
## plutôt qu'une phrase, pour un rendu compact — voir CombatLogPanel pour
## l'affichage. Un deuxième type d'entrée ("turn") sépare visuellement les
## tours, à la manière du journal de combat de Hearthstone.

signal entry_added(entry: Dictionary)

const MAX_ENTRIES := 200

var battle
var entries: Array[Dictionary] = []
var _turn_number: int = 0

func init(_battle) -> void:
	battle = _battle

# is_player : true (camp local, coloré) / false (camp adverse, coloré) / null (neutre, gris).
func _seg_text(text: String, is_player = null) -> Dictionary:
	return {"type": "text", "text": text, "is_player": is_player}

func _seg_card(card_data: CardData, is_player: bool, is_dead: bool = false) -> Dictionary:
	if card_data == null:
		return _seg_text("?", is_player)
	return {"type": "card", "texture": card_data.texture, "name": card_data.display_name(), "is_player": is_player, "dead": is_dead}

# Segment "perte" (dégâts) : toujours mis en avant visuellement (rouge/gras),
# indépendamment du camp qui subit la perte — c'est la mauvaise nouvelle de
# la ligne, elle doit sauter aux yeux avant même de lire qui elle touche.
func _seg_dmg(amount: int) -> Dictionary:
	return {"type": "dmg", "text": "-%d" % amount}

# Segment "héros" : remplace la cible par un cœur coloré par camp plutôt
# qu'une lettre "H" ambiguë.
func _seg_hero(is_player: bool) -> Dictionary:
	return {"type": "hero", "is_player": is_player}

func _add(icon: String, actor_is_player, segments: Array) -> void:
	var entry := {"kind": "event", "icon": icon, "actor_is_player": actor_is_player, "segments": segments}
	entries.append(entry)
	if entries.size() > MAX_ENTRIES:
		entries.pop_front()
	entry_added.emit(entry)

# Séparateur de tour : is_player désigne le camp dont le tour commence.
func turn_started(is_player: bool) -> void:
	_turn_number += 1
	var entry := {"kind": "turn", "turn_number": _turn_number, "is_player": is_player}
	entries.append(entry)
	if entries.size() > MAX_ENTRIES:
		entries.pop_front()
	entry_added.emit(entry)

func card_played(card_data: CardData, is_player: bool) -> void:
	var icon := "play_minion" if card_data.card_type == "Minion" else "play_spell"
	_add(icon, is_player, [_seg_card(card_data, is_player)])

func attack(attacker: Minion, defender: Minion, dmg: int, attacker_dead: bool = false, defender_dead: bool = false) -> void:
	if dmg <= 0 and not attacker_dead and not defender_dead:
		return
	_add("attack", attacker.owner_is_player, [
		_seg_card(attacker.card_data, attacker.owner_is_player, attacker_dead),
		_seg_text(">"),
		_seg_card(defender.card_data, defender.owner_is_player, defender_dead),
		_seg_dmg(dmg),
	])

func attack_hero(attacker: Minion, target_is_player: bool, dmg: int) -> void:
	if dmg <= 0:
		return
	_add("attack", attacker.owner_is_player, [
		_seg_card(attacker.card_data, attacker.owner_is_player),
		_seg_text(">"),
		_seg_hero(target_is_player),
		_seg_dmg(dmg),
	])

func minion_died(minion: Minion) -> void:
	_add("death", minion.owner_is_player, [_seg_card(minion.card_data, minion.owner_is_player)])

func infection_tick(minion: Minion, dealt: int = 1) -> void:
	_add("infection", minion.owner_is_player, [_seg_card(minion.card_data, minion.owner_is_player), _seg_dmg(dealt)])

func self_damage(is_player: bool, dmg: int) -> void:
	if dmg <= 0:
		return
	_add("self_damage", is_player, [_seg_hero(is_player), _seg_dmg(dmg)])
