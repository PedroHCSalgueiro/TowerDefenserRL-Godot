extends GutTest
## Porte de tests/simulation.test.ts (sem as partes que dependem de serialização do
## RunState, que entram com `sim/state.gd`) + testes do congelamento da tela de
## recompensa + paridade com o Phaser (tests/golden/simulation.json).

var _config := {"ticksPerSecond": 30, "speeds": [1, 2, 3], "maxTicksPerFrame": 1000}


func _sim(seed_text: String, systems: Array = [EngineTestSystem.system]) -> Simulation:
	return Simulation.new(TestRunState.new(seed_text), systems)


func test_mesma_semente_mesmas_acoes_mesmo_estado_apos_n_ticks() -> void:
	var a := _sim("seed-1")
	var b := _sim("seed-1")
	var events_a := EngineTestSystem.run_with_actions(a, 500)
	var events_b := EngineTestSystem.run_with_actions(b, 500)

	assert_eq(a.state.tick, 500)
	assert_eq(a.state.rng_state, b.state.rng_state)
	assert_eq(a.state.next_entity_id, b.state.next_entity_id)
	assert_eq(events_a, events_b)
	assert_gt(events_a.size(), 0)


func test_sementes_diferentes_divergem() -> void:
	var a := _sim("seed-1")
	var b := _sim("seed-2")
	EngineTestSystem.run_with_actions(a, 200)
	EngineTestSystem.run_with_actions(b, 200)
	assert_ne(a.state.rng_state, b.state.rng_state)


func test_os_eventos_levam_o_tick_em_que_aconteceram() -> void:
	var sim := _sim("ticks")
	sim.enqueue({"type": "spawnEnemy", "enemyType": "common"})
	sim.step()
	var first: Dictionary = sim.drain_events()[0]
	assert_eq(first["type"], "enemySpawned")
	assert_eq(first["tick"], 1)


func test_acoes_enfileiradas_sao_consumidas_no_proximo_tick() -> void:
	var sim := _sim("queue")
	sim.enqueue({"type": "spawnEnemy", "enemyType": "common"})
	assert_eq(sim.state.command_queue.size(), 1)
	sim.step()
	assert_eq(sim.state.command_queue.size(), 0)


func test_run_perdida_ou_vencida_fica_congelada() -> void:
	for status in ["lost", "won"]:
		var sim := _sim("end")
		sim.state.status = status
		sim.step()
		assert_eq(sim.state.tick, 0, "status %s" % status)


func test_assinante_recebe_eventos_no_drain() -> void:
	var sim := _sim("on")
	var received: Array = []
	sim.on("enemySpawned", func(event: Dictionary) -> void: received.append(event["enemyId"]))
	sim.enqueue({"type": "spawnEnemy", "enemyType": "common"})
	sim.step()
	assert_eq(received, [])
	sim.drain_events()
	assert_eq(received.size(), 1)


# ---------------------------------------------------------------- tela de recompensa (T24)

static func _frozen_system(ctx: TickContext) -> void:
	ctx.emit({"type": "goldChanged", "tick": ctx.state.tick, "gold": 0, "delta": 0})


static func _normal_system(ctx: TickContext) -> void:
	ctx.emit({"type": "enemySpawned", "tick": ctx.state.tick, "enemyId": ctx.allocate_id(), "enemyType": "common"})


func test_tela_de_recompensa_congela_o_tick_e_so_roda_sistemas_marcados() -> void:
	var safe := Simulation.runs_while_frozen(_frozen_system)
	var sim := _sim("frozen", [safe, _normal_system])

	sim.step()
	assert_eq(sim.state.tick, 1)
	var types: Array = sim.drain_events().map(func(e: Dictionary) -> String: return e["type"])
	assert_eq(types, ["goldChanged", "enemySpawned"])

	sim.state.rewards.screen = {"wave": 10}
	assert_true(Simulation.is_frozen(sim.state))
	sim.step()
	assert_eq(sim.state.tick, 1, "o tick não anda congelado")
	types = sim.drain_events().map(func(e: Dictionary) -> String: return e["type"])
	assert_eq(types, ["goldChanged"], "só o sistema marcado roda")

	sim.state.rewards.screen = null
	sim.step()
	assert_eq(sim.state.tick, 2)


# ---------------------------------------------------------------- SimulationRunner

func test_runner_converte_tempo_real_em_ticks_e_expoe_alpha() -> void:
	var runner := SimulationRunner.new(_sim("runner", []), _config)
	runner.update(1000.0)
	assert_eq(runner.sim.state.tick, 30)
	runner.update(20.0)
	assert_eq(runner.sim.state.tick, 30)
	assert_almost_eq(runner.alpha, 0.6, 0.0001)


func test_runner_resultado_nao_depende_da_velocidade_nem_do_tamanho_dos_quadros() -> void:
	var slow := SimulationRunner.new(_sim("speed"), _config)
	var fast := SimulationRunner.new(_sim("speed"), _config)
	fast.clock.set_speed(3.0)
	for i in 300:
		slow.update(1000.0 / 60.0)
	for i in 50:
		fast.update(2000.0 / 60.0)
	assert_eq(slow.sim.state.tick, 150)
	assert_eq(fast.sim.state.tick, slow.sim.state.tick)
	assert_eq(fast.sim.state.rng_state, slow.sim.state.rng_state)
	assert_eq(fast.sim.state.next_entity_id, slow.sim.state.next_entity_id)


class FakeProfiler:
	extends RefCounted
	var clock := 0.0
	var durations: Array = []

	func now() -> float:
		clock += 0.5
		return clock

	func record_tick(ms: float) -> void:
		durations.append(ms)


func test_runner_mede_cada_tick_sem_mudar_o_resultado() -> void:
	var profiler := FakeProfiler.new()
	var measured := SimulationRunner.new(_sim("prof"), _config)
	measured.profiler = profiler
	var plain := SimulationRunner.new(_sim("prof"), _config)

	measured.update(1000.0 / 10.0)
	plain.update(1000.0 / 10.0)
	assert_eq(profiler.durations, [0.5, 0.5, 0.5])
	assert_eq(measured.sim.state.rng_state, plain.sim.state.rng_state)


func test_runner_pausado_nao_roda_ticks_nem_acumula_tempo() -> void:
	var runner := SimulationRunner.new(_sim("pause", []), _config)
	runner.paused = true
	runner.update(1000.0)
	assert_eq(runner.sim.state.tick, 0)
	runner.paused = false
	runner.update(1000.0 / 30.0)
	assert_eq(runner.sim.state.tick, 1)


func test_runner_com_tela_aberta_anda_na_velocidade_base() -> void:
	var runner := SimulationRunner.new(_sim("rw", [Simulation.runs_while_frozen(_frozen_system)]), _config)
	runner.clock.set_speed(3.0)
	runner.update(1000.0)
	assert_eq(runner.sim.state.tick, 90, "3x normal")
	runner.sim.state.rewards.screen = {"wave": 10}
	runner.update(1000.0)
	assert_eq(runner.sim.state.tick, 90, "congelado: o tick não anda")
	assert_almost_eq(runner.clock.alpha, 0.0, 0.0001)


func test_runner_usa_engine_json_por_padrao() -> void:
	var runner := SimulationRunner.new(_sim("default", []))
	runner.update(1000.0 / 30.0 * 5.0)  # 5 ticks devidos
	assert_eq(runner.sim.state.tick, 5)
	runner.update(1000.0)  # 30 devidos, mas o teto de data/engine.json é 12 por quadro
	assert_eq(runner.sim.state.tick, 5 + 12)


# ---------------------------------------------------------------- paridade com o Phaser

func test_golden_simulacao_com_sistema_de_teste() -> void:
	var golden: Dictionary = Golden.load_json("simulation.json")
	for run: Dictionary in golden["runs"]:
		var sim := _sim(run["seed"])
		var events := EngineTestSystem.run_with_actions(sim, int(run["ticks"]))
		var got: Array = events.map(func(e: Dictionary) -> Array: return [e["tick"], e["enemyId"]])
		var expected: Array = []
		for pair in run["events"]:
			expected.append([int(pair[0]), int(pair[1])])
		assert_eq(got, expected, "eventos da semente '%s'" % run["seed"])
		assert_eq(sim.state.tick, int(run["tick"]))
		assert_eq(sim.state.rng_state, int(run["rngState"]), "rng_state da semente '%s'" % run["seed"])
		assert_eq(sim.state.next_entity_id, int(run["nextEntityId"]))


func test_golden_runner() -> void:
	var golden: Dictionary = Golden.load_json("simulation.json")
	for s: Dictionary in golden["runners"]:
		var runner := SimulationRunner.new(_sim(s["seed"]), golden["config"])
		runner.clock.set_speed(float(s["speed"]))
		for i in int(s["frames"]):
			runner.update(float(s["deltaNumerator"]) / float(s["deltaDenominator"]))
		assert_eq(runner.sim.state.tick, int(s["tick"]), s["name"])
		assert_eq(runner.sim.state.rng_state, int(s["rngState"]), s["name"])
		assert_eq(runner.sim.state.next_entity_id, int(s["nextEntityId"]), s["name"])
