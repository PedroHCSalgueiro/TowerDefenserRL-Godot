class_name FortressWalls
extends Node3D
## Muralha em volta da área aberta do mapa e tochas na beira do caminho (`grid.scenery.walls` e `.torches` em
## render.json). Só desenho: não muda nenhuma casa.
##
## Toda casa fechada (ou fora do mapa) vizinha de uma casa aberta vira um bloco de muralha. Se a área aberta fica à
## frente dela (para a câmera), o bloco é alto, com ameias; se fica atrás, o bloco é baixo, para não esconder o jogo.
## Quando um pedaço do mapa abre, a muralha é refeita.

const WALL_SHADER := preload("res://render/fortress_wall.gdshader")

var _cfg: Dictionary
var _material: ShaderMaterial
var _flame_material: StandardMaterial3D
var _pole_material: StandardMaterial3D
## Pontos das chamas (mundo), para a luz por cima.
var torch_points: Array[Vector3] = []
var _flames: Array[MeshInstance3D] = []
var _elapsed := 0.0
var _revision := -1
## Peças em volta (portal, torre, pé da muralha, miudezas, cristal do núcleo); null sem `props`.
var props: SceneryProps


static func create(grid_cfg: Dictionary) -> FortressWalls:
	var cfg: Dictionary = grid_cfg.get("scenery", {})
	if cfg.is_empty():
		return null
	var walls := FortressWalls.new()
	walls._cfg = cfg
	walls._build_materials()
	walls.props = SceneryProps.create(grid_cfg)
	return walls


func _build_materials() -> void:
	var w: Dictionary = _cfg["walls"]
	_material = ShaderMaterial.new()
	_material.shader = WALL_SHADER
	_material.set_shader_parameter("face", load(String(w["texture"])))
	_material.set_shader_parameter("top_color", SceneryGround._vec(w["topColor"]))
	_material.set_shader_parameter("left_light", float(w["leftLight"]))
	_material.set_shader_parameter("right_light", float(w["rightLight"]))
	_material.set_shader_parameter("px_along", GroundTiles.TILE.x / 2.0)
	_material.set_shader_parameter("px_up", GroundProjection.PX_PER_UNIT * cos(GroundProjection.elevation()) / float(RenderConfig.data()["camera"]["pixelArt"]["viewPxPerArtPx"]))
	var t: Dictionary = _cfg["torches"]
	_flame_material = MeshUtil.flat_material(RenderConfig.color(t["flameColor"]))
	_pole_material = MeshUtil.flat_material(RenderConfig.color(t["poleColor"]))


## Casas de muralha: fechadas (ou fora do mapa) com alguma vizinha aberta. Valor: true = alta (a vizinha aberta fica à
## frente, com x e y maiores ou iguais), false = baixa.
static func wall_cells(map: SimMap) -> Dictionary:
	var out := {}
	for y in range(-1, map.height + 1):
		for x in range(-1, map.width + 1):
			var cell := Vector2i(x, y)
			if map.is_inside(cell) and map.is_open(cell):
				continue
			var any := false
			var tall := false
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					var n := cell + Vector2i(dx, dy)
					if map.is_inside(n) and map.is_open(n):
						any = true
						if dx >= 0 and dy >= 0:
							tall = true
			if any:
				out[cell] = tall
	return out


## Casas do caminho que ganham tocha (uma a cada `every`) e o lado livre onde ela fica.
static func torch_spots(map: SimMap, every: int) -> Array:
	var out: Array = []
	var path := map.path_cells
	for k in range(1, path.size() - 1):
		if k % every != 0 or not map.is_open(path[k]):
			continue
		var dir: Vector2i = path[k + 1] - path[k - 1]
		var sides: Array = [Vector2i(1, 0), Vector2i(-1, 0)] if dir.x == 0 else [Vector2i(0, 1), Vector2i(0, -1)]
		for s: Vector2i in sides:
			var n: Vector2i = path[k] + s
			if map.is_inside(n) and map.is_open(n) and not map.is_path(n):
				out.append([path[k], s])
				break
	return out


func rebuild(map: SimMap) -> void:
	if map.revision == _revision:
		return
	_revision = map.revision
	for child in get_children():
		if child == props:
			continue
		remove_child(child)
		child.queue_free()
	if props != null and props.get_parent() == null:
		add_child(props)
	_flames.clear()
	torch_points.clear()
	var w: Dictionary = _cfg["walls"]
	var tall_h := float(w["height"])
	var low_h := float(w["lowHeight"])
	var block := BoxMesh.new()
	block.size = Vector3(1.0, 1.0, 1.0)
	var merlon := BoxMesh.new()
	var ms := float(w["merlonSize"])
	merlon.size = Vector3(ms, float(w["merlonHeight"]), ms)
	var cells := wall_cells(map)
	if props != null:
		props.rebuild(map, cells)
	for cell: Vector2i in cells:
		if props != null and props.portal_cells.has(cell):
			continue
		var h := tall_h if cells[cell] else low_h
		var mi := MeshUtil.instance(block, _material, self)
		mi.scale = Vector3(1.0, h, 1.0)
		mi.position = Vector3(cell.x, h / 2.0 - 0.12, cell.y)
		# ameias: na alta, na beirada que olha para a área aberta; na baixa, na beirada de fora
		for side: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			var n := cell + side
			if not (map.is_inside(n) and map.is_open(n)):
				continue
			if cells[cell] and (side.x < 0 or side.y < 0):
				continue
			var edge := side if cells[cell] else -side
			for t in [-0.3, 0.0, 0.3]:
				var m := MeshUtil.instance(merlon, _material, self)
				var along := Vector3(0, 0, t) if edge.x != 0 else Vector3(t, 0, 0)
				m.position = Vector3(cell.x + edge.x * (0.5 - ms / 2.0), h - 0.12 + float(w["merlonHeight"]) / 2.0, cell.y + edge.y * (0.5 - ms / 2.0)) + along
	var t_cfg: Dictionary = _cfg["torches"]
	var pole := BoxMesh.new()
	pole.size = Vector3(0.05, float(t_cfg["height"]), 0.05)
	var flame := BoxMesh.new()
	flame.size = Vector3(0.09, 0.12, 0.09)
	for spot: Array in torch_spots(map, int(t_cfg["every"])):
		var cell: Vector2i = spot[0]
		var side: Vector2i = spot[1]
		var base := Vector3(cell.x + side.x * 0.5, 0.0, cell.y + side.y * 0.5)
		if props != null and t_cfg.has("sprite"):
			var at := base + Vector3(1, 0, 1).normalized() * float(props._cfg["forwardUnits"])
			if props._sprite(String(t_cfg["sprite"]), at) != null:
				torch_points.append(at + Vector3(0, 0.6, 0))
				continue
		var p := MeshUtil.instance(pole, _pole_material, self)
		p.position = base + Vector3(0, float(t_cfg["height"]) / 2.0, 0)
		var f := MeshUtil.instance(flame, _flame_material, self)
		f.position = base + Vector3(0, float(t_cfg["height"]) + 0.05, 0)
		_flames.append(f)
		torch_points.append(f.position)


## Chama tremendo (só a escala; a luz da `SceneLight` pisca junto).
func animate(delta: float) -> void:
	_elapsed += delta
	for i in _flames.size():
		var s := 0.85 + 0.2 * sin(_elapsed * 11.0 + i * 1.7) * sin(_elapsed * 7.0 + i)
		_flames[i].scale = Vector3(1.0, s, 1.0)
