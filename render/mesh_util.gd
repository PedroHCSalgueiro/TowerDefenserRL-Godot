class_name MeshUtil
extends RefCounted
## Malhas e materiais pequenos usados pelas views (anéis, discos, quadros, linhas).

static var _ring_cache := {}
static var _disc: ArrayMesh = null
static var _frame_cache := {}


## Material liso sem sombreamento (cor chapada, com transparência se alpha < 1).
static func flat_material(color: Color, double_sided: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED if double_sided else BaseMaterial3D.CULL_BACK
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## Material sombreado (luz da cena), com cor da instância opcional.
static func lit_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## Anel plano no chão (plano XZ, y = 0): raio externo 1, espessura relativa `thickness` (0..1).
static func ring_mesh(thickness: float = 0.06, segments: int = 48) -> ArrayMesh:
	var key := "%s:%d" % [thickness, segments]
	if _ring_cache.has(key):
		return _ring_cache[key]
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	var inner := 1.0 - thickness
	for i in segments:
		var a := TAU * float(i) / float(segments)
		verts.append(Vector3(cos(a) * inner, 0.0, sin(a) * inner))
		verts.append(Vector3(cos(a), 0.0, sin(a)))
	for i in segments:
		var a := i * 2
		var b := ((i + 1) % segments) * 2
		indices.append_array([a, a + 1, b + 1, a, b + 1, b])
	var mesh := _array_mesh(verts, indices)
	_ring_cache[key] = mesh
	return mesh


## Disco plano no chão (raio 1, plano XZ).
static func disc_mesh(segments: int = 48) -> ArrayMesh:
	if _disc != null:
		return _disc
	var verts := PackedVector3Array([Vector3.ZERO])
	var indices := PackedInt32Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		verts.append(Vector3(cos(a), 0.0, sin(a)))
	for i in segments:
		indices.append_array([0, 1 + i, 1 + (i + 1) % segments])
	_disc = _array_mesh(verts, indices)
	return _disc


## Quadro quadrado no chão (contorno de uma casa): lado `side`, espessura `line` (em unidades).
static func frame_mesh(side: float = 1.0, line: float = 0.08) -> ArrayMesh:
	var key := "%s:%s" % [side, line]
	if _frame_cache.has(key):
		return _frame_cache[key]
	var h := side / 2.0
	var i := h - line
	var verts := PackedVector3Array([
		Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h),
		Vector3(-i, 0, -i), Vector3(i, 0, -i), Vector3(i, 0, i), Vector3(-i, 0, i),
	])
	var indices := PackedInt32Array()
	for k in 4:
		var n := (k + 1) % 4
		indices.append_array([k, n, 4 + n, k, 4 + n, 4 + k])
	var mesh := _array_mesh(verts, indices)
	_frame_cache[key] = mesh
	return mesh


static func _array_mesh(verts: PackedVector3Array, indices: PackedInt32Array) -> ArrayMesh:
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## MeshInstance3D com malha e material.
static func instance(mesh: Mesh, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if parent != null:
		parent.add_child(mi)
	return mi


## Segmento de linha entre dois pontos 3D como faixa fina (para setas e pulsos).
static func line_strip(parent: Node3D, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ImmediateMesh.new()
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
