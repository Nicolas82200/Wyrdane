extends RefCounted
class_name Race

enum Type {
	NONE,
	HUMAN,
	ELF,
	DWARF,
	UNDEAD,
	DEMON,
	ABOMINATION,
}

static func get_race_name(race: int) -> String:
	match race:
		Type.HUMAN:       return "Human"
		Type.ELF:         return "Elf"
		Type.DWARF:       return "Dwarf"
		Type.UNDEAD:      return "Undead"
		Type.DEMON:       return "Demon"
		Type.ABOMINATION: return "Abomination"
		_:                return "None"

## Races dotées d'au moins une carte (utilisé pour ne proposer, dans l'UI,
## que des races effectivement jouables — Elfe/Nain n'ont encore aucune carte).
static func get_implemented_races() -> Array[int]:
	return [Type.HUMAN, Type.UNDEAD, Type.DEMON, Type.ABOMINATION]

static func from_string(s: String) -> int:
	match s:
		"Human":       return Type.HUMAN
		"Elf":         return Type.ELF
		"Dwarf":       return Type.DWARF
		"Undead":      return Type.UNDEAD
		"Demon":       return Type.DEMON
		"Abomination": return Type.ABOMINATION
		_:             return Type.NONE

# Libellé traduit des races distinctes présentes dans un deck (liste de
# resource_path bruts — utile quand on n'a pas de DeckData complet, ex. le
# deck adverse reçu par NetHandshake). Utilisé par l'écran VS (MatchmakingOverlay) et
# l'historique de parties (SettingsManager/MatchHistoryPanel).
static func deck_race_label(card_paths: Array, unknown_key: String = "NET_VS_UNKNOWN_DECK") -> String:
	var race_names: Array[String] = []
	for path in card_paths:
		if not (path is String):
			continue
		var card := load(path) as CardData
		if card == null or card.race == Type.NONE:
			continue
		var race_name := SettingsManager.t("RACE_" + get_race_name(card.race).to_upper())
		if race_name not in race_names:
			race_names.append(race_name)
	if race_names.is_empty():
		return SettingsManager.t(unknown_key)
	return " / ".join(race_names)
