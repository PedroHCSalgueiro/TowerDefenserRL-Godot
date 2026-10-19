extends GutTest
## Porte de tests/grid.test.ts + paridade com o Phaser (tests/golden/grid.json).

# Mapa pequeno: entra em (0,1), desce em (3,1) até (3,3) e termina em (1,3).
const SMALL := {
	"id": "small", "width": 5, "height": 4,
	"path": [{"x": 0, "y": 1}, {"x": 3, "y": 1}, {"x": 3, "y": 3}, {"x": 1, "y": 3}],
}


func _with(overrides: Dictionary) -> Dictionary:
	var d := SMALL.duplicate(true)
	d.merge(overrides, true)
	return d


func _game_map() -> SimMap:
	return SimMap.load_map(DataLoader.load_json("map.json"))


func test_expande_os_pontos_de_virada_em_casas_contiguas_e_em_ordem() -> void:
	var map := SimMap.load_map(SMALL)
	assert_eq(map.path_cells, [
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
		Vector2i(3, 2), Vector2i(3, 3), Vector2i(2, 3), Vector2i(1, 3),
	])
	assert_eq(map.entrance, Vector2i(0, 1))
	assert_eq(map.nexus, Vector2i(1, 3))


func test_map_json_do_jogo_carrega_com_caminho_contiguo() -> void:
	var map := _game_map()
	var cells := map.path_cells
	assert_eq(cells[0], map.entrance)
	assert_eq(cells[cells.size() - 1], map.nexus)
	for i in range(1, cells.size()):
		var d := cells[i] - cells[i - 1]
		assert_eq(absi(d.x) + absi(d.y), 1)


func test_rejeita_ponto_fora_da_grade() -> void:
	assert_null(SimMap.load_map(_with({"path": [{"x": 0, "y": 1}, {"x": 5, "y": 1}]})))
	assert_push_error("fora da grade")
	assert_null(SimMap.load_map(_with({"path": [{"x": -1, "y": 1}, {"x": 2, "y": 1}]})))
	assert_push_error("fora da grade")


func test_rejeita_trecho_diagonal() -> void:
	assert_null(SimMap.load_map(_with({"path": [{"x": 0, "y": 0}, {"x": 2, "y": 2}]})))
	assert_push_error("diagonal")


func test_rejeita_trecho_de_tamanho_zero() -> void:
	assert_null(SimMap.load_map(_with({"path": [{"x": 0, "y": 1}, {"x": 0, "y": 1}, {"x": 2, "y": 1}]})))
	assert_push_error("tamanho zero")


func test_rejeita_caminho_que_passa_duas_vezes_pela_mesma_casa() -> void:
	var path := [{"x": 0, "y": 1}, {"x": 3, "y": 1}, {"x": 3, "y": 2}, {"x": 1, "y": 2}, {"x": 1, "y": 0}]
	assert_null(SimMap.load_map(_with({"path": path})))
	assert_push_error("duas vezes")


func test_rejeita_caminho_curto_e_tamanho_invalido() -> void:
	assert_null(SimMap.load_map(_with({"path": [{"x": 0, "y": 0}]})))
	assert_push_error("pelo menos 2")
	assert_null(SimMap.load_map(_with({"width": 0})))
	assert_push_error("tamanho")
	assert_null(SimMap.load_map(_with({"height": 2.5})))
	assert_push_error("tamanho")


func test_torre_so_em_casa_livre_dentro_da_grade() -> void:
	var map := SimMap.load_map(SMALL)
	assert_true(map.can_place_tower(Vector2i(0, 0)))
	assert_true(map.can_place_tower(Vector2i(4, 3)))
	assert_false(map.can_place_tower(Vector2i(2, 1)))  # caminho
	assert_false(map.can_place_tower(map.entrance))
	assert_false(map.can_place_tower(map.nexus))


func test_casas_fora_da_grade_nao_sao_caminho_nem_aceitam_torre() -> void:
	# O caso x = 0,5 do Phaser não existe aqui: Vector2i só guarda inteiros.
	var map := SimMap.load_map(SMALL)
	for cell in [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(5, 0), Vector2i(0, 4)]:
		assert_false(map.is_inside(cell))
		assert_false(map.is_path(cell))
		assert_false(map.can_place_tower(cell))


func test_casas_validas_para_torre_igual_largura_x_altura_menos_caminho() -> void:
	for map in [SimMap.load_map(SMALL), _game_map()]:
		var buildable := 0
		for y in map.height:
			for x in map.width:
				if map.can_place_tower(Vector2i(x, y)):
					buildable += 1
		assert_eq(buildable, map.width * map.height - map.path_cells.size())


# ---------------------------------------------------------------- paridade com o Phaser

func test_golden_mapas() -> void:
	var golden: Dictionary = Golden.load_json("grid.json")
	for entry: Dictionary in golden["maps"]:
		var map := SimMap.load_map(entry["data"])
		assert_not_null(map, entry["data"]["id"])
		var cells: Array = []
		for c in map.path_cells:
			cells.append([c.x, c.y])
		assert_eq(_ints(cells), _ints(entry["pathCells"]), "%s: pathCells" % entry["data"]["id"])
		assert_eq([map.entrance.x, map.entrance.y], _ints(entry["entrance"]))
		assert_eq([map.nexus.x, map.nexus.y], _ints(entry["nexus"]))
		var mask := ""
		for y in map.height:
			for x in map.width:
				mask += "1" if map.can_place_tower(Vector2i(x, y)) else "0"
		assert_eq(mask, entry["buildable"], "%s: casas construíveis" % entry["data"]["id"])


func test_golden_vizinhas_de_todas_as_casas() -> void:
	var golden: Dictionary = Golden.load_json("grid.json")
	var entry: Dictionary = golden["neighbors"]
	var map := SimMap.load_map(entry["map"])
	var mismatches := 0
	for mode_key: String in ["4", "8"]:
		var expected_by_cell: Array = entry[mode_key]
		var i := 0
		for y in map.height:
			for x in map.width:
				var got: Array = []
				for c in Neighbors.of(map, Vector2i(x, y), int(mode_key)):
					got.append([c.x, c.y])
				if got != _ints(expected_by_cell[i]):
					mismatches += 1
				i += 1
	assert_eq(mismatches, 0)


# JSON traz floats; normaliza listas aninhadas para int antes de comparar.
func _ints(value: Variant) -> Variant:
	if value is Array:
		var out: Array = []
		for v in value:
			out.append(_ints(v))
		return out
	return int(value)
