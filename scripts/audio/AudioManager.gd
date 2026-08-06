extends Node

var music_player: AudioStreamPlayer
var sounds := {}

# Combat
const ATTACK := "attack"
const HIT := "hit"
const DEATH := "death"
const SUMMON := "summon"

# Cartes
const DRAW := "draw"
const PLAY_CARD := "play_card"
const SPELL_CAST := "spell_cast"
const SPELL_CAST_FREEZE := "spell_cast_freeze"
const RESOURCE_PLAYED := "resource_played"

# Tour
const TURN_START := "turn_start"
const TURN_END := "turn_end"

# Héros
const HERO_DAMAGE := "hero_damage"
const HERO_DEATH := "hero_death"

# UI
const BUTTON := "button"
const HOVER := "hover"
const CONFIRM := "confirm"
const OPEN_MENU := "open_menu"
const CLOSE_MENU := "close_menu"
const SHUFFLE := "shuffle"

# Musique
const MENU_MUSIC := [
	preload("res://assets/audio/music/tavern-at-oakhaven-01.mp3"),
	preload("res://assets/audio/music/tavern-at-oakhaven-02.mp3"),
]
const BATTLE_MUSIC := [
	preload("res://assets/audio/music/The Veil of Forgotten Kings.mp3"),
	preload("res://assets/audio/music/The Veil of Forgotten Kings_1.mp3"),
]


func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	# Sinon Godot met sa lecture en pause en même temps que l'arbre (ex. popups
	# du tutoriel, futurs menus de pause) — cassant l'immersion pour rien : la
	# musique doit continuer même quand get_tree().paused est vrai.
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music_player)
	_apply_saved_settings()
	load_sounds()
	# Sons UI branchés automatiquement sur tout bouton ajouté à l'arbre
	get_tree().node_added.connect(_on_node_added)


# ─── Sons UI automatiques ────────────────────────────────────────────────────
# Chaque BaseButton du jeu reçoit un son de hover et de clic.
# Opt-out par bouton via les metas "no_hover_sound" / "no_click_sound".

func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.has_meta("_ui_sound_wired"):
		node.set_meta("_ui_sound_wired", true)
		node.mouse_entered.connect(_on_button_hover.bind(node))
		node.pressed.connect(_on_button_pressed.bind(node))

func _on_button_hover(button: BaseButton) -> void:
	if button.disabled or button.has_meta("no_hover_sound"):
		return
	play_with_pitch(HOVER)

func _on_button_pressed(button: BaseButton) -> void:
	if button.has_meta("no_click_sound"):
		return
	play(BUTTON)

func play_menu_music() -> void:
	if music_player.playing and music_player.stream in MENU_MUSIC:
		return
	music_player.stream = MENU_MUSIC.pick_random()
	music_player.play()

func play_battle_music() -> void:
	if music_player.playing and music_player.stream in BATTLE_MUSIC:
		return
	music_player.stream = BATTLE_MUSIC.pick_random()
	music_player.play()

func _spawn_player(sound: AudioStream, pitch_variation: bool, min_pitch := 0.92, max_pitch := 1.08) -> void:
	var player := AudioStreamPlayer.new()
	player.bus = "SFX"
	add_child(player)
	player.stream = sound
	if pitch_variation:
		player.pitch_scale = randf_range(min_pitch, max_pitch)
	player.finished.connect(player.queue_free)
	player.play()

func _apply_saved_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://audio_settings.cfg") != OK:
		return
	var music  := cfg.get_value("audio", "music",  0.75) as float
	var sfx    := cfg.get_value("audio", "sfx",    1.0)  as float
	var master := cfg.get_value("audio", "master", 1.0)  as float
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"),  linear_to_db(music))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"),    linear_to_db(sfx))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master))


func load_sounds() -> void:

	sounds = {

		BUTTON: [
			preload("res://assets/audio/sound-effect/interface/button_pressed.mp3")
		],
		HOVER: [
			preload("res://assets/audio/sound-effect/interface/hover_button.mp3")
		],
		CONFIRM: [
			preload("res://assets/audio/sound-effect/interface/confirm.wav")
		],
		OPEN_MENU: [
			preload("res://assets/audio/sound-effect/interface/open_menu.wav")
		],
		CLOSE_MENU: [
			preload("res://assets/audio/sound-effect/interface/close_menu.wav")
		],
		SHUFFLE: [
			preload("res://assets/audio/sound-effect/interface/shuffle_cards.mp3")
		],
		# Carte-ressource jouée : absorbée dans le pool de mana de sa race
		# (voir Battle.play_resource_card) — chime de confirmation, cohérent
		# avec le fait qu'aucun effet de sort n'est réellement lancé.
		RESOURCE_PLAYED: [
			preload("res://assets/audio/sound-effect/interface/confirm.wav")
		],
		DRAW: [
			preload("res://assets/audio/sound-effect/global/draw-card-01.mp3"),
			preload("res://assets/audio/sound-effect/global/draw-card-02.mp3"),
			preload("res://assets/audio/sound-effect/global/draw-card-03.mp3")
		],
		# Son de lancer de sort par race (thème sonore) ; Race.Type.NONE sert de
		# repli générique pour les races sans thème dédié (Elfe/Nain à venir).
		SPELL_CAST: {
			Race.Type.UNDEAD: [
				preload("res://assets/audio/sound-effect/global/spell-cast-undead-01.wav"),
				preload("res://assets/audio/sound-effect/global/spell-cast-undead-02.wav"),
				preload("res://assets/audio/sound-effect/global/spell-cast-undead-03.wav"),
				preload("res://assets/audio/sound-effect/global/spell-cast-undead-04.wav"),
			],
			Race.Type.DEMON: [
				preload("res://assets/audio/sound-effect/global/spell-cast-demon-01.wav"),
				preload("res://assets/audio/sound-effect/global/spell-cast-demon-02.wav"),
				preload("res://assets/audio/sound-effect/global/spell-cast-demon-03.wav"),
				preload("res://assets/audio/sound-effect/global/spell-cast-demon-04.wav"),
			],
			Race.Type.HUMAN: [
				preload("res://assets/audio/sound-effect/global/spell-cast-human-01.wav"),
				preload("res://assets/audio/sound-effect/global/spell-cast-human-02.wav"),
				preload("res://assets/audio/sound-effect/global/spell-cast-human-03.wav"),
				preload("res://assets/audio/sound-effect/global/spell-cast-human-04.wav"),
			],
			Race.Type.ABOMINATION: [
				preload("res://assets/audio/sound-effect/global/spell-cast-abomination-01.wav"),
				preload("res://assets/audio/sound-effect/global/spell-cast-abomination-02.wav"),
				preload("res://assets/audio/sound-effect/global/spell-cast-abomination-03.wav"),
			],
			Race.Type.NONE: [
				preload("res://assets/audio/sound-effect/global/spell-cast-generic-01.wav"),
				preload("res://assets/audio/sound-effect/global/spell-cast-generic-02.wav"),
			],
		},
		# Prioritaire sur le thème de race : tout sort avec un effet Freeze
		# (Démon comme Mort-Vivant) joue un son de gel, indépendamment de la race.
		SPELL_CAST_FREEZE: [
			preload("res://assets/audio/sound-effect/global/spell-cast-ice-01.wav"),
			preload("res://assets/audio/sound-effect/global/spell-cast-ice-02.wav"),
			preload("res://assets/audio/sound-effect/global/spell-cast-ice-03.wav"),
		],
		HIT: [
			preload("res://assets/audio/sound-effect/global/hit-01.wav"),
			preload("res://assets/audio/sound-effect/global/hit-02.wav"),
			preload("res://assets/audio/sound-effect/global/hit-03.wav"),
			preload("res://assets/audio/sound-effect/global/hit-04.wav"),
			preload("res://assets/audio/sound-effect/global/hit-05.wav"),
			preload("res://assets/audio/sound-effect/global/hit-06.wav"),
			preload("res://assets/audio/sound-effect/global/hit-07.wav"),
			preload("res://assets/audio/sound-effect/global/hit-08.wav"),
			preload("res://assets/audio/sound-effect/global/hit-09.wav"),
			preload("res://assets/audio/sound-effect/global/hit-10.wav"),
			preload("res://assets/audio/sound-effect/global/hit-11.wav"),
			preload("res://assets/audio/sound-effect/global/hit-12.wav"),
		],
		SUMMON:{
			UnitStyle.Type.ZOMBIE:[
			preload("res://assets/audio/sound-effect/undead/zombie-roar-01.wav"),
			preload("res://assets/audio/sound-effect/undead/zombie-roar-02.wav"),
			preload("res://assets/audio/sound-effect/undead/zombie-roar-03.wav"),
			preload("res://assets/audio/sound-effect/undead/zombie-roar-04.wav")
			],
			UnitStyle.Type.MAJOR_ZOMBIE:[
			preload("res://assets/audio/sound-effect/undead/major-zombie-01.wav"),
			preload("res://assets/audio/sound-effect/undead/major-zombie-02.wav"),
			preload("res://assets/audio/sound-effect/undead/major-zombie-03.wav")
			],
			UnitStyle.Type.ABOMINATION:[
			preload("res://assets/audio/sound-effect/undead/monster-01.wav"),
			preload("res://assets/audio/sound-effect/undead/monster-02.wav"),
			preload("res://assets/audio/sound-effect/undead/monster-03.wav"),
			preload("res://assets/audio/sound-effect/undead/monster-04.wav"),
			preload("res://assets/audio/sound-effect/undead/monster-06.wav"),
			preload("res://assets/audio/sound-effect/undead/monster-07.wav"),
			preload("res://assets/audio/sound-effect/undead/monster-08.wav"),
			preload("res://assets/audio/sound-effect/undead/monster-09.wav"),
			preload("res://assets/audio/sound-effect/undead/monster-10.mp3")
			],
			UnitStyle.Type.SPECTRAL:      [
				preload("res://assets/audio/sound-effect/undead/spectral.wav")],
			UnitStyle.Type.DEATH_KNIGHT:  [
				preload("res://assets/audio/sound-effect/global/horse-neigh-01.wav"),
				preload("res://assets/audio/sound-effect/global/horse-neigh-02.wav"),
				preload("res://assets/audio/sound-effect/global/horse-neigh-03.wav"),
				preload("res://assets/audio/sound-effect/global/horse-neigh-04.wav"),
			],
			UnitStyle.Type.KNIGHT:        [
				preload("res://assets/audio/sound-effect/global/horse-neigh-01.wav"),
				preload("res://assets/audio/sound-effect/global/horse-neigh-02.wav"),
				preload("res://assets/audio/sound-effect/global/horse-neigh-03.wav"),
				preload("res://assets/audio/sound-effect/global/horse-neigh-04.wav"),
			],
			UnitStyle.Type.ARCHER:        [
				preload("res://assets/audio/sound-effect/global/loading_bow.mp3"),
				preload("res://assets/audio/sound-effect/global/bow-and-arrow.wav"),
			],
			UnitStyle.Type.MAGE:          [
				preload("res://assets/audio/sound-effect/global/spell-01.wav"),
				preload("res://assets/audio/sound-effect/global/spell-02.wav"),
				preload("res://assets/audio/sound-effect/global/spell-03.wav"),
			],
			UnitStyle.Type.PALADIN:       [
				preload("res://assets/audio/sound-effect/global/holy-spell-01.wav"),
			],
			UnitStyle.Type.SOLDIER:       [
				preload("res://assets/audio/sound-effect/human/soldier_01.mp3"),
				preload("res://assets/audio/sound-effect/human/soldier_02.mp3"),
				preload("res://assets/audio/sound-effect/human/soldier_03.mp3"),
			],
			UnitStyle.Type.RANGER:        [],
			UnitStyle.Type.DRUID:         [],
			UnitStyle.Type.BLADE_DANCER:  [],
			UnitStyle.Type.BERSERKER:     [],
			UnitStyle.Type.RUNESMITH:     [],
			UnitStyle.Type.IMP:           [
			preload("res://assets/audio/sound-effect/demon/demon_01.wav"),
			preload("res://assets/audio/sound-effect/demon/demon_02.wav"),
			preload("res://assets/audio/sound-effect/demon/demon_03.wav"),
			preload("res://assets/audio/sound-effect/demon/demon_04.wav"),
			preload("res://assets/audio/sound-effect/demon/demon_05.wav"),
			preload("res://assets/audio/sound-effect/demon/demon_06.wav"),
			preload("res://assets/audio/sound-effect/demon/demon_07.wav"),
			],
			UnitStyle.Type.DEMON_WARRIOR: [
			preload("res://assets/audio/sound-effect/demon/demon_01.wav"),
			preload("res://assets/audio/sound-effect/demon/demon_02.wav"),
			preload("res://assets/audio/sound-effect/demon/demon_03.wav"),
			preload("res://assets/audio/sound-effect/demon/demon_04.wav"),
			preload("res://assets/audio/sound-effect/demon/demon_05.wav"),
			preload("res://assets/audio/sound-effect/demon/demon_06.wav"),
			preload("res://assets/audio/sound-effect/demon/demon_07.wav"),
			],
			UnitStyle.Type.SUCCUBUS:      [
			preload("res://assets/audio/sound-effect/demon/demon_01.wav"),
			preload("res://assets/audio/sound-effect/demon/demon_02.wav"),
			preload("res://assets/audio/sound-effect/demon/demon_03.wav"),
			preload("res://assets/audio/sound-effect/demon/demon_04.wav"),
			preload("res://assets/audio/sound-effect/demon/demon_05.wav"),
			preload("res://assets/audio/sound-effect/demon/demon_06.wav"),
			preload("res://assets/audio/sound-effect/demon/demon_07.wav"),
			],
			UnitStyle.Type.INSECT:        [preload("res://assets/audio/sound-effect/global/swarm-insect.wav")],
			UnitStyle.Type.LARVA:         [preload("res://assets/audio/sound-effect/global/larva.wav")],
			UnitStyle.Type.ABOMINATION_MASS: [
			preload("res://assets/audio/sound-effect/abomination/abomination_01.wav"),
			preload("res://assets/audio/sound-effect/abomination/abomination_02.wav"),
			preload("res://assets/audio/sound-effect/abomination/abomination_03.wav"),
			preload("res://assets/audio/sound-effect/abomination/abomination_04.wav"),
			preload("res://assets/audio/sound-effect/abomination/abomination_05.wav"),
			preload("res://assets/audio/sound-effect/abomination/abomination_06.wav"),
			preload("res://assets/audio/sound-effect/abomination/abomination_07.wav"),
			preload("res://assets/audio/sound-effect/abomination/abomination_08.wav"),
			],
		}
	}


func play(sound_name: String) -> void:
	if not sounds.has(sound_name):
		push_warning("Son introuvable : " + sound_name)
		return
	var variants = sounds[sound_name]
	var sound: AudioStream
	if variants is Array:
		sound = variants.pick_random()
	else:
		sound = variants
	_spawn_player(sound, false)


func play_with_pitch(
	sound_name: String,
	min_pitch := 0.95,
	max_pitch := 1.05
) -> void:
	if not sounds.has(sound_name):
		return
	var variants = sounds[sound_name]
	var sound: AudioStream
	if variants is Array:
		sound = variants.pick_random()
	else:
		sound = variants
	_spawn_player(sound, true, min_pitch, max_pitch)


func play_spell_cast(card_data: CardData) -> void:
	for effect in card_data.effects:
		if effect.effect_id == "Freeze":
			play(SPELL_CAST_FREEZE)
			return
	var race: int = card_data.race
	if not sounds[SPELL_CAST].has(race):
		race = Race.Type.NONE
	play_for_style(SPELL_CAST, race)


func play_for_style(sound_name: String, style: int, pitch_variation := true) -> void:
	if not sounds.has(sound_name):
		push_warning("Son introuvable : " + sound_name)
		return
	var entry = sounds[sound_name]
	if not entry is Dictionary:
		push_warning("'%s' n'est pas un son par style — utilisez play()" % sound_name)
		return
	var variants = entry.get(style)
	if variants == null:
		push_warning("Pas de son pour le style %d dans '%s'" % [style, sound_name])
		return
	var sound: AudioStream = variants.pick_random() if variants is Array else variants
	_spawn_player(sound, pitch_variation)
