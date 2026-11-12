extends "res://scripts/world/level.gd"
## Act Two: Discontinued. The Back: the breakroom floor, the stockroom, and
## Receiving with the Baler.
##
## Layout (x runs left to right, the player lives on z = 0):
##   breakroom   -12..50    (the printout, the vending machine, the fridge)
##   stockroom    50..118   (Saul, the mousetraps, Pallet Nine, the conveyor)
##   receiving   118..172   (the Discontinued, the Baler, the Flaps)

const SHOTS := {
	"a2_table": [Vector3(3.0, 7.0, 31.0), Vector3(4.0, 8.0, -6.0)],
	"a2_under": [Vector3(0.2, 1.7, 7.4), Vector3(-0.6, 1.0, 0.0)],
	"a2_sheet": [Vector3(13.6, 2.7, 9.8), Vector3(14.4, 1.9, -2.0)],
	"a2_traps": [Vector3(65.0, 3.4, 15.0), Vector3(66.0, 1.0, 0.0)],
	"a2_button": [Vector3(158.0, 9.0, 12.5), Vector3(160.8, 6.2, 0.0)],
}
const CHECKPOINTS := {
	"start": Vector3(0.0, 0.0, 0), "stock": Vector3(53.0, 0.0, 0), "pallet": Vector3(86.0, 0.9, 0),
	"receiving": Vector3(120.7, 0.0, 0), "baler": Vector3(128.6, 0.0, 0), "flaps": Vector3(161.5, 6.0, 0),
}
const BELT_Y := 4.4
const Kit = preload("res://scripts/ui/ui_kit.gd")
const TOTE_HOME := Vector3(125.0, 0.0, -1.5)
const TOTE_BELT_X := 137.5
const TOTE_FAIL_X := 148.2     ## the tote's front edge reaches the big ram
const TOTE_SPEED := 0.42

var doug: Node3D
var tyler: Node3D
var tote: Node3D
var corn: Array = []
var belts: Array = []          ## {body, speed, x0, x1, stripes: []}
var rams: Array = []           ## {node, x0, x1, period, hold, offset, down, lamp}
var traps: Array = []
var riders: Array[Node3D] = []
var baler_on := false
var _stairs_built := false
var _alarm: OmniLight3D
var _recv_light: OmniLight3D
var _vista_light: OmniLight3D
var _button: Node3D
var _strips: Array[Node3D] = []
var _note_font: Font


func _setup() -> void:
	act = 2
	act_name = "ACT TWO"
	dlg_file = "res://dialogue/act2.dlg"
	checkpoints = CHECKPOINTS
	shots = SHOTS.duplicate(true)
	cam_min_x = -3.0
	cam_max_x = 168.0
	dot_barks = ["It smells like cardboard and broken dreams back here.", "If a Giant grabs me, tell them I was a cruller. I want to be remembered wrong.",
		"You ever notice nobody prays to get put in Backstock?", "My glaze is sweating. Is that normal? Don't answer.",
		"Fun fact: 'the Back' is also where they keep the mop. So. Hygiene."]


func _environment() -> void:
	super()
	env.ambient_light_color = Color(0.6, 0.6, 0.64)
	env.ambient_light_energy = 0.7
	env.background_color = Color(0.03, 0.03, 0.035)
	env.fog_light_color = Color(0.07, 0.07, 0.07)
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 0.55


func _build_world() -> void:
	_note_font = Kit.body_font(800)
	_build_shell()
	_build_breakroom()
	_build_stockroom()
	_build_receiving()
	_build_vista()


func _begin() -> void:
	Sfx.music("backroom", -13.0)
	Sfx.ambience("hum_back", -17.0)
	if start_checkpoint == "start" and not Game.flag("a2_intro_done"):
		player.locked = true
		await get_tree().process_frame
		runner.run("a2_intro")
	else:
		hud.fade(false, 0.6)


# --- geometry: floor and walls ---------------------------------------------------------------

func _build_shell() -> void:
	store.section = "shell"
	# breakroom: the same tile as out front, a little warmer
	var tile := _floor_mat(Color(1.0, 0.95, 0.86))
	var p := MeshInstance3D.new()
	p.mesh = Meshes.box(Vector3(66.6, 0.4, 44))
	p.material_override = tile
	p.position = Vector3(17.3, -0.2, -6)
	add_child(p)
	# the Back: sealed concrete with a yellow walkway line
	# (one slab and one wall per room: a mesh is drawn again for every light that reaches it)
	var conc := Mats.solid(Color(0.4, 0.4, 0.42), 0.82)
	store.box(Vector3(85.3, -0.2, -6), Vector3(69.4, 0.4, 44), conc)
	store.box(Vector3(151.0, -0.2, -6), Vector3(62.0, 0.4, 44), conc)
	store.box(Vector3(112, 0.012, 2.3), Vector3(122, 0.02, 0.35), Mats.solid(Color(0.95, 0.78, 0.1), 0.7))
	for jx in [66.0, 82.0, 98.0, 114.0, 130.0, 146.0, 162.0]:
		store.box(Vector3(jx, 0.012, -6), Vector3(0.12, 0.02, 44), Mats.solid(Color(0.3, 0.3, 0.32), 0.9))
	store.solid_lane(-24, 186, -2.0, 0.0)
	store.solid_lane(-16.0, -11.6, 0.0, 40.0)
	store.solid_lane(176.0, 182.0, 0.0, 40.0)
	# back walls
	var paint := Mats.solid(Color(0.78, 0.74, 0.62), 0.85)
	store.box(Vector3(19, 20, -15.4), Vector3(64, 40, 0.8), paint)
	store.box(Vector3(19, 0.9, -14.95), Vector3(64, 1.8, 0.2), Mats.solid(Color(0.3, 0.26, 0.22), 0.7))
	var blocks := Mats.textured(FaceTex.blocks(), 0.85, Vector3(0.06, 0.06, 0.06))
	blocks.uv1_triplanar = true
	blocks.uv1_world_triplanar = true
	store.box(Vector3(85.5, 20, -12.4), Vector3(69, 40, 0.8), blocks)
	store.box(Vector3(142.0, 20, -12.4), Vector3(44, 40, 0.8), blocks)
	# the pillars between rooms (seen edge-on)
	for px in [50.6, 118.0]:
		store.box(Vector3(px, 20, -8.2), Vector3(1.4, 40, 9.0), blocks)
		store.box(Vector3(px, 27, -1.0), Vector3(1.4, 26, 5.6), blocks)
		store.box(Vector3(px, 13.7, -1.0), Vector3(1.9, 0.7, 5.8), Mats.solid(Color(0.95, 0.78, 0.1), 0.6))
	# the left wall and the Employees Only door, shut
	store.box(Vector3(-12.4, 20, -6.0), Vector3(0.8, 40, 20), paint)
	store.box(Vector3(-11.95, 10.0, -1.0), Vector3(0.3, 20, 6.0), Mats.solid(Color(0.42, 0.48, 0.55), 0.4, 0.5))
	store.box(Vector3(-11.78, 1.2, -1.0), Vector3(0.06, 2.4, 5.8), Mats.solid(Color(0.7, 0.72, 0.75), 0.3, 0.8))
	store.box(Vector3(-11.4, 22.6, -1.0), Vector3(0.4, 1.2, 3.0), Mats.glow(Color(1.0, 0.15, 0.1), 2.5))
	# the rubber wedge, kicked across the floor
	store.mesh(Meshes.prism(Vector3(1.4, 0.7, 1.2)), Mats.solid(Color(0.2, 0.15, 0.12), 0.8), Vector3(-6.4, 0.35, 1.4), Vector3(0, 0.7, 0))
	store.label("BREAK ROOM", Vector3(-2.0, 21.5, -14.9), 2.2, Color(0.35, 0.3, 0.25), 0)
	store.label("STOCKROOM", Vector3(72, 26.0, -11.9), 4.0, Color(0.95, 0.78, 0.1), 14, Color(0.1, 0.1, 0.1))
	store.label("RECEIVING", Vector3(140, 26.0, -11.9), 4.0, Color(0.95, 0.78, 0.1), 14, Color(0.1, 0.1, 0.1))


# --- geometry: the breakroom -------------------------------------------------------------------

func _build_breakroom() -> void:
	store.section = "break"
	store.omni(Vector3(10, 22, 4), Color(1.0, 0.95, 0.84), 2.1, 40.0)
	# the table Doug eats at, and his chair
	var lam := Mats.solid(Color(0.85, 0.85, 0.8), 0.4)
	var leg := Mats.solid(Color(0.3, 0.3, 0.32), 0.4, 0.6)
	store.box(Vector3(3, 12.9, -10.6), Vector3(26, 0.8, 7.0), lam, 0.2)
	for lx in [-8.5, 14.5]:
		for lz in [-8.0, -13.2]:
			store.mesh(Meshes.cyl(0.4, 0.4, 12.5, 10), leg, Vector3(lx, 6.25, lz))
	var chair := Mats.skin(Color(0.2, 0.34, 0.5), 0.6)
	store.box(Vector3(6.0, 7.6, -6.4), Vector3(5.6, 0.6, 4.6), chair, 0.2)
	store.box(Vector3(6.0, 12.6, -4.3), Vector3(5.6, 6.0, 0.5), chair, 0.2)
	for lx in [3.6, 8.4]:
		for lz in [-4.5, -8.3]:
			store.mesh(Meshes.cyl(0.22, 0.22, 7.4, 8), leg, Vector3(lx, 3.7, lz))
	# crumbs under the table
	for k in 9:
		store.mesh(Meshes.sphere(_rng.randf_range(0.08, 0.2), 6, 4), Mats.solid(Color(0.8, 0.66, 0.4), 0.9),
			Vector3(_rng.randf_range(-6.0, 9.0), 0.08, _rng.randf_range(-3.2, -1.7)))
	_build_sheet()
	_build_vending()
	_build_fridge()
	# a milk crate somebody stands on to reach the top shelf
	var crate := Mats.skin(Color(0.2, 0.35, 0.75), 0.6)
	store.box(Vector3(32.75, 1.1, -0.4), Vector3(2.5, 2.16, 2.6), crate, 0.08)
	store.box(Vector3(32.75, 1.1, 0.92), Vector3(1.6, 0.9, 0.04), Mats.solid(Color(0.1, 0.18, 0.4), 0.7))
	store.solid_lane(31.5, 34.0, 0.0, 2.2)


## The printout that came off the wall: the new Planogram, dairy section.
func _build_sheet() -> void:
	var n := Node3D.new()
	n.position = Vector3(14.4, 0.0, -2.0)
	n.rotation = Vector3(-0.3, 0.0, 0.04)
	add_child(n)
	store.mesh(Meshes.box(Vector3(5.6, 6.6, 0.04)), Mats.solid(Color(0.97, 0.97, 0.94), 0.8), Vector3(0, 3.3, 0), Vector3.ZERO, n)
	var ink := Color(0.12, 0.14, 0.22)
	var rows := [["PLANOGRAM CHANGES", 5.9, 0.44, ink], ["DAIRY  ·  EFFECTIVE 5:00 A.M.", 5.35, 0.24, ink],
		["MILK, SKIM .......... 1 FACING", 4.5, 0.25, ink], ["OAT BEVERAGE ..... 6 FACINGS", 3.8, 0.25, ink],
		["OLIVE OIL, X-VIRGIN ... BTM SHELF", 3.1, 0.25, ink], ["EGGS, LG, GRADE A, 12 CT", 2.4, 0.25, ink],
		["DELETE", 1.55, 0.62, Color(0.85, 0.1, 0.08)], ["REPLACE W/ EGG-STYLE LIQUID 16 OZ", 0.8, 0.2, ink]]
	for r in rows:
		var t: Label3D = store.label(r[0], Vector3.ZERO, r[2], r[3], 0, Color.BLACK, false, _note_font if r[2] < 0.4 else null)
		t.reparent(n, false)
		t.position = Vector3(0, r[1], 0.03)
	var ring := store.mesh(Meshes.torus(0.62, 0.74, 24, 6), Mats.solid(Color(0.45, 0.3, 0.15, 1.0), 0.9), Vector3(1.7, 1.5, 0.025), Vector3(PI * 0.5, 0, 0), n)
	ring.scale = Vector3(1, 0.05, 1)


func _build_vending() -> void:
	var body := Mats.solid(Color(0.1, 0.1, 0.12), 0.5)
	var red := Mats.skin(Color(0.7, 0.1, 0.12), 0.45)
	var x0 := 18.0
	var x1 := 30.0
	var cx := (x0 + x1) * 0.5
	store.box(Vector3(cx, 11.0, -7.4), Vector3(12.0, 22.0, 0.5), body)
	store.box(Vector3(x0 + 0.25, 11.0, -5.4), Vector3(0.5, 22.0, 4.4), red)
	store.box(Vector3(x1 - 0.25, 11.0, -5.4), Vector3(0.5, 22.0, 4.4), red)
	store.box(Vector3(cx, 21.75, -5.4), Vector3(12.0, 0.5, 4.4), red)
	store.box(Vector3(cx, 1.3, -5.4), Vector3(12.0, 2.6, 4.4), red)
	store.box(Vector3(28.4, 11.8, -3.4), Vector3(2.7, 18.4, 0.5), red)
	store.box(Vector3(22.5, 12.0, -7.1), Vector3(8.6, 17.6, 0.1), Mats.glow(Color(0.9, 0.95, 1.0), 0.8))
	store.box(Vector3(22.5, 12.0, -3.3), Vector3(8.8, 18.0, 0.08), Mats.glass(Color(0.8, 0.9, 1.0, 0.12)))
	store.label("SNACKS", Vector3(cx, 20.9, -3.1), 0.9, Color(1, 0.95, 0.7))
	# the delivery flap
	store.box(Vector3(22.5, 1.4, -3.18), Vector3(6.4, 1.7, 0.1), Mats.solid(Color(0.04, 0.04, 0.05), 0.3, 0.4))
	var push: Label3D = store.label("PUSH", Vector3(22.5, 1.4, -3.1), 0.6, Color(0.6, 0.6, 0.62))
	push.outline_size = 0
	# coin slot, keypad, price
	store.box(Vector3(28.4, 13.0, -3.12), Vector3(1.7, 2.6, 0.06), Mats.solid(Color(0.75, 0.76, 0.78), 0.3, 0.8))
	store.box(Vector3(28.4, 16.4, -3.12), Vector3(1.7, 1.0, 0.06), Mats.glow(Color(0.2, 1.0, 0.4), 1.6))
	var price: Label3D = store.label("1.75", Vector3(28.4, 16.4, -3.06), 0.6, Color(0.02, 0.2, 0.05))
	price.outline_size = 0
	store.box(Vector3(28.4, 10.0, -3.12), Vector3(0.9, 0.16, 0.06), Mats.solid(Color(0.03, 0.03, 0.03), 0.4))
	# the snacks on their coils
	var pal := [Color(0.9, 0.15, 0.15), Color(0.2, 0.5, 0.95), Color(0.95, 0.7, 0.1), Color(0.2, 0.7, 0.35), Color(0.6, 0.3, 0.75)]
	var rows_y := [4.6, 8.8, 13.0, 17.2]
	for ri in rows_y.size():
		var y: float = rows_y[ri]
		store.box(Vector3(22.5, y - 0.1, -5.2), Vector3(8.6, 0.16, 3.6), Mats.solid(Color(0.55, 0.56, 0.6), 0.4, 0.5))
		for ci in 6:
			var px := 19.2 + ci * 1.34
			if ri == 0 and ci == 2:
				continue   # Dangler's slot
			var c: Color = pal[(ri * 2 + ci) % pal.size()]
			var kind := "chips" if (ri + ci) % 3 != 0 else "cereal"
			store.product(kind, Vector3(px, y, -4.6), c, Color(0.98, 0.95, 0.85), 0.0, 0.58 if kind == "chips" else 0.5)
			store.product(kind, Vector3(px, y, -5.6), c, Color(0.98, 0.95, 0.85), 0.0, 0.58 if kind == "chips" else 0.5)
	# the coil Dangler is caught on
	store.mesh(Meshes.torus(0.36, 0.44, 16, 6), Mats.solid(Color(0.8, 0.8, 0.84), 0.3, 0.9), Vector3(21.9, 4.75, -4.3), Vector3(0, 0, PI * 0.5))


func _build_fridge() -> void:
	var white := Mats.solid(Color(0.9, 0.91, 0.92), 0.35, 0.1)
	var inner := Mats.solid(Color(0.82, 0.88, 0.94), 0.5)
	# the counter over it
	store.box(Vector3(41.5, 9.9, -8.6), Vector3(16.0, 0.7, 13.0), Mats.solid(Color(0.32, 0.26, 0.22), 0.5), 0.15)
	store.box(Vector3(46.2, 4.8, -9.0), Vector3(6.4, 9.6, 11.5), Mats.solid(Color(0.6, 0.52, 0.42), 0.7))
	store.box(Vector3(34.6, 4.8, -9.0), Vector3(2.4, 9.6, 11.5), Mats.solid(Color(0.6, 0.52, 0.42), 0.7))
	store.box(Vector3(45.5, 12.0, -10.0), Vector3(5.0, 3.4, 3.6), Mats.solid(Color(0.14, 0.14, 0.15), 0.4, 0.3))   # microwave
	store.box(Vector3(44.8, 12.0, -8.16), Vector3(3.0, 2.4, 0.06), Mats.glass(Color(0.2, 0.25, 0.3, 0.6)))
	# the fridge: an open box facing the camera
	store.box(Vector3(39.0, 4.8, -8.9), Vector3(6.4, 9.2, 0.4), white)
	store.box(Vector3(35.95, 4.8, -5.6), Vector3(0.4, 9.2, 7.0), white)
	store.box(Vector3(42.05, 4.8, -5.6), Vector3(0.4, 9.2, 7.0), white)
	store.box(Vector3(39.0, 9.2, -5.6), Vector3(6.4, 0.4, 7.0), white)
	store.box(Vector3(39.0, 0.6, -5.6), Vector3(6.4, 1.2, 7.0), white)
	store.box(Vector3(39.0, 4.9, -8.65), Vector3(5.7, 7.6, 0.1), inner)
	store.box(Vector3(39.0, 5.3, -6.0), Vector3(5.7, 0.14, 5.4), Mats.glass(Color(0.85, 0.95, 1.0, 0.3)))
	store.box(Vector3(39.0, 8.85, -4.0), Vector3(4.6, 0.12, 0.5), Mats.glow(Color(0.85, 0.95, 1.0), 2.6))
	store.omni(Vector3(39.0, 6.0, -3.2), Color(0.75, 0.9, 1.0), 1.8, 9.0)
	store.product("jar", Vector3(37.2, 5.4, -6.4), Color(0.7, 0.2, 0.15), Color(0.85, 0.75, 0.3))
	store.product("carton", Vector3(39.4, 5.4, -6.8), Color(0.97, 0.97, 0.95), Color(0.3, 0.7, 0.35))
	store.product("jar", Vector3(41.0, 5.4, -6.2), Color(0.5, 0.6, 0.2), Color(0.8, 0.2, 0.2))
	store.product("tub", Vector3(41.0, 1.2, -7.2), Color(0.95, 0.6, 0.2), Color(0.95, 0.95, 0.95))
	# the door, swung all the way open against the cabinets
	store.box(Vector3(45.2, 4.9, -2.1), Vector3(6.0, 9.0, 0.4), white, 0.1)
	store.box(Vector3(45.2, 6.6, -1.86), Vector3(2.6, 2.6, 0.03), Mats.solid(Color(1.0, 0.95, 0.6), 0.8))
	var note: Label3D = store.label("YOUR MOTHER\nDOESN'T WORK HERE.\n(she works at\nthe other location)\n- DOUG", Vector3(45.2, 6.6, -1.83), 0.27, Color(0.45, 0.06, 0.06), 0, Color.BLACK, false, _note_font)
	note.outline_size = 0
	store.box(Vector3(39.0, 2.75, -2.6), Vector3(2.2, 0.7, 0.03), Mats.solid(Color(0.98, 0.98, 0.95), 0.8))
	var kl: Label3D = store.label("KAREN'S!! DO NOT EAT", Vector3(39.0, 2.75, -2.57), 0.2, Color(0.5, 0.02, 0.25), 0, Color.BLACK, false, _note_font)
	kl.outline_size = 0


# --- geometry: the stockroom --------------------------------------------------------------------

func _build_stockroom() -> void:
	store.section = "stock"
	# one lamp for the room, kept short of the rooms either side
	store.omni(Vector3(85, 18, 6), Color(1.0, 0.9, 0.72), 2.5, 34.0)
	var card := [Color(0.68, 0.52, 0.33), Color(0.62, 0.47, 0.3), Color(0.72, 0.56, 0.36)]
	var upright := Mats.solid(Color(0.15, 0.3, 0.6), 0.5, 0.3)
	var beam := Mats.solid(Color(0.92, 0.45, 0.1), 0.5, 0.3)
	var wood := Mats.solid(Color(0.62, 0.46, 0.28), 0.85)
	# pallet racking along the back wall
	for ux in [52.5, 68.5, 84.5, 100.5, 116.5]:
		for uz in [-5.4, -10.6]:
			store.box(Vector3(ux, 15, uz), Vector3(0.6, 30, 0.6), upright)
	for by in [9.6, 18.6]:
		for bz in [-5.4, -10.6]:
			store.box(Vector3(84.5, by, bz), Vector3(64.6, 0.7, 0.4), beam)
		for bay in 4:
			var bx := 60.5 + bay * 16.0
			for side in [-3.7, 3.7]:
				store.box(Vector3(bx + side, by + 0.5, -8.0), Vector3(6.4, 0.5, 5.2), wood)
				store.row("crate", bx + side - 1.5, bx + side + 1.5, by + 0.75, -8.0, 2.8, card, card, 0.1)
				if (bay + int(side)) % 2 == 0:
					store.row("crate", bx + side - 1.5, bx + side + 1.5, by + 2.95, -8.0, 2.8, card, card, 0.1)
	# floor-level pallets behind the lane
	for gx in [61.0, 67.5, 100.0, 106.5]:
		store.box(Vector3(gx, 0.45, -8.0), Vector3(6.0, 0.9, 5.0), wood)
		store.row("crate", gx - 1.5, gx + 1.5, 0.9, -8.0, 2.8, card, card, 0.1)
		store.row("crate", gx - 1.5, gx + 1.5, 3.1, -8.0, 2.8, card, card, 0.1)
	store.label("THIS DEPARTMENT HAS WORKED", Vector3(64, 14.3, -11.9), 0.7, Color(0.9, 0.9, 0.85))
	store.label("DAYS WITHOUT AN ACCIDENT", Vector3(64, 11.2, -11.9), 0.7, Color(0.9, 0.9, 0.85))
	store.box(Vector3(64, 12.8, -11.95), Vector3(2.4, 1.7, 0.1), Mats.solid(Color(0.05, 0.05, 0.05), 0.5))
	store.label("0", Vector3(64, 12.8, -11.86), 1.4, Color(1.0, 0.2, 0.15))
	# Saul's glue trap
	store.box(Vector3(55.6, 0.06, -1.6), Vector3(2.8, 0.1, 2.2), Mats.solid(Color(0.8, 0.72, 0.5), 0.9))
	store.box(Vector3(55.6, 0.12, -1.6), Vector3(2.5, 0.04, 1.9), Mats.solid(Color(0.85, 0.7, 0.2), 0.12))
	store.mesh(Meshes.sphere(0.22, 8, 6), Mats.solid(Color(0.2, 0.1, 0.14), 0.7), Vector3(56.6, 0.24, -1.0)).scale = Vector3(1.1, 0.7, 0.9)
	# the mousetraps
	for tx in [60.0, 66.0, 72.0, 77.0]:
		_trap(tx)
	# Pallet Nine
	for k in 3:
		store.box(Vector3(84.7, 0.15 + k * 0.32, -1.0), Vector3(9.4, 0.16, 4.2), wood)
	store.solid_lane(80.0, 89.4, 0.0, 0.9)
	for layer in 2:
		for zz in [-2.7, -1.5]:
			store.row("can", 80.8, 88.7, 0.9 + layer * 1.52, zz, 1.3, [Color(0.96, 0.8, 0.16)], [Color(0.96, 0.8, 0.16)], 0.02)
	store.box(Vector3(84.7, 2.5, -2.1), Vector3(9.3, 3.2, 2.6), Mats.glass(Color(0.85, 0.92, 1.0, 0.16)), 0.2)
	store.box(Vector3(84.7, 4.5, -2.1), Vector3(2.6, 0.9, 0.05), Mats.solid(Color(0.97, 0.97, 0.94), 0.8))
	var pl: Label3D = store.label("PALLET 9", Vector3(84.7, 4.5, -2.06), 0.5, Color(0.1, 0.1, 0.15))
	pl.outline_size = 0
	# the conveyor line to Receiving
	_belt(94.2, 112.0, 3.2)
	store.solid_lane(94.2, 95.0, 0.0, BELT_Y - 0.4)
	store.solid_lane(111.2, 112.0, 0.0, BELT_Y - 0.4)
	store.row("crate", 96.4, 110.4, 0.0, -0.9, 2.8, card, card, 0.12)
	for k in 4:
		var b := store.box(Vector3(96.0 + k * 4.2, BELT_Y + 0.7, -1.9), Vector3(1.9, 1.4, 1.5), Mats.solid(card[k % 3], 0.9))
		riders.append(b)
	# flour sacks to land on
	var sack := Mats.skin(Color(0.9, 0.86, 0.74), 0.95)
	for k in 2:
		var s := MeshInstance3D.new()
		s.mesh = Meshes.rounded_box(Vector3(4.6, 0.95, 3.0), 0.42, 3)
		s.material_override = sack
		s.position = Vector3(114.7 + k * 0.2, 0.45 + k * 0.78, -0.4)
		add_child(s)
	store.solid_lane(112.5, 116.9, 0.0, 1.6, {"cushion": true})
	# one more on the floor, for anyone who leaps off the end of the line
	var s3 := MeshInstance3D.new()
	s3.mesh = Meshes.rounded_box(Vector3(3.1, 0.9, 2.9), 0.4, 3)
	s3.material_override = sack
	s3.position = Vector3(118.4, 0.42, -0.3)
	s3.rotation.y = 0.08
	add_child(s3)
	store.solid_lane(116.9, 119.9, 0.0, 0.8, {"cushion": true})
	var fl: Label3D = store.label("FLOUR", Vector3(114.9, 1.2, 1.12), 0.42, Color(0.3, 0.35, 0.6))
	fl.outline_size = 0


## A snap trap across the lane: touch the plate and the bar comes down.
func _trap(x: float) -> void:
	store.box(Vector3(x, 0.06, 0.0), Vector3(2.4, 0.12, 1.5), Mats.solid(Color(0.72, 0.56, 0.36), 0.9))
	store.box(Vector3(x, 0.14, 0.0), Vector3(0.9, 0.05, 0.8), Mats.glow(Color(1.0, 0.8, 0.15), 0.5))
	store.mesh(Meshes.sphere(0.2, 8, 5), Mats.solid(Color(0.72, 0.5, 0.25), 0.6), Vector3(x, 0.22, 0.0)).scale.y = 0.5
	var steel := Mats.solid(Color(0.75, 0.76, 0.8), 0.25, 0.9)
	store.mesh(Meshes.cyl(0.09, 0.09, 1.5, 8), steel, Vector3(x - 0.95, 0.2, 0.0), Vector3(PI * 0.5, 0, 0))
	# the bar: a U of wire hinged at the spring, cocked back
	var bar := Node3D.new()
	bar.position = Vector3(x - 0.95, 0.2, 0.0)
	add_child(bar)
	for zz in [-0.62, 0.62]:
		store.mesh(Meshes.cyl(0.05, 0.05, 1.9, 6), steel, Vector3(0.95, 0, zz), Vector3(0, 0, PI * 0.5), bar)
	store.mesh(Meshes.cyl(0.05, 0.05, 1.3, 6), steel, Vector3(1.9, 0, 0), Vector3(PI * 0.5, 0, 0), bar)
	bar.rotation.z = 2.75
	var t := {"x": x, "bar": bar}
	traps.append(t)
	var h := _hazard(Rect2(x - 0.7, 0.0, 1.4, 0.85), "snapped")
	h["hit"] = _snap.bind(t)


func _snap(t: Dictionary) -> void:
	Sfx.play("snap", 2.0)
	var tw := create_tween()
	tw.tween_property(t.bar, "rotation:z", 0.05, 0.04)


## A powered belt in the play lane, top at BELT_Y.
func _belt(x0: float, x1: float, speed: float) -> Dictionary:
	var cx := (x0 + x1) * 0.5
	var w := x1 - x0
	var steel := Mats.solid(Color(0.5, 0.52, 0.56), 0.4, 0.6)
	store.box(Vector3(cx, BELT_Y - 0.25, -1.0), Vector3(w, 0.4, 3.8), Mats.solid(Color(0.09, 0.09, 0.1), 0.75))
	for zz in [-2.95, 0.95]:
		store.box(Vector3(cx, BELT_Y - 0.3, zz), Vector3(w + 0.3, 0.7, 0.16), steel)
	var x := x0 + 1.0
	while x < x1:
		for zz in [-2.8, 0.8]:
			store.box(Vector3(x, (BELT_Y - 0.6) * 0.5, zz), Vector3(0.3, BELT_Y - 0.6, 0.3), steel)
		x += 5.6
	var body: StaticBody3D = store.solid_lane(x0, x1, BELT_Y - 0.45, BELT_Y)
	var b := {"body": body, "speed": speed, "x0": x0, "x1": x1, "stripes": [], "on": true}
	var n := int(w / 1.5)
	var sm := Mats.solid(Color(0.2, 0.2, 0.22), 0.6)
	for i in n:
		var s := store.box(Vector3(x0 + (i + 0.5) * w / n, BELT_Y - 0.04, -1.0), Vector3(0.14, 0.03, 3.7), sm)
		b.stripes.append(s)
	belts.append(b)
	_set_belt(b, true)
	return b


func _set_belt(b: Dictionary, on: bool) -> void:
	b.on = on
	(b.body as StaticBody3D).constant_linear_velocity = Vector3(b.speed if on else 0.0, 0, 0)


# --- geometry: receiving and the Baler --------------------------------------------------------------

func _build_receiving() -> void:
	store.section = "recv"
	_recv_light = store.omni(Vector3(146, 20, 6), Color(1.0, 0.92, 0.78), 2.3, 40.0)
	_alarm = store.omni(Vector3(158, 12, 4), Color(1.0, 0.12, 0.08), 2.6, 34.0)
	_alarm.visible = false
	var card := Mats.solid(Color(0.66, 0.5, 0.32), 0.9)
	var green := Mats.solid(Color(0.16, 0.4, 0.24), 0.5, 0.3)
	var steel := Mats.solid(Color(0.6, 0.62, 0.66), 0.35, 0.7)
	var hazard := Mats.solid(Color(0.95, 0.78, 0.1), 0.6)
	# flattened cardboard, stacked into steps up to the feed belt
	for k in 2:
		var top := 1.4 * (k + 1)
		var sx := 130.0 + k * 1.6
		var layers := int(top / 0.2)
		for j in layers:
			store.box(Vector3(sx + 0.8 + _rng.randf_range(-0.05, 0.05), 0.1 + j * 0.2, -0.6), Vector3(1.66, 0.18, 3.2), card)
		store.solid_lane(sx, sx + 1.6, 0.0, top)
	var feed := _belt(133.2, 160.0, 2.4)
	store.solid_lane(133.2, 134.0, 0.0, BELT_Y - 0.4)
	_set_belt(feed, false)
	# the skirt along the front of the belt
	store.box(Vector3(146.6, 1.9, 1.02), Vector3(26.8, 3.7, 0.1), green)
	for sx in [136.0, 150.0]:
		store.box(Vector3(sx, 2.0, 1.08), Vector3(7.0, 1.3, 0.04), hazard)
		var kl: Label3D = store.label("BALER FEED  ·  KEEP CLEAR", Vector3(sx, 2.0, 1.12), 0.42, Color(0.08, 0.08, 0.08))
		kl.outline_size = 0
	# the Baler itself, behind the belt
	store.box(Vector3(153.0, 9.0, -7.4), Vector3(15.0, 18.0, 8.0), green)
	store.label("BALER", Vector3(153.0, 15.4, -3.3), 2.2, Color(0.95, 0.78, 0.1), 10, Color(0.05, 0.1, 0.06))
	store.box(Vector3(153.0, 12.6, -3.36), Vector3(8.0, 1.5, 0.06), hazard)
	var dl: Label3D = store.label("DANGER  ·  CRUSH HAZARD", Vector3(153.0, 12.6, -3.3), 0.6, Color(0.08, 0.08, 0.08))
	dl.outline_size = 0
	# a narrow tamper over the front of the belt (the tote rides past behind it),
	# then the big ram across the whole belt
	_ram(142.6, 145.0, 2.0, 0.45, 0.0, 0.3, 1.5)
	_ram(151.6, 155.2, 3.0, 0.9, 1.1, -1.0, 3.6)
	# finished bales
	for k in 3:
		var bale := store.box(Vector3(178.7 + (k % 2) * 4.4, 2.0 + (k / 2) * 4.1, -1.6), Vector3(4.2, 4.0, 4.2), card, 0.2)
		for sy in [-1.0, 1.0]:
			store.box(bale.position + Vector3(0, sy, 0), Vector3(4.26, 0.12, 4.26), Mats.solid(Color(0.2, 0.2, 0.22), 0.5))
	# the E-stop post at the end of the belt
	store.box(Vector3(161.5, 2.8, -0.6), Vector3(3.0, 5.6, 3.4), hazard, 0.1)
	for k in 3:
		store.box(Vector3(161.5, 1.0 + k * 1.7, 1.12), Vector3(3.0, 0.5, 0.04), Mats.solid(Color(0.06, 0.06, 0.06), 0.6))
	store.solid_lane(160.0, 163.0, 0.0, 5.6)
	_button = Node3D.new()
	_button.position = Vector3(161.5, 5.6, 0.0)
	add_child(_button)
	store.mesh(Meshes.cyl(1.25, 1.25, 0.16, 20), Mats.solid(Color(0.95, 0.85, 0.1), 0.5), Vector3(0, 0.08, 0), Vector3.ZERO, _button)
	var cap := store.mesh(Meshes.hemi(1.0, 20, 8), Mats.skin(Color(0.9, 0.08, 0.06), 0.3), Vector3(0, 0.16, 0), Vector3.ZERO, _button)
	cap.name = "Cap"
	cap.scale.y = 0.55
	store.solid_lane(160.7, 162.3, 5.6, 6.0)
	store.label("E-STOP", Vector3(161.5, 4.6, 1.16), 0.55, Color(0.9, 0.1, 0.08))
	# bales to climb down on the far side
	for k in 2:
		var top := 3.7 - k * 1.85
		store.box(Vector3(163.8 + k * 1.6, top * 0.5, -0.6), Vector3(1.6, top, 3.2), card, 0.08)
		store.solid_lane(163.0 + k * 1.6, 164.6 + k * 1.6, 0.0, top, {"cushion": true})
	# ...and a heap of loose cardboard past them, so a leap off the button ends softly
	var heap := MeshInstance3D.new()
	heap.mesh = Meshes.rounded_box(Vector3(4.3, 0.95, 3.2), 0.42, 3)
	heap.material_override = card
	heap.position = Vector3(168.3, 0.26, -0.5)
	add_child(heap)
	for k in 6:
		var sheet := store.box(Vector3(166.9 + k * 0.56, 0.74 + (k % 2) * 0.05, -0.5 + (k % 3 - 1) * 0.7),
			Vector3(1.5, 0.05, 1.1), Mats.solid(Color(0.7, 0.54, 0.35) if k % 2 == 0 else Color(0.6, 0.45, 0.28), 0.9))
		sheet.rotation = Vector3(_rng.randf_range(-0.12, 0.12), _rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.14, 0.14))
	store.solid_lane(166.2, 170.4, 0.0, 0.7, {"cushion": true})
	# the Flaps: a doorway in the back wall, hung with plastic strips
	var blocks := Mats.solid(Color(0.36, 0.37, 0.4), 0.85)
	store.box(Vector3(165.3, 20, -4.3), Vector3(6.0, 40, 0.6), blocks)
	store.box(Vector3(178.2, 20, -4.3), Vector3(7.6, 40, 0.6), blocks)
	store.box(Vector3(171.4, 28, -4.3), Vector3(6.2, 24, 0.6), blocks)
	store.box(Vector3(171.4, 16.4, -4.0), Vector3(6.6, 0.8, 0.5), hazard)
	for k in 8:
		var piv := Node3D.new()
		piv.position = Vector3(168.7 + k * 0.78, 16.0, -4.1)
		add_child(piv)
		store.mesh(Meshes.box(Vector3(0.74, 15.8, 0.05)), Mats.glass(Color(0.92, 0.95, 0.6, 0.5), 0.15), Vector3(0, -7.9, 0), Vector3.ZERO, piv)
		_strips.append(piv)
	# keep-clear markings on the floor in front of them
	for mz in [-1.3, -2.2, -3.1]:
		store.box(Vector3(171.4, 0.014, mz), Vector3(6.2, 0.02, 0.3), hazard)
	for mx in [168.3, 174.5]:
		store.box(Vector3(mx, 0.014, -2.2), Vector3(0.3, 0.02, 2.1), hazard)
	store.label("TO SALES FLOOR", Vector3(171.4, 18.2, -3.9), 0.8, Color(0.95, 0.95, 0.9))
	# the Discontinued tote
	tote = Node3D.new()
	tote.position = TOTE_HOME
	add_child(tote)
	var grey := Mats.skin(Color(0.45, 0.47, 0.52), 0.6)
	store.mesh(Meshes.box(Vector3(6.4, 0.75, 2.6)), grey, Vector3(0, 0.375, 0), Vector3.ZERO, tote)
	store.mesh(Meshes.box(Vector3(6.4, 2.8, 0.2)), grey, Vector3(0, 1.4, -1.3), Vector3.ZERO, tote)
	store.mesh(Meshes.box(Vector3(6.4, 0.9, 0.2)), grey, Vector3(0, 0.45, 1.3), Vector3.ZERO, tote)
	for sx in [-3.1, 3.1]:
		store.mesh(Meshes.box(Vector3(0.2, 2.8, 2.6)), grey, Vector3(sx, 1.4, 0), Vector3.ZERO, tote)
	store.mesh(Meshes.box(Vector3(5.2, 0.62, 0.04)), Mats.solid(Color(0.85, 0.12, 0.1), 0.6), Vector3(0, 0.45, 1.42), Vector3.ZERO, tote)
	var tl: Label3D = store.label("DISCONTINUED  ·  DO NOT STOCK", Vector3.ZERO, 0.3, Color(1, 1, 1))
	tl.outline_size = 0
	tl.reparent(tote, false)
	tl.position = Vector3(0, 0.45, 1.45)


## A press head over the belt that slams down on a cycle.
func _ram(x0: float, x1: float, period: float, hold: float, offset: float, zc: float, depth: float) -> void:
	var cx := (x0 + x1) * 0.5
	var w := x1 - x0
	var steel := Mats.solid(Color(0.6, 0.62, 0.66), 0.35, 0.7)
	var frame := Mats.solid(Color(0.16, 0.4, 0.24), 0.5, 0.3)
	for px in [x0 - 0.5, x1 + 0.5]:
		store.box(Vector3(px, BELT_Y + 5.0, -3.3), Vector3(0.6, 10.0, 0.6), frame)
	store.box(Vector3(cx, BELT_Y + 10.0, -1.4), Vector3(w + 1.8, 1.0, 4.6), frame)
	var n := Node3D.new()
	n.position = Vector3(cx, BELT_Y + 5.0, zc)
	add_child(n)
	store.mesh(Meshes.rounded_box(Vector3(w, 3.2, depth), 0.12, 2), steel, Vector3(0, 1.6, 0), Vector3.ZERO, n)
	store.mesh(Meshes.box(Vector3(w + 0.04, 0.5, depth + 0.04)), Mats.solid(Color(0.95, 0.78, 0.1), 0.6), Vector3(0, 0.3, 0), Vector3.ZERO, n)
	store.mesh(Meshes.cyl(0.5, 0.5, 9.0, 12), Mats.solid(Color(0.8, 0.82, 0.86), 0.15, 0.9), Vector3(0, 7.6, 0), Vector3.ZERO, n)
	var lamp_m: StandardMaterial3D = Mats.glow(Color(1.0, 0.3, 0.1), 3.0).duplicate()
	var lamp := store.mesh(Meshes.sphere(0.4, 10, 6), lamp_m, Vector3(cx, BELT_Y + 9.0, 1.0))
	var r := {"node": n, "x0": x0, "x1": x1, "period": period, "hold": hold, "offset": offset, "down": false, "lamp": lamp_m}
	rams.append(r)
	_hazard(Rect2(x0 + 0.1, BELT_Y - 0.2, w - 0.2, 3.0), "baled", func(): return baler_on and r.down)


## What Baker sees through the Flaps: the sales floor, lit, and the pull cart.
func _build_vista() -> void:
	store.section = "vista"
	var p := MeshInstance3D.new()
	p.mesh = Meshes.box(Vector3(70, 0.4, 60))
	p.material_override = _floor_mat()
	p.position = Vector3(171, -0.2, -36)
	add_child(p)
	_vista_light = store.omni(Vector3(171, 24, -34), Color(1.0, 0.98, 0.92), 4.6, 62.0)
	_vista_light.visible = false
	# the dairy case, far off
	store.box(Vector3(171, 10.6, -58), Vector3(44, 21.2, 0.6), Mats.solid(Color(0.5, 0.56, 0.63), 0.5, 0.25))
	for y in [1.6, 7.0, 12.4]:
		store.box(Vector3(171, y, -56.4), Vector3(43, 0.3, 3.4), Mats.solid(Color(0.76, 0.79, 0.83), 0.35, 0.55))
		store.box(Vector3(171, y - 0.5, -54.8), Vector3(43, 0.08, 0.14), Mats.glow(Color(0.82, 0.92, 1.0), 2.4))
	store.label("DAIRY", Vector3(171, 18.6, -55.8), 4.4, Color(0.62, 0.86, 1.0), 14, Color(0.04, 0.08, 0.16))
	store.row("jug", 152.0, 190.0, 1.75, -56.6, 2.05, [Color(0.95, 0.95, 0.97)], [Color(0.85, 0.15, 0.15), Color(0.2, 0.42, 0.9)])
	store.row("eggbox", 160.0, 182.0, 7.15, -56.6, 3.9, [Color(0.93, 0.93, 0.9)], [Color(0.55, 0.7, 0.85)])
	store.row("tub", 152.0, 190.0, 12.55, -56.6, 1.9, [Color(0.25, 0.5, 0.9)], [Color(0.95, 0.95, 0.95)])
	# the pull cart: a flatbed with empty crates
	var metal := Mats.solid(Color(0.7, 0.72, 0.76), 0.3, 0.8)
	store.box(Vector3(164, 2.2, -40), Vector3(12, 0.5, 6.4), metal)
	store.box(Vector3(158.2, 8.0, -40), Vector3(0.4, 12, 6.4), metal)
	for k in 4:
		store.mesh(Meshes.cyl(1.0, 1.0, 0.8, 14), Mats.solid(Color(0.06, 0.06, 0.07), 0.6), Vector3(160 + (k % 2) * 8, 1.0, -37.2 - (k / 2) * 5.6), Vector3(PI * 0.5, 0, 0))
	store.row("crate", 160.4, 167.6, 2.45, -40, 3.0, [Color(0.2, 0.35, 0.75), Color(0.8, 0.12, 0.15)], [Color(0.2, 0.35, 0.75)], 0.1)
	store.box(Vector3(164, 6.4, -36.6), Vector3(5.0, 2.2, 0.1), Mats.solid(Color(0.95, 0.78, 0.1), 0.6))
	var pl: Label3D = store.label("PULLS", Vector3(164, 6.4, -36.5), 1.5, Color(0.08, 0.08, 0.08))
	pl.outline_size = 0


# --- cast -----------------------------------------------------------------------------------

func _spawn_cast() -> void:
	var cp: Vector3 = checkpoints.get(start_checkpoint, checkpoints.start)
	_add_actor("dot", cp + Vector3(-1.6, 0, -0.3), "dot_chat", [])
	actors.dot.bark_radius = 0.0
	var dangler := _add_actor("dangler", Vector3(22.0, 2.75, -4.1), "a2_dangler", ["Hey! Down there! Is it Tuesday?", "Six weeks. SIX.", "I can SEE the flap."])
	dangler.rotation.z = 0.24
	dangler.talk_radius = 5.2
	dangler.bark_radius = 8.0
	var las := _add_actor("lasagna", Vector3(39.0, 1.2, -4.2), "a2_lasagna", ["WE SEE YOU.", "Karen...?", "All hail the forgotten."])
	las.talk_radius = 3.6
	var saul := _add_actor("saul", Vector3(55.4, 0.3, -1.7), "a2_saul_talk", ["Don't. Step. On the plate.", "Still stuck."])
	saul.rotation.x = -0.95
	_add_actor("kernel", Vector3(84.0, 0.9, -0.7), "a2_kernel_talk", ["Eyes front!", "Stand ready, boys.", "No salt added. No mercy given."])
	for i in 6:
		var c: Node3D = Actor.make("corn")
		add_child(c)
		c.global_position = Vector3([80.8, 82.1, 85.6, 86.7, 87.8, 88.9][i], 0.9, -0.95)
		c.player = player
		corn.append(c)
	# the Discontinued ride in their tote
	var spots := {"fizz": -1.7, "hollow": 0.1, "zero": 1.8}
	for id in spots.keys():
		var a := _add_actor(id, Vector3.ZERO, "", [])
		a.reparent(tote, false)
		a.position = Vector3(spots[id], 0.75, 0.1)
	actors.fizz.barks = ["Customers?!", "It's kind of a big DILL!"]
	actors.zero.barks = ["Hi! I'm a shape!"]
	doug = Giant.new()
	doug.name = "Doug"
	doug.id = "doug"
	doug.build({"pants": Color(0.72, 0.62, 0.45), "shoe": Color(0.3, 0.18, 0.1), "sole": Color(0.15, 0.1, 0.08), "stripe": Color(0.3, 0.18, 0.1), "sleeve": Color(0.16, 0.22, 0.42)})
	add_child(doug)
	doug.global_position = Vector3(6.0, 0.0, -2.9)
	actors["doug"] = doug
	tyler = Giant.new()
	tyler.name = "Tyler"
	tyler.build({"pants": Color(0.2, 0.28, 0.45), "shoe": Color(0.95, 0.95, 0.95), "stripe": Color(0.9, 0.2, 0.2), "apron": Color(0.15, 0.5, 0.3), "sleeve": Color(0.15, 0.5, 0.3)})
	add_child(tyler)
	tyler.global_position = Vector3(240.0, 0.0, -8.0)
	tyler.visible = false
	actors["tyler"] = tyler


# --- triggers and state ---------------------------------------------------------------------

func _build_triggers() -> void:
	# (each zone is wider than a full jump, so nobody sails over the story)
	_trigger("planogram", Rect2(8.6, -0.5, 8.6, 2.0), func(): runner.run("a2_planogram"),
		func(): return not Game.flag("a2_planogram"))
	_trigger("saul", Rect2(51.6, -0.5, 6.0, 2.0), func(): runner.run("a2_saul"),
		func(): return not Game.flag("a2_saul"))
	_trigger("kernel", Rect2(80.3, 0.7, 8.9, 1.0), func(): runner.run("a2_kernel"),
		func(): return not Game.flag("a2_kernel"))
	_trigger("cp_recv", Rect2(117.0, -0.5, 11.0, 3.0), func(): _checkpoint("receiving"),
		func(): return Game.checkpoint in ["start", "stock", "pallet"])
	_trigger("disc", Rect2(119.2, -0.5, 9.4, 2.0), func(): runner.run("a2_discontinued"),
		func(): return not Game.flag("a2_tote"))
	_trigger("stop", Rect2(160.0, 5.4, 3.0, 1.2), func(): runner.run("a2_stop"),
		func(): return Game.flag("a2_tote") and not Game.flag("a2_stopped"))
	_trigger("ending", Rect2(167.4, -0.5, 8.4, 3.0), func(): runner.run("a2_ending"),
		func(): return Game.flag("a2_stopped"))


func _apply_state() -> void:
	_start_follow()
	doug.visible = not Game.flag("a2_intro_done")
	if Game.flag("a2_kernel"):
		_place_stairs()
	if Game.flag("a2_tote"):
		tote.position = Vector3(TOTE_BELT_X, BELT_Y, -1.7)
		if Game.flag("a2_stopped"):
			tote.position.x = 147.0
			_stopped_look()
		else:
			_baler(true)
	var obj := "Find another way back to the store."
	if Game.flag("a2_planogram"):
		obj = "Get back to the store before Tyler gets to \"eggs.\""
	if Game.flag("a2_kernel"):
		obj = "Ride the conveyor to Receiving. Find the Flaps."
	if Game.flag("a2_tote"):
		obj = "Stop the Baler! Run the belt and jump on the red button."
	if Game.flag("a2_stopped"):
		obj = "Through the Flaps. Get to the dairy case before Tyler does."
	if Game.flag("a2_intro_done"):
		hud.objective(obj)


func _on_respawn() -> void:
	for t in traps:
		t.bar.rotation.z = 2.75
	if Game.flag("a2_tote") and not Game.flag("a2_stopped"):
		tote.position.x = TOTE_BELT_X


func _cam_zone() -> float:
	var x := player.global_position.x
	if x > 88.0 and x < 114.0:
		return 16.5
	if x > 129.0 and x < 166.0:
		return 18.0
	return 0.0


# --- events ---------------------------------------------------------------------------------

func _freeze(on: bool) -> void:
	player.rig.set_product(on)
	actors.dot.set_product(on)


func _ev_doug_stands() -> void:
	_freeze(true)
	Sfx.play("door", -6.0, 0.6)
	shake(0.7)
	await get_tree().create_timer(0.5).timeout
	Sfx.play("thud", 0.0)
	cam.shot(shots.a2_table[0], shots.a2_table[1])
	await get_tree().create_timer(0.7).timeout


func _ev_doug_leaves() -> void:
	await doug.walk_to(-34.0, 10.0)
	doug.visible = false
	Sfx.play("clunk", 2.0, 0.7)
	shake(0.9)
	await get_tree().create_timer(0.5).timeout
	Sfx.play("step", -2.0, 0.6)
	await get_tree().create_timer(0.6).timeout
	_freeze(false)


func _stair_slots() -> Array:
	return [Vector3(90.2, 0.0, -0.1), Vector3(91.8, 0.0, -0.1), Vector3(91.8, 1.5, -0.1),
		Vector3(93.4, 0.0, -0.1), Vector3(93.4, 1.5, -0.1), Vector3(93.4, 3.0, -0.1)]


func _place_stairs() -> void:
	var slots := _stair_slots()
	for i in corn.size():
		corn[i].global_position = slots[i]
		corn[i].face_dir(0.0)
	_solid_stairs()


func _solid_stairs() -> void:
	if _stairs_built:
		return
	_stairs_built = true
	store.solid_lane(89.4, 91.0, 0.0, 1.5)
	store.solid_lane(91.0, 92.6, 0.0, 3.0)
	store.solid_lane(92.6, 94.2, 0.0, 4.5)
	_trigger("corn_gripe", Rect2(90.8, 2.8, 2.0, 1.0), func(): corn[2].bubble("SIR! He's standing on my lid, sir!", 3.0))


func _ev_corn_stairs() -> void:
	cam.shot(Vector3(89.0, 5.0, 17.0), Vector3(90.5, 2.6, 0.0))
	var slots := _stair_slots()
	# bottom cans first, so nobody lands on air
	for i in [0, 1, 3, 2, 4, 5]:
		var c: Node3D = corn[i]
		c.set_emotion("determined")
		c.hop_to(slots[i], 2.6 + slots[i].y, 0.5)
		Sfx.play("jump", -8.0, 0.8 + i * 0.05)
		await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(0.5).timeout
	for c in corn:
		c.face_dir(0.0)
		c.set_emotion("neutral")
	Sfx.play("checkpoint", -8.0)
	_solid_stairs()


func _ev_tote_lift() -> void:
	_freeze(true)
	for id in ["fizz", "hollow", "zero"]:
		actors[id].set_product(true)
	cam.shot(Vector3(128.0, 7.0, 26.0), Vector3(129.0, 5.0, -2.0))
	tyler.visible = true
	tyler.global_position = Vector3(168.0, 0.0, -8.0)
	await tyler.walk_to(128.5, 13.0)
	await tyler.reach(tote.global_position + Vector3(0, 3.6, 0.2), 0.6)
	tyler.close_hand()
	Sfx.play("grab")
	await get_tree().create_timer(0.25).timeout
	var grip: Vector3 = tyler.hand.global_position - tote.global_position
	var up := Vector3(TOTE_HOME.x, BELT_Y + 5.0, TOTE_HOME.z)
	var over := Vector3(TOTE_BELT_X, BELT_Y + 5.0, -1.7)
	var down := Vector3(TOTE_BELT_X, BELT_Y, -1.7)
	var tw := create_tween()
	for stop in [[up, 0.5], [over, 0.9], [down, 0.4]]:
		tw.tween_property(tote, "global_position", stop[0], stop[1]).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(tyler.hand, "global_position", stop[0] + grip, stop[1]).set_trans(Tween.TRANS_SINE)
	await tw.finished
	tyler.open_hand()
	Sfx.play("land", 0.0, 0.7)
	shake(0.3)
	await tyler.retract(0.6)
	_giant_bubble(tyler, "Last tote. Then I'm on my fifteen.")
	await get_tree().create_timer(1.6).timeout
	tyler.walk_to(200.0, 14.0)
	get_tree().create_timer(3.0).timeout.connect(func(): tyler.visible = false)
	for id in ["fizz", "hollow", "zero"]:
		actors[id].set_product(false)
		actors[id].set_emotion("scared")
	_freeze(false)


func _baler(on: bool) -> void:
	baler_on = on
	_set_belt(belts[1], on)
	if on:
		Sfx.ambience("machine", -9.0)
	else:
		Sfx.ambience_stop("machine", 0.2)


func _ev_baler_go() -> void:
	Sfx.play("alarm", -8.0)
	_baler(true)


func _stopped_look() -> void:
	_alarm.visible = true
	_recv_light.light_energy = 1.2
	(_button.get_node("Cap") as Node3D).position.y = -0.1
	for r in rams:
		r.node.position.y = BELT_Y + 5.0
		r.lamp.emission_energy_multiplier = 3.0


func _ev_baler_stop() -> void:
	Sfx.play("slam", 0.0, 1.3)
	var tw := create_tween()
	tw.tween_property(_button.get_node("Cap"), "position:y", -0.1, 0.08)
	_baler(false)
	shake(0.8)
	Sfx.play("hiss", -2.0)
	Sfx.play("alarm", -4.0)
	_stopped_look()
	await get_tree().create_timer(0.9).timeout


func _ev_look_tote() -> void:
	var p := tote.global_position
	cam.shot(p + Vector3(1.5, 3.4, 11.0), p + Vector3(0, 1.4, 0))
	await get_tree().create_timer(0.5).timeout


func _ev_tyler_baler() -> void:
	cam.shot(Vector3(146.0, 8.0, 34.0), Vector3(146.0, 8.5, -4.0))
	_freeze(true)
	for id in ["fizz", "hollow", "zero"]:
		actors[id].set_product(true)
	tyler.visible = true
	# he comes in from the stockroom and stops short of the Baler
	tyler.global_position = Vector3(112.0, 0.0, -7.5)
	await tyler.walk_to(139.0, 13.0)


func _ev_tyler_leaves() -> void:
	await tyler.walk_to(200.0, 14.0)
	tyler.visible = false
	_freeze(false)
	for id in ["fizz", "hollow", "zero"]:
		actors[id].set_product(false)


func _ev_flaps() -> void:
	dot_follow = false
	player.set_physics_process(false)
	auto_face = false
	cam.shot(Vector3(171.4, 4.0, 11.0), Vector3(171.4, 3.6, -4.0))
	player.rig.speed = 0.7
	actors.dot.rigs[0].speed = 0.7
	player.rig.facing = PI
	actors.dot.rigs[0].facing = PI
	var tw := create_tween()
	tw.tween_property(player, "global_position", Vector3(170.0, 0.0, -13.2), 2.8)
	tw.parallel().tween_property(actors.dot, "global_position", Vector3(173.2, 0.0, -12.8), 2.8)
	get_tree().create_timer(1.0).timeout.connect(func():
		Sfx.play("whoosh", -6.0, 0.7)
		for i in _strips.size():
			var s := _strips[i]
			var stw := s.create_tween()
			stw.tween_property(s, "rotation:x", -0.5 if (i >= 2 and i <= 5) else -0.12, 0.4)
			stw.tween_property(s, "rotation:x", 0.0, 1.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT))
	await tw.finished
	player.rig.speed = 0.0
	actors.dot.rigs[0].speed = 0.0
	_vista_light.visible = true
	Sfx.music_stop(0.6)
	Sfx.play("sting", -4.0)
	# low, looking up past the two of them at the lit store
	cam.shot(Vector3(171.5, 0.9, -4.9), Vector3(171.4, 4.2, -50.0), true)
	tyler.visible = true
	tyler.global_position = Vector3(140.0, 0.0, -47.0)
	tyler.walk_to(162.0, 7.0)


func _ev_end_act() -> void:
	await _finish_act("END OF ACT TWO", "The Reset has started.", 0, "Act Three: Recall  ·  coming soon")


# --- per frame -------------------------------------------------------------------------------------

func _tick(dt: float) -> void:
	# belts hold still while a conversation or a scrap has the player's hands tied
	for b in belts:
		var v: float = b.speed if b.on and not Game.busy else 0.0
		var body: StaticBody3D = b.body
		if body.constant_linear_velocity.x != v:
			body.constant_linear_velocity = Vector3(v, 0, 0)
		if v == 0.0:
			continue
		var span: float = b.x1 - b.x0
		for s in b.stripes:
			s.position.x = b.x0 + fposmod(s.position.x - b.x0 + v * dt, span)
		if b == belts[0]:
			for r in riders:
				r.position.x = b.x0 + 1.0 + fposmod(r.position.x - b.x0 - 1.0 + v * dt, span - 2.0)
	if not baler_on:
		return
	for r in rams:
		_ram_tick(r)
	if _dying or Game.busy:
		return
	tote.position.x += TOTE_SPEED * dt
	if tote.position.x >= TOTE_FAIL_X:
		if player.godmode:
			tote.position.x = TOTE_FAIL_X
		else:
			tote.position.x = TOTE_FAIL_X
			Sfx.play("slam", 2.0)
			player.die("late")


## up -> (lamp flashes) -> slam -> hold -> rise. It kills for as long as the
## head is low enough to touch an egg.
func _ram_tick(r: Dictionary) -> void:
	var p := fposmod(_t + r.offset, r.period)
	var drop := 0.1
	var rise := 0.5
	var wait: float = r.period - drop - r.hold - rise
	var up := BELT_Y + 5.0
	var low := BELT_Y + 0.06
	var y := up
	var lamp := 0.2
	if p < wait:
		if p > wait - 0.55 and fmod(p, 0.16) < 0.08:
			lamp = 3.0
	elif p < wait + drop:
		y = lerpf(up, low, (p - wait) / drop)
		lamp = 3.0
	elif p < wait + drop + r.hold:
		y = low
		lamp = 3.0
	else:
		y = lerpf(low, up, ease((p - wait - drop - r.hold) / rise, -2.0))
	r.node.position.y = y
	r.lamp.emission_energy_multiplier = lamp
	var was: bool = r.down
	r.down = y < BELT_Y + 1.9
	if r.down and not was:
		var big: bool = r.hold > 0.6
		Sfx.play_at("slam", r.node.global_position, 0.0, 1.0 if big else 1.25)
		if absf(player.global_position.x - r.node.global_position.x) < 16.0:
			shake(0.45 if big else 0.25)
