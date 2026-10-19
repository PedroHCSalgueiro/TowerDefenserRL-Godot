class_name TrapView
extends Node3D
## Desenha as armadilhas do caminho (Engenheira Mabel): um disco baixo por armadilha, escuro para os
## estrepes e laranja-ferrugem para a armadilha de urso. Um nó por armadilha, criado e removido
## conforme o estado.

const CALTROP_COLOR := Color("#4b4f55")
const BEAR_COLOR := Color("#c2631a")
const HEIGHT := 0.035

var _nodes: Dictionary = {}  # id -> MeshInstance3D
var _caltrop_material: StandardMaterial3D
var _bear_material: StandardMaterial3D


func setup() -> void:
	_caltrop_material = MeshUtil.flat_material(CALTROP_COLOR)
	_bear_material = MeshUtil.flat_material(BEAR_COLOR)


## Sincroniza os nós com `state.traps`.
func draw(state: Object) -> void:
	if state.traps.is_empty() and _nodes.is_empty():
		return
	var seen := {}
	for trap: Trap in state.traps:
		seen[trap.id] = true
		var node: MeshInstance3D = _nodes.get(trap.id)
		if node == null:
			node = MeshUtil.instance(MeshUtil.disc_mesh(16),
					_bear_material if trap.kind == "bear" else _caltrop_material, self)
			var size := trap.radius * (0.9 if trap.kind == "bear" else 0.6)
			node.scale = Vector3(size, 1.0, size)
			node.position = Vector3(trap.x, HEIGHT, trap.y)
			_nodes[trap.id] = node
	for id: int in _nodes.keys():
		if not seen.has(id):
			_nodes[id].queue_free()
			_nodes.erase(id)
