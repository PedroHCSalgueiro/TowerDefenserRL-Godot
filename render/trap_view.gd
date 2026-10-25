class_name TrapView
extends Node3D
## Desenha as invocações do mapa (ver `Trap`): um disco baixo para as armadilhas e zonas (estrepes escuros,
## urso laranja-ferrugem, tentáculo verde-água, nuvem de peste verde, cratera marrom, do tamanho da área),
## uma caixinha para a torreta do Bolt, uma esfera dourada no alto para o grifo da Kallia e uma esfera de
## osso que anda pelo caminho para o esqueleto. Um nó por invocação, criado e removido conforme o estado;
## o esqueleto acompanha a posição a cada quadro.

const COLORS := {
	"caltrop": Color("#4b4f55"),
	"bear": Color("#c2631a"),
	"tentacle": Color("#1fb5a5"),
	"plague": Color("#7cb342"),
	"crater": Color("#6d4c41"),
	"sentinel": Color("#d9a441"),
	"griffin": Color("#ffb74d"),
	"skeleton": Color("#e6e0c8"),
}
## Tamanho do disco em relação ao raio, por tipo.
const DISC_SIZE := {"caltrop": 0.6, "bear": 0.9, "tentacle": 1.0, "plague": 1.0, "crater": 1.0}
const HEIGHT := 0.035

var _nodes: Dictionary = {}  # id -> MeshInstance3D
var _materials: Dictionary = {}  # tipo -> StandardMaterial3D


func setup() -> void:
	for kind: String in COLORS:
		var material := MeshUtil.flat_material(COLORS[kind])
		if kind == "plague" or kind == "crater":
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color.a = 0.55
		_materials[kind] = material


func _visual_kind(trap: Trap) -> String:
	if trap.kind == "sentinel" and trap.params.get("flying", false):
		return "griffin"
	return trap.kind


func _create(trap: Trap) -> MeshInstance3D:
	var kind := _visual_kind(trap)
	var material: StandardMaterial3D = _materials.get(kind, _materials["caltrop"])
	var node: MeshInstance3D
	match kind:
		"sentinel":
			var box := BoxMesh.new()
			box.size = Vector3(0.24, 0.3, 0.24)
			node = MeshUtil.instance(box, material, self)
			node.position = Vector3(trap.x, 0.15, trap.y)
		"griffin", "skeleton":
			var sphere := SphereMesh.new()
			sphere.radius = 0.13 if kind == "griffin" else 0.11
			sphere.height = sphere.radius * 2.0
			sphere.radial_segments = 10
			sphere.rings = 5
			node = MeshUtil.instance(sphere, material, self)
			node.position = Vector3(trap.x, 1.05 if kind == "griffin" else 0.14, trap.y)
		_:
			node = MeshUtil.instance(MeshUtil.disc_mesh(16), material, self)
			var size := trap.radius * float(DISC_SIZE.get(kind, 0.6))
			node.scale = Vector3(size, 1.0, size)
			node.position = Vector3(trap.x, HEIGHT, trap.y)
	return node


## Sincroniza os nós com `state.traps`.
func draw(state: Object) -> void:
	if state.traps.is_empty() and _nodes.is_empty():
		return
	var seen := {}
	for trap: Trap in state.traps:
		seen[trap.id] = true
		var node: MeshInstance3D = _nodes.get(trap.id)
		if node == null:
			node = _create(trap)
			_nodes[trap.id] = node
		elif trap.kind == "skeleton":
			node.position = Vector3(trap.x, node.position.y, trap.y)
	for id: int in _nodes.keys():
		if not seen.has(id):
			_nodes[id].queue_free()
			_nodes.erase(id)
