extends GutTest
## Porte de tests/neighbors.test.ts.

var _map: SimMap


func before_all() -> void:
	_map = SimMap.load_map({"id": "n", "width": 5, "height": 5, "path": [{"x": 0, "y": 4}, {"x": 4, "y": 4}]})


func test_casa_do_meio_4_vizinhas_na_ordem_fixa() -> void:
	assert_eq(Neighbors.of(_map, Vector2i(2, 2)), [Vector2i(2, 1), Vector2i(3, 2), Vector2i(2, 3), Vector2i(1, 2)])


func test_casa_do_meio_8_vizinhas_lados_primeiro_e_depois_diagonais() -> void:
	assert_eq(Neighbors.of(_map, Vector2i(2, 2), 8), [
		Vector2i(2, 1), Vector2i(3, 2), Vector2i(2, 3), Vector2i(1, 2),
		Vector2i(3, 1), Vector2i(3, 3), Vector2i(1, 3), Vector2i(1, 1),
	])


func test_cantos_2_vizinhas_com_4_e_3_com_8() -> void:
	for corner in [Vector2i(0, 0), Vector2i(4, 0), Vector2i(0, 4), Vector2i(4, 4)]:
		assert_eq(Neighbors.of(_map, corner, 4).size(), 2)
		assert_eq(Neighbors.of(_map, corner, 8).size(), 3)


func test_bordas_3_vizinhas_com_4_e_5_com_8() -> void:
	for edge in [Vector2i(2, 0), Vector2i(4, 2), Vector2i(2, 4), Vector2i(0, 2)]:
		assert_eq(Neighbors.of(_map, edge, 4).size(), 3)
		assert_eq(Neighbors.of(_map, edge, 8).size(), 5)


func test_nunca_devolve_a_propria_casa_repetidas_ou_fora_da_grade() -> void:
	for y in _map.height:
		for x in _map.width:
			for mode in [4, 8]:
				var result := Neighbors.of(_map, Vector2i(x, y), mode)
				var seen := {}
				for c in result:
					seen[c] = true
					assert_true(_map.is_inside(c))
					assert_eq(maxi(absi(c.x - x), absi(c.y - y)), 1)
				assert_eq(seen.size(), result.size())
				assert_false(seen.has(Vector2i(x, y)))
