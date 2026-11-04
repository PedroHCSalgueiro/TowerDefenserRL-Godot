extends GutTest
## Pixel 2x: câmera 2:1 (a casa vira o losango de 96x48 no zoom 1), zoom em passos inteiros, vista acertada na grade
## de pixels da arte e o chão em pixel do bioma.

const VIEWPORT := Vector2(1280, 720)
const BOUNDS := Rect2(-200, 0, 400, 200)


func _model(bounds: Rect2 = BOUNDS) -> CameraModel:
	var config := {
		"zoom": {"min": 0.75, "default": 1, "max": 3, "wheelStep": 1.2, "wheelNotchPx": 100,
				"wheelLinesPerNotch": 3, "smoothMs": 120},
		"resetMs": 200,
		"marginPx": 180,
		"uiInsetsPx": {},
	}
	var model := CameraModel.new(config, VIEWPORT, bounds)
	model.set_zoom_step(0.5, 10)
	return model


func test_a_casa_vira_o_losango_2_por_1() -> void:
	assert_almost_eq(GroundProjection.view_px(1, 0), Vector2(48, 24), Vector2(0.001, 0.001), "x anda para baixo e à direita")
	assert_almost_eq(GroundProjection.view_px(0, 1), Vector2(-48, 24), Vector2(0.001, 0.001), "z anda para baixo e à esquerda")


func test_o_zoom_para_so_em_passos_inteiros() -> void:
	var model := _model()
	assert_eq(model.view().zoom, 1.0, "o padrão é o pixel 2x quando o mapa cabe")
	model.wheel(-1.0, VIEWPORT / 2.0)
	assert_eq(model.view().zoom, 1.5, "um dente aproxima um passo, na hora")
	model.wheel(1.0, VIEWPORT / 2.0)
	model.wheel(1.0, VIEWPORT / 2.0)
	assert_eq(model.view().zoom, 0.5, "afastar para no menor passo")
	model.wheel(1.0, VIEWPORT / 2.0)
	assert_eq(model.view().zoom, 0.5, "nunca abaixo de um pixel da arte por pixel da tela")
	for i in 10:
		model.wheel(-1.0, VIEWPORT / 2.0)
	assert_eq(model.view().zoom, 3.0, "o máximo do render.json já é um passo inteiro")


func test_janela_de_tamanho_quebrado_abre_no_passo_mais_perto_do_padrao() -> void:
	var model := _model()
	# janela de 1886x1061 (o Windows desconta a barra de tarefas): 1,4734 pixel da tela por pixel lógico
	var step := 1.0 / (2.0 * 1.4734)
	model.set_zoom_step(step, 10)
	model.reset()
	model.update(1000.0)
	assert_almost_eq(model.view().zoom, 3.0 * step, 0.0001, "o padrão é o 3x (zoom 1,018), não o 2x de 0,679")


func test_mapa_grande_desce_ate_o_passo_que_cabe() -> void:
	var model := _model(Rect2(-1000, 0, 2000, 1000))
	assert_eq(model.view().zoom, 0.5, "o mapa não cabe no 2x: o padrão desce um passo inteiro, não para 0,64")


func test_mapa_maior_que_a_tela_vira_vista_geral() -> void:
	var bounds := Rect2(-2000, 0, 4000, 2000)
	var model := _model(bounds)
	var fit := CameraModel.fit_zoom(bounds, VIEWPORT)
	assert_almost_eq(model.view().zoom, fit, 0.0001, "nem com um pixel da arte por pixel da tela ele cabe: zoom livre")
	model.wheel(-1.0, VIEWPORT / 2.0)
	assert_eq(model.view().zoom, 0.5, "o primeiro dente leva ao primeiro passo inteiro")
	model.wheel(1.0, VIEWPORT / 2.0)
	assert_almost_eq(model.view().zoom, fit, 0.0001, "e afastar volta para a vista geral")


func test_a_vista_cai_na_grade_de_pixels_da_arte() -> void:
	var view := CameraModel.View.new(1.0, Vector2(13.7, -5.2))
	var snapped := CameraModel.snap_center(view, VIEWPORT, 2.0)
	# no zoom 1 o pixel da arte tem 2 pixels de tela: um ponto inteiro da arte cai em pixel de tela par
	for art in [Vector2(0, 0), Vector2(16, 8), Vector2(-48, 24)]:
		var screen := CameraModel.world_to_screen_in(snapped, VIEWPORT, art * 2.0)
		assert_almost_eq(fposmod(screen.x, 2.0), 0.0, 0.0001, "x de %s" % art)
		assert_almost_eq(fposmod(screen.y, 2.0), 0.0, 0.0001, "y de %s" % art)
	assert_true(snapped.center.distance_to(view.center) <= 2.0, "acertar a vista anda menos de um pixel da arte")


func test_o_chao_marca_as_casas_abertas() -> void:
	var map := SimMap.load_map(DataLoader.load_json("map.json"))
	var ground := GroundTiles.create(RenderConfig.data()["grid"])
	assert_not_null(ground, "as imagens do chão estão no jogo")
	ground.update(map, {})
	var image: Image = ground._cells_image
	for cell: Vector2i in [map.nexus, Vector2i(0, 0)]:
		var index := roundi(image.get_pixel(cell.x, cell.y).r * 255.0)
		assert_eq(index > 0, map.is_open(cell), "casa %s" % cell)


func test_a_imagem_da_casa_e_fixa_pela_posicao() -> void:
	var list: Array[int] = [0, 1, 2, 3, 4]
	var seen := {}
	for y in 12:
		for x in 12:
			assert_eq(GroundTiles._pick(list, x, y), GroundTiles._pick(list, x, y))
			seen[GroundTiles._pick(list, x, y)] = true
	assert_eq(seen.size(), list.size(), "todas as imagens aparecem num mapa de 12x12")
