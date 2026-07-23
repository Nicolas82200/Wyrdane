extends Control

@export var next_scene: String = "res://scenes/mainMenu/MainMenu.tscn"

# Délai max accordé à la phase backend (Render en cold start peut être lent) :
# au-delà, on ouvre le menu quand même et la sync continue en arrière-plan
# (MainMenu._start_backend_sync sert de filet de rattrapage).
const BACKEND_TIMEOUT_SEC := 20.0

@onready var progress_bar: ProgressBar = %ProgressBar
@onready var status_label: Label       = %StatusLabel

func _ready() -> void:
	status_label.text  = SettingsManager.t("loading.cards")
	progress_bar.value = 0

	if not CardLibrary.is_loaded:
		await get_tree().process_frame
		CardLibrary.load_all_cards()

	progress_bar.value = 40

	await _sync_backend()

	progress_bar.value = 100
	await get_tree().create_timer(0.25).timeout
	await _fade_out_loading_ui()
	_swap_to_next_scene()

# Remplace change_scene_to_file : celui-ci libère la scène courante avant
# d'instancier la suivante, ce qui laisse passer une frame vide (couleur de
# fond du moteur) — le « flash » visible entre chargement et menu. Ici la
# nouvelle scène est ajoutée avant de libérer celle-ci : aucune frame sans rien
# à l'écran.
func _swap_to_next_scene() -> void:
	var next_root: Node = (load(next_scene) as PackedScene).instantiate()
	var tree := get_tree()
	tree.root.add_child(next_root)
	tree.current_scene = next_root
	queue_free()

# Fait disparaître en fondu la barre de chargement et son texte (le fond
# reste affiché) tout en faisant monter la vignette latérale au niveau
# d'assombrissement du menu (même dégradé que MainMenu/LeftVignette) : la
# dernière frame du chargement est alors identique au fond du menu, dont les
# boutons apparaissent ensuite en fondu (MainMenu._play_intro_animation).
func _fade_out_loading_ui() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property($VBox, "modulate:a", 0.0, 0.3)
	tween.tween_property($Vignette, "modulate:a", 1.0, 0.3)
	await tween.finished

# Auth Steam + récupération du profil joueur (catalogue backend, decks,
# collection, monnaie) pendant l'écran de chargement, pour que le menu s'ouvre
# avec les données déjà présentes au lieu de les voir apparaître après coup.
# Toute étape qui échoue ou dépasse le délai laisse simplement continuer vers
# le menu — même philosophie de dégradation douce que le reste de la sync.
func _sync_backend() -> void:
	if not SteamService.ensure_init():
		return
	var deadline := Time.get_ticks_msec() + int(BACKEND_TIMEOUT_SEC * 1000.0)

	status_label.text = SettingsManager.t("loading.profile")
	# result : 0 = en attente, 1 = succès, -1 = échec (Dictionary : les lambdas
	# GDScript capturent par valeur, seule une référence permet de rapporter).
	var login := {"result": 0}
	BackendClient.login_succeeded.connect(func(_user): login.result = 1, CONNECT_ONE_SHOT)
	BackendClient.login_failed.connect(func(_reason): login.result = -1, CONNECT_ONE_SHOT)
	BackendClient.login_with_steam()
	if not await _wait_until(func(): return login.result != 0, deadline) or login.result != 1:
		return
	progress_bar.value = 55

	var catalog := {"result": 0}
	CardLibrary.sync_backend_catalog(func(success: bool): catalog.result = 1 if success else -1)
	if not await _wait_until(func(): return catalog.result != 0, deadline) or catalog.result != 1:
		return
	progress_bar.value = 60

	# Réclame les 4 decks préfaits + cartes de départ si ce n'est pas déjà fait
	# (idempotent côté backend, voir wyrdane-backend claim-starter) : ainsi un
	# nouveau joueur a déjà ses decks/cartes dès le menu, sans attendre la fin
	# du tutoriel pour les voir apparaître (TutorialManager.notify_victory ne
	# fait plus cet appel).
	var claim := {"result": 0}
	BackendClient.request(HTTPClient.METHOD_POST, "/api/collection/claim-starter", {},
		func(code: int, _parsed): claim.result = 1 if code == 200 else -1)
	await _wait_until(func(): return claim.result != 0, deadline)
	progress_bar.value = 70

	var pending := {"count": 3}
	DeckManager.sync_from_backend(func(_ok: bool): pending.count -= 1)
	CollectionManager.sync_from_backend(func(_ok: bool): pending.count -= 1)
	CurrencyManager.sync_from_backend(func(_ok: bool): pending.count -= 1)
	await _wait_until(func(): return pending.count == 0, deadline)

# Attend que predicate soit vrai ; false si deadline (ticks msec) dépassée.
func _wait_until(predicate: Callable, deadline_msec: int) -> bool:
	while not predicate.call():
		if Time.get_ticks_msec() >= deadline_msec:
			return false
		await get_tree().process_frame
	return true
