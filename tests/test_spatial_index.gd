extends GutTest
## Porte de tests/spatialIndex.test.ts.


## Referência: testa todos contra todos, com o mesmo critério de desempate.
func _brute_nearest(state: Object, x: float, y: float, range_: float) -> Enemy:
	var best: Enemy = null
	var best_sq := INF
	for e: Enemy in state.enemies.slots:
		if not e.active:
			continue
		var d := (e.x - x) * (e.x - x) + (e.y - y) * (e.y - y)
		if d > range_ * range_:
			continue
		if d < best_sq or (d == best_sq and best != null and e.id < best.id):
			best = e
			best_sq = d
	return best


func _between(rng: Rng, lo: float, hi: float) -> float:
	return lo + rng.next_float() * (hi - lo)


func _ids(list: Array) -> Array:
	var ids := list.map(func(e: Enemy) -> int: return e.id)
	ids.sort()
	return ids


func test_sem_inimigos_nao_acha_ninguem() -> void:
	var index := SpatialIndex.new(1.0)
	assert_null(index.find_nearest(TestRunState.new("t"), 0.0, 0.0, 100.0))


func test_a_borda_do_alcance_conta_e_o_empate_vai_para_o_menor_id() -> void:
	var state := TestRunState.new("t")
	var gone := EnemySim.place(state, "walker", 9, 9)  # id 1, slot 0
	var older := EnemySim.place(state, "walker", 3, 0)  # id 2: distância 3
	state.enemies.release(gone)
	EnemySim.place(state, "walker", 0, 3)  # id 3, slot 0: também distância 3
	var index := SpatialIndex.new(1.0)
	assert_same(index.find_nearest(state, 0.0, 0.0, 3.0), older)
	assert_null(index.find_nearest(state, 0.0, 0.0, 2.999))


func test_ignora_inimigos_que_morreram_depois_da_montagem() -> void:
	var state := TestRunState.new("t")
	var a := EnemySim.place(state, "walker", 1, 0)
	var b := EnemySim.place(state, "walker", 2, 0)
	var index := SpatialIndex.new(1.0)
	assert_same(index.find_nearest(state, 0.0, 0.0, 5.0), a)
	state.enemies.release(a)
	assert_same(index.find_nearest(state, 0.0, 0.0, 5.0), b)


func test_avalanche_mortos_saem_das_celulas_e_batem_com_a_busca_completa() -> void:
	var rng := Rng.new(RngHolder.new(99))
	var state := TestRunState.new("t")
	for i in 400:
		EnemySim.place(state, "walker", _between(rng, 0, 3), _between(rng, 0, 3))
	var index := SpatialIndex.new(1.0)
	for round in 40:
		# Mata alguns no meio do tick, entre consultas (como uma explosão de gatilho).
		for e: Enemy in index.collect_in_range(state, _between(rng, 0, 3), _between(rng, 0, 3), 0.8, []):
			if rng.chance(0.5):
				state.enemies.release(e)
		var x := _between(rng, -1, 4)
		var y := _between(rng, -1, 4)
		var range_ := _between(rng, 0, 3)
		assert_same(index.find_nearest(state, x, y, range_), _brute_nearest(state, x, y, range_))
		var collected := _ids(index.collect_in_range(state, x, y, range_, []))
		var expected := _ids(state.enemies.slots.filter(func(e: Enemy) -> bool:
				return e.active and (e.x - x) * (e.x - x) + (e.y - y) * (e.y - y) <= range_ * range_))
		assert_eq(collected, expected)


func test_remonta_a_cada_tick_com_as_posicoes_novas() -> void:
	var state := TestRunState.new("t")
	var a := EnemySim.place(state, "walker", 1, 0)
	var b := EnemySim.place(state, "walker", 5, 0)
	var index := SpatialIndex.new(1.0)
	assert_same(index.find_nearest(state, 5.0, 0.0, 1.0), b)
	a.x = 5.5
	b.x = 20.0
	state.tick += 1
	assert_same(index.find_nearest(state, 5.0, 0.0, 1.0), a)


func test_mesmo_resultado_que_a_busca_completa() -> void:
	# [nome, min, max, tamanho da célula]
	for scenario: Array in [["espalhados", 0.0, 14.0, 0.5], ["agrupados", 0.2, 0.4, 1.0],
			["empilhados na mesma posição", 3.0, 3.0, 0.25]]:
		var rng := Rng.new(RngHolder.new(1234))
		var state := TestRunState.new("t")
		state.enemies = EnemyPool.create(0)
		for i in 600:
			var e := EnemySim.place(state, "walker", _between(rng, scenario[1], scenario[2]),
					_between(rng, scenario[1], scenario[2]))
			if rng.chance(0.2):
				state.enemies.release(e)
		var index := SpatialIndex.new(scenario[3])
		var mismatches := 0
		for q in 400:
			var x := _between(rng, -3, 17)
			var y := _between(rng, -3, 17)
			var range_ := _between(rng, 0, 5)
			if index.find_nearest(state, x, y, range_) != _brute_nearest(state, x, y, range_):
				mismatches += 1
		assert_eq(mismatches, 0, scenario[0])


func test_find_best_e_collect_in_range_dao_o_mesmo_que_a_busca_completa() -> void:
	var rng := Rng.new(RngHolder.new(777))
	var state := TestRunState.new("t")
	for i in 500:
		# Vida em poucos valores, para forçar empates na nota.
		var e := EnemySim.place(state, "walker", _between(rng, 0, 10), _between(rng, 0, 10),
				1.0 + floorf(_between(rng, 0, 5)))
		if rng.chance(0.2):
			state.enemies.release(e)
	var most_hp := func(e: Enemy, _x: float, _y: float) -> float: return -e.hp
	var index := SpatialIndex.new(1.0)
	for q in 300:
		var x := _between(rng, -2, 12)
		var y := _between(rng, -2, 12)
		var range_ := _between(rng, 0, 4)
		var in_range := state.enemies.slots.filter(func(e: Enemy) -> bool:
				return e.active and (e.x - x) * (e.x - x) + (e.y - y) * (e.y - y) <= range_ * range_)
		var expected: Enemy = null
		for e: Enemy in in_range:
			if expected == null or -e.hp < -expected.hp or (e.hp == expected.hp and e.id < expected.id):
				expected = e
		assert_same(index.find_best(state, x, y, range_, most_hp), expected)
		assert_eq(_ids(index.collect_in_range(state, x, y, range_, [])), _ids(in_range))

		# find_best_n: os 3 melhores, na ordem (nota, depois id).
		var best3 := index.find_best_n(state, x, y, range_, most_hp, 3, [])
		var sorted := in_range.duplicate()
		sorted.sort_custom(func(a: Enemy, b: Enemy) -> bool:
				return -a.hp < -b.hp or (a.hp == b.hp and a.id < b.id))
		assert_eq(_ids(best3), _ids(sorted.slice(0, 3)))
		if best3.size() > 0:
			assert_same(best3[0], expected)
