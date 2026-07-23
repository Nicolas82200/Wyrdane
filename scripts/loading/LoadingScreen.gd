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
	await _fade_to_black()
	get_tree().change_scene_to_file(next_scene)

# Fondu vers le noir avant le changement de scène : le menu principal démarre
# lui-même par un fondu depuis le noir (MainMenu._play_intro_animation), ce qui
# évite toute coupure sèche entre les deux écrans.
func _fade_to_black() -> void:
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.3)
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
