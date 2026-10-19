class_name WaveBot
extends RefCounted
## Bot simples para jogar uma run inteira no mapa real (porte de tests/support/waveBot.ts): entre as
## ondas compra o que dá (fusão primeiro, depois a torre mais cara que couber), evolui o núcleo
## quando o limite enche, rerola um pouco, e chama a próxima onda. Na tela de recompensa pega
## sempre a primeira carta. Não é para jogar bem: é para garantir que as 40 ondas terminam sem erro
## e para medir as ondas com torres de verdade matando — e, comparado com o Phaser nas mesmas
## sementes, provar a paridade da simulação inteira.

## Rerolls por pausa entre ondas.
const REROLLS_PER_BREAK := 2
## Ouro que o bot guarda além do reroll (para os juros e a próxima compra).
const REROLL_RESERVE := 10
## Teto de ticks de uma onda (as últimas passam de 100 s; o chefão final leva 76 s só de caminho).
const MAX_WAVE_TICKS := 30 * 60 * 8

static var _bot_map: SimMap = null
static var _cells: Array[Vector2i] = []
## Contagem de TODOS os eventos drenados pelo bot (para comparar com o Phaser): tipo -> int.
static var tally: Dictionary = {}


static func bot_map() -> SimMap:
	if _bot_map == null:
		_bot_map = SimMap.load_map(DataLoader.load_json("map.json"))
		_cells = bot_cells(_bot_map)
	return _bot_map


static func total_waves() -> int:
	return WaveData.game_data().waves.size()


## Casas de torre, das que veem mais casas do caminho (alcance 3) para as que veem menos.
## Empate: ordem original da grade (o sort do JS é estável; o do Godot não, então o desempate é explícito).
static func bot_cells(map: SimMap) -> Array[Vector2i]:
	var scored: Array = []
	for y in map.height:
		for x in map.width:
			if not map.can_place_tower(Vector2i(x, y)):
				continue
			var score := 0
			for p in map.path_cells:
				if SimMath.hypot(float(p.x - x), float(p.y - y)) <= 3.0:
					score += 1
			scored.append({"cell": Vector2i(x, y), "score": score, "i": scored.size()})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["score"] > b["score"] or (a["score"] == b["score"] and a["i"] < b["i"]))
	var out: Array[Vector2i] = []
	for s in scored:
		out.append(s["cell"])
	return out


## Recompensas desligadas (nenhuma onda abre a tela): marcos e comparação "sem recompensas".
static func no_rewards() -> RewardData:
	var base := RewardData.game_data()
	var data := RewardData.new()
	data.choices = base.choices
	data.choose_seconds = base.choose_seconds
	data.reroll_base_cost = base.reroll_base_cost
	data.reroll_cost_step = base.reroll_cost_step
	data.rewards = base.rewards
	data.by_id = base.by_id
	return data


static func bot_sim(seed_text: String, nexus_invulnerable: bool = false, options: Dictionary = {}) -> Simulation:
	var sim := Simulation.create(seed_text, GameSystems.create(bot_map(), options), options.get("economy"))
	if nexus_invulnerable:
		sim.enqueue({"type": "debugSetNexusInvulnerable", "value": true})
	return sim


static func _free_cell(sim: Simulation) -> Variant:
	bot_map()
	var used := {}
	for t: Tower in sim.state.towers:
		used[_bot_map.index_of(Vector2i(t.x, t.y))] = true
	for c in _cells:
		if not used.has(_bot_map.index_of(c)):
			return c
	return null


## Preço do slot com desconto; INF se não for torre de loja.
static func _price(sim: Simulation, type: String) -> float:
	var p := Shop.shop_price(EconomyData.game_data(), TowerData.game_data(), sim.state, type)
	return INF if p < 0 else float(p)


## Uma ação da pausa entre ondas, já enfileirada; false = nada mais a fazer.
static func _bot_action(sim: Simulation, rerolls: Dictionary) -> bool:
	var state = sim.state
	var towers := TowerData.game_data()
	var slots: Array = []
	for slot in state.shop.slots.size():
		var type: Variant = state.shop.slots[slot]
		if type == null:
			continue
		var price := _price(sim, type)
		if price <= state.gold:
			slots.append({"type": type, "slot": slot, "price": price})
	var fusing: Variant = null
	for s: Dictionary in slots:
		if Fusion.plan_fusion(state.towers, towers, s["type"]) != null:
			fusing = s
			break
	if fusing != null:
		sim.enqueue({"type": "buyTower", "slot": fusing["slot"]})
		return true
	var cell: Variant = _free_cell(sim)
	if cell != null and TowerLimit.has_room_for_tower(state) and not slots.is_empty():
		var best: Dictionary = slots[0]
		for s: Dictionary in slots:
			if s["price"] > best["price"]:
				best = s
		sim.enqueue({"type": "buyTower", "slot": best["slot"], "x": cell.x, "y": cell.y})
		return true
	var nexus := NexusData.game_data()
	var level: int = state.nexus.level
	if not TowerLimit.has_room_for_tower(state) and float(level) < nexus.max_level() \
			and state.gold >= nexus.level_data(level + 1).cost:
		sim.enqueue({"type": "evolveNexus"})
		return true
	if rerolls["left"] > 0 and state.gold >= Shop.shop_reroll_cost(EconomyData.game_data(), state) + REROLL_RESERVE:
		rerolls["left"] -= 1
		sim.enqueue({"type": "rerollShop"})
		return true
	return false


## Tela de recompensa do bot simples: a primeira carta.
static func first_reward(sim: Simulation) -> void:
	sim.enqueue({"type": "chooseReward", "index": 0})


## Resolve as telas de recompensa abertas (e as da fila), uma ação por tick. Se `on_reward` não
## fizer nada, o tempo da tela acaba e a simulação escolhe.
static func resolve_rewards(sim: Simulation, on_reward: Callable) -> void:
	var guard := 0
	while guard < 10000 and sim.state.rewards.screen_open():
		if sim.state.status != "playing":
			return
		on_reward.call(sim)
		sim.step()
		guard += 1


## A pausa entre ondas: age até não ter mais o que fazer (um tick por ação).
static func bot_break(sim: Simulation) -> void:
	var rerolls := {"left": REROLLS_PER_BREAK}
	var guard := 0
	while guard < 100 and _bot_action(sim, rerolls):
		sim.step()
		guard += 1


## Chama a próxima onda e roda até ela acabar (ou a run terminar). Devolve as medidas da onda.
## Tela de recompensa aberta no meio da onda: `on_reward`.
static func play_wave(sim: Simulation, on_reward: Callable = Callable()) -> Dictionary:
	if not on_reward.is_valid():
		on_reward = first_reward
	resolve_rewards(sim, on_reward)
	var wave: int = sim.state.wave + 1
	var start: int = sim.state.tick
	var dropped_before: int = sim.state.triggers.dropped_total
	var kills_before: int = sim.state.stats.kills
	sim.enqueue({"type": "callWave"})
	sim.step()
	var m := {"peak": 0, "max_depth": 0, "peak_triggers": 0, "peak_enemies": 0}
	_observe(sim, m)
	var i := 0
	while i < MAX_WAVE_TICKS and not sim.state.waves.active.is_empty():
		if sim.state.status != "playing":
			break
		if sim.state.rewards.screen_open():
			on_reward.call(sim)
		sim.step()
		_observe(sim, m)
		i += 1
	return {
		"wave": wave,
		"ticks": sim.state.tick - start,
		"kills": sim.state.stats.kills - kills_before,
		"peakKillsPerTick": m["peak"],
		"dropped": sim.state.triggers.dropped_total - dropped_before,
		"maxDepth": m["max_depth"],
		"peakTriggersPerTick": m["peak_triggers"],
		"towers": sim.state.towers.size(),
		"nexusHp": sim.state.nexus.hp,
		"peakEnemies": m["peak_enemies"],
		"goldEarned": sim.state.stats.gold_earned,
		"gold": sim.state.gold,
		"chainGold": sim.state.stats.chain_gold,
		"longestChain": sim.state.stats.longest_chain,
		"nexusLevel": sim.state.nexus.level,
	}


static func _observe(sim: Simulation, m: Dictionary) -> void:
	m["peak_enemies"] = maxi(m["peak_enemies"], sim.state.enemies.active_count)
	var kills := 0
	for event: Dictionary in drain(sim):
		if event["type"] == "enemyKilled":
			kills += 1
	m["peak"] = maxi(m["peak"], kills)
	var last: TriggerState.TriggerTickStats = sim.state.triggers.last_tick
	m["max_depth"] = maxi(m["max_depth"], last.max_depth)
	m["peak_triggers"] = maxi(m["peak_triggers"], last.fired)


## Run inteira: telas de recompensa, pausa do bot, onda, até a vitória, a derrota ou a última onda.
static func play_run(sim: Simulation, on_break: Callable = Callable(), on_reward: Callable = Callable()) -> Array:
	if not on_break.is_valid():
		on_break = bot_break
	if not on_reward.is_valid():
		on_reward = first_reward
	var reports: Array = []
	var total := total_waves()
	while sim.state.status == "playing" and sim.state.wave < total:
		resolve_rewards(sim, on_reward)
		on_break.call(sim)
		drain(sim)
		reports.append(play_wave(sim, on_reward))
	return reports


## Drena os eventos da simulação contando cada tipo em `tally`.
static func drain(sim: Simulation) -> Array:
	var events := sim.drain_events()
	for event: Dictionary in events:
		tally[event["type"]] = tally.get(event["type"], 0) + 1
	return events


## Para o modo `--demo` do jogo: a cada chamada faz UMA ação do bot (comprar, evoluir, rerolar,
## escolher recompensa) ou, sem nada a fazer e sem onda em andamento, chama a próxima onda.
static func drive_for_demo(sim: Simulation) -> void:
	var state = sim.state
	if state.status != "playing":
		return
	if state.rewards.screen_open():
		sim.enqueue({"type": "chooseReward", "index": 0})
		return
	if not state.waves.active.is_empty():
		return
	if state.towers.size() < 8 and _bot_action(sim, {"left": 0}):
		return
	sim.enqueue({"type": "callWave"})
