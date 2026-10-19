extends GutTest
## Porte de tests/enemies.test.ts (spawn e movimento sobre o mapa pequeno).
## "Determinismo com inimigos" e o núcleo entram com sim/systems e o RunState.

const STEP := EnemySim.STEP


func test_spawn_enemy_pela_fila_cria_o_inimigo_na_entrada_no_tick_seguinte() -> void:
	var sim := EnemySim.make_sim()
	EnemySim.spawn(sim, "walker")
	assert_eq(EnemySim.active_enemies(sim.state).size(), 0)

	var events := EnemySim.run(sim, 1)
	var enemy := EnemySim.active_enemies(sim.state)[0]
	assert_eq(enemy.type, "walker")
	assert_eq(enemy.hp, 10.0)
	assert_eq(enemy.max_hp, 10.0)
	assert_eq(events, [{"type": "enemySpawned", "tick": 1, "enemyId": enemy.id, "enemyType": "walker"}])
	# Já anda no tick em que nasce: a interpolação parte da entrada.
	assert_eq([enemy.prev_x, enemy.prev_y], [0.0, 1.0])
	assert_eq(enemy.distance, STEP)


func test_tipo_desconhecido_e_erro() -> void:
	var sim := EnemySim.make_sim()
	EnemySim.spawn(sim, "dragon")
	sim.step()
	assert_push_error("desconhecido")
	assert_eq(EnemySim.active_enemies(sim.state).size(), 0)


func test_cada_inimigo_recebe_id_novo_mesmo_reaproveitando_o_slot() -> void:
	var sim := EnemySim.make_sim()
	# Sem núcleo neste teste: o voador é devolvido ao pool à mão.
	EnemySim.spawn(sim, "flyer")
	EnemySim.run(sim, 1)
	var first := EnemySim.active_enemies(sim.state)[0]
	var first_id := first.id
	sim.state.enemies.release(first)

	EnemySim.spawn(sim, "walker")
	EnemySim.run(sim, 1)
	var second := EnemySim.active_enemies(sim.state)[0]
	assert_same(second, first)
	assert_ne(second.id, first_id)
	assert_eq([second.prev_x, second.prev_y], [0.0, 1.0])


func test_anda_speed_sobre_ticks_por_segundo_casas_por_tick_ao_longo_do_caminho() -> void:
	var sim := EnemySim.make_sim()
	EnemySim.spawn(sim, "walker")
	EnemySim.run(sim, 4)
	var enemy := EnemySim.active_enemies(sim.state)[0]
	assert_eq(enemy.distance, 4 * STEP)
	assert_eq([enemy.x, enemy.y], [1.0, 1.0])

	EnemySim.run(sim, 8)  # distância 3: exatamente na curva
	assert_eq([enemy.x, enemy.y], [3.0, 1.0])
	EnemySim.run(sim, 2)  # distância 3,5: já descendo
	assert_eq([enemy.x, enemy.y], [3.0, 1.5])


func test_guarda_a_posicao_do_tick_anterior_para_interpolar() -> void:
	var sim := EnemySim.make_sim()
	EnemySim.spawn(sim, "walker")
	EnemySim.run(sim, 13)
	var enemy := EnemySim.active_enemies(sim.state)[0]
	var before := [enemy.x, enemy.y]
	EnemySim.run(sim, 1)
	assert_eq([enemy.prev_x, enemy.prev_y], before)
	assert_eq([enemy.x, enemy.y], [3.0, 1.5])


func test_o_voador_vai_em_linha_reta() -> void:
	var sim := EnemySim.make_sim()
	EnemySim.spawn(sim, "walker")
	EnemySim.spawn(sim, "flyer")
	EnemySim.run(sim, 4)
	var flyer: Enemy
	for e in EnemySim.active_enemies(sim.state):
		if e.type == "flyer":
			flyer = e
	assert_almost_eq(flyer.y, 1.0 + 2.0 * flyer.x, 1e-12)
	assert_eq(flyer.distance, 1.0)


func test_elite_tem_vida_multiplicada_e_anda_mais_devagar() -> void:
	var data := EnemySim.test_enemies()
	var routes := Route.build_routes(EnemySim.small_map())
	var state := TestRunState.new("elite")
	var spawn := func(ctx: TickContext) -> void:
		if ctx.state.tick == 1:
			EnemySystems.spawn_enemy(ctx, routes, data, "walker", 0.0, 2.0, 3, true)
	var movement := EnemySystems.create_movement_system(routes, data, float(EnemySim.TPS))
	var sim := Simulation.new(state, [spawn, movement])
	sim.step()
	var enemy := EnemySim.active_enemies(state)[0]
	assert_eq(enemy.hp, 10.0 * 2.0 * 6.0)
	assert_eq(enemy.wave, 3)
	assert_true(enemy.elite)
	assert_almost_eq(enemy.distance, 2.0 * 0.8 / 8.0, 1e-12)


func test_dano_aplica_armadura_mata_devolve_ao_pool_e_emite_evento() -> void:
	var data := EnemySim.test_enemies()
	var routes := Route.build_routes(EnemySim.small_map())
	var state := TestRunState.new("dmg")
	var captured := []
	var system := func(ctx: TickContext) -> void:
		if ctx.state.tick == 1:
			var e := EnemySystems.spawn_enemy(ctx, routes, data, "tank")
			captured.append(Damage.damage_enemy(ctx, data, e, 15.0, 7))  # 15 × 100/150 = 10 = vida
	var sim := Simulation.new(state, [system])
	sim.step()
	assert_almost_eq(captured[0], 10.0, 1e-12)
	assert_eq(state.enemies.active_count, 0)
	var types := sim.drain_events().map(func(e: Dictionary) -> String: return e["type"])
	assert_eq(types, ["enemySpawned", "enemyKilled"])


func test_dano_ignorando_armadura_e_peso_do_abate() -> void:
	var data := EnemySim.test_enemies()
	var routes := Route.build_routes(EnemySim.small_map())
	var state := TestRunState.new("exec")
	var killed: Array = []
	var system := func(ctx: TickContext) -> void:
		if ctx.state.tick == 1:
			var e := EnemySystems.spawn_enemy(ctx, routes, data, "tank")
			Damage.damage_enemy(ctx, data, e, 10.0, null,
					{"ignoreArmor": true, "killWeight": 2, "chain": ChainMark.new(4, 9)})
			killed.append_array(ctx.tick_events.filter(func(ev: Dictionary) -> bool: return ev["type"] == "enemyKilled"))
	var sim := Simulation.new(state, [system])
	sim.step()
	assert_eq(killed.size(), 1)
	var ev: Dictionary = killed[0]
	assert_eq([ev["weight"], ev["chainId"], ev["originTowerId"], ev["towerId"]], [2, 4, 9, null])
