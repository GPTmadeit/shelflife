extends Camera3D
## Side-on follow camera with dialogue framing, fixed shots and shake.

var mode := "follow"                 ## follow | frame | shot
var target: Node3D                   ## followed node (the player)
var frame_nodes: Array = []          ## nodes to keep in frame (dialogue)
var shot_pos := Vector3.ZERO
var shot_look := Vector3.ZERO
var dist := 13.5                     ## follow distance
var dist_override := 0.0             ## level zones can push the camera out
var height_bias := 0.0               ## zones can raise/lower the framing
var min_x := -999.0
var max_x := 999.0
var min_y := 1.0
var speed := 4.0                     ## follow smoothing
var frame_speed := 3.0
var _look := Vector3.ZERO
var _pos := Vector3.ZERO
var _ahead := 0.0
var _shake := 0.0
var _snap := true


func _ready() -> void:
	fov = 40.0
	near = 0.1
	far = 400.0
	current = true


func shake(amount: float) -> void:
	if Game.settings.get("shake", true):
		_shake = maxf(_shake, amount)


func snap() -> void:
	_snap = true


func follow(node: Node3D) -> void:
	target = node
	mode = "follow"


func frame(nodes: Array) -> void:
	frame_nodes = nodes.filter(func(n): return n != null and is_instance_valid(n))
	mode = "frame" if frame_nodes.size() > 0 else "follow"


func shot(pos: Vector3, look: Vector3, instant := false) -> void:
	shot_pos = pos
	shot_look = look
	mode = "shot"
	if instant:
		snap()


func _head(n: Node3D) -> Vector3:
	if n.has_method("head_pos"):
		return n.head_pos()
	return n.global_position + Vector3(0, 1.0, 0)


func _process(dt: float) -> void:
	var want_look := _look
	var want_pos := _pos
	var k := speed
	match mode:
		"follow":
			if target != null and is_instance_valid(target):
				var p := target.global_position
				var dir: float = target.get("facing_dir") if target.get("facing_dir") != null else 0.0
				_ahead = lerpf(_ahead, dir * 1.4, 1.0 - exp(-dt * 1.5))
				var d := dist_override if dist_override > 0.0 else dist
				want_look = Vector3(p.x + _ahead, p.y + 1.7 + height_bias, 0.0)
				want_pos = want_look + Vector3(0, 1.3, d)
		"frame":
			k = frame_speed
			var lo := Vector3(INF, INF, 0)
			var hi := Vector3(-INF, -INF, 0)
			for n in frame_nodes:
				if not is_instance_valid(n):
					continue
				var hp := _head(n)
				var fp: Vector3 = n.global_position
				lo = Vector3(minf(lo.x, minf(hp.x, fp.x)), minf(lo.y, minf(hp.y, fp.y)), 0)
				hi = Vector3(maxf(hi.x, maxf(hp.x, fp.x)), maxf(hi.y, maxf(hp.y, fp.y)), 0)
			if lo.x == INF:
				mode = "follow"
				return
			var c := (lo + hi) * 0.5
			var w := hi.x - lo.x
			var hh := hi.y - lo.y
			var d2 := clampf(maxf(w * 0.85, hh * 1.85) + 3.4, 6.0, 26.0)
			# the dialogue box covers the bottom of the screen: frame higher
			want_look = Vector3(c.x, c.y - d2 * 0.1, 0.0)
			want_pos = want_look + Vector3(0, 0.5, d2)
		"shot":
			k = frame_speed
			want_look = shot_look
			want_pos = shot_pos
	if mode != "shot":
		want_look.x = clampf(want_look.x, min_x, max_x)
		want_pos.x = clampf(want_pos.x, min_x, max_x)
		var floor_y := min_y if mode == "follow" else -0.4
		var lift := maxf(0.0, floor_y - want_look.y)
		want_look.y += lift
		want_pos.y += lift
	if _snap:
		_look = want_look
		_pos = want_pos
		_snap = false
	else:
		var a := 1.0 - exp(-dt * k)
		_look = _look.lerp(want_look, a)
		_pos = _pos.lerp(want_pos, a)
	var off := Vector3.ZERO
	if _shake > 0.0:
		off = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.35
		_shake = maxf(0.0, _shake - dt * 2.5)
	global_position = _pos + off
	look_at(_look + off * 0.5, Vector3.UP)
