class_name ProjectileView
extends Node3D
## Desenha os projéteis (porte de `ProjectileView.ts`): uma esfera pequena por projétil ativo, numa
## MultiMesh, interpolada entre ticks; e o anel que cresce e some nas explosões em área (um pool de
## `maxActive` anéis).

const FLOATS := 12

var _cfg: Dictionary
var _mmi: MultiMeshInstance3D
var _capacity := 0
var _buf := PackedFloat32Array()
var _rings: Array[MeshInstance3D] = []
var _ring_materials: Array[StandardMaterial3D] = []
var _ring_left: Array[float] = []
var _ring_radius: Array[float] = []
var _next_ring := 0


func setup() -> void:
	_cfg = RenderConfig.data()["projectiles"]
	var radius: float = float(_cfg["radius"]) * RenderConfig.PX_TO_UNIT * 1.6
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	_mmi = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sphere
	mm.instance_count = 0
	_mmi.multimesh = mm
	_mmi.material_override = MeshUtil.flat_material(RenderConfig.color(_cfg["color"]))
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mmi)
	var ex: Dictionary = _cfg["explosion"]
	for i in int(ex["maxActive"]):
		var mat := MeshUtil.flat_material(RenderConfig.color(ex["color"], ex["alpha"]))
		var ring := MeshUtil.instance(MeshUtil.ring_mesh(0.08), mat, self)
		ring.visible = false
		_rings.append(ring)
		_ring_materials.append(mat)
		_ring_left.append(0.0)
		_ring_radius.append(1.0)


func _grow(needed: int) -> void:
	if needed <= _capacity:
		return
	_capacity = maxi(needed, maxi(128, _capacity * 2))
	_mmi.multimesh.instance_count = _capacity
	_mmi.multimesh.visible_instance_count = 0
	_buf.resize(_capacity * FLOATS)


## Explosões em área nascem dos eventos `areaExploded` (sem gatilho; as de gatilho têm o próprio
## efeito no `TriggerFxView`).
func handle_events(events: Array) -> void:
	for event: Dictionary in events:
		if event["type"] == "areaExploded" and not event["trigger"]:
			_spawn_ring(event["x"], event["y"], event["radius"])


func _spawn_ring(x: float, y: float, radius: float) -> void:
	var i := _next_ring
	_next_ring = (_next_ring + 1) % _rings.size()
	_ring_left[i] = float(_cfg["explosion"]["durationMs"])
	_ring_radius[i] = radius
	_rings[i].position = Vector3(x, 0.05, y)
	_rings[i].visible = true


func draw(state: Object, alpha: float, frame_delta_ms: float) -> void:
	var slots: Array[Projectile] = state.projectiles.slots
	_grow(slots.size())
	var buf := _buf
	var n := 0
	for p in slots:
		if not p.active:
			continue
		var o := n * FLOATS
		buf[o] = 1.0
		buf[o + 1] = 0.0
		buf[o + 2] = 0.0
		buf[o + 3] = lerpf(p.prev_x, p.x, alpha)
		buf[o + 4] = 0.0
		buf[o + 5] = 1.0
		buf[o + 6] = 0.0
		buf[o + 7] = 0.45
		buf[o + 8] = 0.0
		buf[o + 9] = 0.0
		buf[o + 10] = 1.0
		buf[o + 11] = lerpf(p.prev_y, p.y, alpha)
		n += 1
	var mm := _mmi.multimesh
	mm.visible_instance_count = n
	if n > 0:
		mm.buffer = buf
	var duration: float = float(_cfg["explosion"]["durationMs"])
	for i in _rings.size():
		if _ring_left[i] <= 0.0:
			continue
		_ring_left[i] = maxf(0.0, _ring_left[i] - frame_delta_ms)
		var life := _ring_left[i] / duration
		var r: float = _ring_radius[i] * (1.0 - 0.6 * life)
		_rings[i].scale = Vector3(r, 1.0, r)
		var c: Color = _ring_materials[i].albedo_color
		c.a = float(_cfg["explosion"]["alpha"]) * life
		_ring_materials[i].albedo_color = c
		if _ring_left[i] <= 0.0:
			_rings[i].visible = false
