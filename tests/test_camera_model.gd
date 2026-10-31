extends GutTest
## Enquadramento da câmera: o mapa inteiro cabe no meio livre da tela, sem passar por baixo da interface.

const VIEWPORT := Vector2(1280, 720)
const BOUNDS := Rect2(-1000, 200, 2400, 1200)
const EPS := 0.01


func _config(insets: Dictionary) -> Dictionary:
	return {
		"zoom": {"min": 0.75, "default": 1, "max": 3, "wheelStep": 1.2, "wheelNotchPx": 100,
				"wheelLinesPerNotch": 3, "smoothMs": 120},
		"resetMs": 200,
		"marginPx": 180,
		"uiInsetsPx": insets,
	}


## O retângulo do mapa na tela, na vista atual.
func _on_screen(model: CameraModel, bounds: Rect2) -> Rect2:
	var start := model.world_to_screen(bounds.position)
	return Rect2(start, model.world_to_screen(bounds.end) - start)


func _assert_inside(map: Rect2, free: Rect2) -> void:
	assert_true(map.position.x >= free.position.x - EPS and map.position.y >= free.position.y - EPS
			and map.end.x <= free.end.x + EPS and map.end.y <= free.end.y + EPS,
			"mapa %s dentro do meio livre %s" % [map, free])


func test_sem_faixas_o_mapa_fica_no_centro_da_tela() -> void:
	var model := CameraModel.new(_config({}), VIEWPORT, BOUNDS)
	var map := _on_screen(model, BOUNDS)
	assert_almost_eq(map.get_center().x, VIEWPORT.x / 2.0, EPS)
	assert_almost_eq(map.get_center().y, VIEWPORT.y / 2.0, EPS)


func test_vista_padrao_cabe_e_centraliza_no_meio_livre() -> void:
	var insets := {"top": 66.0, "bottom": 230.0, "left": 256.0, "right": 206.0}
	var model := CameraModel.new(_config(insets), VIEWPORT, BOUNDS)
	var map := _on_screen(model, BOUNDS)
	var free := Rect2(256, 66, 818, 424)
	_assert_inside(map, free)
	assert_almost_eq(map.get_center().x, free.get_center().x, EPS)
	assert_almost_eq(map.get_center().y, free.get_center().y, EPS)


func test_mapa_pequeno_tambem_fica_acima_da_loja() -> void:
	var small := Rect2(0, 0, 300, 150)
	var model := CameraModel.new(_config({"top": 44.0, "bottom": 230.0}), VIEWPORT, small)
	assert_eq(model.view().zoom, 1.0, "no zoom padrão: o mapa cabe sem afastar")
	_assert_inside(_on_screen(model, small), Rect2(0, 44, 1280, 446))


func test_trocar_as_faixas_e_voltar_ao_padrao_reenquadra() -> void:
	var model := CameraModel.new(_config({"top": 44.0, "bottom": 230.0}), VIEWPORT, BOUNDS)
	model.set_insets({"top": 66.0, "bottom": 230.0, "left": 256.0, "right": 206.0})
	model.reset()
	model.update(1000.0)
	_assert_inside(_on_screen(model, BOUNDS), Rect2(256, 66, 818, 424))
	model.set_insets({"top": 44.0, "bottom": 230.0})
	model.reset()
	model.update(1000.0)
	_assert_inside(_on_screen(model, BOUNDS), Rect2(0, 44, 1280, 446))
