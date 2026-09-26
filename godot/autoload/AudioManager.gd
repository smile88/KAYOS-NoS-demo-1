extends Node
## AudioManager — master audio singleton for KAYOS: The Night of Silence.
##
## Manages:
## 1. Dual-channel cross-fading music & ambient playback.
## 2. Pooled SFX players (2D and 3D).
## 3. Procedural dialogue synthesizer generating organic, speaker-tailored vocal blips
##    for typewriter text reveals with zero external audio file dependencies.

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer

var _sfx_pool: Array[AudioStreamPlayer] = []
var _voice_pool: Array[AudioStreamPlayer] = []
var _voice_streams: Dictionary = {}

const SAMPLE_RATE := 22050
const VOICE_POOL_SIZE := 8
const SFX_POOL_SIZE := 12


func _ready() -> void:
	_init_players()
	_generate_procedural_voices()


func _init_players() -> void:
	# Music players for seamless A/B crossfading
	_music_a = AudioStreamPlayer.new()
	_music_a.name = "MusicA"
	_music_a.bus = "Master"
	add_child(_music_a)

	_music_b = AudioStreamPlayer.new()
	_music_b.name = "MusicB"
	_music_b.bus = "Master"
	add_child(_music_b)
	_active_music = _music_a

	# Ambient player
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "Ambient"
	_ambient_player.bus = "Master"
	add_child(_ambient_player)

	# General SFX pool
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "SFX_%d" % i
		p.bus = "Master"
		add_child(p)
		_sfx_pool.append(p)

	# Dialogue Voice Blip pool
	for i in range(VOICE_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "Voice_%d" % i
		p.bus = "Master"
		p.volume_db = -8.0
		add_child(p)
		_voice_pool.append(p)


## Play an audio stream through the SFX pool with optional pitch randomness.
func play_sfx(stream: AudioStream, pitch_variance: float = 0.08, volume_db: float = 0.0) -> void:
	if stream == null or _sfx_pool.is_empty():
		return
	var player: AudioStreamPlayer = null
	for p in _sfx_pool:
		if not p.playing:
			player = p
			break
	if player == null:
		player = _sfx_pool[0] # reuse oldest if all active
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	player.play()


## Play dialogue typewriter vocal blip with speaker-specific resonance.
func play_dialogue_blip(speaker: String = "") -> void:
	var key := speaker.to_lower().strip_edges()
	if not _voice_streams.has(key):
		key = "default"
	var stream: AudioStream = _voice_streams.get(key, _voice_streams.get("default"))
	if stream == null:
		return

	# Find available voice player
	var player: AudioStreamPlayer = null
	for p in _voice_pool:
		if not p.playing:
			player = p
			break
	if player == null:
		player = _voice_pool[0]

	player.stream = stream
	# Subtle pitch jitter gives life to the dialogue
	player.pitch_scale = randf_range(0.96, 1.04)
	player.play()


## Smooth cross-fade to a new music track.
func play_music(track_path: String, fade: float = 1.0) -> void:
	if track_path == "":
		stop_music(fade)
		return
	var stream = load(track_path) as AudioStream
	if stream == null:
		return

	var incoming := _music_b if _active_music == _music_a else _music_a
	var outgoing := _active_music

	incoming.stream = stream
	incoming.volume_db = -40.0
	incoming.play()

	var tween := create_tween().set_parallel(true)
	tween.tween_property(incoming, "volume_db", 0.0, fade)
	tween.tween_property(outgoing, "volume_db", -40.0, fade)
	tween.chain().tween_callback(outgoing.stop)

	_active_music = incoming


## Play ambient background loop.
func play_ambient(track_path: String, fade: float = 1.5) -> void:
	if track_path == "":
		stop_ambient(fade)
		return
	var stream = load(track_path) as AudioStream
	if stream == null:
		return
	_ambient_player.stream = stream
	_ambient_player.volume_db = -40.0
	_ambient_player.play()
	var tween := create_tween()
	tween.tween_property(_ambient_player, "volume_db", -6.0, fade)


func stop_music(fade: float = 1.0) -> void:
	if _active_music and _active_music.playing:
		var tween := create_tween()
		tween.tween_property(_active_music, "volume_db", -40.0, fade)
		tween.tween_callback(_active_music.stop)


func stop_ambient(fade: float = 1.0) -> void:
	if _ambient_player and _ambient_player.playing:
		var tween := create_tween()
		tween.tween_property(_ambient_player, "volume_db", -40.0, fade)
		tween.tween_callback(_ambient_player.stop)


func stop_all(fade: float = 1.0) -> void:
	stop_music(fade)
	stop_ambient(fade)


## Procedural synthesis of vocal blip profiles
func _generate_procedural_voices() -> void:
	# Speaker profiles: (base_freq, wave_type, duration_s, decay_rate)
	# wave_type: 0=sine/chime, 1=triangle/soft, 2=complex harmonic
	var profiles := {
		"elorin": [580.0, 0, 0.055, 38.0],      # Ethereal crystal chime
		"grakkar": [145.0, 1, 0.065, 30.0],     # Deep baritone pulse
		"talindir": [440.0, 0, 0.045, 45.0],    # Crisp quill-like tone
		"corel": [320.0, 2, 0.050, 40.0],       # Mellow harmonic chord
		"morga": [210.0, 1, 0.060, 32.0],       # Weathered low resonance
		"vara": [520.0, 0, 0.040, 50.0],        # Bright quick tone
		"festivalgoer": [410.0, 0, 0.045, 42.0],# Festive soft bell
		"default": [380.0, 0, 0.045, 42.0],     # Warm neutral blip
	}

	for spk in profiles:
		var cfg: Array = profiles[spk]
		_voice_streams[spk] = _synthesize_blip(cfg[0], int(cfg[1]), float(cfg[2]), float(cfg[3]))


func _synthesize_blip(freq: float, wave_type: int, duration: float, decay: float) -> AudioStreamWAV:
	var total_samples := int(SAMPLE_RATE * duration)
	var byte_data := PackedByteArray()
	byte_data.resize(total_samples * 2) # 16-bit mono = 2 bytes per sample

	var two_pi := TAU
	for i in range(total_samples):
		var t := float(i) / float(SAMPLE_RATE)
		var envelope := exp(-decay * t) # Exponential decay envelope
		if t < 0.003: # Quick 3ms attack ramp to eliminate pop
			envelope *= (t / 0.003)

		var sample_val := 0.0
		match wave_type:
			0: # Sine chime with light second harmonic
				sample_val = sin(two_pi * freq * t) * 0.8 + sin(two_pi * freq * 2.0 * t) * 0.2
			1: # Triangle / soft rounded wave
				var phase := fmod(freq * t, 1.0)
				sample_val = (absf(phase - 0.5) * 4.0 - 1.0) * 0.9
			2: # Complex harmonic (3rd & 5th partials)
				sample_val = (sin(two_pi * freq * t) * 0.6 +
							  sin(two_pi * freq * 1.5 * t) * 0.3 +
							  sin(two_pi * freq * 2.0 * t) * 0.1)

		var int16 := int(clampf(sample_val * envelope, -1.0, 1.0) * 32767.0)
		byte_data.encode_s16(i * 2, int16)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = byte_data
	return stream
