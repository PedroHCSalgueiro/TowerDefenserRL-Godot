class_name RunStateIO
extends RefCounted
## Salvar e restaurar o estado da run (porte de `serializeRunState`/`deserializeRunState`): o estado
## todo vira um Dictionary com as chaves do Phaser (camelCase) e daí JSON. Os floats vão exatos
## (`SaveCodec`). Restaurar uma run e continuar dá o MESMO resultado que não ter parado (testado).
##
## O que não entra no save: eventos do tick, o índice espacial e os caches de desempenho dos
## inimigos (`type_data`, `route`, `seg`, `step`), que são refeitos na restauração.


# ---------------------------------------------------------------- estado → dicionário

static func to_dict(state: RunState) -> Dictionary:
	var enemies := []
	for e in state.enemies.slots:
		var enemy := {
			"slot": e.slot, "active": e.active, "id": e.id, "type": e.type, "wave": e.wave, "elite": e.elite,
			"hp": e.hp, "maxHp": e.max_hp, "distance": e.distance,
			"x": e.x, "y": e.y, "prevX": e.prev_x, "prevY": e.prev_y,
			"slowPercent": e.slow_percent, "slowTicks": e.slow_ticks, "stunTicks": e.stun_ticks,
			"bleedDamage": e.bleed_damage, "bleedTicks": e.bleed_ticks, "bleedSource": e.bleed_source,
			"marks": _marks_to_list(e.marks), "curse": e.curse.duplicate(),
			"poisonDamage": e.poison_damage, "poisonTicks": e.poison_ticks, "poisonSource": e.poison_source,
		}
		# Só no mapa que cresce (o save do mapa sem salas não muda).
		if e.entrance != 0:
			enemy["entrance"] = e.entrance
		enemies.append(enemy)
	var projectiles := []
	for p in state.projectiles.slots:
		projectiles.append({
			"slot": p.slot, "active": p.active, "id": p.id, "sourceId": p.source_id, "chainId": p.chain_id,
			"originTowerId": p.origin_tower_id, "targetId": p.target_id, "targetSlot": p.target_slot,
			"targetX": p.target_x, "targetY": p.target_y, "retargeted": p.retargeted, "damage": p.damage,
			"areaRadius": p.area_radius, "statusType": p.status_type, "speed": p.speed, "x": p.x, "y": p.y, "prevX": p.prev_x, "prevY": p.prev_y,
			"curse": p.curse.duplicate(), "forceMark": p.force_mark,
		})
	var towers := []
	for t: Tower in state.towers:
		towers.append({
			"id": t.id, "type": t.type, "star": t.star, "x": t.x, "y": t.y, "cooldownTicks": t.cooldown_ticks,
			"triggerCounter": t.trigger_counter, "charges": t.charges, "activationReadyTick": t.activation_ready_tick,
			"invested": t.invested,
			"lastEffect": null if t.last_effect == null else {"effect": t.last_effect.effect, "seq": t.last_effect.seq},
			"doubleShot": t.double_shot, "followupTicks": t.followup_ticks, "curseNext": t.curse_next.duplicate(),
			"lootCount": t.loot_count, "markNext": t.mark_next, "waveBuffPercent": t.wave_buff_percent,
		})
	var traps := []
	for trap: Trap in state.traps:
		traps.append({"id": trap.id, "ownerId": trap.owner_id, "kind": trap.kind, "x": trap.x, "y": trap.y,
				"damage": trap.damage, "holdTicks": trap.hold_ticks, "radius": trap.radius, "params": trap.params.duplicate()})
	var queue := []
	for q: TriggerState.PendingTrigger in state.triggers.queue:
		queue.append({
			"towerId": q.tower_id, "sourceTowerId": q.source_tower_id, "weight": q.weight, "depth": q.depth,
			"tickDepth": q.tick_depth, "hasPoint": q.has_point, "x": q.x, "y": q.y, "blastRadius": q.blast_radius,
			"blastPercent": q.blast_percent, "chainId": q.chain_id, "originTowerId": q.origin_tower_id,
		})
	var chains := []
	for c: TriggerState.ChainRecord in state.triggers.chains:
		chains.append({"id": c.id, "originTowerId": c.origin_tower_id, "length": c.length})
	var last := state.triggers.last_tick
	var classes := {}
	for id: String in state.classes:
		var status: ClassState.ClassStatus = state.classes[id]
		classes[id] = {"level": status.level, "members": status.members.duplicate()}
	var active_waves := []
	for w: WaveState.ActiveWave in state.waves.active:
		active_waves.append({"wave": w.wave, "startTick": w.start_tick, "spawned": w.spawned,
				"bossesKilled": w.bosses_killed, "earlyBonus": w.early_bonus})
	var taken := []
	for r: RewardsState.TakenReward in state.rewards.taken:
		taken.append({"id": r.id, "classId": r.class_id, "wave": r.wave})
	var screen: Variant = null
	if state.rewards.screen != null:
		var s: RewardsState.RewardScreen = state.rewards.screen
		screen = {"wave": s.wave, "options": s.options.duplicate(true), "rerolls": s.rerolls, "ticksLeft": s.ticks_left}
	var out := _base_dict(state, enemies, projectiles, towers, traps, queue, last, chains, classes, active_waves,
			taken, screen)
	# Mapa que cresce: só entra no save depois que algo aconteceu (o save do mapa sem salas não muda).
	if state.expansion != null and not state.expansion.is_untouched(state.seed_text):
		var ex: ExpansionState = state.expansion
		var ex_screen: Variant = null
		if ex.screen != null:
			ex_screen = {"wave": ex.screen.wave, "options": ex.screen.options.duplicate(), "ticksLeft": ex.screen.ticks_left}
		out["expansion"] = {"rngState": ex.rng_state, "opened": ex.opened.duplicate(), "screen": ex_screen,
				"pending": ex.pending}
	return out


static func _base_dict(state: RunState, enemies: Array, projectiles: Array, towers: Array, traps: Array,
		queue: Array, last: Variant, chains: Variant, classes: Dictionary, active_waves: Array, taken: Array,
		screen: Variant) -> Dictionary:
	return {
		"version": state.version,
		"seed": state.seed_text,
		"tick": state.tick,
		"rngState": state.rng_state,
		"nextEntityId": state.next_entity_id,
		"status": state.status,
		"cheated": state.cheated,
		"nexus": {"hp": state.nexus.hp, "maxHp": state.nexus.max_hp,
				"attackCooldownTicks": state.nexus.attack_cooldown_ticks, "level": state.nexus.level},
		"enemies": {"slots": enemies, "free": state.enemies.free.duplicate(), "activeCount": state.enemies.active_count},
		"projectiles": {"slots": projectiles, "free": state.projectiles.free.duplicate(), "activeCount": state.projectiles.active_count},
		"towers": towers,
		"traps": traps,
		"triggers": {"queue": queue, "nextSeq": state.triggers.next_seq,
				"lastTick": {"fired": last.fired, "maxDepth": last.max_depth, "deferred": last.deferred, "dropped": last.dropped},
				"droppedTotal": state.triggers.dropped_total, "nextChainId": state.triggers.next_chain_id, "chains": chains},
		"classes": classes,
		"gold": state.gold,
		"pendingLoot": state.pending_loot,
		"souls": state.souls,
		"echoCounter": state.echo_counter,
		"godSaveWave": state.god_save_wave,
		"reportedGold": state.reported_gold,
		"wave": state.wave,
		"waves": {"active": active_waves},
		"stats": {"kills": state.stats.kills, "longestChain": state.stats.longest_chain, "goldEarned": state.stats.gold_earned,
				"rewardRerollGold": state.stats.reward_reroll_gold, "chainGold": state.stats.chain_gold},
		"shop": {"slots": state.shop.slots.duplicate(), "freeRerolls": state.shop.free_rerolls},
		"rewards": {"rngState": state.rewards.rng_state, "taken": taken, "screen": screen, "queue": state.rewards.queue.duplicate()},
		"debug": {"nexusInvulnerable": state.debug.nexus_invulnerable, "infiniteGold": state.debug.infinite_gold,
				"stress": state.debug.stress},
		"commandQueue": state.command_queue.duplicate(true),
	}


## Marcas do inimigo como lista de [id da torre, ticks] (as chaves de um objeto JSON viram texto).
static func _marks_to_list(marks: Dictionary) -> Array:
	var out: Array = []
	for id: int in marks:
		out.append([id, marks[id]])
	return out


## O estado todo em JSON (floats exatos).
static func serialize(state: RunState) -> String:
	return JSON.stringify(SaveCodec.encode(to_dict(state)))


# ---------------------------------------------------------------- dicionário → estado

static func _fail(message: String) -> RunState:
	push_error("Save inválido: %s" % message)
	return null


static func _has_all(d: Variant, keys: Array) -> bool:
	if not (d is Dictionary):
		return false
	for k: String in keys:
		if not d.has(k):
			return false
	return true


## Restaura o estado. `map`: o mapa da run (as rotas dos inimigos são refeitas dele). Inválido:
## push_error e null. Saves de versões antigas que ainda abrem (`RunState.OLDEST_VERSION`) voltam com os
## campos que não existiam vazios (o save 16 não tem marcas, Maldição, tiro duplo nem ouro guardado; o 17
## não tem Envenenado, parâmetros das invocações, almas, eco nem o deus do núcleo).
static func from_dict(d: Variant, map: SimMap) -> RunState:
	if not (d is Dictionary):
		return _fail("não é um objeto")
	var version: Variant = d.get("version")
	if typeof(version) != TYPE_INT or version < RunState.OLDEST_VERSION or version > RunState.VERSION:
		return _fail("versão não suportada: %s (este jogo abre de %d a %d)" % [version, RunState.OLDEST_VERSION, RunState.VERSION])
	if not _has_all(d, ["seed", "tick", "rngState", "nextEntityId", "status", "cheated", "nexus", "enemies",
			"projectiles", "towers", "triggers", "classes", "gold", "reportedGold", "wave", "waves", "stats",
			"shop", "rewards", "debug", "commandQueue"]):
		return _fail("campos ausentes")
	if not ["playing", "lost", "won"].has(d["status"]):
		return _fail("status desconhecido")

	var state := RunState.new()
	state.seed_text = d["seed"]
	state.tick = d["tick"]
	state.rng_state = d["rngState"]
	state.next_entity_id = d["nextEntityId"]
	state.status = d["status"]
	state.cheated = d["cheated"]
	var nx: Dictionary = d["nexus"]
	state.nexus.hp = float(nx["hp"])
	state.nexus.max_hp = nx["maxHp"]
	state.nexus.attack_cooldown_ticks = nx["attackCooldownTicks"]
	state.nexus.level = nx["level"]

	# Mapa que cresce: as salas abertas voltam ao mapa antes das rotas dos inimigos (as entradas novas).
	state.expansion = ExpansionState.create(state.seed_text)
	if d.has("expansion"):
		var ex: Dictionary = d["expansion"]
		state.expansion.rng_state = ex["rngState"]
		for id in ex["opened"]:
			state.expansion.opened.append(str(id))
		state.expansion.pending = ex["pending"]
		if ex["screen"] != null:
			var ex_screen := ExpansionState.ExpansionScreen.new()
			ex_screen.wave = ex["screen"]["wave"]
			ex_screen.options = ex["screen"]["options"]
			ex_screen.ticks_left = ex["screen"]["ticksLeft"]
			state.expansion.screen = ex_screen
	var expansion_data := ExpansionData.for_map(map)
	if expansion_data != null:
		Expansion.sync(map, null, expansion_data, state.expansion.opened)
	var routes := Route.build_routes(map)
	var enemy_data := EnemyData.game_data()
	state.enemies = EnemyPool.new()
	for e: Dictionary in d["enemies"]["slots"]:
		var enemy := Enemy.new(e["slot"])
		enemy.active = e["active"]
		enemy.id = e["id"]
		enemy.type = e["type"]
		enemy.wave = e["wave"]
		enemy.elite = e["elite"]
		enemy.hp = float(e["hp"])
		enemy.max_hp = float(e["maxHp"])
		enemy.distance = float(e["distance"])
		enemy.x = float(e["x"])
		enemy.y = float(e["y"])
		enemy.prev_x = float(e["prevX"])
		enemy.prev_y = float(e["prevY"])
		enemy.slow_percent = float(e["slowPercent"])
		enemy.slow_ticks = e["slowTicks"]
		enemy.stun_ticks = e["stunTicks"]
		enemy.bleed_damage = float(e["bleedDamage"])
		enemy.bleed_ticks = e["bleedTicks"]
		enemy.bleed_source = e["bleedSource"]
		for pair in e.get("marks", []):
			enemy.marks[int(pair[0])] = int(pair[1])
		enemy.curse = e.get("curse", {})
		enemy.poison_damage = float(e.get("poisonDamage", 0.0))
		enemy.poison_ticks = e.get("poisonTicks", 0)
		enemy.poison_source = e.get("poisonSource")
		enemy.entrance = int(e.get("entrance", 0))
		if enemy.active:
			# Caches de desempenho: refeitos da rota do tipo (na entrada do inimigo).
			var type := enemy_data.get_type(enemy.type)
			if type == null:
				return _fail("inimigo de tipo desconhecido: %s" % enemy.type)
			var route_key := Route.key_for(type.movement, enemy.entrance)
			if not routes.has(route_key):
				return _fail("inimigo numa entrada que o mapa não tem: %d" % enemy.entrance)
			enemy.type_data = type
			enemy.route = routes[route_key]
			enemy.route_length = enemy.route.length
			enemy.seg = enemy.route.find_segment(enemy.distance)
			enemy.step = -1.0
		state.enemies.slots.append(enemy)
	for s in d["enemies"]["free"]:
		state.enemies.free.append(int(s))
	state.enemies.active_count = d["enemies"]["activeCount"]

	state.projectiles = ProjectilePool.new()
	for p: Dictionary in d["projectiles"]["slots"]:
		var proj := Projectile.new(p["slot"])
		proj.active = p["active"]
		proj.id = p["id"]
		proj.source_id = p["sourceId"]
		proj.chain_id = p["chainId"]
		proj.origin_tower_id = p["originTowerId"]
		proj.target_id = p["targetId"]
		proj.target_slot = p["targetSlot"]
		proj.target_x = float(p["targetX"])
		proj.target_y = float(p["targetY"])
		proj.retargeted = p["retargeted"]
		proj.damage = float(p["damage"])
		proj.area_radius = float(p["areaRadius"])
		proj.status_type = p["statusType"]
		proj.curse = p.get("curse", {})
		proj.force_mark = p.get("forceMark", false)
		proj.speed = float(p["speed"])
		proj.x = float(p["x"])
		proj.y = float(p["y"])
		proj.prev_x = float(p["prevX"])
		proj.prev_y = float(p["prevY"])
		state.projectiles.slots.append(proj)
	for s in d["projectiles"]["free"]:
		state.projectiles.free.append(int(s))
	state.projectiles.active_count = d["projectiles"]["activeCount"]

	var towers_data := TowerData.game_data()
	for t: Dictionary in d["towers"]:
		if not towers_data.has_type(t["type"]):
			return _fail("torre de tipo desconhecido: %s" % t["type"])
		var tower := Tower.new(t["id"], t["type"], Vector2i(t["x"], t["y"]), t["star"])
		tower.cooldown_ticks = t["cooldownTicks"]
		tower.trigger_counter = float(t["triggerCounter"])
		tower.charges = float(t["charges"])
		tower.activation_ready_tick = t["activationReadyTick"]
		tower.invested = t["invested"]
		if t["lastEffect"] != null:
			tower.last_effect = Tower.LastEffect.new(_typed_effect(t["lastEffect"]["effect"]), t["lastEffect"]["seq"])
		tower.double_shot = t.get("doubleShot", false)
		tower.followup_ticks = t.get("followupTicks", 0)
		tower.curse_next = t.get("curseNext", {})
		tower.loot_count = t.get("lootCount", 0)
		tower.mark_next = t.get("markNext", false)
		tower.wave_buff_percent = float(t.get("waveBuffPercent", 0.0))
		state.towers.append(tower)

	for t: Dictionary in d.get("traps", []):
		var trap := Trap.new()
		trap.id = t["id"]
		trap.owner_id = t["ownerId"]
		trap.kind = t["kind"]
		trap.x = float(t["x"])
		trap.y = float(t["y"])
		trap.damage = float(t["damage"])
		trap.hold_ticks = t["holdTicks"]
		trap.radius = float(t["radius"])
		trap.params = t.get("params", {})
		state.traps.append(trap)

	var tr: Dictionary = d["triggers"]
	for q: Dictionary in tr["queue"]:
		var entry := TriggerState.PendingTrigger.new()
		entry.tower_id = q["towerId"]
		entry.source_tower_id = q["sourceTowerId"]
		entry.weight = float(q["weight"])
		entry.depth = q["depth"]
		entry.tick_depth = q["tickDepth"]
		entry.has_point = q["hasPoint"]
		entry.x = float(q["x"])
		entry.y = float(q["y"])
		entry.blast_radius = float(q["blastRadius"])
		entry.blast_percent = float(q["blastPercent"])
		entry.chain_id = q["chainId"]
		entry.origin_tower_id = q["originTowerId"]
		state.triggers.queue.append(entry)
	state.triggers.next_seq = tr["nextSeq"]
	state.triggers.last_tick.fired = tr["lastTick"]["fired"]
	state.triggers.last_tick.max_depth = tr["lastTick"]["maxDepth"]
	state.triggers.last_tick.deferred = tr["lastTick"]["deferred"]
	state.triggers.last_tick.dropped = tr["lastTick"]["dropped"]
	state.triggers.dropped_total = tr["droppedTotal"]
	state.triggers.next_chain_id = tr["nextChainId"]
	for c: Dictionary in tr["chains"]:
		var chain := TriggerState.ChainRecord.new(c["id"], c["originTowerId"])
		chain.length = c["length"]
		state.triggers.chains.append(chain)

	state.classes = ClassState.create(ClassData.game_data())
	for id: String in d["classes"]:
		if not state.classes.has(id):
			return _fail("classe desconhecida: %s" % id)
		var status: ClassState.ClassStatus = state.classes[id]
		status.level = d["classes"][id]["level"]
		for m in d["classes"][id]["members"]:
			status.members.append(m)

	state.gold = d["gold"]
	state.pending_loot = d.get("pendingLoot", 0)
	state.souls = d.get("souls", 0)
	state.echo_counter = d.get("echoCounter", 0)
	state.god_save_wave = d.get("godSaveWave", -1)
	state.reported_gold = d["reportedGold"]
	state.wave = d["wave"]
	for w: Dictionary in d["waves"]["active"]:
		var active := WaveState.ActiveWave.new()
		active.wave = w["wave"]
		active.start_tick = w["startTick"]
		active.spawned = w["spawned"]
		active.bosses_killed = w["bossesKilled"]
		active.early_bonus = w["earlyBonus"]
		state.waves.active.append(active)
	var st: Dictionary = d["stats"]
	state.stats.kills = st["kills"]
	state.stats.longest_chain = st["longestChain"]
	state.stats.gold_earned = st["goldEarned"]
	state.stats.reward_reroll_gold = st["rewardRerollGold"]
	state.stats.chain_gold = st["chainGold"]

	state.shop = Shop.ShopState.new()
	for slot in d["shop"]["slots"]:
		state.shop.slots.append(slot)
	state.shop.free_rerolls = d["shop"]["freeRerolls"]

	var rw: Dictionary = d["rewards"]
	state.rewards = RewardsState.new()
	state.rewards.rng_state = rw["rngState"]
	for r: Dictionary in rw["taken"]:
		state.rewards.taken.append(RewardsState.TakenReward.new(r["id"], r["classId"], r["wave"]))
	if rw["screen"] != null:
		var screen := RewardsState.RewardScreen.new()
		screen.wave = rw["screen"]["wave"]
		screen.options = rw["screen"]["options"]
		screen.rerolls = rw["screen"]["rerolls"]
		screen.ticks_left = rw["screen"]["ticksLeft"]
		state.rewards.screen = screen
	for w in rw["queue"]:
		state.rewards.queue.append(int(w))

	state.debug.nexus_invulnerable = d["debug"]["nexusInvulnerable"]
	state.debug.infinite_gold = d["debug"]["infiniteGold"]
	state.debug.stress = d["debug"]["stress"]
	state.command_queue = d["commandQueue"]
	return state


## Os efeitos guardados em `last_effect` voltam do JSON com contagens como int e números como
## float (o `SaveCodec` já devolveu os floats exatos; aqui só garante os tipos dos campos de contagem).
static func _typed_effect(effect: Dictionary) -> Dictionary:
	return effect


## Restaura do JSON de `serialize`. Inválido: push_error e null.
static func deserialize(text: String, map: SimMap) -> RunState:
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return _fail("JSON ilegível")
	return from_dict(SaveCodec.decode(json.data), map)
