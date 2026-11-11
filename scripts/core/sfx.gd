extends Node
## Plays the synthesized sounds. Generation runs on a worker thread at
## startup; anything requested before it finishes is skipped, except music
## and ambience, which start as soon as they exist.

const Synth = preload("res://scripts/core/synth.gd")
const POOL := 12
const POOL3D := 10

var streams := {}
var is_ready := false
var _task := -1
var _result := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _voices: Array[AudioStreamPlayer] = []
var _vi := 0
var _i := 0
var _i3 := 0
var _music: AudioStreamPlayer
var _music_name := ""
var _music_tween: Tween
var _amb := {}            # name -> AudioStreamPlayer
var _amb_wanted := {}     # name -> volume_db (requested before ready)
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	for i in POOL3D:
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = "SFX"
		p3.unit_size = 14.0
		p3.max_distance = 120.0
		add_child(p3)
		_pool3d.append(p3)
	for i in 2:
		var v := AudioStreamPlayer.new()
		v.bus = "Voice"
		add_child(v)
		_voices.append(v)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_task = WorkerThreadPool.add_task(_generate, false, "synthesize sounds")


func _generate() -> void:
	_result = Synth.new().make_all()


func _process(_dt: float) -> void:
	if _task != -1 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		streams = _result
		is_ready = true
		print("sounds ready in %d ms" % Time.get_ticks_msec())
		if _music_name != "" and not _music.playing:
			var name := _music_name
			_music_name = ""
			music(name)
		for a in _amb_wanted.keys():
			ambience(a, _amb_wanted[a])
		_amb_wanted.clear()


func _exit_tree() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func play(name: String, vol_db := 0.0, pitch := 1.0) -> void:
	var s: AudioStream = streams.get(name)
	if s == null:
		return
	var p := _pool[_i]
	_i = (_i + 1) % POOL
	p.stream = s
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


func play_at(name: String, pos: Vector3, vol_db := 0.0, pitch := 1.0) -> void:
	var s: AudioStream = streams.get(name)
	if s == null:
		return
	var p := _pool3d[_i3]
	_i3 = (_i3 + 1) % POOL3D
	p.stream = s
	p.global_position = pos
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


func blip(voice: String) -> void:
	var s: AudioStream = streams.get("blip_%s_%d" % [voice, _rng.randi() % Synth.BLIP_VARIANTS])
	if s == null:
		return
	var p := _voices[_vi]
	_vi = (_vi + 1) % _voices.size()
	p.stream = s
	p.volume_db = -4.0
	p.play()


func music(name: String, vol_db := -6.0, fade := 1.0) -> void:
	if _music_tween:
		_music_tween.kill()
	if name == "" or name == "off":
		music_stop(fade)
		return
	if _music_name == name and _music.playing:
		return
	_music_name = name
	var s: AudioStream = streams.get(name)
	if s == null:
		return  # starts in _process once synthesized
	_music.stream = s
	_music.volume_db = -40.0
	_music.play()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", vol_db, fade)


func music_stop(fade := 1.0) -> void:
	_music_name = ""
	if _music_tween:
		_music_tween.kill()
	if not _music.playing:
		return
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", -50.0, maxf(fade, 0.01))
	_music_tween.tween_callback(_music.stop)


## Cuts the music instantly with a tape-stop drop in pitch (the store closing).
func music_cut() -> void:
	_music_name = ""
	if _music_tween:
		_music_tween.kill()
	if not _music.playing:
		return
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "pitch_scale", 0.3, 0.45)
	_music_tween.parallel().tween_property(_music, "volume_db", -40.0, 0.5)
	_music_tween.tween_callback(func():
		_music.stop()
		_music.pitch_scale = 1.0)


func ambience(name: String, vol_db := -12.0) -> void:
	var s: AudioStream = streams.get(name)
	if s == null:
		_amb_wanted[name] = vol_db
		return
	var p: AudioStreamPlayer = _amb.get(name)
	if p == null:
		p = AudioStreamPlayer.new()
		p.bus = "Ambience"
		add_child(p)
		_amb[name] = p
		p.stream = s
		p.volume_db = -40.0
		p.play()
	var tw := create_tween()
	tw.tween_property(p, "volume_db", vol_db, 1.0)


func ambience_stop(name: String, fade := 1.0) -> void:
	_amb_wanted.erase(name)
	var p: AudioStreamPlayer = _amb.get(name)
	if p == null:
		return
	_amb.erase(name)
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -50.0, fade)
	tw.tween_callback(p.queue_free)


func stop_all_ambience(fade := 0.5) -> void:
	for k in _amb.keys():
		ambience_stop(k, fade)
