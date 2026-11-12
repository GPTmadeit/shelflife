extends "res://scripts/world/level.gd"
## Act One: Unplanned. The dairy case, the main aisle and the Narc, the
## bakery, the Employees Only doors and the breakroom.
##
## Layout (x runs left to right, the player lives on z = 0):
##   dairy cooler  -12..28   (decks per bay; Baker starts on the egg deck)
##   main aisle     28..92   (Her Holiness's endcap, the Narc's patrol)
##   bakery         92..132  (tables, the Reduced rack, Dot)
##   back hall     132..150  (the Employees Only doors) -> breakroom behind

const CHECKPOINTS := {
	"start": Vector3(-0.6, 10.8, 0), "yogurt": Vector3(9.4, 8.4, 0), "floor": Vector3(30.0, 0, 0),
	"narc": Vector3(47.0, 0, 0), "bakery": Vector3(93.6, 1.6, 0), "hall": Vector3(126.0, 0, 0),
}
const SHOTS := {
	"intro_wide": [Vector3(9.0, 11.5, 44.0), Vector3(9.0, 9.6, 0.0)],
	"carton": [Vector3(3.0, 12.9, 9.5), Vector3(3.0, 11.7, -0.8)],
	"restock": [Vector3(13.0, 11.0, 17.0), Vector3(14.0, 9.6, -0.5)],
	"oven": [Vector3(104.0, 7.5, 12.0), Vector3(111.0, 8.5, -9.0)],
	"narc_show": [Vector3(58.0, 7.0, 22.0), Vector3(60.0, 4.5, -2.0)],
	"doors": [Vector3(144.5, 4.0, 10.0), Vector3(146.5, 3.5, -4.0)],
	"breakroom": [Vector3(144.9, 1.1, -1.2), Vector3(145.5, 8.0, -22.0)],
	"egg_closeup": [Vector3(146.6, 0.9, -13.4), Vector3(144.8, 1.0, -5.6)],
	"hand": [Vector3(150.2, 2.6, -15.0), Vector3(145.2, 2.4, -8.4)],
	"end": [Vector3(146.0, 2.0, 3.0), Vector3(146.4, 1.4, -5.0)],
}

var narc: Node3D
var tyler: Node3D
var day_lights: Array[Light3D] = []
var dairy_ids := ["one", "six", "twelve", "meadow", "clover", "blueberry", "peach", "skim", "whole", "twopct"]
var extra_eggs: Array = []
var blocker: StaticBody3D
var gary_slot := Vector3(13.6, 8.4, -0.7)
var doug: Node3D
var doug_arm: Node3D
var doug_hand: Node3D
var deviled: Node3D
var mic: Node3D
var door_leaf: Node3D
var _cleanup := false
var _flicker: OmniLight3D


func _setup() -> void:
	act = 1
	act_name = "ACT ONE"
	dlg_file = "res://dialogue/act1.dlg"
	checkpoints = CHECKPOINTS
	shots = SHOTS
	cam_min_x = -6.0
	cam_max_x = 146.0
	dot_barks = ["You walk like a lava lamp.", "If you crack, I'm not carrying your yolk.",
		"Fun fact: the floor is where dreams go to get mopped.", "Thirteenth egg. Do you get, like, superpowers?",
		"I'd kill for a coffee. I'd also get dunked in it, so... mixed feelings."]


func _build_world() -> void:
	_build_floor()
	_build_dairy()
	_build_aisle()
	_build_bakery()
	_build_backhall()
	_build_breakroom()


func _begin() -> void:
	if start_checkpoint == "start" and not Game.flag("intro_done"):
		_prepare_intro()
		await get_tree().process_frame
		runner.run("intro")
	else:
		hud.fade(false, 0.6)


# --- geometry: floor ---------------------------------------------------------------------

func _build_floor() -> void:
	var fm := _floor_mat()
	for seg in [[-18.0, 30.0], [30.0, 92.0], [92.0, 133.0], [133.0, 180.0]]:
		var w: float = seg[1] - seg[0]
		var p := MeshInstance3D.new()
		p.mesh = Meshes.box(Vector3(w, 0.4, 56.0))
		p.material_override = fm
		p.position = Vector3(seg[0] + w * 0.5, -0.2, -20.0)
		add_child(p)
	store.solid_lane(-20, 182, -2.0, 0.0)
	store.solid_lane(-16.0, -12.3, 0.0, 40.0)
	store.solid_lane(150.0, 156.0, 0.0, 40.0)
	# the store's back wall and ceiling darkness behind everything
	var wall := Mats.solid(Color(0.13, 0.15, 0.2), 0.9)
	store.box(Vector3(8, 18, -7.0), Vector3(50, 36, 1), wall)


# --- geometry: dairy --------------------------------------------------------------------------

func _deck(x0: float, x1: float, top: float) -> void:
	var deck_m := Mats.solid(Color(0.76, 0.79, 0.83), 0.35, 0.55)
	store.platform(x0, x1, top, 0.3, deck_m, -2.9, 0.92)
	var cx := (x0 + x1) * 0.5
	store.box(Vector3(cx, top - 0.44, 0.99), Vector3(x1 - x0, 0.48, 0.08), Mats.solid(Color(0.86, 0.87, 0.88), 0.5))
	store.box(Vector3(cx, top - 0.7, 0.72), Vector3(x1 - x0, 0.06, 0.14), Mats.glow(Color(0.82, 0.92, 1.0), 2.4))
	var x := x0 + 1.3
	while x < x1 - 0.8:
		store.product("tag", Vector3(x, top - 0.6, 1.04), Color(1.0, 0.9, 0.35) if _rng.randf() < 0.3 else Color(0.97, 0.97, 0.95))
		x += 2.7


func _build_dairy() -> void:
	store.section = "dairy"
	var steel := Mats.solid(Color(0.58, 0.62, 0.67), 0.45, 0.4)
	var kick := Mats.solid(Color(0.1, 0.11, 0.13), 0.6)
	var led := Mats.glow(Color(0.85, 0.93, 1.0), 2.4)
	# base (kick plate) and the bottom deck on top of it
	store.box(Vector3(8, 0.78, -0.8), Vector3(40.4, 1.56, 4.5), kick)
	store.solid_lane(-12.3, 28.0, 0.0, 1.6)
	store.box(Vector3(8, 1.55, -0.85), Vector3(40.0, 0.1, 4.3), Mats.solid(Color(0.76, 0.79, 0.83), 0.35, 0.55))
	store.box(Vector3(8, 1.12, 1.42), Vector3(40.0, 0.5, 0.08), Mats.solid(Color(0.86, 0.87, 0.88), 0.5))
	store.box(Vector3(8, 10.6, -3.15), Vector3(40.8, 21.2, 0.4), Mats.solid(Color(0.5, 0.56, 0.63), 0.5, 0.25))
	store.box(Vector3(-12.6, 10.6, -0.8), Vector3(0.6, 21.2, 4.8), steel)
	store.box(Vector3(28.6, 10.6, -2.3), Vector3(0.6, 21.2, 1.8), steel)
	store.box(Vector3(8, 20.8, -1.0), Vector3(41.4, 2.0, 5.0), Mats.solid(Color(0.17, 0.19, 0.23), 0.5))
	store.box(Vector3(8, 19.7, 1.35), Vector3(40.8, 0.25, 0.25), led)
	store.label("DAIRY", Vector3(8, 25.0, -3.2), 5.0, Color(0.62, 0.86, 1.0), 14, Color(0.04, 0.08, 0.16))
	for bx in [-2.0, 8.0, 18.0]:
		store.box(Vector3(bx, 10.6, -2.85), Vector3(0.35, 21.2, 0.3), steel)
	_deck(-12.3, -2, 6.2)
	_deck(-12.3, -2, 10.8)
	_deck(-12.3, -2, 15.4)
	_deck(-2, 8, 6.2)
	_deck(-2, 8, 10.8)
	_deck(-2, 8, 15.4)
	_deck(8, 18, 8.4)
	_deck(8, 18, 13.4)
	_deck(18, 25, 4.4)
	_deck(18, 28, 11.6)
	for bx in [0.0, 18.0]:
		store.omni(Vector3(bx, 9.5, 3.0), Color(0.78, 0.88, 1.0), 1.6, 19.0)
	# --- products
	var whites := [Color(0.95, 0.95, 0.97)]
	var caps := [Color(0.85, 0.15, 0.15), Color(0.2, 0.42, 0.9), Color(0.85, 0.36, 0.7), Color(0.3, 0.7, 0.9)]
	# B1
	store.row("tallcan", -11.3, -2.8, 15.4, -2.2, 1.0, whites, [Color(0.9, 0.2, 0.2), Color(0.2, 0.4, 0.85)])
	store.row("tallcan", -10.8, -3.2, 15.4, -1.2, 1.0, whites, [Color(0.9, 0.2, 0.2)])
	for z in [-2.2]:
		for x in [-10.4, -6.6, -3.0]:
			store.product("eggbox", Vector3(x, 10.8, z), Color(0.72, 0.56, 0.38), Color(0.3, 0.58, 0.28))
			store.product("eggbox", Vector3(x, 12.05, z), Color(0.72, 0.56, 0.38), Color(0.3, 0.58, 0.28))
	store.label("FREE RANGE", Vector3(-6.8, 14.2, -2.0), 0.9, Color(0.3, 0.58, 0.28), 6, Color(0.95, 0.92, 0.85))
	store.row("box", -11.2, -2.8, 6.2, -2.1, 1.75, [Color(0.98, 0.86, 0.36)], [Color(0.85, 0.2, 0.15)])
	store.row("box", -11.2, -2.8, 6.2, -1.0, 1.75, [Color(0.98, 0.86, 0.36)], [Color(0.2, 0.45, 0.8)])
	store.row("box", -11.2, -2.8, 6.9, -2.1, 1.75, [Color(0.98, 0.86, 0.36)], [Color(0.85, 0.2, 0.15)])
	# B2
	store.row("tub", -1.2, 7.2, 15.4, -2.1, 1.9, [Color(0.25, 0.5, 0.9), Color(0.2, 0.6, 0.4)], [Color(0.95, 0.95, 0.95)])
	store.row("tub", -0.5, 6.6, 15.4, -0.9, 1.9, [Color(0.25, 0.5, 0.9)], [Color(0.95, 0.95, 0.95)])
	store.product("eggbox", Vector3(-0.2, 10.8, -2.2), Color(0.93, 0.93, 0.9), Color(0.55, 0.7, 0.85), 0.04)
	store.product("eggbox", Vector3(-0.2, 12.05, -2.2), Color(0.93, 0.93, 0.9), Color(0.55, 0.7, 0.85), -0.03)
	store.row("box", -1.2, 7.2, 6.2, -2.1, 1.75, [Color(0.95, 0.8, 0.3), Color(0.98, 0.95, 0.85)], [Color(0.2, 0.55, 0.3)])
	store.row("box", -1.2, 7.2, 6.2, -1.0, 1.75, [Color(0.95, 0.8, 0.3)], [Color(0.2, 0.55, 0.3)])
	store.row("carton", -11.0, 7.0, 1.6, -2.1, 1.6, [Color(0.97, 0.97, 0.95), Color(1.0, 0.65, 0.2)], [Color(0.25, 0.5, 0.9), Color(0.95, 0.5, 0.1), Color(0.3, 0.7, 0.35)])
	store.row("jug", -10.6, 6.6, 1.6, -0.6, 2.05, whites, caps)
	# B3
	store.row("tub", 8.9, 17.2, 13.4, -2.1, 1.85, [Color(0.95, 0.95, 0.97)], [Color(0.2, 0.45, 0.85)])
	var yog := [Color(0.94, 0.42, 0.55), Color(0.36, 0.38, 0.76), Color(0.98, 0.6, 0.32), Color(0.55, 0.78, 0.35), Color(0.96, 0.95, 0.9)]
	store.row("cup", 8.8, 17.3, 8.4, -2.1, 1.05, yog, [Color.WHITE])
	store.row("cup", 8.8, 9.4, 8.4, -1.05, 1.05, yog, [Color.WHITE])
	store.row("cup", 14.8, 17.3, 8.4, -1.05, 1.05, yog, [Color.WHITE])
	store.row("jug", 9.0, 17.2, 1.6, -2.2, 2.05, whites, caps)
	# B4
	store.row("bag", 18.9, 27.3, 11.6, -2.1, 1.9, [Color(0.98, 0.78, 0.3), Color(0.98, 0.95, 0.85)], [Color(0.98, 0.97, 0.9)])
	store.row("bag", 19.6, 26.6, 11.6, -1.2, 1.9, [Color(0.98, 0.78, 0.3)], [Color(0.98, 0.97, 0.9)])
	store.row("box", 18.9, 24.2, 4.4, -2.1, 1.75, [Color(0.86, 0.89, 0.95)], [Color(0.2, 0.35, 0.75)])
	store.row("box", 21.6, 24.2, 4.4, -1.0, 1.75, [Color(0.86, 0.89, 0.95)], [Color(0.2, 0.35, 0.75)])
	store.row("jug", 18.9, 27.2, 1.6, -2.2, 2.05, whites, caps)
	# the cream cheese stairs
	var cc := Mats.skin(Color(0.86, 0.89, 0.95), 0.5)
	var ccb := Mats.solid(Color(0.2, 0.35, 0.75), 0.5)
	for k in 3:
		store.box(Vector3(19.5, 4.4 + 0.35 + k * 0.7, -0.3), Vector3(2.2, 0.68, 1.6), cc, 0.08)
		store.box(Vector3(19.5, 4.4 + 0.4 + k * 0.7, -0.3), Vector3(2.24, 0.2, 1.64), ccb)
	store.solid_lane(18.4, 20.6, 4.4, 6.5)
	# shelf talkers
	_talker(Vector3(12.0, 8.4 - 1.0, 1.1), "NEW!", Color(0.95, 0.2, 0.25))
	_talker(Vector3(-6.0, 10.8 - 1.0, 1.1), "ORGANIC", Color(0.3, 0.6, 0.3))
	_talker(Vector3(22.0, 4.4 - 1.0, 1.1), "2 FOR $5", Color(1.0, 0.8, 0.15))
	# the family carton: open, twelve cups
	var foam := Mats.skin(Color(0.9, 0.9, 0.86), 0.9)
	store.box(Vector3(4.35, 10.8 + 0.45, -1.6), Vector3(6.6, 0.9, 2.3), foam, 0.15)
	var lid := store.box(Vector3(4.35, 12.6, -2.75), Vector3(6.6, 2.6, 0.18), foam, 0.06)
	lid.rotation.x = -0.25
	store.label("GRADE A LARGE • 12 CT", Vector3(4.35, 12.7, -2.6), 0.42, Color(0.3, 0.45, 0.7))
	blocker = store.solid_lane(28.0, 28.4, 1.6, 7.0)




# --- geometry: main aisle ------------------------------------------------------------------------

func _endcap(cx: float, z: float, palettes: Array, header: String, header_col: Color) -> void:
	var frame := Mats.solid(Color(0.24, 0.26, 0.3), 0.6)
	store.box(Vector3(cx, 13.0, z - 1.6), Vector3(10.0, 26.0, 0.6), frame)
	store.box(Vector3(cx, 0.8, z), Vector3(10.4, 1.6, 3.4), Mats.solid(Color(0.15, 0.16, 0.19), 0.6))
	store.box(Vector3(cx, 27.0, z), Vector3(10.6, 2.6, 3.6), Mats.solid(header_col.darkened(0.3), 0.5))
	store.label(header, Vector3(cx, 27.0, z + 1.82), 1.4, Color(1, 1, 1), 8, header_col.darkened(0.6))
	var shelves := [1.6, 6.6, 11.6, 16.6, 21.6]
	for i in shelves.size():
		var y: float = shelves[i]
		store.box(Vector3(cx, y - 0.1, z), Vector3(10.0, 0.2, 3.2), Mats.solid(Color(0.7, 0.72, 0.75), 0.4, 0.4))
		var pal: Array = palettes[i % palettes.size()]
		store.row(pal[0], cx - 3.8, cx + 3.8, y, z + 0.6, pal[1], pal[2], pal[3] if pal.size() > 3 else [])


func _build_aisle() -> void:
	store.section = "aisle"
	var cereal := ["cereal", 2.5, [Color(0.95, 0.75, 0.1), Color(0.85, 0.2, 0.2), Color(0.25, 0.5, 0.9), Color(0.5, 0.3, 0.75)], [Color(1, 1, 1), Color(0.98, 0.9, 0.3)]]
	var chips := ["chips", 2.1, [Color(0.9, 0.15, 0.15), Color(0.2, 0.5, 0.95), Color(0.95, 0.7, 0.1), Color(0.2, 0.7, 0.35)], [Color(0.98, 0.95, 0.85)]]
	var cans := ["can", 1.25, [Color(0.85, 0.2, 0.15), Color(0.9, 0.55, 0.1), Color(0.3, 0.6, 0.3), Color(0.95, 0.9, 0.8)]]
	var soda := ["soda", 3.5, [Color(0.85, 0.12, 0.12), Color(0.1, 0.35, 0.8), Color(0.2, 0.65, 0.3)], [Color(0.98, 0.98, 0.95), Color(0.95, 0.85, 0.2)]]
	var jars := ["jar", 1.45, [Color(0.75, 0.3, 0.15), Color(0.55, 0.65, 0.2), Color(0.85, 0.6, 0.2)], [Color(0.9, 0.85, 0.3), Color(0.8, 0.2, 0.2)]]
	_endcap(36.0, -10.0, [soda, cereal, chips, cereal, chips], "SNACK ATTACK", Color(0.9, 0.25, 0.2))
	_endcap(52.0, -10.0, [cans, jars, cans, jars, cans], "SOUP-ER SAVER", Color(0.25, 0.55, 0.9))
	_endcap(68.0, -10.0, [cereal, cereal, chips, cereal, soda], "BREAKFAST BLOWOUT", Color(0.95, 0.65, 0.1))
	_endcap(84.0, -10.0, [chips, soda, chips, cans, chips], "GAME DAY", Color(0.2, 0.65, 0.35))
	# dark aisles receding between the endcaps
	var gondola := Mats.solid(Color(0.12, 0.13, 0.17), 0.8)
	for gx in [44.0, 60.0, 76.0, 92.0]:
		for side in [-1.0, 1.0]:
			store.box(Vector3(gx + side * 3.3, 13.0, -34.0), Vector3(1.2, 26.0, 46.0), gondola)
		store.label(str(int(gx / 16.0)), Vector3(gx, 31.0, -14.0), 3.0, Color(1, 1, 1), 10, Color(0.1, 0.2, 0.4))
	# soda pyramid
	var reds := [Mats.skin(Color(0.82, 0.12, 0.12), 0.5), Mats.skin(Color(0.12, 0.35, 0.8), 0.5)]
	var layers := [[31.6, 36.6, 0.0], [32.8, 35.4, 1.6]]
	for i in layers.size():
		var l: Array = layers[i]
		var w: float = l[1] - l[0]
		var n := maxi(1, int(round(w / 1.7)))
		for k in n:
			var bx: float = l[0] + (k + 0.5) * w / n
			store.box(Vector3(bx, l[2] + 0.8, -0.6), Vector3(w / n - 0.06, 1.56, 2.6), reds[(i + k) % 2], 0.08)
		store.solid_lane(l[0], l[1], l[2], l[2] + 1.6)
	store.label("FIZZ!", Vector3(34.1, 4.4, -0.6), 0.9, Color(1, 0.95, 0.4), 8, Color(0.5, 0.1, 0.1))
	# Her Holiness's endcap (oils & vinegars), in the play lane
	var ec := 41.6
	store.box(Vector3(ec, 0.6, -0.7), Vector3(8.4, 1.2, 4.4), Mats.solid(Color(0.16, 0.12, 0.1), 0.6))
	store.solid_lane(ec - 4.2, ec + 4.2, 0.0, 1.2)
	store.box(Vector3(ec, 9.0, -2.95), Vector3(8.4, 18.0, 0.3), Mats.solid(Color(0.3, 0.22, 0.16), 0.6))
	for y in [4.8, 8.6, 12.4]:
		store.box(Vector3(ec, y - 0.1, -1.9), Vector3(8.4, 0.2, 2.0), Mats.solid(Color(0.55, 0.42, 0.28), 0.5))
	store.row("bottle", ec - 3.2, ec + 3.2, 8.6, -2.2, 1.1, [Color(0.1, 0.25, 0.1), Color(0.12, 0.3, 0.12), Color(0.15, 0.06, 0.05)], [Color(0.96, 0.9, 0.7), Color(0.85, 0.75, 0.4)])
	store.row("bottle", ec - 3.2, ec + 3.2, 12.4, -2.2, 1.1, [Color(0.15, 0.06, 0.05), Color(0.1, 0.25, 0.1)], [Color(0.96, 0.9, 0.7)])
	store.row("bottle", ec - 3.6, ec - 2.4, 4.8, -2.3, 1.1, [Color(0.1, 0.25, 0.1)], [Color(0.96, 0.9, 0.7)])
	store.row("jar", ec - 3.4, ec + 3.4, 1.2, -2.0, 1.4, [Color(0.4, 0.5, 0.15), Color(0.25, 0.3, 0.1)], [Color(0.85, 0.7, 0.3)])
	store.box(Vector3(ec, 17.4, -2.6), Vector3(8.6, 1.6, 0.5), Mats.solid(Color(0.12, 0.2, 0.1), 0.5))
	store.label("PREMIUM OILS & VINEGARS", Vector3(ec, 17.4, -2.32), 0.85, Color(0.96, 0.85, 0.5))
	_talker(Vector3(ec - 2.0, 4.0, -0.85), "EYE LEVEL", Color(0.75, 0.55, 0.15))
	var holy := store.spot(Vector3(ec - 0.5, 16.0, 3.0), Vector3(ec - 0.5, 6.0, -1.2), Color(1.0, 0.85, 0.5), 4.0, 16.0, 16.0)
	holy.name = "HolyLight"
	# the Narc's beat: baskets, the wet floor sign, the pallet, a cart, a mop bucket
	var basket := Mats.skin(Color(0.8, 0.12, 0.15), 0.5)
	for k in 3:
		store.box(Vector3(53.5, 0.4 + k * 0.7, -0.4), Vector3(3.0 - k * 0.04, 0.66, 2.2), basket, 0.12)
	store.solid_lane(52.0, 55.0, 0.0, 2.1)
	_wet_floor_sign(59.5)
	hide_zones.append(Rect2(58.2, -1.0, 2.6, 3.2))
	var wood := Mats.solid(Color(0.62, 0.46, 0.28), 0.85)
	for k in 3:
		store.box(Vector3(66.0, 0.15 + k * 0.32, -0.6), Vector3(6.0, 0.16, 3.2), wood)
	store.solid_lane(63.0, 69.0, 0.0, 0.9)
	store.box(Vector3(66.6, 2.1, -0.7), Vector3(3.2, 2.4, 2.8), Mats.solid(Color(0.7, 0.55, 0.36), 0.9), 0.05)
	store.solid_lane(65.0, 68.2, 0.9, 3.3)
	store.label("SUPER\nSAVER", Vector3(66.6, 2.1, 0.72), 0.7, Color(0.75, 0.15, 0.1))
	_cart(73.2)
	_mop_bucket(79.3)
	for k in 4:
		store.box(Vector3(86.5, 0.1 + k * 0.2, -0.5), Vector3(4.0 + _rng.randf() * 0.4, 0.18, 3.0), Mats.solid(Color(0.68, 0.53, 0.34), 0.9))
	store.solid_lane(84.5, 88.5, 0.0, 0.8)
	# one warm pool of light mid-aisle
	store.spot(Vector3(70.0, 26.0, 6.0), Vector3(70.0, 0.0, -1.0), Color(1.0, 0.93, 0.82), 2.6, 34.0, 22.0)


func _wet_floor_sign(x: float) -> void:
	var yel := Mats.skin(Color(1.0, 0.82, 0.08), 0.45)
	var half := 1.35
	var hgt := 9.0
	for side in [-1.0, 1.0]:
		var panel := MeshInstance3D.new()
		panel.mesh = Meshes.rounded_box(Vector3(0.18, hgt, 3.0), 0.08, 2)
		panel.material_override = yel
		add_child(panel)
		var tilt := atan2(half, hgt)
		panel.position = Vector3(x + side * half * 0.5, hgt * 0.5 * cos(tilt), -0.2)
		panel.rotation.z = side * tilt
	var t: Label3D = store.label("CAUTION\nWET FLOOR", Vector3(x, 6.4, 1.4), 0.62, Color(0.1, 0.08, 0.05))
	t.outline_size = 0
	store.mesh(Meshes.rounded_box(Vector3(3.0, 0.3, 0.3), 0.1, 2), yel, Vector3(x, hgt * 0.97, -0.2))


func _cart(x: float) -> void:
	var metal := Mats.solid(Color(0.7, 0.72, 0.76), 0.3, 0.8)
	var red := Mats.skin(Color(0.8, 0.12, 0.15), 0.5)
	var black := Mats.solid(Color(0.06, 0.06, 0.07), 0.6)
	for wx in [-2.4, 2.4]:
		for wz in [-1.6, 1.2]:
			store.mesh(Meshes.cyl(0.42, 0.42, 0.34, 14), black, Vector3(x + wx, 0.42, wz - 0.2), Vector3(PI * 0.5, 0, 0))
	store.box(Vector3(x, 2.25, -0.2), Vector3(5.6, 0.14, 3.2), metal)
	store.solid_lane(x - 2.7, x + 2.7, 2.1, 2.3)
	for wx in [-2.7, 2.7]:
		store.box(Vector3(x + wx, 5.2, -0.2), Vector3(0.12, 10.2, 0.12), metal)
	store.box(Vector3(x, 8.6, -0.4), Vector3(6.4, 4.6, 3.8), Mats.glass(Color(0.7, 0.72, 0.76, 0.22)), 0.2)
	store.box(Vector3(x, 10.9, -0.4), Vector3(6.5, 0.22, 3.9), red)
	store.box(Vector3(x - 3.6, 12.2, -0.4), Vector3(0.4, 0.4, 4.0), red)


func _mop_bucket(x: float) -> void:
	var yel := Mats.skin(Color(1.0, 0.8, 0.08), 0.45)
	var prof := PackedVector2Array([Vector2(0, 0), Vector2(1.15, 0), Vector2(1.3, 2.3), Vector2(1.18, 2.3), Vector2(1.05, 0.3), Vector2(0, 0.3)])
	store.mesh(Meshes.lathe(prof, 22), yel, Vector3(x, 0, -0.2))
	store.mesh(Meshes.cyl(1.17, 1.17, 0.1, 22), Mats.glass(Color(0.35, 0.45, 0.4, 0.8)), Vector3(x, 1.85, -0.2))
	store.mesh(Meshes.cyl(0.12, 0.12, 22.0, 8), Mats.solid(Color(0.4, 0.3, 0.2), 0.7), Vector3(x + 0.6, 12.0, -0.5), Vector3(0, 0, -0.12))
	store.solid_lane(x - 1.25, x + 1.25, 0.0, 2.3)


# --- geometry: bakery ----------------------------------------------------------------------------

func _build_bakery() -> void:
	store.section = "bakery"
	var wood := Mats.solid(Color(0.55, 0.36, 0.2), 0.7)
	var steel := Mats.solid(Color(0.7, 0.72, 0.75), 0.3, 0.7)
	# back: counter, display case, oven wall, sign
	store.box(Vector3(112, 18, -12.5), Vector3(42, 36, 1), Mats.solid(Color(0.32, 0.22, 0.16), 0.9))
	store.box(Vector3(110, 4.5, -7.0), Vector3(30, 9, 3), Mats.solid(Color(0.45, 0.28, 0.18), 0.7))
	store.box(Vector3(110, 10.5, -7.0), Vector3(30, 3.0, 3), Mats.glass(Color(0.75, 0.85, 0.9, 0.18)))
	store.row("cake", 97.5, 122.5, 9.0, -7.0, 3.6, [Color(0.98, 0.9, 0.8), Color(0.45, 0.25, 0.15), Color(0.98, 0.7, 0.75)], [Color(0.98, 0.5, 0.6), Color(1, 1, 1), Color(0.35, 0.2, 0.12)])
	store.box(Vector3(112, 11.0, -11.6), Vector3(16, 12, 1.0), steel)
	store.box(Vector3(112, 10.5, -11.0), Vector3(11, 6.5, 0.3), Mats.glow(Color(1.0, 0.45, 0.12), 2.2))
	store.box(Vector3(112, 15.6, -11.0), Vector3(3, 0.6, 0.4), Mats.solid(Color(0.15, 0.15, 0.16), 0.5))
	store.label("BAKERY", Vector3(112, 22.5, -11.8), 4.5, Color(1.0, 0.75, 0.4), 14, Color(0.25, 0.1, 0.03))
	store.row("loaf", 95.5, 104.5, 13.0, -11.6, 3.4, [Color(0.75, 0.5, 0.25), Color(0.6, 0.38, 0.18)], [Color(0.9, 0.75, 0.5)])
	store.row("baguette", 118.5, 128.5, 13.5, -11.6, 4.6, [Color(0.85, 0.62, 0.32)])
	store.omni(Vector3(112, 9.0, -8.0), Color(1.0, 0.55, 0.22), 2.6, 22.0)
	store.omni(Vector3(110, 10.0, 4.0), Color(1.0, 0.85, 0.65), 1.4, 22.0)
	# bread trays as a step
	var tray := Mats.skin(Color(0.25, 0.55, 0.35), 0.6)
	for k in 3:
		store.box(Vector3(93.5, 0.25 + k * 0.5, -0.3), Vector3(1.8, 0.46, 2.6), tray, 0.06)
	store.solid_lane(92.6, 94.4, 0.0, 1.5)
	# tables
	for t in [[94.6, 104.6], [108.6, 116.2]]:
		var x0: float = t[0]
		var x1: float = t[1]
		store.platform(x0, x1, 3.0, 0.3, wood, -2.8, 1.0, 0.06)
		for lx in [x0 + 0.4, x1 - 0.4]:
			for lz in [-2.4, 0.6]:
				store.box(Vector3(lx, 1.35, lz), Vector3(0.3, 2.7, 0.3), wood)
	store.row("loaf", 99.0, 103.5, 3.0, -2.0, 3.4, [Color(0.75, 0.5, 0.25)], [Color(0.92, 0.8, 0.55)])
	store.row("cake", 112.0, 115.5, 3.0, -1.6, 3.6, [Color(0.98, 0.9, 0.8), Color(0.45, 0.25, 0.15)], [Color(0.98, 0.5, 0.6), Color(1, 1, 1)])
	# the bouncy brioche (a cushion)
	var bri := MeshInstance3D.new()
	bri.mesh = Meshes.rounded_box(Vector3(2.4, 1.3, 2.0), 0.6, 3)
	bri.material_override = Mats.skin(Color(0.95, 0.68, 0.3), 0.35)
	bri.position = Vector3(110.3, 3.65, -0.3)
	add_child(bri)
	store.solid_lane(109.1, 111.5, 3.0, 4.2, {"cushion": true})
	_talker(Vector3(110.3, 2.4, 1.05), "SO SOFT!", Color(0.95, 0.45, 0.2))
	# the Reduced rack (wire shelves)
	var wire := Mats.solid(Color(0.75, 0.77, 0.8), 0.3, 0.8)
	for s in [[118.0, 124.0, 2.3], [118.0, 124.0, 4.9], [118.0, 121.2, 7.5]]:
		store.platform(s[0], s[1], s[2], 0.14, wire, -2.4, 0.7)
	for px in [118.0, 124.0]:
		for pz in [-2.3, 0.6]:
			store.box(Vector3(px, 5.0, pz), Vector3(0.16, 10.0, 0.16), wire)
	store.box(Vector3(121, 10.6, -1.0), Vector3(5.0, 1.4, 0.15), Mats.solid(Color(1.0, 0.85, 0.1), 0.5))
	var rl: Label3D = store.label("REDUCED", Vector3(121, 10.6, -0.9), 0.9, Color(0.75, 0.1, 0.05))
	rl.outline_size = 0
	store.row("loaf", 119.2, 123.0, 4.9, -1.7, 1.9, [Color(0.65, 0.45, 0.25)], [Color(0.85, 0.75, 0.55)])
	store.row("baguette", 120.0, 120.0, 2.3, -1.9, 3.0, [Color(0.8, 0.6, 0.32)])


# --- geometry: back hall & breakroom -----------------------------------------------------------------

func _build_backhall() -> void:
	store.section = "hall"
	var blocks := Mats.textured(FaceTex.blocks(), 0.85, Vector3(0.06, 0.06, 0.06))
	blocks.uv1_triplanar = true
	blocks.uv1_world_triplanar = true
	# the wall with the doors; an opening (x 142..147.5) where the door is propped
	store.box(Vector3(136.0, 20.0, -4.3), Vector3(12.0, 40.0, 0.6), blocks)
	store.box(Vector3(160.0, 20.0, -4.3), Vector3(25.0, 40.0, 0.6), blocks)
	store.box(Vector3(145.0, 30.0, -4.3), Vector3(6.0, 20.0, 0.6), blocks)
	store.box(Vector3(130.3, 20.0, -8.4), Vector3(0.6, 40.0, 8.0), blocks)
	var door_m := Mats.solid(Color(0.42, 0.48, 0.55), 0.4, 0.5)
	# closed right leaf
	store.box(Vector3(150.6, 10.0, -4.0), Vector3(6.2, 20.0, 0.4), door_m)
	store.box(Vector3(150.6, 1.2, -3.78), Vector3(6.0, 2.4, 0.05), Mats.solid(Color(0.7, 0.72, 0.75), 0.3, 0.8))
	# the propped leaf, hinged at x=142
	door_leaf = Node3D.new()
	door_leaf.position = Vector3(142.0, 0, -4.0)
	add_child(door_leaf)
	store.mesh(Meshes.box(Vector3(5.6, 20.0, 0.4)), door_m, Vector3(2.8, 10.0, 0), Vector3.ZERO, door_leaf)
	store.mesh(Meshes.box(Vector3(5.4, 2.4, 0.05)), Mats.solid(Color(0.7, 0.72, 0.75), 0.3, 0.8), Vector3(2.8, 1.2, 0.22), Vector3.ZERO, door_leaf)
	door_leaf.rotation.y = 0.55
	var sign_m := Mats.solid(Color(0.85, 0.12, 0.1), 0.5)
	store.box(Vector3(150.6, 11.5, -3.75), Vector3(4.6, 2.2, 0.08), sign_m)
	var t: Label3D = store.label("EMPLOYEES\nONLY", Vector3(150.6, 11.5, -3.68), 0.85, Color(1, 1, 1))
	t.outline_size = 0
	# the rubber wedge
	store.mesh(Meshes.prism(Vector3(1.4, 0.7, 1.2)), Mats.solid(Color(0.2, 0.15, 0.12), 0.8), Vector3(146.8, 0.35, -5.0))
	# decor: crates, bucket, bulletin board, extinguisher, exit sign
	var crate := Mats.skin(Color(0.2, 0.35, 0.75), 0.6)
	for k in 2:
		store.box(Vector3(135.25, 0.55 + k * 1.1, -0.4), Vector3(2.5, 1.06, 2.6), crate, 0.08)
	store.solid_lane(134.0, 136.5, 0.0, 2.2)
	store.box(Vector3(138.5, 11.0, -3.95), Vector3(6.0, 4.5, 0.2), Mats.solid(Color(0.6, 0.45, 0.28), 0.9))
	store.box(Vector3(137.4, 11.3, -3.82), Vector3(2.2, 2.8, 0.04), Mats.solid(Color(0.97, 0.97, 0.93), 0.8))
	var eom: Label3D = store.label("EMPLOYEE\nOF THE MONTH:\nTYLER", Vector3(137.4, 11.3, -3.78), 0.32, Color(0.15, 0.15, 0.2))
	eom.outline_size = 0
	store.box(Vector3(139.9, 11.0, -3.82), Vector3(2.0, 2.6, 0.04), Mats.solid(Color(1.0, 0.95, 0.6), 0.8))
	var memo: Label3D = store.label("RESET\n5 A.M.\nNO EXCUSES\n-DOUG", Vector3(139.9, 11.0, -3.78), 0.3, Color(0.5, 0.1, 0.1))
	memo.outline_size = 0
	store.mesh(Meshes.cyl(0.55, 0.55, 2.6, 14), Mats.skin(Color(0.85, 0.1, 0.08), 0.4), Vector3(133.2, 6.5, -3.6))
	store.box(Vector3(146.0, 22.6, -3.9), Vector3(3.0, 1.2, 0.3), Mats.glow(Color(1.0, 0.15, 0.1), 2.5))
	_flicker = store.omni(Vector3(140.0, 14.0, 1.0), Color(0.85, 0.95, 0.88), 1.6, 20.0)



func _build_breakroom() -> void:
	store.section = "breakroom"
	var bx := 147.0
	var paint := Mats.solid(Color(0.8, 0.76, 0.64), 0.85)
	store.box(Vector3(bx, 20, -40.0), Vector3(46, 40, 1), paint)
	store.box(Vector3(bx - 22.5, 20, -22.0), Vector3(1, 40, 36), paint)
	store.box(Vector3(bx + 22.5, 20, -22.0), Vector3(1, 40, 36), paint)
	store.omni(Vector3(bx, 30, -18), Color(1.0, 0.95, 0.85), 2.4, 48.0)
	store.omni(Vector3(bx - 2, 7, -8), Color(1.0, 0.9, 0.75), 1.4, 14.0)
	var lam := Mats.solid(Color(0.85, 0.85, 0.8), 0.4)
	store.box(Vector3(bx, 12.5, -22), Vector3(24, 0.8, 11), lam, 0.2)
	for lx in [bx - 10.0, bx + 10.0]:
		for lz in [-17.5, -26.5]:
			store.mesh(Meshes.cyl(0.4, 0.4, 12.2, 10), Mats.solid(Color(0.3, 0.3, 0.32), 0.4, 0.6), Vector3(lx, 6.1, lz))
	# the New Planogram on the wall
	store.box(Vector3(bx + 11, 24, -39.4), Vector3(12, 8, 0.2), Mats.solid(Color(0.98, 0.98, 0.96), 0.8))
	var pg: Label3D = store.label("NEW PLANOGRAM\nEFFECTIVE 5:00 A.M.", Vector3(bx + 11, 25.5, -39.25), 1.1, Color(0.15, 0.2, 0.4))
	pg.outline_size = 0
	for gy in 3:
		for gx in 6:
			store.box(Vector3(bx + 6.2 + gx * 1.9, 21.0 + gy * 0.9, -39.28), Vector3(1.7, 0.7, 0.02), Mats.solid(Color(0.6 + gx * 0.05, 0.7, 0.85 - gy * 0.1), 0.8))
	var clock: Label3D = store.label("3:12", Vector3(bx - 9, 30, -39.4), 2.0, Color(0.9, 0.1, 0.1))
	clock.outline_size = 0
	store.box(Vector3(bx + 18, 10, -36), Vector3(7, 20, 6), Mats.solid(Color(0.85, 0.86, 0.88), 0.3, 0.4))
	store.box(Vector3(bx - 15, 14, -37.5), Vector3(8, 1, 4), Mats.solid(Color(0.5, 0.45, 0.4), 0.6))
	store.box(Vector3(bx - 15, 16, -37.5), Vector3(4.5, 3, 3), Mats.solid(Color(0.12, 0.12, 0.13), 0.4))
	_build_doug(bx)


func _build_doug(bx: float) -> void:
	doug = Node3D.new()
	doug.name = "Doug"
	add_child(doug)
	var polo := Mats.skin(Color(0.16, 0.22, 0.42), 0.8)
	var khaki := Mats.skin(Color(0.72, 0.62, 0.45), 0.85)
	var skin := Mats.skin(Color(0.93, 0.74, 0.6), 0.6)
	var shoe := Mats.skin(Color(0.3, 0.18, 0.1), 0.4)
	for side in [-1.0, 1.0]:
		var hx: float = bx + side * 2.0
		store.mesh(Meshes.cyl(1.9, 1.9, 9.0, 14), khaki, Vector3(hx, 10.8, -24.5), Vector3(PI * 0.5, 0, 0), doug)
		store.mesh(Meshes.cyl(1.6, 1.4, 10.4, 14), khaki, Vector3(hx, 5.4, -20.2), Vector3.ZERO, doug)
		store.mesh(Meshes.rounded_box(Vector3(2.4, 1.6, 4.6), 0.6, 2), shoe, Vector3(hx, 0.8, -19.2), Vector3.ZERO, doug)
	store.mesh(Meshes.rounded_box(Vector3(11.0, 17.0, 8.0), 3.0, 3), polo, Vector3(bx, 21.0, -29.0), Vector3.ZERO, doug)
	store.mesh(Meshes.sphere(5.6, 20, 12), polo, Vector3(bx, 17.5, -26.0), Vector3.ZERO, doug)
	store.mesh(Meshes.box(Vector3(2.6, 1.3, 0.1)), Mats.solid(Color(0.97, 0.97, 0.95), 0.6), Vector3(bx - 3.5, 25.0, -24.95), Vector3.ZERO, doug)
	var tag: Label3D = store.label("DOUG\nNIGHT MGR", Vector3(bx - 3.5, 25.0, -24.88), 0.36, Color(0.15, 0.15, 0.3))
	tag.outline_size = 0
	tag.reparent(doug)
	store.mesh(Meshes.sphere(4.2, 20, 12), skin, Vector3(bx, 33.5, -28.5), Vector3.ZERO, doug)
	store.mesh(Meshes.cyl(1.0, 1.4, 4.0, 12), skin, Vector3(bx, 30.0, -28.5), Vector3.ZERO, doug)
	store.mesh(Meshes.cyl(1.4, 1.5, 9.0, 12), polo, Vector3(bx + 6.0, 21.0, -26.0), Vector3(0, 0, 0.25), doug)
	store.mesh(Meshes.cyl(1.2, 1.3, 8.0, 12), skin, Vector3(bx + 7.0, 13.6, -22.0), Vector3(PI * 0.5, 0, 0), doug)
	doug_arm = Node3D.new()
	doug_arm.position = Vector3(bx - 5.5, 26.0, -26.0)
	doug.add_child(doug_arm)
	store.mesh(Meshes.cyl(1.3, 1.4, 10.0, 12), skin, Vector3(0, -5.0, 0), Vector3.ZERO, doug_arm)
	doug_hand = Node3D.new()
	doug_hand.position = Vector3(0, -10.4, 0)
	doug_arm.add_child(doug_hand)
	store.mesh(Meshes.rounded_box(Vector3(2.8, 1.2, 3.4), 0.5, 2), skin, Vector3.ZERO, Vector3.ZERO, doug_hand)
	doug_arm.rotation = Vector3(0.9, 0, 0.15)
	var tub := Node3D.new()
	tub.position = Vector3(bx - 4.5, 12.9, -18.6)
	add_child(tub)
	store.mesh(Meshes.rounded_box(Vector3(5.2, 1.6, 3.6), 0.3, 2), Mats.glass(Color(0.9, 0.95, 1.0, 0.35)), Vector3(0, 0.8, 0), Vector3.ZERO, tub)
	store.mesh(Meshes.box(Vector3(3.6, 0.5, 0.05)), Mats.solid(Color(0.95, 0.92, 0.75), 0.8), Vector3(0, 0.9, 1.82), Vector3.ZERO, tub)
	var tl: Label3D = store.label("DOUG'S - DO NOT TOUCH", Vector3(0, 0.9, 1.86), 0.26, Color(0.2, 0.2, 0.5))
	tl.outline_size = 0
	tl.reparent(tub, false)
	tl.position = Vector3(0, 0.9, 1.86)
	for i in 4:
		var d := _deviled_egg()
		d.position = Vector3(-1.6 + (i % 2) * 1.6 + (i / 2) * 0.8, 0.3, -0.7 + (i / 2) * 1.2)
		tub.add_child(d)
	deviled = _deviled_egg()
	deviled.position = Vector3(bx - 3.4, 13.3, -17.2)
	deviled.visible = false
	add_child(deviled)
	mic = Node3D.new()
	mic.position = Vector3(bx + 5.0, 12.9, -19.5)
	add_child(mic)
	store.mesh(Meshes.cyl(0.6, 0.8, 0.4, 12), Mats.solid(Color(0.1, 0.1, 0.1), 0.5), Vector3(0, 0.2, 0), Vector3.ZERO, mic)
	store.mesh(Meshes.capsule(0.35, 2.6), Mats.solid(Color(0.15, 0.15, 0.16), 0.4), Vector3(0, 1.6, 0), Vector3(0.3, 0, 0), mic)


func _deviled_egg() -> Node3D:
	var n := Node3D.new()
	var white := MeshInstance3D.new()
	white.mesh = Meshes.hemi(0.75, 16, 8)
	white.material_override = Mats.skin(Color(0.98, 0.97, 0.94), 0.35)
	white.rotation.x = PI
	white.scale = Vector3(1.3, 0.7, 0.85)
	n.add_child(white)
	var yolk := MeshInstance3D.new()
	yolk.mesh = Meshes.sphere(0.48, 14, 8)
	yolk.material_override = Mats.skin(Color(1.0, 0.82, 0.25), 0.6)
	yolk.position.y = 0.12
	yolk.scale = Vector3(1.3, 0.75, 0.85)
	n.add_child(yolk)
	for k in 5:
		var p := MeshInstance3D.new()
		p.mesh = Meshes.sphere(0.07, 6, 4)
		p.material_override = Mats.solid(Color(0.85, 0.15, 0.05), 0.8)
		p.position = Vector3(randf_range(-0.4, 0.4), 0.45, randf_range(-0.2, 0.2))
		n.add_child(p)
	return n


# --- cast -----------------------------------------------------------------------------------

func _spawn_cast() -> void:
	# the family in their carton (front row y sits in the cups)
	var cups_y := 10.8 + 0.55
	var slots := [1.8, 2.85, 3.9, 4.95, 6.0, 7.05]
	_add_actor("twelve", Vector3(slots[0], cups_y, -1.0), "twelve_talk", ["Be careful, Baker!", "Eggs don't bounce!"])
	_add_actor("one", Vector3(slots[2], cups_y, -1.0), "one_talk", ["Facing up, Baker.", "Twelve cups. It's math."])
	_add_actor("six", Vector3(slots[4], cups_y, -1.0), "six_talk", ["Is it warm in here?", "I can feel my yolk."])
	for i in 6:
		if i in [0, 2, 4]:
			continue
		var e: Node3D = Cast.make_rig("sib")
		add_child(e)
		e.global_position = Vector3(slots[i], cups_y, -1.0)
		extra_eggs.append(e)
	for i in 6:
		var e2: Node3D = Cast.make_rig("sib")
		add_child(e2)
		e2.global_position = Vector3(slots[i] + 0.2, cups_y + 0.35, -2.0)
		extra_eggs.append(e2)
	_add_actor("meadow", Vector3(-7.4, 10.8, -0.75), "range_talk", ["Free range, darling.", "Is that a CAGE egg?"])
	_add_actor("clover", Vector3(-5.9, 10.8, -0.75), "range_talk", ["Don't stare, Meadow.", "Henrietta did yoga."])
	_add_actor("blueberry", Vector3(10.1, 8.4, -0.75), "yogurt_talk", [])
	_add_actor("peach", Vector3(11.4, 8.4, -0.75), "yogurt_talk", [])
	var gary := _add_actor("gary", gary_slot, "gary_talk", ["I love being Gary.", "...Fruit on the bottom."])
	gary.visible = false
	_add_actor("skim", Vector3(12.8, 1.6, -0.25), "skim_talk", ["Stay cold, child."])
	_add_actor("whole", Vector3(9.6, 1.6, -1.25), "", ["Oat milk is a cult.", "Stay cold!"])
	_add_actor("twopct", Vector3(15.5, 1.6, -1.25), "", ["I'm two percent better than skim.", "Eye level is buy level."])
	actors.whole.face_dir(1.0)
	actors.twopct.face_dir(-1.0)
	_add_actor("virgin", Vector3(40.9, 4.8, -1.1), "virgin_talk", ["Eye level, darling.", "Mind the Narc."])
	_add_actor("balsamic", Vector3(43.9, 4.8, -1.3), "", ["Her Holiness has spoken!", "Aged twelve years. Like fine wine. Or a grudge."])
	_add_actor("beans", Vector3(47.6, 0.0, -0.9), "beans_talk", ["Psst! Floor bad. Up good.", "Under the yellow sign!"])
	actors.beans.watch_player = true
	_add_actor("sour", Vector3(97.6, 3.0, -0.9), "sour_talk", ["Seventy-two hours, darling.", "Ugh. Dairy."])
	_add_actor("rolls", Vector3(101.8, 3.0, -0.9), "rolls_talk", ["Ooooh, fresh meat!", "It's an EGG!", "Ooooh, fresh egg!"], {}, 3)
	var bag := MeshInstance3D.new()
	bag.mesh = Meshes.rounded_box(Vector3(3.6, 1.3, 1.7), 0.4, 2)
	bag.material_override = Mats.glass(Color(0.95, 0.95, 1.0, 0.18))
	bag.position = Vector3(0, 0.55, -0.1)
	actors.rolls.add_child(bag)
	_add_actor("dot", Vector3(121.2, 2.3, -0.4), "dot_meet", [])
	actors.dot.bark_radius = 0.0
	# the Narc and the night crew
	narc = Narc.new()
	narc.name = "Narc"
	add_child(narc)
	narc.global_position = Vector3(62.0, 0.0, -3.4)
	narc.x_min = 52.0
	narc.x_max = 88.5
	narc.player = player
	narc.spotted.connect(_on_narc_spotted)
	actors["narc"] = narc
	tyler = Giant.new()
	tyler.name = "Tyler"
	tyler.build({"pants": Color(0.2, 0.28, 0.45), "shoe": Color(0.95, 0.95, 0.95), "stripe": Color(0.9, 0.2, 0.2), "apron": Color(0.15, 0.5, 0.3), "sleeve": Color(0.15, 0.5, 0.3)})
	add_child(tyler)
	tyler.global_position = Vector3(220.0, 0.0, -6.0)
	tyler.visible = false
	actors["tyler"] = tyler
	actors["doug"] = doug




# --- triggers -------------------------------------------------------------------------------



func _build_triggers() -> void:
	_trigger("gary", Rect2(8.6, 8.0, 7.0, 2.0), func(): runner.run("gary_restock"),
		func(): return not Game.flag("gary_restocked"))
	_trigger("cc_hint", Rect2(15.5, 8.0, 2.4, 2.0), func(): actors.blueberry.bubble("Walk off onto the cream cheese! Don't JUMP down, you'll crack!", 4.0),
		func(): return Game.flag("gary_restocked"))
	_trigger("sermon", Rect2(8.0, 1.5, 20.0, 2.5), func(): runner.run("sermon"),
		func(): return not Game.flag("sermon_done"))
	_trigger("virgin", Rect2(36.6, -0.5, 3.0, 3.0), func(): runner.run("virgin_meet"),
		func(): return not Game.flag("met_virgin"))
	_trigger("beans", Rect2(45.5, -0.5, 3.5, 2.5), func(): runner.run("beans_hint"),
		func(): return not Game.flag("met_beans"))
	_trigger("cp_bakery", Rect2(92.5, -0.5, 3.0, 4.0), func(): _checkpoint("bakery"),
		func(): return Game.checkpoint in ["start", "yogurt", "floor", "narc"])
	_trigger("rolls_hello", Rect2(93.0, -0.5, 4.0, 5.0), func(): actors.rolls.bubble("Ooooh! Fresh meat!"))
	_trigger("dot", Rect2(116.6, -0.5, 8.0, 6.0), func(): runner.run("dot_meet"),
		func(): return not Game.flag("dot_joined"))
	_trigger("ending", Rect2(140.5, -0.5, 6.0, 5.0), func(): runner.run("ending"),
		func(): return Game.flag("dot_joined"))




func _apply_state() -> void:
	var g := Game.flag("gary_restocked")
	actors.gary.visible = g
	if Game.flag("sermon_done") and blocker != null:
		blocker.queue_free()
		blocker = null
	if Game.flag("dot_joined"):
		_start_follow()
	if Game.flag("feather"):
		var tf: Node = actors.twelve.rig().body.get_node_or_null("Feather")
		if tf != null:
			tf.queue_free()
		_give_feather()
	var obj := "Get down to Father Skim's sermon on the bottom shelf."
	if Game.flag("sermon_done"):
		obj = "Get to the Office. Past the Bakery, through the Employees Only doors."
	if Game.flag("met_beans"):
		obj = "Get past the Narc to the Bakery. Stay off the floor when it's looking."
	if Game.flag("dot_joined"):
		obj = "Get to the Employees Only doors. Dot's coming too."
	if Game.flag("intro_done"):
		hud.objective(obj)


func _product(who: String, on: bool) -> void:
	if who != "dairy":
		super(who, on)
		return
	for id in dairy_ids:
		if actors.has(id):
			actors[id].set_product(on)
	for e in extra_eggs:
		e.set_product(on)


# --- events (called from dialogue with ~ event name) ------------------------------------------------

func _prepare_intro() -> void:
	for id in dairy_ids:
		if actors.has(id):
			actors[id].set_product(true)
	for e in extra_eggs:
		e.set_product(true)
	player.rig.set_product(true)
	player.locked = true
	hud.set_black(false)


func _ev_day() -> void:
	env.ambient_light_energy = 1.0
	sun.light_energy = 1.1
	for x in [-4.0, 20.0]:
		var l: OmniLight3D = store.omni(Vector3(x, 26.0, 10.0), Color(1.0, 0.97, 0.9), 2.2, 50.0)
		day_lights.append(l)
	Sfx.ambience("hum_store", -20.0)


func _ev_shopper() -> void:
	var g: Node3D = Giant.new()
	g.build({"pants": Color(0.12, 0.12, 0.14), "shoe": Color(0.15, 0.15, 0.16), "stripe": Color(0.95, 0.95, 0.95), "sole": Color(0.9, 0.9, 0.9)})
	add_child(g)
	g.global_position = Vector3(-30.0, 0.0, 5.0)
	g.walk_to(60.0, 14.0)
	get_tree().create_timer(7.0).timeout.connect(g.queue_free)


func _ev_lights_out() -> void:
	for i in day_lights.size():
		await get_tree().create_timer(0.35).timeout
		day_lights[i].visible = false
		Sfx.play("clunk", -2.0)
		shake(0.2)
	await get_tree().create_timer(0.35).timeout
	Sfx.play("clunk", 0.0, 0.8)
	var tw := create_tween()
	tw.tween_property(env, "ambient_light_energy", 0.5, 0.4)
	tw.parallel().tween_property(sun, "light_energy", 0.5, 0.4)
	Sfx.ambience("hum_fridge", -16.0)


func _ev_wake_up() -> void:
	var ids := dairy_ids.duplicate()
	ids.shuffle()
	var all: Array = []
	for id in ids:
		all.append(actors[id])
	for e in extra_eggs:
		all.append(e)
	all.shuffle()
	for a in all:
		a.set_product(false)
		if _rng.randf() < 0.3:
			Sfx.blip(Cast.info("one").voice)
		await get_tree().create_timer(0.07).timeout
	player.rig.set_product(false)


func _ev_facer_coming() -> void:
	cam.shot(SHOTS.restock[0], SHOTS.restock[1])
	tyler.visible = true
	tyler.global_position = Vector3(48.0, 0.0, 7.5)
	tyler.walk_to(24.0, 12.0)
	await get_tree().create_timer(0.8).timeout


func _ev_restock() -> void:
	for id in dairy_ids:
		actors[id].set_product(true)
	for e in extra_eggs:
		e.set_product(true)
	player.rig.set_product(true)
	await get_tree().create_timer(0.9).timeout
	# the hand comes in from the camera side holding the new Gary
	var gary: Node3D = actors.gary
	var to := gary_slot + Vector3(0.2, 1.75, 0.55)
	var start := to + Vector3(9, 16, 10)
	var grip := Vector3(-0.2, -1.75, -0.55)
	tyler.hand.visible = true
	tyler.hand.global_position = start
	tyler.hand.rotation = Vector3(-0.9, 0.6, 0.0)
	tyler.close_hand()
	gary.visible = true
	gary.set_product(true)
	gary.global_position = start + grip
	Sfx.play_at("whoosh", to, -2.0)
	var tw := create_tween()
	tw.tween_property(tyler.hand, "global_position", to, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(gary, "global_position", gary_slot, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tw.finished
	tyler.open_hand()
	Sfx.play("land", -4.0, 0.8)
	await get_tree().create_timer(0.3).timeout
	var away := create_tween()
	away.tween_property(tyler.hand, "global_position", start, 0.7).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await away.finished
	tyler.hand.visible = false
	await _tyler_line("♪ Stock it up, stock it up, girl you know I stock it up... ♪")
	tyler.walk_to(70.0, 12.0)
	await get_tree().create_timer(1.6).timeout
	tyler.visible = false
	tyler.global_position = Vector3(220, 0, -6)
	for id in dairy_ids:
		actors[id].set_product(false)
	for e in extra_eggs:
		e.set_product(false)
	gary.set_product(false)
	player.rig.set_product(false)
	gary.set_emotion("dazed")


func _tyler_line(text: String) -> void:
	await ui.say("tyler", text, null)


func _ev_feather() -> void:
	Game.set_flag("feather")
	var f: Node = actors.twelve.rig().body.get_node_or_null("Feather")
	if f != null:
		f.queue_free()
	_give_feather()
	Sfx.play("scrap", -6.0)


func _give_feather() -> void:
	var r: Node3D = player.rig
	if r.body.has_node("Feather"):
		return
	var f := MeshInstance3D.new()
	f.name = "Feather"
	f.mesh = Meshes.rounded_box(Vector3(0.05, 0.3, 0.012) * r.h, 0.012 * r.h, 2)
	f.material_override = Mats.skin(Color(0.95, 0.9, 0.82), 0.8)
	f.position = Vector3(0.16 * r.h, 0.92 * r.h, 0.0)
	f.rotation = Vector3(0.0, 0.0, -0.5)
	r.body.add_child(f)


func _ev_sermon_done() -> void:
	if blocker != null:
		blocker.queue_free()
		blocker = null


func _ev_show_narc() -> void:
	cam.shot(SHOTS.narc_show[0], SHOTS.narc_show[1])
	await get_tree().create_timer(1.2).timeout


func _ev_dot_join() -> void:
	var dot: Node3D = actors.dot
	await dot.hop_to(Vector3(player.global_position.x - 1.6, player.global_position.y, -0.3), 1.6, 0.6)
	_start_follow()




func _ev_reveal_enter() -> void:
	dot_follow = false
	player.set_physics_process(false)
	Sfx.play("door", -6.0)
	var tw := create_tween()
	tw.tween_property(door_leaf, "rotation:y", 1.45, 0.7)
	cam.shot(SHOTS.doors[0], SHOTS.doors[1])
	player.rig.speed = 0.7
	actors.dot.rigs[0].speed = 0.7
	var tw2 := create_tween()
	tw2.tween_property(player, "global_position", Vector3(144.0, 0.0, -5.6), 1.6)
	tw2.parallel().tween_property(actors.dot, "global_position", Vector3(145.7, 0.0, -5.4), 1.6)
	player.face_toward(145.0)
	await tw2.finished
	player.rig.speed = 0.0
	actors.dot.rigs[0].speed = 0.0
	auto_face = false
	player.rig.facing = PI - 0.35
	actors.dot.rigs[0].facing = PI + 0.35
	Sfx.stop_all_ambience(1.0)
	Sfx.ambience("hum_store", -26.0)


func _ev_egg_drop() -> void:
	deviled.visible = true
	deviled.position = Vector3(143.6, 13.3, -17.2)
	var tw := create_tween()
	tw.tween_property(deviled, "position", Vector3(143.4, 0.25, -15.4), 0.75).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(deviled, "rotation", Vector3(2.0, 0.4, 1.0), 0.75)
	await tw.finished
	Sfx.play("splat", -8.0, 1.5)
	shake(0.15)
	var tw2 := create_tween()
	tw2.tween_property(deviled, "position", Vector3(145.0, 0.3, -9.6), 1.1).set_ease(Tween.EASE_OUT)
	tw2.parallel().tween_property(deviled, "rotation", Vector3(0.0, 2.4, 0.0), 1.1)
	await tw2.finished
	actors.baker.set_emotion("shock")
	actors.dot.set_emotion("worried")


func _ev_egg_pickup() -> void:
	cam.shot(SHOTS.hand[0], SHOTS.hand[1])
	var h: Node3D = MeshInstance3D.new()
	(h as MeshInstance3D).mesh = Meshes.rounded_box(Vector3(4.6, 1.6, 5.0), 0.8, 3)
	(h as MeshInstance3D).material_override = Mats.skin(Color(0.93, 0.74, 0.6), 0.6)
	add_child(h)
	for i in 4:
		var f := MeshInstance3D.new()
		f.mesh = Meshes.capsule(0.5, 3.6)
		f.material_override = Mats.skin(Color(0.93, 0.74, 0.6), 0.6)
		f.position = Vector3(-1.6 + i * 1.05, -0.6, 2.2)
		f.rotation.x = 1.2
		h.add_child(f)
	h.global_position = Vector3(145.0, 28.0, -10.6)
	player.rig.set_product(true)
	actors.dot.set_product(true)
	Sfx.play("whoosh", -2.0)
	var tw := create_tween()
	tw.tween_property(h, "global_position", Vector3(145.0, 1.6, -10.6), 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tw.finished
	Sfx.play("grab", -2.0)
	deviled.reparent(h, true)
	await get_tree().create_timer(0.35).timeout
	var tw2 := create_tween()
	tw2.tween_property(h, "global_position", Vector3(146.0, 30.0, -14.0), 0.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await tw2.finished
	h.queue_free()
	player.rig.set_product(false)
	actors.dot.set_product(false)
	cam.shot(SHOTS.breakroom[0], SHOTS.breakroom[1])


func _ev_doug_mic() -> void:
	cam.shot(SHOTS.breakroom[0], SHOTS.breakroom[1])
	var tw := create_tween()
	tw.tween_property(doug_arm, "rotation", Vector3(0.6, 0, 1.05), 0.6)
	await tw.finished
	mic.reparent(doug_hand, true)
	var tw2 := create_tween()
	tw2.tween_property(doug_arm, "rotation", Vector3(-0.2, 0, 0.6), 0.6)
	await tw2.finished
	Sfx.play("chime", -4.0)
	await get_tree().create_timer(0.5).timeout


func _ev_end_act() -> void:
	await _finish_act("END OF ACT ONE", "The Reset begins at 5 a.m.", 2, "Act Two: Discontinued")



# --- the Narc's cleanup -------------------------------------------------------------------------

func _on_narc_spotted(x: float) -> void:
	if _cleanup:
		return
	_cleanup = true
	ui.pa_auto("Cleanup on aisle four. Cleanup, aisle four.")
	await get_tree().create_timer(2.2).timeout
	if not player.alive:
		_cleanup = false
		return
	tyler.visible = true
	var from_x := x + 30.0 if x < 70.0 else x - 30.0
	tyler.global_position = Vector3(from_x, 0.0, -6.5)
	await tyler.walk_to(x + (2.8 if from_x > x else -2.8), 16.0)
	await tyler.reach(Vector3(x, 1.4, 0.0), 0.5)
	var dx := absf(player.global_position.x - x)
	var exposed: bool = player.alive and dx < 3.4 and player.global_position.y < 0.7 and not player.hidden and not Game.dev.has("godmode")
	if exposed:
		tyler.close_hand()
		Sfx.play("grab")
		player.locked = true
		player.set_physics_process(false)
		player.rig.set_emotion("scared")
		var tw := create_tween()
		tw.tween_property(player, "global_position", tyler.hand.global_position + Vector3(0, -0.6, -1.6), 0.15)
		await tw.finished
		var tw2 := create_tween()
		tw2.tween_property(tyler.hand, "global_position", tyler.hand.global_position + Vector3(0, 26, 3), 0.7).set_ease(Tween.EASE_IN)
		tw2.parallel().tween_property(player, "global_position", player.global_position + Vector3(0, 26, 3), 0.7).set_ease(Tween.EASE_IN)
		await tw2.finished
		tyler.hand.visible = false
		player.die("shrunk")
	else:
		await tyler.pat(2.6)
		var miss: Array = ["...Nothing. Stupid robot.", "Bro. There's nothing here.", "I'm on my fifteen in like four minutes, man."]
		_giant_bubble(tyler, miss[_rng.randi() % miss.size()])
		await tyler.retract(0.6)
	await tyler.walk_to(from_x, 16.0)
	tyler.visible = false
	tyler.global_position = Vector3(220, 0, -6)
	narc.resume()
	_cleanup = false


func _on_respawn() -> void:
	narc.reset_far()
	if tyler.visible:
		tyler.hand.visible = false


func _tick(_dt: float) -> void:
	if _flicker != null:
		_flicker.light_energy = 1.6 if fmod(_t, 4.7) > 0.25 or fmod(_t * 13.0, 1.0) > 0.5 else 0.3


## Pull the camera back where the level is tall.
func _cam_zone() -> float:
	var x := player.global_position.x
	var y := player.global_position.y
	if x < 28.0 and y > 3.0:
		return 15.5
	if x > 116.0 and x < 125.0:
		return 14.5
	return 0.0
