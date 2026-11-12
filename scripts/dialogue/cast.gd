extends RefCounted
## Who's who: display names, name-tag colours, voices and character specs.

const FoodRig = preload("res://scripts/actors/food_rig.gd")

const CAST := {
	"baker": {"name": "BAKER", "tag": Color(1.0, 0.78, 0.25), "voice": "baker",
		"rig": {"kind": "egg", "h": 0.95, "color": Color(0.97, 0.93, 0.84), "legs": true, "shoe": Color(0.92, 0.3, 0.22), "brow": Color(0.36, 0.22, 0.14)}},
	"one": {"name": "ONE", "tag": Color(0.75, 0.82, 0.95), "voice": "one",
		"rig": {"kind": "egg", "h": 1.0, "color": Color(0.99, 0.98, 0.95), "arms": false, "brow": Color(0.3, 0.25, 0.25)}},
	"six": {"name": "SIX", "tag": Color(0.68, 0.9, 0.7), "voice": "six",
		"rig": {"kind": "egg", "h": 1.0, "color": Color(0.99, 0.98, 0.95), "arms": false, "brow": Color(0.3, 0.25, 0.25)}},
	"twelve": {"name": "TWELVE", "tag": Color(1.0, 0.7, 0.82), "voice": "twelve",
		"rig": {"kind": "egg", "h": 0.92, "color": Color(0.99, 0.98, 0.95), "arms": false, "feather": true, "eye": 1.12, "brow": Color(0.3, 0.25, 0.25)}},
	"sib": {"name": "EGG", "tag": Color(0.9, 0.9, 0.9), "voice": "one",
		"rig": {"kind": "egg", "h": 1.0, "color": Color(0.99, 0.98, 0.95), "simple": true}},
	"meadow": {"name": "MEADOW", "tag": Color(0.86, 0.66, 0.42), "voice": "posh",
		"rig": {"kind": "egg", "h": 1.05, "color": Color(0.74, 0.5, 0.32), "arms": false, "brow": Color(0.25, 0.15, 0.1)}},
	"clover": {"name": "CLOVER", "tag": Color(0.8, 0.6, 0.4), "voice": "posh",
		"rig": {"kind": "egg", "h": 1.02, "color": Color(0.68, 0.45, 0.28), "arms": false, "brow": Color(0.25, 0.15, 0.1)}},
	"skim": {"name": "FATHER SKIM", "tag": Color(0.8, 0.7, 0.98), "voice": "skim",
		"rig": {"kind": "jug", "h": 3.3, "collar": true, "color": Color(0.88, 0.36, 0.68), "accent": Color(0.5, 0.4, 0.82), "label": "SKIM", "arm_len": 1.0, "hand": 0.15, "limb_t": 0.055}},
	"whole": {"name": "WHOLE MILK", "tag": Color(0.95, 0.5, 0.5), "voice": "jug",
		"rig": {"kind": "jug", "h": 2.8, "color": Color(0.85, 0.15, 0.15), "accent": Color(0.85, 0.3, 0.3), "label": "WHOLE", "arm_len": 1.0, "hand": 0.15, "limb_t": 0.055}},
	"twopct": {"name": "TWO PERCENT", "tag": Color(0.55, 0.7, 1.0), "voice": "jug",
		"rig": {"kind": "jug", "h": 2.8, "color": Color(0.2, 0.4, 0.9), "accent": Color(0.35, 0.55, 0.9), "label": "2%", "arm_len": 1.0, "hand": 0.15, "limb_t": 0.055}},
	"gary": {"name": "GARY", "tag": Color(1.0, 0.55, 0.65), "voice": "gary",
		"rig": {"kind": "cup", "h": 1.15, "color": Color(0.94, 0.42, 0.55)}},
	"blueberry": {"name": "BLUEBERRY", "tag": Color(0.6, 0.62, 1.0), "voice": "yogurt",
		"rig": {"kind": "cup", "h": 1.15, "color": Color(0.36, 0.38, 0.76)}},
	"peach": {"name": "PEACH", "tag": Color(1.0, 0.7, 0.45), "voice": "yogurt",
		"rig": {"kind": "cup", "h": 1.15, "color": Color(0.98, 0.6, 0.32)}},
	"virgin": {"name": "HER HOLINESS", "tag": Color(0.95, 0.85, 0.45), "voice": "virgin",
		"rig": {"kind": "bottle", "h": 4.6, "color": Color(0.08, 0.22, 0.09), "accent": Color(0.96, 0.91, 0.76), "halo": true, "label": "EXTRA VIRGIN", "arm_len": 1.1, "hand": 0.13, "limb_t": 0.05, "limb": Color(0.12, 0.2, 0.1)}},
	"balsamic": {"name": "BALSAMIC", "tag": Color(0.7, 0.45, 0.45), "voice": "jug",
		"rig": {"kind": "bottle", "h": 3.4, "color": Color(0.1, 0.05, 0.05), "accent": Color(0.3, 0.12, 0.14), "arm_len": 0.95, "hand": 0.12, "limb_t": 0.045, "limb": Color(0.12, 0.06, 0.06)}},
	"beans": {"name": "BEANS", "tag": Color(0.95, 0.6, 0.3), "voice": "beans",
		"rig": {"kind": "can", "h": 1.4, "color": Color(0.84, 0.42, 0.14), "tilt": 0.07, "brow": Color(0.2, 0.12, 0.08)}},
	"dot": {"name": "DOT", "tag": Color(1.0, 0.85, 0.3), "voice": "dot",
		"rig": {"kind": "donut", "h": 1.3, "legs": true, "sticker": true, "color": Color(0.62, 0.36, 0.16), "accent": Color(0.93, 0.66, 0.32), "shoe": Color(0.95, 0.45, 0.6), "brow": Color(0.35, 0.2, 0.1)}},
	"sour": {"name": "SOURDOUGH", "tag": Color(0.85, 0.7, 0.5), "voice": "sour",
		"rig": {"kind": "boule", "h": 1.6, "w": 2.8, "brow": Color(0.3, 0.18, 0.08), "arm_len": 0.6, "hand": 0.13, "limb_t": 0.05}},
	"rolls": {"name": "THE ROLLS", "tag": Color(0.95, 0.75, 0.45), "voice": "rolls",
		"rig": {"kind": "roll", "h": 0.62, "w": 0.95, "arms": false, "brow": Color(0.35, 0.2, 0.1)}},
	# --- Act Two: the Back
	"dangler": {"name": "DANGLER", "tag": Color(1.0, 0.6, 0.3), "voice": "dangler",
		"rig": {"kind": "block", "h": 2.1, "w": 1.5, "d": 0.5, "radius": 0.22, "crimp": true, "color": Color(0.9, 0.28, 0.12), "accent": Color(1.0, 0.82, 0.2), "band": Vector2(0.06, 0.22), "label": "ZESTY", "label_y": 0.17, "label_color": Color(0.7, 0.12, 0.05), "face_y": 0.66, "rough": 0.25, "arm_len": 0.5}},
	"lasagna": {"name": "KAREN'S LASAGNA", "tag": Color(0.6, 0.85, 0.5), "voice": "lasagna",
		"rig": {"kind": "block", "h": 1.25, "w": 2.7, "d": 1.9, "radius": 0.2, "color": Color(0.72, 0.3, 0.2), "lid": Color(0.25, 0.5, 0.8), "mold": true, "arms": false, "face_y": 0.5, "brow": Color(0.25, 0.4, 0.2)}},
	"kernel": {"name": "COLONEL KERNEL", "tag": Color(1.0, 0.88, 0.35), "voice": "kernel",
		"rig": {"kind": "can", "h": 1.5, "color": Color(0.96, 0.8, 0.16), "label": "CORN", "label_color": Color(0.2, 0.45, 0.15), "helmet": true, "brow": Color(0.25, 0.18, 0.05)}},
	"corn": {"name": "THE CORN", "tag": Color(0.95, 0.85, 0.4), "voice": "kernel",
		"rig": {"kind": "can", "h": 1.5, "color": Color(0.96, 0.8, 0.16), "label": "CORN", "label_color": Color(0.2, 0.45, 0.15), "arms": false, "brow": Color(0.25, 0.18, 0.05)}},
	"saul": {"name": "SAUL", "tag": Color(0.95, 0.86, 0.65), "voice": "saul",
		"rig": {"kind": "block", "h": 1.25, "w": 1.25, "d": 0.16, "radius": 0.05, "color": Color(0.94, 0.82, 0.58), "rough": 0.9, "brow": Color(0.5, 0.35, 0.15), "arm_len": 0.4}},
	"fizz": {"name": "PICKLE FIZZ", "tag": Color(0.6, 0.9, 0.35), "voice": "fizz",
		"rig": {"kind": "can", "h": 1.9, "r": 0.27, "color": Color(0.3, 0.58, 0.16), "label": "FIZZ", "label_color": Color(1.0, 0.95, 0.4), "brow": Color(0.1, 0.25, 0.05)}},
	"hollow": {"name": "HOLLOW", "tag": Color(0.75, 0.52, 0.35), "voice": "hollow",
		"rig": {"kind": "egg", "h": 1.5, "color": Color(0.36, 0.2, 0.1), "ears": true, "brow": Color(0.16, 0.08, 0.03)}},
	"zero": {"name": "ZERO", "tag": Color(1.0, 0.95, 0.6), "voice": "zero",
		"rig": {"kind": "block", "h": 1.3, "w": 1.3, "d": 0.14, "radius": 0.05, "color": Color(1.0, 0.86, 0.3), "rough": 0.2, "brow": Color(0.7, 0.5, 0.1), "arm_len": 0.4}},
	"machine": {"name": "THE MACHINE", "tag": Color(0.7, 0.8, 0.95), "voice": "dangler"},
	"narc": {"name": "THE NARC", "tag": Color(0.5, 0.85, 1.0), "voice": "narc"},
	"tyler": {"name": "TYLER", "tag": Color(0.6, 0.85, 0.6), "voice": "tyler"},
	"doug": {"name": "DOUG", "tag": Color(0.8, 0.8, 0.85), "voice": "doug"},
	"pa": {"name": "THE VOICE", "tag": Color(1.0, 0.9, 0.5), "voice": "pa"},
	"crowd": {"name": "THE FAITHFUL", "tag": Color(0.8, 0.75, 0.95), "voice": "jug"},
}


static func info(id: String) -> Dictionary:
	return CAST.get(id, {"name": id.to_upper(), "tag": Color(0.85, 0.85, 0.85), "voice": "one"})


static func make_rig(id: String, extra := {}) -> Node3D:
	var rig: Node3D = FoodRig.new()
	var spec: Dictionary = info(id).get("rig", {"kind": "egg"}).duplicate()
	spec.name = id
	spec.merge(extra, true)
	rig.build(spec)
	rig.name = id
	return rig
