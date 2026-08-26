# DeckManager.gd
extends Node

# Les decks sont désormais autoritaires côté wyrdane-backend (pas de cache
# hors-ligne) : `decks` n'est peuplé qu'après sync_from_backend(), et toute
# mutation locale est répercutée vers l'API. Seule la préférence "deck actif"
# reste purement locale (aucune notion côté serveur).
const MAX_COPIES_PER_CARD := 4
const ACTIVE_DECK_PATH := "user://active_deck.cfg"

# Règles minimales de validité d'un deck (voir README « Système de Ressources
# par Race ») : plus de plafond de taille, seuls des minimums sont imposés,
# cartes jouables et ressources comptées séparément bien que mélangées dans
# le même paquet. Source unique — DeckBuilder (édition) et l'écran de choix
# du deck à lancer (MainMenu) référencent ces constantes plutôt que de
# recopier leurs propres valeurs.
const MIN_PLAYABLE_CARDS := 40
const MIN_RESOURCE_CARDS := 10
const MIN_TOTAL_CARDS    := MIN_PLAYABLE_CARDS + MIN_RESOURCE_CARDS

var decks: Array[DeckData] = []
var active_deck_index: int = 0

signal decks_loaded
signal sync_failed(reason: String)

func _ready() -> void:
	_load_active_index()

# ─── Sync depuis le backend ───────────────────────────────────────────────────

# À appeler après CardLibrary.sync_backend_catalog() (le mapping id -> carte
# doit exister pour reconstruire card_paths depuis les cardId renvoyés par l'API).
# on_complete (optionnel) est appelé avec (success: bool) une fois la réponse
# reçue — permet à l'écran de chargement d'attendre la fin de la sync.
func sync_from_backend(on_complete: Callable = Callable()) -> void:
	BackendClient.request(HTTPClient.METHOD_GET, "/api/decks", {}, func(code: int, parsed) -> void:
		if code != 200 or not (parsed is Array):
			sync_failed.emit("Impossible de charger les decks (HTTP %d)" % code)
			if on_complete.is_valid():
				on_complete.call(false)
			return
		decks.clear()
		for row in parsed:
			decks.append(_deck_from_api(row))
		active_deck_index = clamp(active_deck_index, 0, max(0, decks.size() - 1))
		decks_loaded.emit()
		if on_complete.is_valid():
			on_complete.call(true)
	)

func _deck_from_api(row: Dictionary) -> DeckData:
	var deck := DeckData.new()
	deck.name = row.get("name", "Deck")
	deck.backend_id = row.get("id", -1)
	var paths: Array[String] = []
	for entry in row.get("cards", []):
		var card: CardData = CardLibrary.card_by_backend_id.get(entry.get("card_id"), null)
		if card == null:
			continue
		for i in range(int(entry.get("quantity", 1))):
			paths.append(card.resource_path)
	deck.card_paths = paths
	return deck

# ─── Deck actif (préférence locale uniquement) ────────────────────────────────

func get_active_deck() -> DeckData:
	if decks.is_empty():
		return null
	active_deck_index = clamp(active_deck_index, 0, decks.size() - 1)
	return decks[active_deck_index]

func set_active_deck(index: int) -> void:
	active_deck_index = clamp(index, 0, decks.size() - 1)
	_save_active_index()

# ─── CRUD ─────────────────────────────────────────────────────────────────────

func create_deck(deck_name: String = "") -> DeckData:
	var deck := DeckData.new()
	if deck_name == "":
		deck_name = SettingsManager.t("deck.default_name")
	deck.name = make_unique_name(deck_name, deck)
	decks.append(deck)
	save_decks()
	return deck

## Retourne base_name tel quel s'il n'est déjà pris par aucun autre deck
## (exclude), sinon lui ajoute le premier suffixe " N" (N = 1, 2, 3...) libre.
func make_unique_name(base_name: String, exclude: DeckData) -> String:
	var taken: Array[String] = []
	for deck in decks:
		if deck != exclude:
			taken.append(deck.name)
	if not (base_name in taken):
		return base_name
	var n := 1
	while ("%s %d" % [base_name, n]) in taken:
		n += 1
	return "%s %d" % [base_name, n]

func delete_deck(index: int) -> void:
	if index < 0 or index >= decks.size():
		return
	var deck := decks[index]
	decks.remove_at(index)
	if active_deck_index >= decks.size():
		active_deck_index = max(0, decks.size() - 1)
	_save_active_index()
	if deck.backend_id >= 0:
		BackendClient.request(HTTPClient.METHOD_DELETE, "/api/decks/%d" % deck.backend_id, {}, func(code: int, _parsed) -> void:
			if code != 204 and code != 200:
				sync_failed.emit("Échec de suppression du deck « %s » (HTTP %d)" % [deck.name, code])
		)

## Duplique le deck à l'index donné (nom + copie suffixée) et l'insère juste après.
func duplicate_deck(index: int) -> DeckData:
	if index < 0 or index >= decks.size():
		return null
	var source := decks[index]
	var copy := DeckData.new()
	copy.name = make_unique_name(source.name + SettingsManager.t("decklist.copy_suffix"), copy)
	copy.card_paths = source.card_paths.duplicate()
	decks.insert(index + 1, copy)
	save_decks()
	return copy

## Ajoute un deck déjà construit (import) à la liste et le pousse au backend.
func add_deck(deck: DeckData) -> void:
	deck.name = make_unique_name(deck.name, deck)
	decks.append(deck)
	save_decks()

## Avertissements de ressources de race (textes déjà traduits ; vide si OK) —
## voir README « Système de Ressources par Race ». Deux cas surveillés :
##  - une race a des serviteurs/sorts dans le deck mais pas assez de cartes-
##    ressource de cette race pour atteindre le coût de race de sa carte la
##    plus chère (le pool ne pourra jamais monter assez haut) ;
##  - des cartes-ressource d'une race sont présentes alors qu'aucune carte
##    jouable de cette race n'en a l'usage (ressources gâchées).
func race_warnings(deck: DeckData) -> Array[String]:
	if deck == null:
		return []
	var max_race_cost: Dictionary = {}       # Race.Type -> coût de race max requis
	var playable_race_present: Dictionary = {}  # Race.Type -> true
	var resource_race_present: Dictionary = {}  # Race.Type -> true
	var resource_counts: Dictionary = {}        # Race.Type -> nb de cartes-ressource

	for card in deck.get_cards():
		if card.card_type == "Resource":
			resource_race_present[card.race] = true
			resource_counts[card.race] = int(resource_counts.get(card.race, 0)) + 1
		elif card.race != Race.Type.NONE:
			playable_race_present[card.race] = true
			var race_cost: int = CostSystem.compute_race_cost(
				card.cost, card.race, card.rarity, card.race_cost_override)
			max_race_cost[card.race] = max(int(max_race_cost.get(card.race, 0)), race_cost)

	var warnings: Array[String] = []
	for race in max_race_cost:
		var needed: int = max_race_cost[race]
		var have: int = int(resource_counts.get(race, 0))
		if have < needed:
			warnings.append(SettingsManager.t("deck.warning_missing_resource") % [needed, _race_label(race)])
	for race in resource_race_present:
		if not playable_race_present.has(race):
			warnings.append(SettingsManager.t("deck.warning_unused_resource") % _race_label(race))
	return warnings

func _race_label(race: int) -> String:
	return SettingsManager.t("RACE_" + Race.Type.keys()[race])

## Toutes les raisons pour lesquelles ce deck ne respecte pas les règles
## minimales (nombre de cartes + race_warnings ci-dessus), textes déjà
## traduits, vide si le deck est valide. Centralisé ici pour être réutilisable
## hors du deck builder (ex. tooltip d'avertissement dans l'écran de choix du
## deck à lancer, voir MainMenu._make_play_deck_row) — le deck builder lui-même
## garde un affichage séparé compteur/avertissements (voir DeckBuilder._can_save).
func validation_warnings(deck: DeckData) -> Array[String]:
	if deck == null:
		return []
	var playable := 0
	var resources := 0
	for card in deck.get_cards():
		if card.card_type == "Resource":
			resources += 1
		else:
			playable += 1

	var warnings: Array[String] = []
	if playable < MIN_PLAYABLE_CARDS:
		warnings.append(SettingsManager.t("deck.count_format") % [playable, MIN_PLAYABLE_CARDS])
	if resources < MIN_RESOURCE_CARDS:
		warnings.append(SettingsManager.t("deck.resource_count_format") % [resources, MIN_RESOURCE_CARDS])
	warnings.append_array(race_warnings(deck))
	return warnings

func can_add_card(deck: DeckData, card_data: CardData) -> bool:
	# Cartes-ressource : quantité illimitée dans un deck, sans lien avec ce qui
	# est possédé en collection (voir README « Système de Ressources par Race »
	# — le backend ne vérifie ni plafond ni possession pour ce type de carte).
	if card_data.card_type == "Resource":
		return true
	var owned := CollectionManager.owned_quantity(card_data)
	var count := 0
	for path in deck.card_paths:
		if path == card_data.resource_path:
			count += 1
	return count < min(MAX_COPIES_PER_CARD, owned)

# ─── Sauvegarde (pousse tous les decks vers l'API) ────────────────────────────

## Crée (POST) ou met à jour (PUT) chaque deck côté backend selon qu'il a déjà
## ou non un backend_id. Les cartes du deck absentes du catalogue backend
## (CardLibrary.backend_id_by_path) sont silencieusement exclues du payload.
func save_decks() -> void:
	for deck in decks:
		_push_deck(deck)

func _push_deck(deck: DeckData) -> void:
	var payload := {"name": deck.name, "entries": _to_api_entries(deck)}
	var is_new := deck.backend_id < 0
	var method: HTTPClient.Method = HTTPClient.METHOD_POST if is_new else HTTPClient.METHOD_PUT
	var path := "/api/decks" if is_new else "/api/decks/%d" % deck.backend_id

	BackendClient.request(method, path, payload, func(code: int, parsed) -> void:
		if code == 200 and parsed is Dictionary and is_new:
			deck.backend_id = parsed.get("id", -1)
		elif code != 200:
			sync_failed.emit("Échec de sauvegarde du deck « %s » (HTTP %d)" % [deck.name, code])
	)

func _to_api_entries(deck: DeckData) -> Array:
	var counts: Dictionary = {}
	for path in deck.card_paths:
		counts[path] = counts.get(path, 0) + 1

	var entries := []
	for path in counts:
		if not CardLibrary.backend_id_by_path.has(path):
			push_warning("DeckManager : carte sans id backend ignorée dans « %s » (%s)" % [deck.name, path])
			continue
		entries.append({
			"cardId": CardLibrary.backend_id_by_path[path],
			"quantity": counts[path],
		})
	return entries

# ─── Persistance locale : uniquement la préférence "deck actif" ───────────────

func _save_active_index() -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "active_deck_index", active_deck_index)
	config.save(ACTIVE_DECK_PATH)

func _load_active_index() -> void:
	var config := ConfigFile.new()
	if config.load(ACTIVE_DECK_PATH) != OK:
		return
	active_deck_index = config.get_value("meta", "active_deck_index", 0)
