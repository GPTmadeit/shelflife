extends RefCounted
## Procedural mesh builders. Every prop and character is made from these.
## Front faces wind clockwise (Godot's convention).


static func _mesh(verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, idx: PackedInt32Array, colors := PackedColorArray()) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	if colors.size() == verts.size() and colors.size() > 0:
		arr[Mesh.ARRAY_COLOR] = colors
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Surface of revolution around +Y. `profile` holds (radius, y) points from
## bottom to top; a radius of 0 at an end closes the shape there.
static func lathe(profile: PackedVector2Array, segments := 28) -> ArrayMesh:
	var n := profile.size()
	var n2 := PackedVector2Array()
	n2.resize(n)
	for i in n:
		var a: Vector2 = profile[maxi(i - 1, 0)]
		var b: Vector2 = profile[mini(i + 1, n - 1)]
		var t := b - a
		var nn := Vector2(t.y, -t.x)
		n2[i] = nn.normalized() if nn.length_squared() > 1e-12 else Vector2(1, 0)
	var lens := PackedFloat32Array()
	lens.resize(n)
	var total := 0.0
	for i in n:
		if i > 0:
			total += profile[i].distance_to(profile[i - 1])
		lens[i] = total
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in n:
		var p: Vector2 = profile[i]
		for j in segments + 1:
			var th := TAU * float(j) / segments
			var c := cos(th)
			var s := sin(th)
			verts.append(Vector3(p.x * c, p.y, p.x * s))
			norms.append(Vector3(n2[i].x * c, n2[i].y, n2[i].x * s))
			uvs.append(Vector2(float(j) / segments, 1.0 - lens[i] / maxf(total, 1e-6)))
	var row := segments + 1
	for i in n - 1:
		for j in segments:
			var a0 := i * row + j
			var b0 := i * row + j + 1
			var c0 := (i + 1) * row + j
			var d0 := (i + 1) * row + j + 1
			idx.append_array([a0, b0, d0, a0, d0, c0])
	return _mesh(verts, norms, uvs, idx)


## Radius of a lathe profile at height y (linear between points).
static func profile_radius(profile: PackedVector2Array, y: float) -> float:
	if y <= profile[0].y:
		return profile[0].x
	for i in range(1, profile.size()):
		var a := profile[i - 1]
		var b := profile[i]
		if y <= b.y:
			var t := (y - a.y) / maxf(b.y - a.y, 1e-6)
			return lerpf(a.x, b.x, t)
	return profile[profile.size() - 1].x


## An egg: blunt end down, pointy end up.
static func egg_profile(h: float, w: float, rings := 22) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in rings + 1:
		var th := PI * float(i) / rings
		var y := -cos(th)
		var r := sin(th) * (1.0 - 0.13 * y)
		pts.append(Vector2(r * w * 0.5, (y + 1.0) * 0.5 * h))
	return pts


## A dome (loaves, rolls, buns): flat bottom, rounded top.
static func dome_profile(w: float, h: float, rings := 14, flat := 0.12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(0, 0))
	pts.append(Vector2(w * 0.5 * (1.0 - flat), 0))
	for i in range(1, rings + 1):
		var th := (PI * 0.5) * float(i) / rings
		var r := cos(th) * w * 0.5
		var y := flat * h + sin(th) * h * (1.0 - flat)
		pts.append(Vector2(r if i < rings else 0.0, y))
	return pts


## Rounded box centred on the origin. `steps` = rows across each rounded edge.
static func rounded_box(size: Vector3, radius: float, steps := 3) -> ArrayMesh:
	var half := size * 0.5
	var r := minf(radius, minf(half.x, minf(half.y, half.z)) * 0.98)
	var inner := half - Vector3.ONE * r
	var faces := [
		[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
		[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
	]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for f in faces:
		var N: Vector3 = f[0]
		var U: Vector3 = f[1]
		var V: Vector3 = f[2]
		var hn := absf(N.dot(half))
		var hu := absf(U.dot(half))
		var hv := absf(V.dot(half))
		var su := _edge_samples(hu, r, steps)
		var sv := _edge_samples(hv, r, steps)
		var base := verts.size()
		for l in sv.size():
			for k in su.size():
				var p := N * hn + U * su[k] + V * sv[l]
				var c := p.clamp(-inner, inner)
				var d := p - c
				var dn := d.normalized() if d.length_squared() > 1e-12 else N
				verts.append(c + dn * r)
				norms.append(dn)
				uvs.append(Vector2((su[k] / hu + 1.0) * 0.5, 1.0 - (sv[l] / hv + 1.0) * 0.5))
		var w := su.size()
		for l in sv.size() - 1:
			for k in su.size() - 1:
				var a0 := base + l * w + k
				var b0 := a0 + 1
				var c0 := a0 + w
				var d0 := c0 + 1
				idx.append_array([a0, c0, d0, a0, d0, b0])
	return _mesh(verts, norms, uvs, idx)


static func _edge_samples(h: float, r: float, steps: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var inner := h - r
	for k in steps + 1:
		out.append(-h + r * float(k) / steps)
	if inner > 1e-4:
		for k in steps + 1:
			out.append(inner + r * float(k) / steps)
	else:
		for k in range(1, steps + 1):
			out.append(r * float(k) / steps - (r - h))
	return out


## A grid laid on a front-facing surface: z = surf(x, y) + lift. Used for
## faces (mouths, cracks, labels) so they hug curved bodies.
static func surface_patch(w: float, h: float, center: Vector2, surf: Callable, lift := 0.004, cols := 10, rows := 8) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var e := 0.002
	for l in rows + 1:
		for k in cols + 1:
			var u := float(k) / cols
			var v := float(l) / rows
			var x := center.x + (u - 0.5) * w
			var y := center.y + (0.5 - v) * h
			var z: float = surf.call(x, y)
			var zx: float = (surf.call(x + e, y) - surf.call(x - e, y)) / (2.0 * e)
			var zy: float = (surf.call(x, y + e) - surf.call(x, y - e)) / (2.0 * e)
			var n := Vector3(-zx, -zy, 1.0).normalized()
			verts.append(Vector3(x, y, z) + n * lift)
			norms.append(n)
			uvs.append(Vector2(u, v))
	var wv := cols + 1
	for l in rows:
		for k in cols:
			var a0 := l * wv + k          # top-left
			var b0 := a0 + 1              # top-right
			var c0 := a0 + wv             # bottom-left
			var d0 := c0 + 1              # bottom-right
			# rows go top -> bottom, so "up" is towards row 0
			idx.append_array([c0, a0, b0, c0, b0, d0])
	return _mesh(verts, norms, uvs, idx)


## A ribbon tube along a polyline (crack lines, handles, wires).
static func tube(points: PackedVector3Array, radius: float, sides := 6) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var n := points.size()
	for i in n:
		var a := points[maxi(i - 1, 0)]
		var b := points[mini(i + 1, n - 1)]
		var t := (b - a).normalized()
		var up := Vector3.UP if absf(t.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
		var s := t.cross(up).normalized()
		var u := s.cross(t).normalized()
		for j in sides + 1:
			var th := TAU * float(j) / sides
			var d := s * cos(th) + u * sin(th)
			verts.append(points[i] + d * radius)
			norms.append(d)
			uvs.append(Vector2(float(j) / sides, float(i) / maxf(n - 1, 1)))
	var row := sides + 1
	for i in n - 1:
		for j in sides:
			var a0 := i * row + j
			var b0 := a0 + 1
			var c0 := a0 + row
			var d0 := c0 + 1
			idx.append_array([a0, b0, d0, a0, d0, c0])
	return _mesh(verts, norms, uvs, idx)


## Bakes several meshes (with transforms and flat vertex colours) into one
## mesh, so a multi-part prop is a single draw call.
static func merge(parts: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for part in parts:
		var mesh: Mesh = part[0]
		var xf: Transform3D = part[1]
		var col: Color = part[2] if part.size() > 2 else Color.WHITE
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var uv = arr[Mesh.ARRAY_TEX_UV]
			var ix = arr[Mesh.ARRAY_INDEX]
			var base := verts.size()
			var nb := xf.basis.inverse().transposed()
			for i in v.size():
				verts.append(xf * v[i])
				norms.append((nb * nr[i]).normalized())
				uvs.append(uv[i] if uv != null and i < uv.size() else Vector2.ZERO)
				cols.append(col)
			if ix == null or ix.size() == 0:
				for i in v.size():
					idx.append(base + i)
			else:
				for i in ix.size():
					idx.append(base + ix[i])
	return _mesh(verts, norms, uvs, idx, cols)


static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func cyl(r_top: float, r_bot: float, h: float, segs := 24) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = segs
	m.rings = 1
	return m


static func sphere(r: float, segs := 18, rings := 10) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = segs
	m.rings = rings
	return m


static func hemi(r: float, segs := 18, rings := 8) -> SphereMesh:
	var m := sphere(r, segs, rings)
	m.is_hemisphere = true
	m.height = r
	return m


static func capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = maxf(h, r * 2.0)
	m.radial_segments = 12
	m.rings = 4
	return m


static func torus(inner: float, outer: float, rings := 28, ring_segs := 14) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = rings
	m.ring_segments = ring_segs
	return m


static func quad(w: float, h: float) -> QuadMesh:
	var m := QuadMesh.new()
	m.size = Vector2(w, h)
	return m


static func prism(size: Vector3) -> PrismMesh:
	var m := PrismMesh.new()
	m.size = size
	return m
