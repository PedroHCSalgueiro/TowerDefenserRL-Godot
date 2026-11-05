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
## Rebordo da saia: o mesmo bloco, com o topo na cor do meio-fio.
var _rim_material: ShaderMaterial
var _box: BoxMesh
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
	for key: String in ["leftTint", "rightTint"]:
		var c: Array = w[key]
		_material.set_shader_parameter(key.replace("Tint", "_tint").to_lower(), Vector3(c[0], c[1], c[2]))
	_material.set_shader_parameter("edge_light", float(w["edgeLight"]))
	_material.set_shader_parameter("outline_dark", float(w["outlineDark"]))
	_material.set_shader_parameter("px_along", px_along())
	_material.set_shader_parameter("px_up", px_up())
	var top: Array = w["topColor"]
	_material.set_shader_parameter("top_color", Vector3(top[0], top[1], top[2]))
	_rim_material = _material.duplicate() as ShaderMaterial
	var rim: Array = w["rimColor"]
	_rim_material.set_shader_parameter("top_color", Vector3(rim[0], rim[1], rim[2]))
	var t: Dictionary = _cfg["torches"]
	_flame_material = MeshUtil.flat_material(RenderConfig.color(t["flameColor"]))
	_pole_material = MeshUtil.flat_material(RenderConfig.color(t["poleColor"]))


## Pixels da arte por unidade do mundo ao longo de um lado da casa (casa de 48: 24 por lado).
static func px_along() -> float:
	return GroundTiles.TILE.x / 2.0


## Pixels da arte por unidade do mundo na vertical (na tela, a altura encolhe pelo cosseno da elevação).
static func px_up() -> float:
	return GroundProjection.PX_PER_UNIT * cos(GroundProjection.elevation()) / float(RenderConfig.data()["camera"]["pixelArt"]["viewPxPerArtPx"])


func _unit_box() -> BoxMesh:
	if _box == null:
		_box = BoxMesh.new()
		_box.size = Vector3.ONE
	return _box


static func _open(map: SimMap, cell: Vector2i) -> bool:
	return map.is_inside(cell) and map.is_open(cell)


## Casa baixa de canto: sem vizinha aberta nos 4 lados, só na diagonal.
static func _corner_low(map: SimMap, cells: Dictionary, cell: Vector2i) -> bool:
	if not cells.has(cell) or cells[cell]:
		return false
	for side: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _open(map, cell + side):
			return false
	return true


## Blocos da muralha e da saia ({lo, hi: Vector3, rim: bool}), em unidades do mundo, com o chão em y = 0. Medidas em
## pixels da arte em `walls` (render.json). Só geometria, sem nó: usado pelo `rebuild` e pelos testes.
## - Muralha (casa alta): meia casa de espessura, na metade de dentro (encostada na área aberta); vai do fundo da
##   saia até `heightPx`. Na ponta que encontra a saia da frente, ela avança a largura do rebordo, e a face de fecho
##   vira um paredão só (muralha + saia).
## - Saia (casa baixa): o rebordo, uma faixa de `rimPx` de largura rente ao chão, descendo `skirtPx`. No canto
##   coberto pela ponta da muralha, nada.
## - Ameias: blocos de `merlonLengthPx` x `merlonThicknessPx` x `merlonHeightPx` na beirada de fora do topo, a cada
##   1/`merlonsPerCell` casa, com a primeira encostada na ponta da muralha que dá para a frente.
static func wall_boxes(map: SimMap, cells: Dictionary, w: Dictionary, portals: Dictionary = {}) -> Array:
	var out: Array = []
	var tall_h := float(w["heightPx"]) / px_up()
	var skirt := float(w["skirtPx"]) / px_up()
	var rim := float(w["rimPx"]) / px_along()
	var mer_h := float(w["merlonHeightPx"]) / px_up()
	var mer_t := float(w["merlonThicknessPx"]) / px_along()
	var mer_l := float(w["merlonLengthPx"]) / px_along()
	var step := 1.0 / float(w["merlonsPerCell"])
	# ponta da frente de cada direção (onde fica a primeira ameia)
	var end_z := float(map.height) - 0.5 + rim
	var end_x := float(map.width) - 0.5 + rim
	for cell: Vector2i in cells:
		var cx := float(cell.x)
		var cz := float(cell.y)
		if cells[cell]:
			if portals.has(cell):
				continue
			var ox := _open(map, cell + Vector2i(1, 0))
			var oz := _open(map, cell + Vector2i(0, 1))
			var boxes: Array = []   # [x0, x1, z0, z1, ao longo de z?]
			if ox:
				var z1 := cz + 0.5 + (rim if _corner_low(map, cells, cell + Vector2i(0, 1)) else 0.0)
				boxes.append([cx, cx + 0.5, cz - 0.5, z1, true])
			if oz:
				var x1 := cx + 0.5 + (rim if _corner_low(map, cells, cell + Vector2i(1, 0)) else 0.0)
				boxes.append([cx - 0.5, x1, cz, cz + 0.5, false])
			if not ox and not oz:
				boxes.append([cx, cx + 0.5, cz, cz + 0.5, true])
				boxes.append([cx, cx + 0.5, cz, cz + 0.5, false])
			for k in boxes.size():
				var b: Array = boxes[k]
				if not (not ox and not oz and k == 1):
					out.append({"lo": Vector3(b[0], -skirt, b[2]), "hi": Vector3(b[1], tall_h, b[3]), "rim": false})
				# ameias na beirada de fora (x = cx na parede que corre ao longo de z; z = cz na outra)
				var along_z: bool = b[4]
				var a0: float = b[2] if along_z else b[0]
				var a1: float = b[3] if along_z else b[1]
				var anchor := end_z if along_z else end_x
				var c := anchor - mer_l / 2.0 - ceilf((anchor - mer_l / 2.0 - (a1 - mer_l / 2.0)) / step - 0.0001) * step
				while c - mer_l / 2.0 >= a0 - 0.0001:
					if along_z:
						out.append({"lo": Vector3(cx, tall_h, c - mer_l / 2.0), "hi": Vector3(cx + mer_t, tall_h + mer_h, c + mer_l / 2.0), "rim": false})
					else:
						out.append({"lo": Vector3(c - mer_l / 2.0, tall_h, cz), "hi": Vector3(c + mer_l / 2.0, tall_h + mer_h, cz + mer_t), "rim": false})
					c -= step
		else:
			var open_mz := _open(map, cell + Vector2i(0, -1))
			var open_mx := _open(map, cell + Vector2i(-1, 0))
			if open_mz:
				out.append({"lo": Vector3(cx - 0.5, -skirt, cz - 0.5), "hi": Vector3(cx + 0.5, 0.0, cz - 0.5 + rim), "rim": true})
			if open_mx:
				out.append({"lo": Vector3(cx - 0.5, -skirt, cz - 0.5), "hi": Vector3(cx - 0.5 + rim, 0.0, cz + 0.5), "rim": true})
			if not open_mz and not open_mx:
				# canto: coberto pela ponta da muralha, ou um quadradinho de rebordo
				var covered: bool = (cells.get(cell + Vector2i(0, -1), false) and _open(map, cell + Vector2i(1, -1))) 						or (cells.get(cell + Vector2i(-1, 0), false) and _open(map, cell + Vector2i(-1, 1)))
				if not covered:
					out.append({"lo": Vector3(cx - 0.5, -skirt, cz - 0.5), "hi": Vector3(cx - 0.5 + rim, 0.0, cz - 0.5 + rim), "rim": true})
	return out


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
	var cells := wall_cells(map)
	if props != null:
		props.rebuild(map, cells)
	for b: Dictionary in wall_boxes(map, cells, w, props.portal_cells if props != null else {}):
		var mi := MeshUtil.instance(_unit_box(), _rim_material if b["rim"] else _material, self)
		var lo: Vector3 = b["lo"]
		var hi: Vector3 = b["hi"]
		mi.scale = hi - lo
		mi.position = (lo + hi) / 2.0
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
