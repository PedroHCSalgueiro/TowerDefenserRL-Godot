extends GutTest
## Mapa que cresce (`Expansion`, `data/expansion.json`): começo pequeno em volta do caminho, escolha da
## parede depois do chefão (e da recompensa), simulação congelada com a escolha aberta, sala com
## entrada nova alternando os inimigos, escolha automática no fim do tempo e save no meio.

var data: ExpansionData


func before_each() -> void:
	data = ExpansionData.game_data()


func _sim(seed_text: String = "salas") -> Dictionary:
	var map := data.build_map()
	var sim := Simulation.create(seed_text, GameSystems.create(map))
	return {"sim": sim, "map": map}


func _step(sim: Simulation, n: int = 1) -> Array:
	var events: Array = []
	for i in n:
		sim.step()
		events.append_array(sim.drain_events())
	return events


func _types(events: Array) -> Array:
	return events.map(func(e: Dictionary) -> String: return e["type"])


## Abre a escolha pelo debug e põe `room_id` como única opção.
func _open_with(sim: Simulation, room_id: String) -> void:
	sim.enqueue({"type": "debugOpenExpansion"})
	_step(sim)
	sim.state.expansion.screen.options = [room_id]


func test_data_loads_rooms_and_small_start() -> void:
	assert_true(data.enabled)
	assert_eq(data.map_id, "salas-01")
	assert_eq(data.rooms.size(), 7)
	var map := data.build_map()
	assert_true(map.can_place_tower(Vector2i(7, 5)), "casa encostada no caminho começa aberta")
	assert_false(map.can_place_tower(Vector2i(10, 2)), "Salão Norte começa no escuro")
	assert_false(map.is_open(Vector2i(8, 12)), "portão da entrada da Ala Oeste fica fechado")
	assert_false(map.is_open(Vector2i(17, 8)), "portão da entrada da Ala Leste fica fechado")
	var west := data.get_room("ala_oeste")
	assert_true(west.has_entrance())
	assert_eq(map.path_cells[west.join_index], Vector2i(9, 12), "a entrada se junta no caminho em (9, 12)")
	assert_false(west.cells.has(Vector2i(3, 12)), "as casas da entrada não são de construir")


func test_all_rooms_touch_the_start() -> void:
	var map := data.build_map()
	var state := RunState.create("x")
	assert_eq(Expansion.candidates(map, data, state).size(), data.rooms.size())


func test_open_screen_freezes_the_simulation() -> void:
	var s := _sim()
	var sim: Simulation = s["sim"]
	sim.enqueue({"type": "debugOpenExpansion"})
	var events := _step(sim)
	assert_has(_types(events), "expansionOpened")
	assert_true(sim.state.cheated, "abrir pelo debug é trapaça")
	var screen: ExpansionState.ExpansionScreen = sim.state.expansion.screen
	assert_not_null(screen)
	assert_eq(screen.options.size(), data.choices)
	var tick: int = sim.state.tick
	_step(sim, 5)
	assert_eq(sim.state.tick, tick, "congelada com a escolha aberta")
	sim.enqueue({"type": "callWave"})
	_step(sim)
	assert_true(sim.state.waves.active.is_empty(), "com a escolha aberta, chamar onda é ignorado")


func test_choose_opens_the_room() -> void:
	var s := _sim()
	var sim: Simulation = s["sim"]
	var map: SimMap = s["map"]
	_open_with(sim, "salao_norte")
	sim.enqueue({"type": "chooseExpansion", "index": 0})
	var events := _step(sim)
	assert_has(_types(events), "expansionChosen")
	assert_null(sim.state.expansion.screen)
	assert_eq(sim.state.expansion.opened, ["salao_norte"] as Array[String])
	assert_true(map.can_place_tower(Vector2i(10, 2)), "o Salão Norte abriu")
	var tick: int = sim.state.tick
	_step(sim)
	assert_eq(sim.state.tick, tick + 1, "a simulação volta a andar")
	assert_false(Expansion.candidates(map, data, sim.state).has("salao_norte"), "sala aberta não volta")


func test_entrance_room_alternates_enemies() -> void:
	var s := _sim()
	var sim: Simulation = s["sim"]
	var map: SimMap = s["map"]
	_open_with(sim, "ala_oeste")
	sim.enqueue({"type": "chooseExpansion", "index": 0})
	_step(sim)
	assert_eq(map.entrance_count(), 2)
	assert_true(map.is_path(Vector2i(8, 12)), "o portão virou caminho")
	sim.enqueue({"type": "callWave"})
	var spawned: Array[Enemy] = []
	for i in 200:
		_step(sim)
		spawned.clear()
		for enemy: Enemy in sim.state.enemies.slots:
			if enemy.active:
				spawned.append(enemy)
		if spawned.size() >= 2:
			break
	assert_gte(spawned.size(), 2)
	var entrances := spawned.map(func(e: Enemy) -> int: return e.entrance)
	assert_has(entrances, 0, "um entra pela principal")
	assert_has(entrances, 1, "outro entra pela Ala Oeste")


func test_timeout_picks_automatically() -> void:
	var s := _sim()
	var sim: Simulation = s["sim"]
	sim.enqueue({"type": "debugOpenExpansion"})
	_step(sim)
	var events := _step(sim, Expansion.choose_ticks(data, 30.0) + 2)
	var chosen := events.filter(func(e: Dictionary) -> bool: return e["type"] == "expansionChosen")
	assert_eq(chosen.size(), 1)
	assert_true(chosen[0]["auto"])
	assert_eq(sim.state.expansion.opened.size(), 1)


## Escolhe a primeira opção das telas abertas (recompensas e paredes) até não sobrar nenhuma.
func _clear_screens(sim: Simulation) -> void:
	for i in 40:
		if sim.state.rewards.screen != null:
			sim.enqueue({"type": "chooseReward", "index": 0})
		elif sim.state.expansion.screen != null:
			sim.enqueue({"type": "chooseExpansion", "index": 0})
		else:
			return
		_step(sim)


func test_choice_waves_come_from_data() -> void:
	assert_eq(data.after_waves, [10, 20, 30] as Array[int])


func test_choice_wave_opens_after_the_reward() -> void:
	var s := _sim()
	var sim: Simulation = s["sim"]
	var wave: int = data.after_waves[0]
	sim.enqueue({"type": "debugSkipToWave", "wave": wave})
	_step(sim)
	_clear_screens(sim)
	assert_eq(sim.state.expansion.opened.size(), 0, "as ondas antes da primeira escolha não abrem salas")
	sim.enqueue({"type": "endWave"})
	_step(sim)
	assert_eq(sim.state.wave, wave)
	if sim.state.rewards.screen != null:
		assert_null(sim.state.expansion.screen, "a recompensa vem antes")
		assert_eq(sim.state.expansion.pending, 1)
		sim.enqueue({"type": "chooseReward", "index": 0})
		_step(sim)
	assert_not_null(sim.state.expansion.screen, "a escolha da parede abriu depois da onda %d" % wave)


func test_save_mid_run_restores_rooms_and_entrances() -> void:
	var s := _sim("salas-save")
	var sim: Simulation = s["sim"]
	_open_with(sim, "ala_leste")
	sim.enqueue({"type": "chooseExpansion", "index": 0})
	_step(sim)
	sim.enqueue({"type": "callWave"})
	_step(sim, 60)
	var text := sim.serialize()
	var map2 := data.build_map()
	var restored := RunStateIO.deserialize(text, map2)
	assert_not_null(restored)
	assert_eq(map2.entrance_count(), 2, "a sala volta ao mapa novo")
	assert_true(map2.can_place_tower(Vector2i(20, 6)), "as casas da Ala Leste voltam abertas")
	var sim2 := Simulation.new(restored, GameSystems.create(map2))
	_step(sim, 90)
	_step(sim2, 90)
	assert_eq(sim2.serialize(), sim.serialize(), "continuar do save dá o mesmo resultado")


func test_map_without_rooms_has_no_expansion() -> void:
	var map := SimMap.load_map(DataLoader.load_json("map.json"))
	var sim := Simulation.create("sem-salas", GameSystems.create(map))
	sim.enqueue({"type": "debugOpenExpansion"})
	_step(sim, 2)
	assert_null(sim.state.expansion.screen)
	assert_true(map.can_place_tower(Vector2i(5, 0)), "o mapa sem salas continua todo aberto")
	assert_false(sim.serialize().contains("\"expansion\""), "o save do mapa sem salas não muda")
