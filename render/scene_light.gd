class_name SceneLight
extends CanvasLayer
## Luz por cima do cenário (`grid.scenery.light` em render.json): uma camada que multiplica a imagem do 3D, abaixo da
## interface e dos textos dos efeitos. Ambiente frio, cantos escuros e luz em volta das tochas, das entradas e do
## núcleo, que acompanha a câmera a cada quadro. Ver docs/direcao-visual-cenario.md (regra 6).

const SHADER := preload("res://render/scene_light.gdshader")
const MAX_LIGHTS := 48

var _rect: ColorRect
var _mat: ShaderMaterial
var _cfg: Dictionary
var _camera: Camera3D
var _map: SimMap
var _walls: FortressWalls
var _elapsed := 0.0


static func create(grid_cfg: Dictionary) -> SceneLight:
	var cfg: Dictionary = grid_cfg.get("scenery", {})
	if cfg.is_empty():
		return null
	var light := SceneLight.new()
	light._cfg = cfg["light"]
	return light


func setup(camera: Camera3D, map: SimMap, walls: FortressWalls) -> void:
	_camera = camera
	_map = map
	_walls = walls
	layer = -2
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("ambient", SceneryGround._vec(_cfg["ambient"]))
	_mat.set_shader_parameter("vignette", float(_cfg["vignette"]))
	_rect.material = _mat
	add_child(_rect)


func _process(delta: float) -> void:
	_elapsed += delta
	if _camera == null:
		return
	var lights := PackedVector4Array()
	var colors := PackedVector4Array()
	var t: Dictionary = _cfg["torch"]
	if _walls != null:
		var points: Array[Vector3] = _walls.torch_points.duplicate()
		if _walls.props != null:
			points.append_array(_walls.props.light_points)
		for i in points.size():
			var flicker := 1.0 + float(t["flicker"]) * sin(_elapsed * 9.0 + i * 2.3) * sin(_elapsed * 5.3 + i)
			_add(lights, colors, points[i], t, flicker)
	for i in _map.entrance_count():
		_add(lights, colors, Vector3(_map.entrance_cell(i).x, 0.4, _map.entrance_cell(i).y), _cfg["entrance"], 1.0)
	_add(lights, colors, Vector3(_map.nexus.x, 0.5, _map.nexus.y), _cfg["nexus"], 1.0 + 0.06 * sin(_elapsed * 2.0))
	var n := mini(lights.size(), MAX_LIGHTS)
	lights.resize(MAX_LIGHTS)
	colors.resize(MAX_LIGHTS)
	_mat.set_shader_parameter("lights", lights)
	_mat.set_shader_parameter("colors", colors)
	_mat.set_shader_parameter("count", n)
	_mat.set_shader_parameter("view_size", get_viewport().get_visible_rect().size)


## Uma fonte: posição e raio (em casas) projetados na tela.
func _add(lights: PackedVector4Array, colors: PackedVector4Array, point: Vector3, cfg: Dictionary, k: float) -> void:
	if lights.size() >= MAX_LIGHTS or _camera.is_position_behind(point):
		return
	var p := _camera.unproject_position(point)
	var r := float(cfg["radius"])
	var px := _camera.unproject_position(point + Vector3(r, 0, -r) * 0.7071).distance_to(p)
	var c := RenderConfig.color(cfg["color"])
	lights.append(Vector4(p.x, p.y, px, px * 0.6))
	colors.append(Vector4(c.r, c.g, c.b, float(cfg["strength"]) * k))
