extends SceneTree
## Bancada dos heróis (parte do agente testador): cada herói de loja do conjunto defende sozinho, com
## `--copies` cópias em ★`--star` nas melhores casas do mapa (as mesmas para todos), sem loja nem núcleo
## evoluído, chamando as ondas uma de cada vez até perder ou vencer. Mede a força de cada herói isolado,
## num número comparável entre regiões: a onda alcançada, o dano e os abates.
##
##   godot --headless --path . -s dev/hero_bench.gd -- --set=costarubra --copies=4 --star=2 --seeds=2 --out=arquivo.json
##
## Roda no mapa que cresce (`--map=fixed` usa o de `data/map.json`; `--walls=`, ver `WaveBot.WALL_POLICIES`): as
## torres ficam nas melhores casas da base e as paredes abrem como no jogo, sem torre nova nos pedaços novos.
##
## Suportes e quem depende de vizinhas (auras, "vizinha abate", "ao ser ativado") rendem menos aqui por
## natureza: o relatório (`tools/playtest/agent_report.js`) não os marca como fracos só por isso.

const MAX_WAVE_TICKS := 30 * 60 * 5
const MAX_WAVE_TICKS_GROWING := 30 * 60 * 40


func _init() -> void:
	var args := _parse_args()
	var set_id: String = args.get("set", "valcoroa")
	if not GameSets.select(set_id):
		quit(1)
		return
	WaveBot.use_growing_map(args.get("map", "growing") != "fixed", args.get("walls", "auto"))
	var copies := int(args.get("copies", "4"))
	var star := int(args.get("star", "2"))
	var seeds := int(args.get("seeds", "2"))
	var out_path: String = args.get("out", "user://bench.json")
	var only: Array = String(args.get("heroes", "")).split(",", false)
	var towers := TowerData.game_data()
	var classes := ClassData.game_data()
	var results: Array = []
	for id: String in towers.types:
		var type: TowerData.TowerType = towers.types[id]
		if type.rarity == null or (not only.is_empty() and not only.has(id)):
			continue
		var runs: Array = []
		for s in seeds:
			runs.append(_bench(id, copies, star, "bench-%s-%d" % [id, s]))
		var waves: Array = runs.map(func(r: Dictionary) -> int: return r["wave"])
		var result := {
			"set": set_id,
			"hero": id,
			"name": type.name,
			"class": type.classes[0],
			"region": type.classes[1],
			"className": classes.classes[type.classes[0]].name,
			"rarity": type.rarity,
			"needsNeighbors": _needs_neighbors(type),
			"wave": _mean(waves),
			"waves": waves,
			"damage": _mean(runs.map(func(r: Dictionary) -> float: return r["damage"])),
			"kills": _mean(runs.map(func(r: Dictionary) -> int: return r["kills"])),
			"seconds": _mean(runs.map(func(r: Dictionary) -> float: return r["seconds"])),
			"dropped": runs.map(func(r: Dictionary) -> int: return r["dropped"]).reduce(func(a: int, b: int) -> int: return a + b, 0),
		}
		results.append(result)
		print("[bench] %s %-28s onda %5.1f  dano %9.0f  abates %5.0f" % [set_id, type.name, result["wave"], result["damage"], result["kills"]])
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(results))
	file.close()
	quit()


## O herói rende pelo que faz com as vizinhas (aura, "vizinha abate", "ao ser ativado")? A bancada não
## mede isso direito.
static func _needs_neighbors(type: TowerData.TowerType) -> bool:
	if not type.aura.is_empty():
		return true
	if type.trigger == null:
		return false
	var when: String = type.trigger.stars[0].when["kind"]
	return when == "onActivated" or when == "neighborKills"


static func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for v in values:
		total += float(v)
	return total / float(values.size())


func _parse_args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		var clean := arg.trim_prefix("--")
		if clean.contains("="):
			var parts := clean.split("=", true, 1)
			out[parts[0]] = parts[1]
		else:
			out[clean] = true
	return out


## Uma run da bancada: `copies` torres do herói nas melhores casas, ondas uma a uma até o fim.
func _bench(hero: String, copies: int, star: int, seed_text: String) -> Dictionary:
	var map := WaveBot.new_run_map()
	var sim := Simulation.create(seed_text, GameSystems.create(map))
	var state: RunState = sim.state
	var cells := WaveBot.bot_cells(map)
	for i in copies:
		sim.enqueue({"type": "placeTower", "towerType": hero, "x": cells[i].x, "y": cells[i].y, "star": star})
	sim.step()
	sim.drain_events()
	# As torres postas pelo debug não ligam a trapaça para a bancada: o que interessa é a defesa.
	Damage.track = true
	Damage.dealt = {}
	var kills := 0
	var total := WaveBot.total_waves()
	var limit := MAX_WAVE_TICKS_GROWING if WaveBot.growing else MAX_WAVE_TICKS
	var timed_out := false
	while state.status == "playing" and state.wave < total:
		WaveBot.resolve_rewards(sim, WaveBot.first_reward)
		sim.drain_events()
		if state.status != "playing":
			break
		sim.enqueue({"type": "callWave"})
		sim.step()
		var guard := 0
		while state.status == "playing" and not state.waves.active.is_empty() and guard < limit:
			if state.rewards.screen_open():
				sim.enqueue({"type": "chooseReward", "index": 0})
			elif state.expansion.screen_open():
				WaveBot.choose_wall(sim)
			sim.step()
			for e: Dictionary in sim.drain_events():
				if e["type"] == "enemyKilled":
					kills += 1
			guard += 1
		if guard >= limit:
			timed_out = true
			break
	Damage.track = false
	var damage := 0.0
	for who in Damage.dealt:
		if who != -1:
			damage += Damage.dealt[who]
	return {"wave": state.wave, "damage": damage, "kills": kills, "seconds": float(state.tick) / 30.0,
			"dropped": state.triggers.dropped_total, "path": map.path_cells.size(), "timedOut": timed_out}
