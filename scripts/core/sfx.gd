extends Node
## Plays the synthesized sounds. Generation runs on worker threads at
## startup, in a few shares side by side; a sound requested before its share
## is done is skipped, except music and ambience, which start as soon as
## they exist (at the volume that was asked for).

const Synth = preload("res://scripts/core/synth.gd")
const POOL := 12
const POOL3D := 10

var streams := {}
var is_ready := false
var _tasks := {}          # worker task id -> which share of the sounds (see Synth.make_part)
var _made := {}           # share -> its streams, handed over by the worker thread
var _mutex := Mutex.new()
var _pool: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _voices: Array[AudioStreamPlayer] = []
var _vi := 0
var _i := 0
var _i3 := 0
var _music: AudioStreamPlayer
var _music_name := ""
var _music_vol := -6.0    # what a music() call asked for before its stream existed
var _music_fade := 1.0
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
	# high priority: only a fraction of the pool's threads take low-priority
	# tasks (one, on a four-core machine), which would run the shares in a row
	for part in Synth.PARTS:
		_tasks[WorkerThreadPool.add_task(_generate.bind(part), true, "synthesize sounds")] = part


## Runs on a worker thread.
func _generate(part: int) -> void:
	var streams_made: Dictionary = Synth.new(part).make_part(part)
	_mutex.lock()
	_made[part] = streams_made
	_mutex.unlock()


func _process(_dt: float) -> void:
	if _tasks.is_empty():
		return
	for id in _tasks.keys():
		if not WorkerThreadPool.is_task_completed(id):
			continue
		WorkerThreadPool.wait_for_task_completion(id)
		var part: int = _tasks[id]
		_tasks.erase(id)
		_mutex.lock()
		var got: Dictionary = _made.get(part, {})
		_made.erase(part)
		_mutex.unlock()
		streams.merge(got)
		_start_wanted()
	if _tasks.is_empty():
		is_ready = true
		print("sounds ready in %d ms" % Time.get_ticks_msec())


## Starts the music and ambience that were asked for before they existed.
func _start_wanted() -> void:
	if _music_name != "" and not _music.playing and streams.has(_music_name):
		var name := _music_name
		_music_name = ""
		if Game.dev.has("trace"):
			print("music %s starts at %.0f dB, %d ms in" % [name, _music_vol, Time.get_ticks_msec()])
		music(name, _music_vol, _music_fade)
	for a in _amb_wanted.keys():
		if streams.has(a):
			var vol: float = _amb_wanted[a]
			_amb_wanted.erase(a)
			ambience(a, vol)


func _exit_tree() -> void:
	for id in _tasks.keys():
		WorkerThreadPool.wait_for_task_completion(id)
	_tasks.clear()


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
		_music_vol = vol_db   # starts in _process once synthesized
		_music_fade = fade
		return
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
