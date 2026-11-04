class_name GroundTiles
extends RefCounted
## O chão em pixel do mapa (`grid.ground` em render.json): as casas de 48x24 do bioma (geradas por
## `Arte/ferramentas/gerar_biomas.py`, cópias na pasta `folder`) num atlas de uma linha, e uma textura com a imagem de
## cada casa do mapa, que o `ground_tiles.gdshader` desenha pixel a pixel por cima das lajes do `GridView`.
##
## A imagem de cada casa sai de um sorteio fixo pela posição (hash da casa, não o RNG da simulação): o chão não muda
## quando uma sala abre. Casa livre usa as imagens de `free`, caminho as de `path` (o número é o peso de cada uma);
## entrada e núcleo usam a primeira do caminho tingida com `entranceColor` e `nexusColor`.

const SHADER := preload("res://render/ground_tiles.gdshader")
const TILE := Vector2i(48, 24)

var material: ShaderMaterial
var _free: Array[int] = []
var _path: Array[int] = []
var _entrance := -1
var _nexus := -1
var _cells_image: Image
var _cells_texture: ImageTexture


## O chão do conjunto atual; null sem `grid.ground` ou se faltar alguma imagem (o mapa fica com as lajes coloridas).
static func create(grid_cfg: Dictionary) -> GroundTiles:
	var cfg: Dictionary = grid_cfg.get("ground", {})
	if cfg.is_empty():
		return null
	var ground := GroundTiles.new()
	return ground if ground._build(cfg, grid_cfg) else null


func _build(cfg: Dictionary, grid_cfg: Dictionary) -> bool:
	var folder := String(cfg["folder"])
	var names: Array[String] = []
	for group: String in ["free", "path"]:
		for name: String in cfg[group]:
			if not names.has(name):
				names.append(name)
	var images: Array[Image] = []
	for name in names:
		var path := folder + name + ".png"
		if not ResourceLoader.exists(path):
			push_warning("chão: imagem ausente %s" % path)
			return false
		var image := (load(path) as Texture2D).get_image()
		image.convert(Image.FORMAT_RGBA8)
		if image.get_size() != TILE:
			push_warning("chão: %s não tem %dx%d" % [path, TILE.x, TILE.y])
			return false
		images.append(image)
	for group: String in ["free", "path"]:
		var list: Array[int] = _free if group == "free" else _path
		for name: String in cfg[group]:
			for i in int(cfg[group][name]):
				list.append(names.find(name))
	var base: Image = images[_path[0]]
	var amount := float(cfg["tintAmount"])
	_entrance = images.size()
	images.append(_tinted(base, RenderConfig.color(grid_cfg["entranceColor"]), amount))
	_nexus = images.size()
	images.append(_tinted(base, RenderConfig.color(grid_cfg["nexusColor"]), amount))
	var atlas := Image.create_empty(TILE.x * images.size(), TILE.y, false, Image.FORMAT_RGBA8)
	for i in images.size():
		atlas.blit_rect(images[i], Rect2i(Vector2i.ZERO, TILE), Vector2i(i * TILE.x, 0))
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("atlas", ImageTexture.create_from_image(atlas))
	material.set_shader_parameter("grid_shade", float(cfg["gridShade"]))
	material.set_shader_parameter("tile", TILE)
	material.set_shader_parameter("grid_radius", float(cfg["gridRadius"]))
	set_cursor(null)
	return true


static func _tinted(image: Image, tint: Color, amount: float) -> Image:
	var out := image.duplicate() as Image
	for y in out.get_height():
		for x in out.get_width():
			var c := out.get_pixel(x, y)
			if c.a > 0.0:
				var mixed := Color(c.r * tint.r, c.g * tint.g, c.b * tint.b).lerp(tint, 0.25)
				out.set_pixel(x, y, Color(c.lerp(mixed, amount), c.a))
	return out


## A grade só aparece em volta do mouse (`gridRadius` casas, sumindo para fora); null = mouse fora do mapa.
func set_cursor(ground: Variant) -> void:
	material.set_shader_parameter("cursor", ground if ground != null else Vector2(-1000, -1000))


## Refaz a imagem de cada casa: aberta ganha chão, fechada fica sem (o fundo escuro aparece).
func update(map: SimMap, entrances: Dictionary) -> void:
	if _cells_image == null or _cells_image.get_size() != Vector2i(map.width, map.height):
		_cells_image = Image.create_empty(map.width, map.height, false, Image.FORMAT_R8)
		_cells_texture = ImageTexture.create_from_image(_cells_image)
		material.set_shader_parameter("cells", _cells_texture)
		material.set_shader_parameter("map_size", Vector2(map.width, map.height))
	for y in map.height:
		for x in map.width:
			var cell := Vector2i(x, y)
			var index := -1
			if map.is_open(cell):
				if entrances.has(cell):
					index = _entrance
				elif cell == map.nexus:
					index = _nexus
				elif map.is_path(cell):
					index = _pick(_path, x, y)
				else:
					index = _pick(_free, x, y)
			_cells_image.set_pixel(x, y, Color((index + 1) / 255.0, 0, 0))
	_cells_texture.update(_cells_image)


## Imagem fixa da casa: hash inteiro da posição (o mesmo em toda run e em toda máquina).
static func _pick(list: Array[int], x: int, y: int) -> int:
	var h := (x * 374761393 + y * 668265263) & 0xffffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0xffffffff
	h ^= h >> 16
	return list[h % list.size()]
