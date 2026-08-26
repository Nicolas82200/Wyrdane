extends Node
class_name CombatLogSystem

## Historique des évènements de bataille (cartes jouées, attaques, morts,
## Infection, dégâts auto-infligés) : les triggers d'effets s'exécutent en
## arrière-plan sans retour visuel dédié, ce système donne au joueur une trace
## consultable de ce qui vient de se passer. Chaque entrée est une icône +
## une poignée de courts segments (miniatures d'illustration de carte, ou
## texte pour les nombres/flèches) plutôt qu'une phrase, pour un rendu
## compact — voir CombatLogPanel pour l'affichage.

signal entry_added(entry: Dictionary)

const MAX_ENTRIES := 200

var battle
var entries: Array[Dictionary] = []

func init(_battle) -> void:
	battle = _battle

# is_player : true (camp local, coloré) / false (camp adverse, coloré) / null (neutre, gris).
func _seg_text(text: String, is_player = null) -> Dictionary:
	return {"type": "text", "text": text, "is_player": is_player}

func _seg_card(card_data: CardData, is_player: bool, is_dead: bool = false) -> Dictionary:
	if card_data == null:
		return _seg_text("?", is_player)
	return {"type": "card", "texture": card_data.texture, "name": card_data.display_name(), "is_player": is_player, "dead": is_dead}

func _add(icon: String, segments: Array) -> void:
	var entry := {"icon": icon, "segments": segments}
	entries.append(entry)
	if entries.size() > MAX_ENTRIES:
		entries.pop_front()
	entry_added.emit(entry)

func card_played(card_data: CardData, is_player: bool) -> void:
	var icon := "+" if card_data.card_type == "Minion" else "*"
	_add(icon, [_seg_card(card_data, is_player)])

func attack(attacker: Minion, defender: Minion, dmg: int, attacker_dead: bool = false, defender_dead: bool = false) -> void:
	if dmg <= 0 and not attacker_dead and not defender_dead:
		return
	_add(">", [
		_seg_card(attacker.card_data, attacker.owner_is_player, attacker_dead),
		_seg_text(">"),
		_seg_card(defender.card_data, defender.owner_is_player, defender_dead),
		_seg_text("-%d" % dmg),
	])

func attack_hero(attacker: Minion, target_is_player: bool, dmg: int) -> void:
	if dmg <= 0:
		return
	_add(">", [
		_seg_card(attacker.card_data, attacker.owner_is_player),
		_seg_text(">"),
		_seg_text("H", target_is_player),
		_seg_text("-%d" % dmg),
	])

func minion_died(minion: Minion) -> void:
	_add("X", [_seg_card(minion.card_data, minion.owner_is_player)])

func infection_tick(minion: Minion, dealt: int = 1) -> void:
	_add("Inf.", [_seg_card(minion.card_data, minion.owner_is_player), _seg_text("-%d" % dealt)])

func self_damage(is_player: bool, dmg: int) -> void:
	if dmg <= 0:
		return
	_add("!", [_seg_text("H", is_player), _seg_text("-%d" % dmg)])
