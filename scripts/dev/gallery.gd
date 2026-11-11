extends Node3D
## Character gallery for screenshots: `-- --gallery [--emotions]`.

const FoodRig = preload("res://scripts/actors/food_rig.gd")
const Cast = preload("res://scripts/dialogue/cast.gd")
const Meshes = preload("res://scripts/gfx/meshes.gd")
const Mats = preload("res://scripts/gfx/mats.gd")

var rigs: Array = []


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.12, 0.13, 0.17)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.6, 0.72)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	sun.look_at_from_position(Vector3(4, 10, 8), Vector3.ZERO)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-6, 4, 6)
	fill.light_color = Color(0.7, 0.8, 1.0)
	fill.light_energy = 1.2
	fill.omni_range = 30
	add_child(fill)
	var floor := MeshInstance3D.new()
	floor.mesh = Meshes.box(Vector3(60, 0.2, 14))
	floor.material_override = Mats.solid(Color(0.32, 0.33, 0.38), 0.7)
	floor.position = Vector3(0, -0.1, -3)
	add_child(floor)
	var cam := Camera3D.new()
	cam.fov = 40
	add_child(cam)
	if Game.dev.has("emotions"):
		_emotions(cam)
	else:
		_cast(cam)


func _cast(cam: Camera3D) -> void:
	var ids := ["baker", "one", "twelve", "skim", "gary", "virgin", "beans", "dot", "sour", "rolls"]
	var x := -11.0
	for id in ids:
		var rig := Cast.make_rig(id)
		add_child(rig)
		rig.position = Vector3(x, 0, 0)
		x += maxf(rig.h * 0.9, 1.6) + 0.9
		rigs.append(rig)
		var t := Label3D.new()
		t.text = id
		t.font_size = 48
		t.pixel_size = 0.006
		t.position = Vector3(rig.position.x, -0.35, 0.8)
		add_child(t)
	var center := (x - 11.0 - 1.0) * 0.5
	var span := x + 11.0
	cam.position = Vector3(center, 2.4, span * 0.75)
	cam.look_at(Vector3(center, 1.8, 0))


func _emotions(cam: Camera3D) -> void:
	var names: Array = FoodRig.EMO.keys()
	var cols := 8
	for i in names.size():
		var rig := Cast.make_rig("baker")
		add_child(rig)
		rig.position = Vector3((i % cols) * 1.5 - 5.25, 0 if i < cols else -2.0, 0)
		rig.set_emotion(names[i])
		rig.set("_blink_t", 999.0)
		var t := Label3D.new()
		t.text = names[i]
		t.font_size = 32
		t.pixel_size = 0.005
		t.position = rig.position + Vector3(0, -0.25, 0.6)
		add_child(t)
	cam.position = Vector3(0, 0.0, 10)
	cam.look_at(Vector3(0, -0.4, 0))
