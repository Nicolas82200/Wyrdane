extends Node
class_name CombatLogSystem

## Historique des évènements de bataille (cartes jouées, attaques, morts,
## Infection, dégâts auto-infligés) : les triggers d'effets s'exécutent en
## arrière-plan sans retour visuel dédié, ce système donne au joueur une trace
## consultable de ce qui vient de se passer. Chaque entrée est une icône +
## une poignée de segments courts (noms de cartes, nombres) plutôt qu'une
## phrase, pour un rendu compact — voir CombatLogPanel pour l'affichage.

signal entry_added(entry: Dictionary)

const MAX_ENTRIES := 200

var battle
var entries: Array[Dictionary] = []

func init(_battle) -> void:
	battle = _battle

# is_player : true (camp local, coloré) / false (camp adverse, coloré) / null (neutre, gris).
func _seg(text: String, is_player = null) -> Dictionary:
	return {"text": text, "is_player": is_player}

func _add(icon: String, segments: Array) -> void:
	var entry := {"icon": icon, "segments": segments}
	entries.append(entry)
	if entries.size() > MAX_ENTRIES:
		entries.pop_front()
	entry_added.emit(entry)

func _minion_name(minion: Minion) -> String:
	if minion == null or minion.card_data == null:
		return "?"
	return minion.card_data.display_name()

func card_played(card_data: CardData, is_player: bool) -> void:
	var icon := "➕" if card_data.card_type == "Minion" else "✨"
	_add(icon, [_seg(card_data.display_name(), is_player)])

func attack(attacker: Minion, defender: Minion, dmg: int) -> void:
	if dmg <= 0:
		return
	_add("⚔️", [
		_seg(_minion_name(attacker), attacker.owner_is_player),
		_seg("→"),
		_seg(_minion_name(defender), defender.owner_is_player),
		_seg("-%d" % dmg),
	])

func attack_hero(attacker: Minion, target_is_player: bool, dmg: int) -> void:
	if dmg <= 0:
		return
	_add("⚔️", [
		_seg(_minion_name(attacker), attacker.owner_is_player),
		_seg("→"),
		_seg("👑", target_is_player),
		_seg("-%d" % dmg),
	])

func minion_died(minion: Minion) -> void:
	_add("💀", [_seg(_minion_name(minion), minion.owner_is_player)])

func infection_tick(minion: Minion) -> void:
	_add("🧪", [_seg(_minion_name(minion), minion.owner_is_player), _seg("-1")])

func self_damage(is_player: bool, dmg: int) -> void:
	if dmg <= 0:
		return
	_add("🩸", [_seg("👑", is_player), _seg("-%d" % dmg)])
