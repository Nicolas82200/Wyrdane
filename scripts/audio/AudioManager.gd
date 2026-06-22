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

# Tour
const TURN_START := "turn_start"
const TURN_END := "turn_end"

# Héros
const HERO_DAMAGE := "hero_damage"
const HERO_DEATH := "hero_death"

# UI
const BUTTON := "button"
const HOVER := "hover"

# Musique
const BATTLE_MUSIC :AudioStreamMP3= preload(
	"res://assets/audio/music/The Tavern at Oakhaven.mp3"
)


func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	_apply_saved_settings()
	load_sounds()

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

		DRAW: [
			preload("res://assets/audio/sound-effect/global/draw-card-01.mp3"),
			preload("res://assets/audio/sound-effect/global/draw-card-02.mp3"),
			preload("res://assets/audio/sound-effect/global/draw-card-03.mp3")
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
			UnitStyle.Type.ARCHER:        [],
			UnitStyle.Type.MAGE:          [],
			UnitStyle.Type.PALADIN:       [],
			UnitStyle.Type.RANGER:        [],
			UnitStyle.Type.DRUID:         [],
			UnitStyle.Type.BLADE_DANCER:  [],
			UnitStyle.Type.BERSERKER:     [],
			UnitStyle.Type.RUNESMITH:     [],
			UnitStyle.Type.IMP:           [],
			UnitStyle.Type.DEMON_WARRIOR: [],
			UnitStyle.Type.SUCCUBUS:      [],
			UnitStyle.Type.INSECT:        [preload("res://assets/audio/sound-effect/global/swarm-insect.wav")],
			UnitStyle.Type.LARVA:         [preload("res://assets/audio/sound-effect/global/larva.wav")],
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
	var player := AudioStreamPlayer.new()
	add_child(player)
	player.stream = sound
	player.finished.connect(player.queue_free)
	player.play()


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
	var player := AudioStreamPlayer.new()
	add_child(player)
	player.stream = sound
	player.pitch_scale = randf_range(min_pitch, max_pitch)
	player.finished.connect(player.queue_free)
	player.play()

func play_battle_music() -> void:
	music_player.bus = "Music"
	if music_player.stream == BATTLE_MUSIC and music_player.playing:
		return

	music_player.stream = BATTLE_MUSIC
	music_player.play()

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

func _spawn_player(sound: AudioStream, pitch_variation: bool, min_pitch := 0.92, max_pitch := 1.08) -> void:
	var player := AudioStreamPlayer.new()
	add_child(player)
	player.stream = sound
	if pitch_variation:
		player.pitch_scale = randf_range(min_pitch, max_pitch)
	player.finished.connect(player.queue_free)
	player.play()
	player.bus = "SFX"
func stop_music() -> void:
	music_player.stop()
