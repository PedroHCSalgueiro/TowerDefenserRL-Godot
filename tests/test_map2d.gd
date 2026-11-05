extends GutTest
## Mapa 2D de teste (`Map2DBuilders`): as peças e a decoração nunca ficam no caminho nem fora do mapa, todo tile pedido
## existe no atlas, e a montagem é a mesma em toda execução (sem sorteio solto).

var cfg: Dictionary
var map: SimMap
var assets: Map2DAssets


func before_all() -> void:
	cfg = DataLoader.load_json("scenery2d.json")
	map = SimMap.load_map(cfg["testMap"])
	assets = Map2DAssets.load_from(String(cfg["assets"]))


func _cell(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x + 0.5), floori(at.y + 0.5))


func test_tiles_pedidos_existem() -> void:
	var cells := FortressWalls.wall_cells(map)
	var portals := SceneryProps.portal_cells_of(map)
	for name: String in Map2DBuilders.wall_tiles(map, cells, portals).values():
		assert_true(assets.has_tile("muralha", name), name)
	for name: String in Map2DBuilders.edge_tiles(map, cells).values():
		assert_true(assets.has_tile("borda", name), name)


func test_pecas_fora_do_caminho() -> void:
	var cells := FortressWalls.wall_cells(map)
	var portals := SceneryProps.portal_cells_of(map)
	var props := Map2DBuilders.place_props(map, cells, portals, cfg)
	var decor := Map2DBuilders.scatter_decor(map, Map2DBuilders.terrain_kinds(map, cfg["terrain"]), props, cfg)
	assert_gt(props.size(), 5)
	for p: Dictionary in props + decor:
		var c := _cell(p["at"])
		if p["name"] in ["portal", "torre"]:
			continue
		assert_false(map.is_inside(c) and map.is_path(c) and not (p["name"] in ["tocha", "braseiro", "cristal_nucleo"]),
				"%s em cima do caminho (%s)" % [p["name"], c])
		assert_true(assets.meta["pecas"].has(p["name"]), "peça existe: %s" % p["name"])


func test_montagem_e_sempre_igual() -> void:
	var cells := FortressWalls.wall_cells(map)
	var portals := SceneryProps.portal_cells_of(map)
	var a := Map2DBuilders.place_props(map, cells, portals, cfg)
	var b := Map2DBuilders.place_props(map, cells, portals, cfg)
	assert_eq(str(a), str(b))



func test_posicao_das_pecas_bate_com_as_casas_do_tilemap() -> void:
	var l := TileMapLayer.new()
	l.tile_set = assets.tile_set
	add_child_autofree(l)
	# casa inteira: exatamente o centro que o TileMap usa para desenhar o losango
	for c: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(3, 5), Vector2i(-1, 0), Vector2i(10, 11)]:
		assert_eq(Map2DBuilders.cell_point(l, c.x, c.y), l.map_to_local(c), "centro da casa %s" % c)
	# fração: a mesma direção e escala do losango (meia casa em x anda 12 px para a direita e 6 para baixo)
	assert_eq(Map2DBuilders.cell_point(l, 2.5, 3.0) - l.map_to_local(Vector2i(2, 3)), Vector2(12, 6))
	assert_almost_eq(Map2DBuilders.cell_point(l, 4.0, 1.7) - l.map_to_local(Vector2i(4, 2)), Map2DBuilders.iso(0.0, -0.3), Vector2(0.001, 0.001))
	# a casa vizinha está a uma casa de distância (o iso é só o vetor, não a posição)
	assert_eq(l.map_to_local(Vector2i(1, 0)) - l.map_to_local(Vector2i(0, 0)), Map2DBuilders.iso(1, 0))
