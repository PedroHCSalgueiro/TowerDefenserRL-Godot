extends GutTest
## Porte de tests/route.test.ts + paridade bit a bit com o Phaser (tests/golden/enemies.json).

var _routes: Dictionary
var _small: SimMap


func before_all() -> void:
	_small = EnemySim.small_map()
	_routes = Route.build_routes(_small)


func _at(route: Route, distance: float) -> Vector2:
	# Vector2 só para comparar no teste (valores exatos em float32 aqui).
	var p := MutablePoint.new(NAN, NAN)
	route.sample_into(distance, p)
	return Vector2(p.x, p.y)


func test_rota_terrestre_passa_pelo_centro_de_todas_as_casas() -> void:
	var ground: Route = _routes["ground"]
	assert_eq(ground.length, 7.0)
	for i in _small.path_cells.size():
		assert_eq(_at(ground, float(i)), Vector2(_small.path_cells[i]))


func test_comeca_na_entrada_e_termina_no_nucleo() -> void:
	var ground: Route = _routes["ground"]
	var air: Route = _routes["air"]
	assert_eq(_at(ground, 0.0), Vector2(_small.entrance))
	assert_eq(_at(ground, ground.length), Vector2(_small.nexus))
	assert_eq(_at(air, 0.0), Vector2(_small.entrance))
	assert_eq(_at(air, air.length), Vector2(_small.nexus))


func test_interpola_dentro_do_trecho_e_vira_exatamente_na_curva() -> void:
	var ground: Route = _routes["ground"]
	assert_eq(_at(ground, 1.5), Vector2(1.5, 1))
	assert_eq(_at(ground, 3.0), Vector2(3, 1))
	assert_eq(_at(ground, 3.5), Vector2(3, 1.5))
	assert_eq(_at(ground, 6.25), Vector2(1.75, 3))


func test_distancias_fora_da_rota_ficam_presas_nas_pontas() -> void:
	var ground: Route = _routes["ground"]
	assert_eq(_at(ground, -2.0), Vector2(_small.entrance))
	assert_eq(_at(ground, 99.0), Vector2(_small.nexus))


func test_rota_aerea_e_uma_reta_da_entrada_ao_nucleo() -> void:
	var air: Route = _routes["air"]
	assert_almost_eq(air.length, sqrt(5.0), 1e-12)
	var mid := _at(air, air.length / 2.0)
	assert_almost_eq(mid.x, 0.5, 1e-6)
	assert_almost_eq(mid.y, 2.0, 1e-6)
	var p := _at(air, 0.8)
	assert_almost_eq(p.y, 1.0 + 2.0 * p.x, 1e-6)


func test_no_mapa_do_jogo_a_rota_terrestre_tem_uma_casa_por_trecho() -> void:
	var map := SimMap.load_map(DataLoader.load_json("map.json"))
	assert_eq(Route.build_routes(map)["ground"].length, float(map.path_cells.size() - 1))


func test_rejeita_rota_com_menos_de_2_pontos_ou_ponto_repetido() -> void:
	var one: Array[Vector2i] = [Vector2i(0, 0)]
	assert_false(Route.new(one).valid)
	assert_push_error("2 pontos")
	var repeated: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 0)]
	assert_false(Route.new(repeated).valid)
	assert_push_error("repetido")


func test_golden_rotas_do_mapa_do_jogo_bit_a_bit() -> void:
	var golden: Dictionary = Golden.load_json("enemies.json")
	var map := SimMap.load_map(DataLoader.load_json("map.json"))
	var routes := Route.build_routes(map)
	for kind: String in ["ground", "air"]:
		var route: Route = routes[kind]
		var entry: Dictionary = golden["routes"][kind]
		assert_eq(Golden.bits_of(route.length), Golden.parse_bits(entry["length"]),
				"%s: comprimento %s vs %s" % [kind, route.length, Golden.float_of_bits(entry["length"])])
		var bad := 0
		var p := MutablePoint.new()
		for s: Array in entry["samples"]:
			route.sample_into(Golden.float_of_bits(s[0]), p)
			if Golden.bits_of(p.x) != Golden.parse_bits(s[1]) or Golden.bits_of(p.y) != Golden.parse_bits(s[2]):
				bad += 1
		assert_eq(bad, 0, "%s: amostras diferentes do Phaser" % kind)
