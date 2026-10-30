extends GutTest
## Mapa que cresce com moldes (`Expansion`, `ExpansionData`, `data/expansion.json`): começa só com o
## pedaço da base (zigue-zague fixo); as primeiras paredes seguem para a frente na hora; depois o jogador
## escolhe a direção e o molde de cada uma já vem sorteado; o caminho nunca encosta em si mesmo; quem está
## andando numa linha esticada fica no mesmo lugar; no debug, a parede pode dividir a linha principal
## (entrada nova, horda dividida); save no meio continua igual.

var data: ExpansionData


func before_each() -> void:
	data = ExpansionData.game_data()


func _sim(seed_text: String = "moldes") -> Dictionary:
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


## Derruba uma parede pelo debug (abre no fim do tick).
func _open(sim: Simulation, split: bool = false) -> Array:
	sim.enqueue({"type": "debugOpenExpansion", "split": split})
	return _step(sim)


## Índice da primeira opção da escolha aberta que vai para `dir` (na linha `line`), ou -1.
func _option(sim: Simulation, dir: String, line: int = 0) -> int:
	var screen: ExpansionState.ExpansionScreen = sim.state.expansion.screen
	for i in screen.options.size():
		if String(screen.options[i]).begins_with("%d:%s:" % [line, dir]):
			return i
	return -1


func _choose(sim: Simulation, index: int) -> void:
	sim.enqueue({"type": "chooseExpansion", "index": index})
	_step(sim)


## Derruba `n` paredes indo sempre para `dir` (ou a primeira opção, se não der).
func _walls(sim: Simulation, n: int, dir: String = ExpansionData.RIGHT) -> void:
	for i in n:
		_open(sim)
		if sim.state.expansion.screen != null:
			_choose(sim, maxi(0, _option(sim, dir)))


## Centro do pedaço `piece`, onde a linha entrou indo para `dir` (a entrada dos inimigos dele).
func _center(piece: Vector2i, dir: String) -> Vector2i:
	return data.to_global(piece, dir, Vector2i(data.center(), data.center()))


## Primeiro inimigo vivo da entrada `entrance` depois de chamar a onda (null se não nascer).
func _walker(sim: Simulation, entrance: int) -> Enemy:
	sim.enqueue({"type": "callWave"})
	for i in 400:
		_step(sim)
		for enemy: Enemy in sim.state.enemies.slots:
			if enemy.active and enemy.entrance == entrance and enemy.distance > 2.0:
				return enemy
	return null


## O inimigo está no ponto da rota dele (depois de a linha esticar).
func _assert_on_route(enemy: Enemy) -> void:
	var point := MutablePoint.new()
	enemy.route.sample_into(enemy.distance, point)
	assert_almost_eq(point.x, enemy.x, 1e-6, "x no mesmo lugar")
	assert_almost_eq(point.y, enemy.y, 1e-6, "y no mesmo lugar")


## Quantas vezes o caminho `cells` encosta em si mesmo fora da ordem (casa vizinha que não é a anterior
## nem a próxima), mais os passos que não são de uma casa e as casas repetidas.
func _touches(cells: Array[Vector2i]) -> int:
	var index := {}
	for i in cells.size():
		index[cells[i]] = i
	var bad := 0 if index.size() == cells.size() else 1
	for i in cells.size():
		if i > 0 and absi(cells[i].x - cells[i - 1].x) + absi(cells[i].y - cells[i - 1].y) != 1:
			bad += 1
		for n in [cells[i] + Vector2i.RIGHT, cells[i] + Vector2i.LEFT, cells[i] + Vector2i.UP, cells[i] + Vector2i.DOWN]:
			if index.has(n) and absi(int(index[n]) - i) != 1:
				bad += 1
	return bad


func test_starts_with_the_fixed_zigzag_base() -> void:
	assert_true(data.enabled)
	assert_eq(data.piece_size, 11)
	assert_eq(data.after_waves, [5, 10, 15, 20, 25, 30] as Array[int])
	var map := data.build_map()
	assert_eq(map.id, "moldes-01")
	assert_eq([map.width, map.height], [77, 99], "6 pedaços para a direita e 4 para cima e para baixo")
	assert_eq(map.nexus, Vector2i(1, 46))
	assert_eq(map.entrance, Vector2i(5, 49), "os inimigos saem do centro da base")
	assert_eq(map.path_cells.size(), 14, "zigue-zague fixo do centro até o núcleo")
	assert_eq(_touches(map.path_cells), 0)
	assert_true(map.can_place_tower(Vector2i(2, 45)))
	assert_true(map.is_reserved(Vector2i(8, 47)), "a metade de longe da base fica cercada")
	assert_false(map.can_place_tower(Vector2i(8, 47)))
	assert_false(map.is_open(Vector2i(13, 49)), "o pedaço seguinte começa no escuro")


func test_first_walls_go_forward_at_once() -> void:
	var s := _sim()
	var sim: Simulation = s["sim"]
	var map: SimMap = s["map"]
	for k in data.forward_only_walls:
		var tick: int = sim.state.tick
		var events := _open(sim)
		assert_null(sim.state.expansion.screen, "com uma opção só, não abre escolha")
		assert_has(_types(events), "expansionChosen")
		assert_eq(map.entrance, Vector2i(5 + 11 * (k + 1), 49), "a entrada vai para o centro do pedaço novo")
		assert_true(sim.state.expansion.opened[k].begins_with("0:direita:"))
		_step(sim)
		assert_eq(sim.state.tick, tick + 2, "a simulação não congela")
	assert_eq(_touches(map.path_cells), 0)
	assert_false(map.is_reserved(Vector2i(8, 47)), "a metade de longe da base libera")


func test_then_the_player_chooses_up_down_or_right() -> void:
	var s := _sim()
	var sim: Simulation = s["sim"]
	var map: SimMap = s["map"]
	_walls(sim, data.forward_only_walls)
	_open(sim)
	var screen: ExpansionState.ExpansionScreen = sim.state.expansion.screen
	assert_not_null(screen)
	assert_eq(screen.options.size(), 3)
	for i in 3:
		assert_true(String(screen.options[i]).begins_with("0:%s:" % ExpansionData.GROW_DIRS[i]), "direita, cima, baixo")
		assert_not_null(data.opening(sim.state.expansion.opened, screen.options[i]), "cada opção já vem com moldes")
	var tick: int = sim.state.tick
	_step(sim, 5)
	assert_eq(sim.state.tick, tick, "congelada com a escolha aberta")
	var old_tip := Vector2i(2, data.vertical_pieces())
	_choose(sim, _option(sim, ExpansionData.UP))
	var tip := old_tip + Vector2i(0, -1)
	assert_eq(map.entrance, _center(tip, ExpansionData.UP), "entrada no centro do pedaço de cima")
	assert_true(map.is_open(tip * 11), "o pedaço de cima abriu")
	assert_eq(_touches(map.path_cells), 0)
	assert_true(map.is_reserved(data.to_global(tip, ExpansionData.UP, Vector2i(8, 8))), "o pedaço novo fica cercado na metade de longe")
	var dirs := data.free_dirs(data.layout(sim.state.expansion.opened), 0)
	assert_eq(dirs, [ExpansionData.RIGHT, ExpansionData.UP] as Array[String], "subindo: para cima ou para a direita (nunca volta)")


func test_path_never_touches_itself() -> void:
	for n in 60:
		var map := data.build_map()
		var rng := Rng.new(RngHolder.new(Rng.hash_seed("caminho-%d" % n)))
		for wall in data.max_walls():
			var options := data.roll_options(map.applied, rng)
			assert_false(options.is_empty())
			assert_true(Expansion.apply(map, null, data, options[rng.next_int(0, options.size() - 1)]))
		assert_eq(_touches(map.path_cells), 0, "mapa %d: o caminho nunca encosta nele mesmo" % n)
		assert_true(data.roll_options(map.applied, rng).is_empty(), "acabaram as paredes")
		assert_true(data.reserved_cells(map.applied).is_empty(), "sem parede, nada cercado")


func test_molds_are_rolled_from_the_wall_rng() -> void:
	var a := _sim("mesma-semente")
	var b := _sim("mesma-semente")
	for s in [a, b]:
		_walls(s["sim"], data.forward_only_walls)
		_open(s["sim"])
	assert_eq(a["sim"].state.expansion.screen.options, b["sim"].state.expansion.screen.options, "mesma semente, mesmos moldes")
	var seen := {}
	for n in 40:
		for id: String in data.roll_options([], Rng.new(RngHolder.new(Rng.hash_seed("sorteio-%d" % n)))):
			seen[id.split(":")[2].trim_suffix("~")] = true
	assert_gt(seen.size(), 2, "o molde da frente varia")


func test_enemies_keep_their_place_when_the_line_grows() -> void:
	var s := _sim("moldes-andando")
	var sim: Simulation = s["sim"]
	var map: SimMap = s["map"]
	var enemy := _walker(sim, 0)
	assert_not_null(enemy)
	var before := enemy.distance
	var size := map.path_cells.size()
	_open(sim)
	assert_eq(sim.state.expansion.opened.size(), 1)
	assert_almost_eq(enemy.distance, before + float(map.path_cells.size() - size), 0.2, "ganhou as casas novas (e andou um tick)")
	_assert_on_route(enemy)


func test_debug_split_opens_a_second_line() -> void:
	var s := _sim("moldes-dividir")
	var sim: Simulation = s["sim"]
	var map: SimMap = s["map"]
	_walls(sim, data.forward_only_walls)
	var old_c := map.entrance
	_open(sim, true)
	var screen: ExpansionState.ExpansionScreen = sim.state.expansion.screen
	assert_not_null(screen)
	assert_eq(screen.options.size(), 3, "direita+cima, direita+baixo, cima+baixo")
	for id: String in screen.options:
		assert_true(id.contains("+"))
	_choose(sim, 0)
	assert_eq(map.entrance_count(), 2)
	assert_eq(map.path_cells[int(map.extra_entrances[0]["join"])], old_c, "as duas linhas se juntam no centro antigo")
	assert_eq(_touches(map.entrance_path(1)), 0)
	assert_eq(_touches(map.path_cells), 0)
	assert_false(sim.state.expansion.split_next)
	_open(sim)
	screen = sim.state.expansion.screen
	var lines := {}
	for id: String in screen.options:
		lines[id.split(":")[0]] = true
	assert_eq(lines.size(), 2, "depois, cada parede pergunta qual das duas linhas cresce")
	assert_string_starts_with(data.option_name(screen.options[screen.options.size() - 1]), "Linha 2:")


func test_horde_splits_between_the_two_lines() -> void:
	var s := _sim("moldes-horda")
	var sim: Simulation = s["sim"]
	_open(sim, true)
	_choose(sim, 0)
	sim.enqueue({"type": "callWave"})
	var by_entrance := {0: 0, 1: 0}
	_step(sim, 150)
	for enemy: Enemy in sim.state.enemies.slots:
		if enemy.active:
			by_entrance[enemy.entrance] += 1
	assert_gt(by_entrance[0], 0)
	assert_gt(by_entrance[1], 0)
	assert_lte(absi(by_entrance[0] - by_entrance[1]), 2, "alternando um para cada")


func test_enemies_keep_their_place_when_the_second_line_grows() -> void:
	var s := _sim("moldes-andando-2")
	var sim: Simulation = s["sim"]
	_walls(sim, data.forward_only_walls)
	_open(sim, true)
	_choose(sim, 0)
	var enemy := _walker(sim, 1)
	assert_not_null(enemy, "a horda se divide: alguém entra pela linha nova")
	var before := enemy.distance
	_open(sim)
	var screen: ExpansionState.ExpansionScreen = sim.state.expansion.screen
	var index := -1
	for i in screen.options.size():
		if String(screen.options[i]).begins_with("1:"):
			index = i
	_choose(sim, index)
	assert_gt(enemy.distance, before + 5.0)
	_assert_on_route(enemy)


func test_timeout_picks_automatically() -> void:
	var s := _sim()
	var sim: Simulation = s["sim"]
	_walls(sim, data.forward_only_walls)
	_open(sim)
	var events := _step(sim, Expansion.choose_ticks(data, 30.0) + 2)
	var chosen := events.filter(func(e: Dictionary) -> bool: return e["type"] == "expansionChosen")
	assert_eq(chosen.size(), 1)
	assert_true(chosen[0]["auto"])
	assert_eq(sim.state.expansion.opened.size(), data.forward_only_walls + 1)


func test_no_more_walls_after_the_last() -> void:
	var s := _sim()
	var sim: Simulation = s["sim"]
	_walls(sim, data.max_walls())
	assert_eq(sim.state.expansion.opened.size(), data.max_walls())
	_open(sim)
	assert_null(sim.state.expansion.screen)
	assert_eq(sim.state.expansion.opened.size(), data.max_walls())
	assert_eq(sim.state.expansion.pending, 0)


## Escolhe a primeira opção das telas de recompensa abertas até não sobrar nenhuma.
func _clear_rewards(sim: Simulation) -> void:
	for i in 40:
		if sim.state.rewards.screen == null:
			return
		sim.enqueue({"type": "chooseReward", "index": 0})
		_step(sim)


func test_wall_falls_after_the_reward() -> void:
	var s := _sim()
	var sim: Simulation = s["sim"]
	var wave: int = data.after_waves[0]
	sim.enqueue({"type": "debugSkipToWave", "wave": wave})
	_step(sim)
	_clear_rewards(sim)
	assert_eq(sim.state.expansion.opened.size(), 0, "as ondas antes da primeira parede não abrem nada")
	sim.enqueue({"type": "endWave"})
	_step(sim)
	assert_eq(sim.state.wave, wave)
	if sim.state.rewards.screen != null:
		assert_eq(sim.state.expansion.opened.size(), 0, "a recompensa vem antes")
		assert_eq(sim.state.expansion.pending, 1)
		sim.enqueue({"type": "chooseReward", "index": 0})
		_step(sim)
	assert_eq(sim.state.expansion.opened.size(), 1, "a parede da onda %d caiu" % wave)
	assert_eq(sim.state.expansion.opened_waves, [wave] as Array[int])


func test_skipping_to_wave_40_drops_every_wall_one_by_one() -> void:
	var s := _sim("moldes-pular")
	var sim: Simulation = s["sim"]
	sim.enqueue({"type": "debugSkipToWave", "wave": 40})
	_step(sim)
	var screens := 0
	for i in 200:
		if sim.state.rewards.screen != null:
			sim.enqueue({"type": "chooseReward", "index": 0})
		elif sim.state.expansion.screen != null:
			screens += 1
			sim.enqueue({"type": "chooseExpansion", "index": 0})
		elif sim.state.expansion.pending == 0 and sim.state.rewards.queue.is_empty():
			break
		_step(sim)
	assert_eq(sim.state.expansion.opened.size(), data.max_walls(), "todas as paredes caíram")
	assert_eq(screens, data.max_walls() - data.forward_only_walls, "cada uma depois das primeiras com a sua escolha")
	assert_eq(sim.state.expansion.opened_waves, data.after_waves)


func test_skip_with_a_wave_running_ends_it_first() -> void:
	var s := _sim("moldes-pular-andando")
	var sim: Simulation = s["sim"]
	sim.enqueue({"type": "callWave"})
	_step(sim, 30)
	assert_false(sim.state.waves.active.is_empty())
	# O que o painel manda: encerrar e pular no mesmo tick.
	sim.enqueue({"type": "endWave"})
	sim.enqueue({"type": "debugSkipToWave", "wave": 40})
	_step(sim)
	assert_true(sim.state.waves.active.is_empty())
	assert_eq(WaveState.next_wave_number(sim.state), 40, "a próxima a chamar é a 40")


func test_save_mid_run_restores_lines_and_enemies() -> void:
	var s := _sim("moldes-save")
	var sim: Simulation = s["sim"]
	var map: SimMap = s["map"]
	_walls(sim, data.forward_only_walls)
	_open(sim, true)
	_choose(sim, 1)
	sim.enqueue({"type": "callWave"})
	_step(sim, 60)
	_open(sim)
	_choose(sim, 0)
	_step(sim, 30)
	var text := sim.serialize()
	var map2 := data.build_map()
	var restored := RunStateIO.deserialize(text, map2)
	assert_not_null(restored)
	assert_eq(map2.entrance_count(), 2, "a segunda linha volta ao mapa novo")
	assert_eq(map2.path_cells, map.path_cells)
	assert_eq(map2.entrance_cell(1), map.entrance_cell(1))
	assert_eq(data.reserved_cells(map2.applied), data.reserved_cells(map.applied))
	var sim2 := Simulation.new(restored, GameSystems.create(map2))
	_step(sim, 90)
	_step(sim2, 90)
	assert_eq(sim2.serialize(), sim.serialize(), "continuar do save dá o mesmo resultado")


func test_split_flag_survives_the_save() -> void:
	var s := _sim("moldes-save-dividir")
	var sim: Simulation = s["sim"]
	sim.state.expansion.split_next = true
	var map2 := data.build_map()
	var restored := RunStateIO.deserialize(sim.serialize(), map2)
	assert_true(restored.expansion.split_next)


func test_map_that_does_not_grow_has_no_expansion() -> void:
	var map := SimMap.load_map(DataLoader.load_json("map.json"))
	var sim := Simulation.create("sem-salas", GameSystems.create(map))
	sim.enqueue({"type": "debugOpenExpansion"})
	_step(sim, 2)
	assert_null(sim.state.expansion.screen)
	assert_true(map.can_place_tower(Vector2i(5, 0)), "o mapa que não cresce continua todo aberto")
	assert_false(sim.serialize().contains("\"expansion\""), "o save dele não muda")


func test_option_names_and_run_report() -> void:
	assert_eq(data.option_name("0:direita:s:reto"), "Seguir para a direita")
	assert_eq(data.option_name("1:baixo:u:u-largo~"), "Linha 2: Abrir para baixo")
	assert_eq(data.option_name("0:direita:s:reto+n:cima:reto:reto"), "Dividir: Seguir para a direita + Abrir para cima")
	var s := _sim("moldes-relatorio")
	var sim: Simulation = s["sim"]
	sim.state.expansion.opened.assign(["0:direita:s:reto", "0:cima:gancho~:u-largo"])
	sim.state.expansion.opened_waves.assign([5, 15])
	var report := RunReport.summarize(sim.state, {
		"version": "teste", "total_waves": 40, "ticks_per_second": 60.0,
		"tower_name": func(type: String) -> String: return type,
		"reward_name": func(id: String, _class_id: Variant) -> String: return id,
		"room_name": func(id: String) -> String: return data.option_name(id),
	})
	assert_eq(report.rooms, ["Onda 5: Seguir para a direita", "Onda 15: Abrir para cima"] as Array[String])
	assert_string_contains(report.format(), "Paredes (2): Onda 5: Seguir para a direita")


func test_invalid_openings_are_refused() -> void:
	assert_null(data.opening([], "0:cima:gancho:reto"), "nas primeiras paredes só para a frente")
	assert_null(data.opening([], "0:direita:nao-existe:reto"))
	assert_null(data.opening([], "0:esquerda:reto:reto"), "nunca para o lado do núcleo")
	assert_null(data.opening([], "lixo"))
	assert_not_null(data.opening([], "0:direita:u~:u-pequeno"))
	assert_not_null(data.opening([], "0:direita:reto:reto+n:cima:reto:reto"), "dividir ignora as primeiras paredes")
	assert_null(data.opening([], "0:direita:reto:reto+n:cima:reto~:reto"), "o molde do lado precisa sair pelo lado escolhido")


func test_bad_data_is_rejected() -> void:
	var raw: Dictionary = DataLoader.load_json("expansion.json")
	var even := raw.duplicate(true)
	even["pieceSize"] = 10
	assert_null(ExpansionData.load_data(even))
	assert_push_error("ímpar")
	var diagonal := raw.duplicate(true)
	diagonal["molds"]["forward"][0]["points"] = [[5, 5], [10, 6]]
	assert_null(ExpansionData.load_data(diagonal))
	assert_push_error("molde")
	var wrong_end := raw.duplicate(true)
	wrong_end["molds"]["side"][0]["points"] = [[5, 5], [10, 5]]
	assert_null(ExpansionData.load_data(wrong_end))
	assert_push_error("molde")
