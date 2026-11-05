extends GutTest
## Cenário do conjunto (`grid.scenery`): tipo de cada casa no chão, muralha em volta da área aberta (alta atrás,
## baixa na frente) e tochas na beira do caminho. Só desenho: nada aqui muda casa nenhuma.


func _map() -> SimMap:
	var path: Array[Vector2i] = []
	for x in range(1, 5):
		path.append(Vector2i(x, 2))
	var map := SimMap.new("teste", 6, 5, path)
	return map


func test_tipo_das_casas() -> void:
	var map := _map()
	var entradas := {map.entrance: true}
	assert_eq(SceneryGround.kind_of(map, Vector2i(1, 2), entradas), SceneryGround.KIND_ENTRANCE)
	assert_eq(SceneryGround.kind_of(map, Vector2i(2, 2), entradas), SceneryGround.KIND_PATH)
	assert_eq(SceneryGround.kind_of(map, map.nexus, entradas), SceneryGround.KIND_NEXUS)
	assert_eq(SceneryGround.kind_of(map, Vector2i(2, 3), entradas), SceneryGround.KIND_FREE)


func test_muralha_cerca_a_area_aberta() -> void:
	var map := _map()
	var muros := FortressWalls.wall_cells(map)
	for cell: Vector2i in muros:
		assert_false(map.is_inside(cell) and map.is_open(cell), "muralha só em casa fechada ou fora do mapa: %s" % cell)
	# o mapa inteiro está aberto: a muralha é o anel em volta, com 2*(6+5)+4 casas
	assert_eq(muros.size(), 26)
	assert_true(muros[Vector2i(-1, -1)], "o canto de trás é alto")
	assert_true(muros[Vector2i(2, -1)], "o lado de trás é alto")
	assert_false(muros[Vector2i(2, 5)], "o lado da frente é baixo, para não esconder o jogo")
	assert_false(muros[Vector2i(6, 5)], "o canto da frente é baixo")


func test_tochas_ficam_ao_lado_do_caminho() -> void:
	var map := _map()
	var spots := FortressWalls.torch_spots(map, 2)
	assert_gt(spots.size(), 0)
	for spot: Array in spots:
		var cell: Vector2i = spot[0]
		var side: Vector2i = spot[1]
		assert_true(map.is_path(cell))
		assert_false(map.is_path(cell + side), "a tocha fica do lado livre")


func test_medidas_em_pixels_da_arte() -> void:
	# 1 pixel da arte = 2 pixels da tela no zoom 1 (pixel 2x)
	var tela_por_unidade_vertical := GroundProjection.PX_PER_UNIT * cos(GroundProjection.elevation())
	assert_almost_eq(40.0 / FortressWalls.px_up() * tela_por_unidade_vertical, 80.0, 0.01, "muralha de 40 px da arte = 80 px na tela")
	assert_almost_eq(12.0 / FortressWalls.px_up() * tela_por_unidade_vertical, 24.0, 0.01, "saia de 12 px da arte = 24 px na tela")
	# ao longo de um lado da casa, 24 px da arte na horizontal (meia largura do losango de 48)
	var meio_lado := GroundProjection.view_px(1, 0).x
	assert_almost_eq(meio_lado, FortressWalls.px_along() * 2.0, 0.01, "um lado da casa anda 24 px da arte (48 na tela) na horizontal")
