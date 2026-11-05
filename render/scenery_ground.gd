class_name SceneryGround
extends RefCounted
## Chão do cenário de um conjunto (`grid.scenery` em render.json): pátio de lajes em manchas e caminho de pedra
## clara com borda orgânica e brilho saindo das entradas (`scenery_ground.gdshader`). Tem a mesma cara do
## `GroundTiles` para o `GridView` (`material`, `update`, `set_cursor`). Ver docs/direcao-visual-cenario.md.

const SHADER := preload("res://render/scenery_ground.gdshader")
const KIND_CLOSED := 0
const KIND_FREE := 1
const KIND_PATH := 2
const KIND_ENTRANCE := 3
const KIND_NEXUS := 4

var material: ShaderMaterial
var _decay := 5.0
var _cells_image: Image
var _cells_texture: ImageTexture
var _glow_image: Image
var _glow_texture: ImageTexture


## O chão do conjunto atual; null sem `grid.scenery`.
static func create(grid_cfg: Dictionary) -> SceneryGround:
	var cfg: Dictionary = grid_cfg.get("scenery", {})
	if cfg.is_empty():
		return null
	var ground := SceneryGround.new()
	ground._build(cfg)
	return ground


func _build(cfg: Dictionary) -> void:
	var g: Dictionary = cfg["ground"]
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("tile", GroundTiles.TILE)
	material.set_shader_parameter("floor_ramp", _ramp(g["floorRamp"]))
	material.set_shader_parameter("path_ramp", _ramp(g["pathRamp"]))
	material.set_shader_parameter("dirt_ramp", _ramp(g["dirtRamp"]))
	material.set_shader_parameter("grass_ramp", _ramp(g["grassRamp"]))
	material.set_shader_parameter("slab_share", float(g["slabShare"]))
	material.set_shader_parameter("grass_share", float(g["grassShare"]))
	material.set_shader_parameter("glow_color", _vec(g["glowColor"]))
	material.set_shader_parameter("glow_strength", float(g["glowStrength"]))
	material.set_shader_parameter("warp", float(g["warp"]))
	material.set_shader_parameter("slab", float(g["slab"]))
	material.set_shader_parameter("joint_dark", float(g["jointDark"]))
	material.set_shader_parameter("moss_amount", float(g["mossAmount"]))
	material.set_shader_parameter("moss_color", _vec(g["mossColor"]))
	material.set_shader_parameter("rim_dark", float(g["rimDark"]))
	material.set_shader_parameter("grid_shade", float(g["gridShade"]))
	material.set_shader_parameter("grid_radius", float(g["gridRadius"]))
	_decay = float(g["glowDecayCells"])
	set_cursor(null)


static func _vec(hex: String) -> Vector3:
	var c := RenderConfig.color(hex)
	return Vector3(c.r, c.g, c.b)


static func _ramp(list: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for hex: String in list:
		out.append(_vec(hex))
	return out


func set_cursor(ground: Variant) -> void:
	material.set_shader_parameter("cursor", ground if ground != null else Vector2(-1000, -1000))


## Tipo de cada casa e brilho do caminho (1 na entrada, caindo `glowDecayCells` casas a cada 1/e).
func update(map: SimMap, entrances: Dictionary) -> void:
	var size := Vector2i(map.width, map.height)
	if _cells_image == null or _cells_image.get_size() != size:
		_cells_image = Image.create_empty(map.width, map.height, false, Image.FORMAT_R8)
		_cells_texture = ImageTexture.create_from_image(_cells_image)
		_glow_image = Image.create_empty(map.width, map.height, false, Image.FORMAT_R8)
		_glow_texture = ImageTexture.create_from_image(_glow_image)
		material.set_shader_parameter("cells", _cells_texture)
		material.set_shader_parameter("glow", _glow_texture)
		material.set_shader_parameter("map_size", Vector2(size))
	_glow_image.fill(Color(0, 0, 0))
	for y in map.height:
		for x in map.width:
			var cell := Vector2i(x, y)
			_cells_image.set_pixel(x, y, Color(kind_of(map, cell, entrances) / 255.0, 0, 0))
	for i in map.entrance_count():
		var path := map.entrance_path(i)
		for k in path.size():
			var cell: Vector2i = path[k]
			if not map.is_open(cell):
				continue
			var value := exp(-float(k) / _decay)
			if value > _glow_image.get_pixelv(cell).r:
				_glow_image.set_pixelv(cell, Color(value, 0, 0))
	_cells_texture.update(_cells_image)
	_glow_texture.update(_glow_image)


static func kind_of(map: SimMap, cell: Vector2i, entrances: Dictionary) -> int:
	if not map.is_open(cell):
		return KIND_CLOSED
	if entrances.has(cell):
		return KIND_ENTRANCE
	if cell == map.nexus:
		return KIND_NEXUS
	if map.is_path(cell):
		return KIND_PATH
	return KIND_FREE
