extends GutTest
## Porte de tests/enemyPool.test.ts e tests/enemyOrder.test.ts.


func test_pre_aloca_a_capacidade_e_entrega_os_slots_em_ordem() -> void:
	var pool := EnemyPool.create(3)
	assert_eq(pool.slots.size(), 3)
	assert_true(pool.slots.all(func(e: Enemy) -> bool: return not e.active))
	assert_eq(pool.acquire().slot, 0)
	assert_eq(pool.acquire().slot, 1)
	assert_eq(pool.active_count, 2)


func test_reaproveita_o_mesmo_objeto_depois_de_devolvido() -> void:
	var pool := EnemyPool.create(2)
	var first := pool.acquire()
	pool.acquire()
	pool.release(first)
	assert_false(first.active)
	assert_eq(pool.active_count, 1)

	var again := pool.acquire()
	assert_same(again, first)
	assert_true(again.active)
	assert_eq(pool.slots.size(), 2)


func test_cresce_quando_esgota_sem_mexer_nos_objetos_existentes() -> void:
	var pool := EnemyPool.create(1)
	var a := pool.acquire()
	var b := pool.acquire()
	assert_eq(b.slot, 1)
	assert_eq(pool.slots, [a, b] as Array[Enemy])
	assert_eq(pool.active_count, 2)


func test_devolver_duas_vezes_e_erro() -> void:
	var pool := EnemyPool.create(1)
	var enemy := pool.acquire()
	pool.release(enemy)
	pool.release(enemy)
	assert_push_error("já foi devolvido")
	assert_eq(pool.free, [0] as Array[int])


func test_release_all_devolve_todos_sem_eventos() -> void:
	var pool := EnemyPool.create(4)
	pool.acquire()
	pool.acquire()
	pool.release_all()
	assert_eq(pool.active_count, 0)
	assert_eq(pool.free.size(), 4)


# ---------------------------------------------------------------- ordenação por id

func _enemy(id: int) -> Enemy:
	var e := Enemy.new()
	e.id = id
	return e


func test_ordenacao_por_id_igual_a_ordenar_pelo_comparador() -> void:
	var rng := Rng.new(RngHolder.new(42))
	for size in [0, 1, 2, 7, 300, 2000]:
		var list: Array = []
		for i in size:
			list.append(_enemy(i * 3 + 1))
		rng.shuffle(list)
		var sorted := EnemyOrder.sort_by_id(list)
		assert_same(sorted, list, "no próprio array")
		for i in range(1, sorted.size()):
			assert_lt(sorted[i - 1].id, sorted[i].id)


func test_lista_ja_em_ordem_fica_como_esta() -> void:
	var in_order := [_enemy(1), _enemy(5), _enemy(9)]
	var ids := EnemyOrder.sort_by_id(in_order).map(func(e: Enemy) -> int: return e.id)
	assert_eq(ids, [1, 5, 9])
	var huge := [_enemy(1 << 40), _enemy(3), _enemy((1 << 40) - 1)]
	ids = EnemyOrder.sort_by_id(huge).map(func(e: Enemy) -> int: return e.id)
	assert_eq(ids, [3, (1 << 40) - 1, 1 << 40])
