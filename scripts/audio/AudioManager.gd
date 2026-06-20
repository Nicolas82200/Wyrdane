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
	music_player.volume_db = -20
	add_child(music_player)

	load_sounds()


func load_sounds() -> void:

	sounds = {

		DRAW: [
			preload("res://assets/audio/sound-effect/global/draw-card-01.mp3"),
			preload("res://assets/audio/sound-effect/global/draw-card-02.mp3"),
			preload("res://assets/audio/sound-effect/global/draw-card-03.mp3")
		]

		# Exemple pour plus tard :
		#
		# ATTACK: [
		# 	preload("res://assets/audio/sound-effect/global/attack-01.mp3"),
		# 	preload("res://assets/audio/sound-effect/global/attack-02.mp3")
		# ]
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

	if music_player.stream == BATTLE_MUSIC and music_player.playing:
		return

	music_player.stream = BATTLE_MUSIC
	music_player.play()

func stop_music() -> void:
	music_player.stop()
