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
	ARTIFACT,
}

## Races "sans race" au sens deck/quêtes/coût : jamais comptées dans
## l'identité de race d'un deck (Battle.deck_races, quêtes par race, coût de
## race à payer). NONE = vraiment aucune race (cartes de test, sentinelle
## par défaut) ; ARTIFACT = la race Artefact, volontairement jouable dans
## n'importe quel deck (pas de pool/carte-ressource dédiée).
static func is_raceless(race: int) -> bool:
	return race == Type.NONE or race == Type.ARTIFACT

static func get_race_name(race: int) -> String:
	match race:
		Type.HUMAN:       return "Human"
		Type.ELF:         return "Elf"
		Type.DWARF:       return "Dwarf"
		Type.UNDEAD:      return "Undead"
		Type.DEMON:       return "Demon"
		Type.ABOMINATION: return "Abomination"
		Type.ARTIFACT:    return "Artifact"
		_:                return "None"

## Races dotées d'au moins une carte (utilisé pour ne proposer, dans l'UI,
## que des races effectivement jouables — Elfe/Nain n'ont encore aucune carte).
## Inclut ARTIFACT (filtre du deck builder, ACH_COLLECTOR).
static func get_implemented_races() -> Array[int]:
	return [Type.HUMAN, Type.UNDEAD, Type.DEMON, Type.ABOMINATION, Type.ARTIFACT]

## Sous-ensemble de get_implemented_races() pouvant apparaître dans
## Battle.deck_races (identité de race d'un deck) : exclut les races
## "sans race" au sens is_raceless() (ARTIFACT), qui n'y figurent jamais
## (voir DeckSystem._compute_deck_races) — utilisé par les succès dérivés de
## deck_races (ex. ACH_FULL_ROSTER/SettingsManager.record_race_win), sinon
## structurellement impossibles à débloquer.
static func get_deck_identity_races() -> Array[int]:
	return get_implemented_races().filter(func(r): return not is_raceless(r))

static func from_string(s: String) -> int:
	match s:
		"Human":       return Type.HUMAN
		"Elf":         return Type.ELF
		"Dwarf":       return Type.DWARF
		"Undead":      return Type.UNDEAD
		"Demon":       return Type.DEMON
		"Abomination": return Type.ABOMINATION
		"Artifact":    return Type.ARTIFACT
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
		var race_name := get_race_name(card.race)
		if race_name not in race_names:
			race_names.append(race_name)
	return race_names_label(race_names, unknown_key)

# Même libellé traduit que deck_race_label, mais à partir de noms de race déjà
# résolus (ex. "Human"/"Undead", tels que renvoyés par
# rankedModel.getMatchHistory côté backend, deck_races/opponent_deck_races) —
# pas de CardData à charger. Utilisé par MatchHistoryPanel.
static func race_names_label(race_names: Array, unknown_key: String = "NET_VS_UNKNOWN_DECK") -> String:
	var translated: Array[String] = []
	for race_name in race_names:
		if not (race_name is String):
			continue
		var label := SettingsManager.t("RACE_" + race_name.to_upper())
		if label not in translated:
			translated.append(label)
	if translated.is_empty():
		return SettingsManager.t(unknown_key)
	return " / ".join(translated)
