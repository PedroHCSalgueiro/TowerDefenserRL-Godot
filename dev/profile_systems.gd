extends SceneTree
## Perfil por sistema da simulação (sem renderização): roda o cenário de estresse (30 torres do cenário
## "fullScenario" do conjunto em ★2, 1.000 inimigos) e imprime o tempo total e o máximo de cada sistema.
##   godot --headless --path . -s dev/profile_systems.gd -- --set=costarubra


func _names(towers: TowerData) -> Array:
	var names := ["tickIndex", "rewardClock", "commands", "rewardTimeout", "waveSpawn", "stress", "movement",
			"nexusContact", "nexusAttack", "projectiles", "towers"]
	if towers.uses_statuses():
		names.append("status")
	if towers.uses_traps():
		names.append("traps")
	names.append_array(["triggers", "gold", "waveProgress", "rewardOpen", "classes"])
	return names


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--set="):
			GameSets.select(arg.trim_prefix("--set="))
	var map := SimMap.load_map(DataLoader.load_json("map.json"))
	var systems: Array = GameSystems.create(map)
	var names := _names(TowerData.game_data())
	var totals := PackedFloat64Array()
	var maxes := PackedFloat64Array()
	totals.resize(systems.size())
	maxes.resize(systems.size())
	var wrapped: Array = []
	for i in systems.size():
		var system: Callable = systems[i]
		var index := i
		var timed := func(ctx: TickContext) -> void:
			var t0 := Time.get_ticks_usec()
			system.call(ctx)
			var dt := (Time.get_ticks_usec() - t0) / 1000.0
			totals[index] += dt
			maxes[index] = maxf(maxes[index], dt)
		wrapped.append(timed)
	var sim := Simulation.new(RunState.create("perf"), wrapped)
	var cfg: Dictionary = DataLoader.load_json("debug.json")
	sim.enqueue({"type": "debugSetNexusInvulnerable", "value": true})
	sim.enqueue({"type": "debugSpawnTowers", "count": 30, "towerTypes": cfg["fullScenario"]["towerTypes"], "layout": "clustered", "star": 2})
	sim.enqueue({"type": "debugSetStress", "stress": {"count": 1000, "layout": "spread"}})
	var ticks := 600
	var t_all := Time.get_ticks_usec()
	var per_tick: Array = []
	for i in ticks:
		var t0 := Time.get_ticks_usec()
		sim.step()
		per_tick.append([(Time.get_ticks_usec() - t0) / 1000.0, i])
		sim.drain_events()
	per_tick.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	print("Conjunto: %s" % GameSets.current())
	print("Piores ticks (ms, índice): ", per_tick.slice(0, 6))
	var wall := (Time.get_ticks_usec() - t_all) / 1000.0
	print("Total: %.1f ms em %d ticks (%.3f ms/tick)" % [wall, ticks, wall / ticks])
	print("Gatilhos descartados: %d" % sim.state.triggers.dropped_total)
	for i in systems.size():
		var label: String = names[i] if i < names.size() else "sistema %d" % i
		print("%-14s total %8.1f ms  médio %6.3f  máx %7.2f" % [label, totals[i], totals[i] / ticks, maxes[i]])
	quit()
