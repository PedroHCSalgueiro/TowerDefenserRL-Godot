extends SceneTree
## Playtest em lote com bots: joga várias runs inteiras e grava as medidas de cada uma em JSON (o
## relatório sai de `tools/playtest/report.js`).
##
##   godot --headless --path . -s dev/playtest.gd -- --set=valcoroa --policy=sequential --from=0 --count=20 --out=arquivo.json
##
## Políticas:
##   sequential: o jogador clássico. Entre as ondas compra, evolui o núcleo e rerola um pouco; depois chama
##               a próxima onda e só chama outra quando a anterior acabou.
##   stack:      o jogador apressado. Chama uma onda nova a cada `--interval` ticks (padrão 600 = 20 s), com as
##               anteriores ainda em andamento, e compra durante as ondas.
##   lazy:       o jogador que quase não joga (como no relato do Pedro): compra só até o limite de torres do núcleo
##               (prefere Sir Aldric, depois Irmão Tomás, depois Lyra), funde quando dá, põe as torres lado a lado,
##               nunca rerola nem evolui o núcleo e chama as ondas uma de cada vez.
## Ondas de chefão só podem ser chamadas com o mapa vazio (regra do jogo), então o empilhamento para nelas.

const MAX_TICKS := 30 * 60 * 60  # 1 hora de jogo: teto de segurança
const STACK_CHECK_TICKS := 30

var _id_to_type: Dictionary = {}


func _init() -> void:
	var args := _parse_args()
	var set_id: String = args.get("set", "valcoroa")
	if not GameSets.select(set_id):
		quit(1)
		return
	# Varredura de balanço: sobrescreve o ouro por abate (base, por degrau e tamanho do degrau) sem mexer nos dados.
	var economy := EconomyData.game_data()
	if args.has("kill-base"):
		economy.kill_gold_base = int(args["kill-base"])
	if args.has("kill-per"):
		economy.kill_gold_per_wave = int(args["kill-per"])
	if args.has("kill-step"):
		economy.kill_gold_wave_step = int(args["kill-step"])
	# `--brom=old|mid`: valores antigos do Mestre Brom (dano, raio e dano da bola carregada), para isolar o efeito.
	if args.has("brom") and args["brom"] != "new":
		var brom: TowerData.TowerType = TowerData.game_data().get_type("brom")
		var presets := {"old": [8.0, 1.5, [200.0, 250.0, 250.0], [1.5, 1.5, 1.75]], "mid": [7.0, 1.25, [175.0, 225.0, 225.0], [1.25, 1.25, 1.5]]}
		var p: Array = presets.get(args["brom"], presets["old"])
		brom.damage = p[0]
		for i in brom.trigger.stars.size():
			brom.trigger.stars[i].effect["damagePercent"] = p[2][i]
			brom.trigger.stars[i].effect["radiusMultiplier"] = p[3][i]
	# `--buff=aldric:1.4,mabel:1.4`: multiplica o dano dos heróis (varredura de balanço).
	if args.has("buff"):
		for pair: String in String(args["buff"]).split(","):
			var parts := pair.split(":")
			TowerData.game_data().get_type(parts[0]).damage *= float(parts[1])
	# Varredura de dificuldade da vida das ondas: `--hp=3:1.3,12:2.0,25:1.8` troca a curva de pontos (`none` = sem curva)
	# e `--growth=0.05` o crescimento exponencial por onda. Com `--growth` sem `--hp`, a curva de pontos sai.
	if args.has("hp") or args.has("growth"):
		var waves := WaveData.game_data()
		var points: Array = []
		if args.has("hp") and args["hp"] != "none":
			for pair: String in String(args["hp"]).split(","):
				var parts := pair.split(":")
				points.append([float(parts[0]), float(parts[1])])
		if args.has("growth"):
			waves.hp_growth = float(args["growth"])
		waves.apply_hp_scale(points)
	var policy: String = args.get("policy", "sequential")
	var from := int(args.get("from", "0"))
	var count := int(args.get("count", "10"))
	var interval := int(args.get("interval", "600"))
	var out_path: String = args.get("out", "user://playtest.json")
	var results: Array = []
	for i in count:
		var seed_text := "pt-%s-%s-%d" % [set_id, policy, from + i]
		var started := Time.get_ticks_msec()
		var result := _play(seed_text, policy, interval)
		result["policy"] = policy
		result["seed"] = seed_text
		result["wallMs"] = Time.get_ticks_msec() - started
		results.append(result)
		print("[playtest] %s -> %s onda %d, %.0f s de jogo, %d ms" % [seed_text, result["outcome"], result["wave"],
				result["seconds"], result["wallMs"]])
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(results))
	file.close()
	quit()


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


func _play(seed_text: String, policy: String, interval: int) -> Dictionary:
	_id_to_type = {}
	Damage.track = true
	Damage.dealt = {}
	var sim := WaveBot.bot_sim(seed_text)
	var state: RunState = sim.state
	var total := WaveBot.total_waves()
	var m := {
		"kills": 0, "killsByType": {}, "shotsByType": {}, "killGold": 0, "interestGold": 0, "bonusGold": 0,
		"earlyGold": 0, "chainGold": 0, "maxGold": 0, "peakEnemies": 0, "earlyCalls": 0, "callsRefused": 0,
		"waveStartGold": {}, "waveStartTowers": {}, "waveStartTick": {}, "waveEndTick": {}, "waveNexusHp": {},
		"purchases": {}, "merges": 0, "rerolls": 0, "evolves": 0, "towerWaves": {}, "starWaves": {},
		"killsByEnemy": {}, "rewards": [], "gotKillsAtWave": {}, "activeWavesAtCall": [], "firstBuyWave": {}, "buysByRarity": {},
	}
	var next_call := 0
	var rerolls := {"left": 0}
	var ticks_guard := 0
	while state.status == "playing" and state.tick < MAX_TICKS:
		if state.rewards.screen_open():
			sim.enqueue({"type": "chooseReward", "index": 0})
		elif policy == "lazy":
			if state.waves.active.is_empty() and WaveState.next_wave_number(state) <= total:
				var lazy_guard := 0
				while lazy_guard < 20 and _lazy_action(sim):
					_step(sim, m)
					lazy_guard += 1
					if state.status != "playing":
						break
				if state.status == "playing" and not state.rewards.screen_open():
					sim.enqueue({"type": "callWave"})
		elif policy == "sequential":
			if state.waves.active.is_empty() and WaveState.next_wave_number(state) <= total:
				rerolls = {"left": WaveBot.REROLLS_PER_BREAK}
				var guard := 0
				while guard < 100 and WaveBot._bot_action(sim, rerolls):
					_step(sim, m)
					guard += 1
					if state.status != "playing":
						break
				if state.status == "playing" and not state.rewards.screen_open():
					sim.enqueue({"type": "callWave"})
		else:
			if state.tick >= next_call and WaveState.next_wave_number(state) <= total:
				sim.enqueue({"type": "callWave"})
				next_call = state.tick + interval
			if state.tick % STACK_CHECK_TICKS == 0:
				WaveBot._bot_action(sim, {"left": 1 if state.waves.active.is_empty() else 0})
		_step(sim, m)
		ticks_guard += 1
	Damage.track = false

	var by_type := {}
	for who in Damage.dealt:
		var type: String = "nexus" if who == -1 else str(_id_to_type.get(who, "?"))
		by_type[type] = by_type.get(type, 0.0) + Damage.dealt[who]
	var outcome: String = state.status
	if outcome == "playing":
		outcome = "timeout"
	var final_towers := {}
	for t: Tower in state.towers:
		final_towers[t.type] = final_towers.get(t.type, []) + [t.star]
	m["outcome"] = outcome
	m["wave"] = state.wave
	m["seconds"] = float(state.tick) / 30.0
	m["ticks"] = state.tick
	m["goldEarned"] = state.stats.gold_earned
	m["goldFinal"] = state.gold
	m["towersFinal"] = state.towers.size()
	m["nexusLevel"] = state.nexus.level
	m["nexusHpFinal"] = state.nexus.hp
	m["longestChain"] = state.stats.longest_chain
	m["droppedTriggers"] = state.triggers.dropped_total
	m["damageByType"] = by_type
	m["finalTowers"] = final_towers
	m["totalDamage"] = by_type.values().reduce(func(a: float, b: float) -> float: return a + b, 0.0)
	return m


## Um tick, com a leitura dos eventos para as medidas.
func _step(sim: Simulation, m: Dictionary) -> void:
	var state: RunState = sim.state
	sim.step()
	m["maxGold"] = maxi(m["maxGold"], state.gold)
	m["peakEnemies"] = maxi(m["peakEnemies"], state.enemies.active_count)
	for e: Dictionary in sim.drain_events():
		match e["type"]:
			"towerPlaced":
				_id_to_type[e["towerId"]] = e["towerType"]
				m["purchases"][e["towerType"]] = m["purchases"].get(e["towerType"], 0) + 1
				var rarity: Variant = TowerData.game_data().get_type(e["towerType"]).rarity
				if rarity != null:
					m["buysByRarity"][rarity] = m["buysByRarity"].get(rarity, 0) + 1
					if not m["firstBuyWave"].has(rarity):
						m["firstBuyWave"][rarity] = state.wave + 1
			"towersMerged":
				m["merges"] += 1
			"towerFired":
				var type: String = str(_id_to_type.get(e["towerId"], "?"))
				m["shotsByType"][type] = m["shotsByType"].get(type, 0) + 1
			"enemyKilled":
				m["kills"] += 1
				m["killGold"] += int(Economy.kill_gold_for(EconomyData.game_data(), 0.0, int(e["wave"])))
				var by: String = "nexus" if e["towerId"] == null else str(_id_to_type.get(e["towerId"], "?"))
				m["killsByType"][by] = m["killsByType"].get(by, 0) + 1
				m["killsByEnemy"][e["enemyType"]] = m["killsByEnemy"].get(e["enemyType"], 0) + 1
			"waveStarted":
				var w := str(e["wave"])
				m["waveStartGold"][w] = state.gold
				m["waveStartTowers"][w] = state.towers.size()
				m["waveStartTick"][w] = e["tick"]
				m["activeWavesAtCall"].append(state.waves.active.size())
				if e["early"]:
					m["earlyCalls"] += 1
				for t: Tower in state.towers:
					m["towerWaves"][t.type] = m["towerWaves"].get(t.type, 0) + 1
					m["starWaves"][t.type] = m["starWaves"].get(t.type, 0) + t.star
			"waveEnded":
				var w := str(e["wave"])
				m["waveEndTick"][w] = e["tick"]
				m["waveNexusHp"][w] = state.nexus.hp
				m["interestGold"] += int(e["interest"])
				m["bonusGold"] += int(e["bonus"])
				m["earlyGold"] += int(e["earlyBonus"])
			"chainGold":
				m["chainGold"] += int(e["gold"])
			"callWaveRefused":
				m["callsRefused"] += 1
			"nexusEvolved":
				m["evolves"] += 1
			"shopChanged":
				if e["reason"] == "reroll":
					m["rerolls"] += 1
			"rewardChosen":
				m["rewards"].append(str(e.get("rewardId", e.get("id", "?"))))


## Uma compra do jogador preguiçoso (ver `lazy`); false = nada mais a fazer.
func _lazy_action(sim: Simulation) -> bool:
	var state: RunState = sim.state
	var towers := TowerData.game_data()
	for slot in state.shop.slots.size():
		var type: Variant = state.shop.slots[slot]
		if type == null or WaveBot._price(sim, type) > state.gold:
			continue
		if Fusion.plan_fusion(state.towers, towers, type) != null:
			sim.enqueue({"type": "buyTower", "slot": slot})
			return true
	if not TowerLimit.has_room_for_tower(state):
		return false
	for wanted in ["aldric", "tomas", "lyra"]:
		for slot in state.shop.slots.size():
			if state.shop.slots[slot] == wanted and WaveBot._price(sim, wanted) <= state.gold:
				var cell: Variant = _lazy_cell(sim)
				if cell == null:
					return false
				sim.enqueue({"type": "buyTower", "slot": slot, "x": cell.x, "y": cell.y})
				return true
	return false


## Casa da próxima torre: ao lado de uma já posta (lado a lado, como o Pedro fez); a primeira vai na melhor casa.
func _lazy_cell(sim: Simulation) -> Variant:
	var map := WaveBot.bot_map()
	var state: RunState = sim.state
	var taken := {}
	for t: Tower in state.towers:
		taken[Vector2i(t.x, t.y)] = true
	for t: Tower in state.towers:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var c: Vector2i = Vector2i(t.x, t.y) + d
			if not taken.has(c) and map.can_place_tower(c):
				return c
	return WaveBot._free_cell(sim)
