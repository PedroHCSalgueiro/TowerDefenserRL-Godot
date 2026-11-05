extends Node2D
## Cena de teste do mapa 2D (`scenes/teste_mapa_2d.tscn`): um pedaço de 12x12 montado pelos `Map2DBuilders` com os
## assets atuais, em pixel 2x (Camera2D com zoom 2, filtro sem suavizar), Y-Sort entre muralha, peças e heróis, e
## luz 2D (CanvasModulate + PointLight2D). Não muda nada no jogo.
##
## Linha de comando (depois de `--`): `--shot=arquivo.png` salva uma captura depois de 1 s e encerra.

var cfg: Dictionary
var map: SimMap
var assets: Map2DAssets
var _light_tex: Texture2D
## Camada de referência para a posição das casas (todas as camadas usam o mesmo TileSet e a mesma origem).
var _grid: TileMapLayer
var _shot := ""
var _elapsed := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	RenderingServer.set_default_clear_color(Color("#0d0d12"))
	cfg = DataLoader.load_json("scenery2d.json")
	map = SimMap.load_map(cfg["testMap"])
	assets = Map2DAssets.load_from(String(cfg["assets"]))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot = arg.trim_prefix("--shot=")
	_build()


func _layer(name: String, z: int, y_sort: bool) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.name = name
	l.tile_set = assets.tile_set
	l.z_index = z
	l.y_sort_enabled = y_sort
	return l


func _build() -> void:
	var cells := FortressWalls.wall_cells(map)
	var portals := SceneryProps.portal_cells_of(map)
	var kinds := Map2DBuilders.terrain_kinds(map, cfg["terrain"])
	# chão: terreno e caminho embaixo de tudo, depois a saia
	var terrain := _layer("Terreno", -3, false)
	add_child(terrain)
	_grid = terrain
	Map2DBuilders.paint_terrain(terrain, assets, map, kinds, cfg["terrain"])
	var path := _layer("Caminho", -2, false)
	add_child(path)
	Map2DBuilders.paint_path(path, assets, map)
	var soleiras := Map2DBuilders.threshold_tiles(portals)
	for c: Vector2i in soleiras:
		path.set_cell(c, Map2DAssets.SRC_CHAO, assets.tile("chao", soleiras[c]))
	var edge := _layer("Borda", -1, false)
	add_child(edge)
	var edges := Map2DBuilders.edge_tiles(map, cells)
	for c: Vector2i in edges:
		edge.set_cell(c, Map2DAssets.SRC_BORDA, assets.tile("borda", edges[c]))
	# mundo com Y-Sort: muralha, peças e heróis se ordenam pela altura na tela (o pé)
	var world := Node2D.new()
	world.name = "Mundo"
	world.y_sort_enabled = true
	add_child(world)
	var walls := _layer("Muralha", 0, true)
	world.add_child(walls)
	var wt := Map2DBuilders.wall_tiles(map, cells, portals)
	for c: Vector2i in wt:
		walls.set_cell(c, Map2DAssets.SRC_MURALHA, assets.tile("muralha", wt[c]))
	var props := Map2DBuilders.place_props(map, cells, portals, cfg)
	var decor := Map2DBuilders.scatter_decor(map, kinds, props, cfg)
	var lights: Array = []
	for p: Dictionary in props + decor:
		var s := assets.prop(String(p["name"]))
		if s == null:
			continue
		if p["flip"]:
			s.flip_h = true
			s.offset.x = -(s.texture.get_width() + s.offset.x)
		var at: Vector2 = p["at"]
		s.position = Map2DBuilders.cell_point(_grid, at.x, at.y).round()
		world.add_child(s)
		if String(p["light"]) != "":
			lights.append([s.position + Vector2(0, -float(s.texture.get_height()) * 0.7), String(p["light"])])
	for h: Array in cfg["heroes"]:
		var hero := _hero(String(h[0]))
		if hero != null:
			hero.position = Map2DBuilders.cell_point(_grid, float(h[1]), float(h[2])).round()
			world.add_child(hero)
	_add_lights(lights)
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	cam.position = Map2DBuilders.cell_point(_grid, map.width / 2.0 - 0.5, map.height / 2.0 - 0.5).round() + Vector2(0, -40)
	add_child(cam)
	cam.make_current()


func _hero(id: String) -> AnimatedSprite2D:
	var folder := "res://assets/personagens/%s/pixel/" % id
	if not FileAccess.file_exists(folder + "meta.json"):
		return null
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder + "meta.json"))
	var sheet: Texture2D = load(folder + "Idle.png")
	var cell := int(meta["cell"])
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", 8)
	var row := 1
	for f in int(meta["cols"]):
		var a := AtlasTexture.new()
		a.atlas = sheet
		a.region = Rect2(f * cell, row * cell, cell, cell)
		frames.add_frame("default", a)
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames
	s.centered = false
	s.offset = -Vector2(roundf(float(meta["anchor"][0])), roundf(float(meta["anchor"][1])))
	s.play()
	return s


func _add_lights(points: Array) -> void:
	var lc: Dictionary = cfg["lights"]
	var mod := CanvasModulate.new()
	mod.color = Color(String(lc["ambient"]))
	add_child(mod)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	for p: Array in points:
		var c: Dictionary = lc[p[1]]
		var l := PointLight2D.new()
		l.texture = tex
		l.color = Color(String(c["color"]))
		l.energy = float(c["energy"])
		l.texture_scale = float(c["scale"])
		l.position = p[0]
		add_child(l)


func _process(delta: float) -> void:
	if _shot == "":
		return
	_elapsed += delta
	if _elapsed >= 1.0:
		get_viewport().get_texture().get_image().save_png(_shot)
		get_tree().quit()
