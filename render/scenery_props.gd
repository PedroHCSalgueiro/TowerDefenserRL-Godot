class_name SceneryProps
extends Node3D
## Peças do cenário (`grid.scenery.props` em render.json): sprites em pixel (um texel = um pixel da arte) espalhados
## por regra, refeitos quando o mapa cresce. Só desenho: nenhuma casa muda.
##
## - Pé da muralha alta: barris, caixas, tochas, obeliscos, árvores... encostados na parede, por sorteio fixo da casa.
## - Canto de trás da muralha: a torre. Entrada: o portal no lugar da parede.
## - Casas livres: miudezas (ossos, pedras, cogumelos, capim) com pouca chance, para não poluir a área de construir.
## - Núcleo: o cristal (o cilindro do `NexusView` some).

var _cfg: Dictionary
var _folder := ""
var _textures := {}
var _revision := -1
var _pixel := 1.0
## Pontos (mundo) das peças que acendem (tocha, braseiro...), para a `SceneLight`.
var light_points: Array[Vector3] = []
## Casa do portal de cada entrada (a parede não é desenhada ali).
var portal_cells := {}


static func create(grid_cfg: Dictionary) -> SceneryProps:
	var cfg: Dictionary = grid_cfg.get("scenery", {}).get("props", {})
	if cfg.is_empty():
		return null
	var props := SceneryProps.new()
	props._cfg = cfg
	props._folder = String(cfg["folder"])
	props._pixel = float(RenderConfig.data()["camera"]["pixelArt"]["viewPxPerArtPx"]) / GroundProjection.PX_PER_UNIT
	return props


## Casa fora da área aberta por onde cada entrada chega (o lado oposto ao caminho).
static func portal_cells_of(map: SimMap) -> Dictionary:
	var out := {}
	for i in map.entrance_count():
		var path := map.entrance_path(i)
		if path.size() < 2:
			continue
		var outward: Vector2i = path[0] - path[1]
		out[path[0] + outward] = outward
	return out


static func pick(weights: Dictionary, h: int) -> String:
	var total := 0
	for k: String in weights:
		total += int(weights[k])
	var r := h % maxi(total, 1)
	for k: String in weights:
		r -= int(weights[k])
		if r < 0:
			return k
	return ""


## Sorteio fixo pela casa (o mesmo em toda run, como o `GroundTiles`).
static func cell_hash(cell: Vector2i, salt: int) -> int:
	var h := (cell.x * 374761393 + cell.y * 668265263 + salt * 2246822519) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return h ^ (h >> 16)


func _texture(name: String) -> Texture2D:
	if not _textures.has(name):
		var path := _folder + name + ".png"
		_textures[name] = load(path) if ResourceLoader.exists(path) else null
	return _textures[name]


func _sprite(name: String, at: Vector3) -> Sprite3D:
	var tex := _texture(name)
	if tex == null:
		return null
	var s := Sprite3D.new()
	s.texture = tex
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	s.double_sided = true
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.pixel_size = _pixel
	# a base da imagem fica no ponto (os pés), num canto de pixel
	s.offset = Vector2(0, roundf(tex.get_height() * 0.5))
	s.position = at
	add_child(s)
	return s


func rebuild(map: SimMap, walls: Dictionary) -> void:
	if map.revision == _revision:
		return
	_revision = map.revision
	for child in get_children():
		remove_child(child)
		child.queue_free()
	light_points.clear()
	portal_cells = portal_cells_of(map)
	var lights: Array = _cfg["lights"]
	var forward := float(_cfg["forwardUnits"])
	var cam_dir := Vector3(1, 0, 1).normalized() * forward
	# portal
	for cell: Vector2i in portal_cells:
		var out: Vector2i = portal_cells[cell]
		var at := Vector3(cell.x - out.x * 0.45, 0.0, cell.y - out.y * 0.45) + cam_dir * 0.4
		var portal := _sprite(String(_cfg["portal"]), at)
		# a imagem do arco segue a parede que corre ao longo de x (desce para a direita na tela); na parede que corre
		# ao longo de z (desce para a esquerda), ela é espelhada
		if portal != null:
			portal.flip_h = out.x != 0
	# pé da muralha alta e cantos
	for cell: Vector2i in walls:
		if not walls[cell] or portal_cells.has(cell):
			continue
		var sides: Array[Vector2i] = []
		for side: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var n := cell + side
			if map.is_inside(n) and map.is_open(n):
				sides.append(side)
		if sides.is_empty():
			var diag := cell + Vector2i(1, 1)
			if map.is_inside(diag) and map.is_open(diag):
				_sprite(String(_cfg["corner"]), Vector3(cell.x + 0.3, 0.0, cell.y + 0.3) + cam_dir)
			continue
		var h := cell_hash(cell, 1)
		if float(h % 1000) / 1000.0 >= float(_cfg["wallChance"]):
			continue
		var name := pick(_cfg["wallFoot"], cell_hash(cell, 2))
		var side: Vector2i = sides[0]
		var at := Vector3(cell.x + side.x * 0.62, 0.0, cell.y + side.y * 0.62) + cam_dir
		if _sprite(name, at) != null and lights.has(name):
			light_points.append(at + Vector3(0, 0.6, 0))
	# miudezas nas casas livres
	for y in map.height:
		for x in map.width:
			var cell := Vector2i(x, y)
			if not map.can_place_tower(cell):
				continue
			var h := cell_hash(cell, 3)
			if float(h % 1000) / 1000.0 >= float(_cfg["groundChance"]):
				continue
			var name := pick(_cfg["ground"], cell_hash(cell, 4))
			var ox := float(cell_hash(cell, 5) % 100) / 100.0 * 0.6 - 0.3
			var oz := float(cell_hash(cell, 6) % 100) / 100.0 * 0.6 - 0.3
			_sprite(name, Vector3(x + ox, 0.0, y + oz) + cam_dir * 0.5)
	# núcleo
	_sprite(String(_cfg["nexus"]), Vector3(map.nexus.x, 0.0, map.nexus.y) + cam_dir)
