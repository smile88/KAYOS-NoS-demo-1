extends Node
class_name ColdOpenAudio
## The Cold Open's sound (godot/audio/coldopen/, made by tools/gen_coldopen_audio.py). Two loops run
## the whole night: the Song — the hum under the world — and the festival. Where Talindir stands sets
## the mix: indoors the Song is a presence in the walls and the festival a far-off murmur; in the
## cloister the street comes up; on the balcony both are full. The cutscene then plays the Invocation,
## the wrong note, the falter and the wave — and at the instant the ring passes, everything stops.

const DIR := "res://audio/coldopen/"
const L = preload("res://threed/coldopen/ColdOpenLayout.gd")

var song: AudioStreamPlayer
var festival: AudioStreamPlayer
var _director: Node3D
var _silenced := false
var _master := 1.0


static func start(director: Node3D) -> ColdOpenAudio:
	var a := ColdOpenAudio.new()
	a.name = "Audio"
	a._director = director
	director.add_child(a)
	return a


static func of(n: Node) -> ColdOpenAudio:
	return n.get_node_or_null("Audio") as ColdOpenAudio


static func load_stream(file: String, loop := false) -> AudioStream:
	var s := load(DIR + file) as AudioStreamWAV
	if s and loop:
		s = s.duplicate() as AudioStreamWAV
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = s.data.size() / 2
	return s


func _ready() -> void:
	song = _player("song_hum.wav", true, -60.0)
	festival = _player("festival.wav", true, -60.0)
	song.play()
	festival.play()


func _player(file: String, loop: bool, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load_stream(file, loop)
	p.volume_db = db
	add_child(p)
	return p


func _process(delta: float) -> void:
	if _silenced or _director == null:
		return
	var player := _director.get("player") as Node3D
	if player == null:
		return
	var p := player.global_position
	# how "outside" he is: 0 in the scriptorium and the Hall, ~0.6 in the cloister, 1 on the balcony
	var outside := 0.0
	if p.y > L.BAL_Y - 1.0:
		outside = 1.0
	elif p.x < L.CLO_X1:
		outside = 0.6
	elif p.x < L.STAIR_X1 and p.z < L.STAIR_Z1:
		outside = 0.25 + 0.5 * clampf(p.y / L.BAL_Y, 0.0, 1.0)
	var song_db := lerpf(-13.0, -6.0, outside) + linear_to_db(_master)
	var fest_db := lerpf(-27.0, -9.0, outside) + linear_to_db(_master)
	song.volume_db = lerpf(song.volume_db, song_db, clampf(delta * 1.5, 0.0, 1.0))
	festival.volume_db = lerpf(festival.volume_db, fest_db, clampf(delta * 1.5, 0.0, 1.0))


## Play a one-shot. Returns the player so a caller can stop or fade it.
func shot(file: String, db := 0.0, pitch := 1.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load_stream(file)
	p.volume_db = db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p


## Fade the two loops (the cutscene uses this to lift the Song for the Invocation).
func set_master(v: float) -> void:
	_master = maxf(v, 0.0001)


## The instant the ring passes: every sound in the world stops.
func silence() -> void:
	_silenced = true
	for c in get_children():
		if c is AudioStreamPlayer:
			(c as AudioStreamPlayer).stop()


# --- the director's calls -----------------------------------------------------------------------
## The count: `n` strokes of the far bell, a second and a half apart.
static func bell(director: Node, n: int, near := false) -> void:
	var a := of(director)
	if a == null:
		return
	for i in n:
		director.get_tree().create_timer(i * 1.6).timeout.connect(func():
			# the scene may be gone by the time a late stroke falls (a hand-off, a test)
			if is_instance_valid(a) and not a._silenced:
				a.shot("bell.wav" if near else "bell_far.wav", -8.0 if near else -16.0))


static func bell_wrong(director: Node) -> void:
	var a := of(director)
	if a:
		a.shot("bell_wrong.wav", -6.0)


static func on_balcony(_director: Node) -> void:
	pass
