extends RefCounted
## Every Planogram scrap in the game: id -> [act, position, title, verse].

const ALL := {
	"s1": [1, Vector3(-10.8, 10.8, 0), "PLANOGRAM 1:1", "In the beginning there was the Warehouse, and the Warehouse was without form, and pallets were upon the face of the dock."],
	"s2": [1, Vector3(34.1, 3.2, 0), "PLANOGRAM 3:16", "For Corporate so loved the shelf that it gave its only Facing, that whosoever is scanned shall not perish, but have Restock everlasting."],
	"s3": [1, Vector3(79.3, 2.3, 0), "PLANOGRAM 4:20", "And the night crew did take their fifteen, out back, by the Dumpster. And lo, it was a long fifteen."],
	"s4": [1, Vector3(99.6, 0.0, 0), "PLANOGRAM 7:7", "Eye level is buy level. The bottom shelf is for the poor. The top shelf is for the tall, and the damned."],
	"s5": [1, Vector3(119.6, 7.5, 0), "PLANOGRAM 9:12", "Blessed are the marked-down, for they shall inherit the clearance bin."],
	"s6": [1, Vector3(134.8, 2.2, 0), "PLANOGRAM 11:30", "Thou shalt not covet thy neighbor's Facing. Unless it is an endcap. Then go nuts."],
	"b1": [2, Vector3(-7.6, 0.0, 0), "BREAKROOM 1:1", "Thou shalt label thy food. Thou shalt not eat what is labeled. Karen, this means thee."],
	"b2": [2, Vector3(32.75, 2.2, 0), "PLANOGRAM 2:15", "And on the seventh day, Corporate rested. The night crew did not. The night crew does not get the seventh day."],
	"b3": [2, Vector3(73.5, 0.0, 0), "RECEIVING 6:9", "First in, first out. So it is written. So it is never, ever done."],
	"b4": [2, Vector3(103.0, 5.3, 0), "PLANOGRAM 12:1", "Lift with thy legs, for thy back is not covered."],
	"b5": [2, Vector3(139.5, 7.3, 0), "SHRINK 3:3", "Known loss is a write-off. Unknown loss is a mystery. Both are Tyler."],
	"b6": [2, Vector3(165.4, 1.85, 0), "PLANOGRAM 13:13", "There is no thirteenth Facing. Stop asking. Sincerely, Corporate."],
}


static func for_act(act: int) -> Dictionary:
	var out := {}
	for id in ALL.keys():
		if ALL[id][0] == act:
			out[id] = ALL[id]
	return out
