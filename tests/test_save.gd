extends GutTest
## Salvar e restaurar a run: o estado volta idêntico e, depois de restaurar, a simulação segue
## EXATAMENTE como seguiria sem a pausa (mesmos eventos, mesmo estado final).

const CHAIN := ["mortar", "reaper", "relay", "obelisk", "ballista", "clock", "executioner", "mirror"]


func _map() -> SimMap:
	return SimMap.load_map(DataLoader.load_json("map.json"))


func _scenario_commands() -> Array:
	return [
		{"type": "debugSetNexusInvulnerable", "value": true},
		{"type": "debugSpawnTowers", "count": 16, "towerTypes": CHAIN, "layout": "clustered", "star": 2},
		{"type": "debugSetStress", "stress": {"count": 300, "layout": "spread"}},
		{"type": "debugAddGold", "amount": 100},
	]


func _tally(events: Array, into: Dictionary) -> void:
	for e: Dictionary in events:
		into[e["type"]] = into.get(e["type"], 0) + 1


func _run(sim: Simulation, ticks: int, tally: Dictionary) -> void:
	for i in ticks:
		sim.step()
		_tally(sim.drain_events(), tally)


func test_estado_inicial_ida_e_volta() -> void:
	var map := _map()
	var sim := Simulation.create("save-inicial", GameSystems.create(map))
	var text := sim.serialize()
	var restored := Simulation.restore(text, GameSystems.create(map), map)
	assert_not_null(restored)
	assert_eq(restored.serialize(), text, "salvar o restaurado dá o mesmo texto")
	assert_eq(restored.state.gold, 10)
	assert_eq(restored.state.shop.slots, sim.state.shop.slots)


func test_run_no_meio_ida_e_volta_exata() -> void:
	var map := _map()
	var sim := Simulation.create("save-meio", GameSystems.create(map))
	for c in _scenario_commands():
		sim.enqueue(c)
	sim.enqueue({"type": "callWave"})
	_run(sim, 400, {})
	assert_gt(sim.state.enemies.active_count, 50, "há inimigos no mapa")
	assert_gt(sim.state.projectiles.active_count + sim.state.triggers.queue.size() + sim.state.stats.kills, 0)
	var text := sim.serialize()
	var restored := Simulation.restore(text, GameSystems.create(map), map)
	assert_eq(restored.serialize(), text, "estado restaurado idêntico, bit a bit")


func test_continuar_depois_de_restaurar_e_igual_a_nao_ter_parado() -> void:
	var map := _map()
	var straight := Simulation.create("save-continua", GameSystems.create(map))
	var first := Simulation.create("save-continua", GameSystems.create(map))
	for sim in [straight, first]:
		for c in _scenario_commands():
			sim.enqueue(c.duplicate(true))
		sim.enqueue({"type": "callWave"})
	var tally_straight := {}
	_run(straight, 700, tally_straight)

	var tally_split := {}
	_run(first, 350, tally_split)
	var restored := Simulation.restore(first.serialize(), GameSystems.create(map), map)
	_run(restored, 350, tally_split)

	assert_eq(tally_split, tally_straight, "mesmos eventos")
	assert_eq(restored.serialize(), straight.serialize(), "mesmo estado final")


func test_save_com_tela_de_recompensa_aberta() -> void:
	var map := _map()
	var sim := Simulation.create("save-recompensa", GameSystems.create(map))
	sim.enqueue({"type": "debugOpenReward"})
	_run(sim, 5, {})
	assert_true(sim.state.rewards.screen_open())
	var restored := Simulation.restore(sim.serialize(), GameSystems.create(map), map)
	assert_true(restored.state.rewards.screen_open())
	restored.enqueue({"type": "chooseReward", "index": 0})
	_run(restored, 3, {})
	assert_false(restored.state.rewards.screen_open())
	assert_eq(restored.state.rewards.taken.size(), 1)


func test_rejeita_save_invalido() -> void:
	var map := _map()
	var sim := Simulation.create("save-ruim", GameSystems.create(map))
	var d := RunStateIO.to_dict(sim.state)
	d["version"] = 14
	assert_null(RunStateIO.from_dict(d, map))
	assert_push_error("versão")
	assert_null(RunStateIO.deserialize("isto não é json", map))
	assert_push_error("ilegível")
	d = RunStateIO.to_dict(sim.state)
	d["status"] = "perdido"
	assert_null(RunStateIO.from_dict(d, map))
	assert_push_error("status")
