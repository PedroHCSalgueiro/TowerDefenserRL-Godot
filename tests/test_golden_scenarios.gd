extends GutTest
## Paridade com o Phaser em cenários de debug (tests/golden/scenarios.json, gerado por
## tools/golden/gen_scenarios.ts): torres de todos os tipos em ★1/★2/★3 contra hordas, loja, fusão,
## venda, mover, núcleo, ondas tardias e recompensas. Os comandos agendados vêm do próprio JSON.

var _golden: Dictionary


func before_all() -> void:
	_golden = Golden.load_json("scenarios.json")


func _play(s: Dictionary) -> Dictionary:
	var sim := Simulation.create(s["seed"], GameSystems.create(WaveBot.bot_map(), Golden.phaser_options()),
			Golden.phaser_options()["economy"])
	var by_tick := {}
	for entry in s["commands"]:
		var tick := int(entry[0])
		if not by_tick.has(tick):
			by_tick[tick] = []
		by_tick[tick].append(entry[1])
	var tally := {}
	for tick in int(s["ticks"]):
		for command in by_tick.get(tick, []):
			sim.enqueue(command.duplicate(true))
		sim.step()
		for event: Dictionary in sim.drain_events():
			tally[event["type"]] = tally.get(event["type"], 0) + 1
	return {"sim": sim, "tally": tally}


func _check(s: Dictionary) -> void:
	var name: String = s["name"]
	var result := _play(s)
	var sim: Simulation = result["sim"]
	var st = sim.state
	var tally: Dictionary = result["tally"]
	var expected_tally: Dictionary = s["tally"]
	for type: String in expected_tally:
		assert_eq(int(tally.get(type, 0)), int(expected_tally[type]), "%s: eventos '%s'" % [name, type])
	for type: String in tally:
		assert_true(expected_tally.has(type), "%s: tipo de evento inesperado '%s'" % [name, type])

	var f: Dictionary = s["final"]
	assert_eq(st.tick, int(f["tick"]), "%s: tick" % name)
	assert_eq(st.rng_state, int(f["rngState"]), "%s: rng_state" % name)
	assert_eq(st.next_entity_id, int(f["nextEntityId"]), "%s: next_entity_id" % name)
	assert_eq(st.status, f["status"], "%s: status" % name)
	assert_eq(st.cheated, f["cheated"], "%s: cheated" % name)
	assert_eq(st.gold, int(f["gold"]), "%s: ouro" % name)
	assert_eq(st.wave, int(f["wave"]), "%s: onda" % name)
	assert_almost_eq(st.nexus.hp, float(f["nexus"]["hp"]), 1e-9, "%s: vida do núcleo" % name)
	assert_eq(st.nexus.max_hp, int(f["nexus"]["maxHp"]), "%s: vida máxima do núcleo" % name)
	assert_eq(st.nexus.level, int(f["nexus"]["level"]), "%s: nível do núcleo" % name)
	assert_eq(st.nexus.attack_cooldown_ticks, int(f["nexus"]["attackCooldownTicks"]), "%s: recarga do núcleo" % name)
	assert_eq(st.stats.kills, int(f["stats"]["kills"]), "%s: abates" % name)
	assert_eq(st.stats.longest_chain, int(f["stats"]["longestChain"]), "%s: maior cadeia" % name)
	assert_eq(st.stats.gold_earned, int(f["stats"]["goldEarned"]), "%s: ouro ganho" % name)
	assert_eq(st.stats.reward_reroll_gold, int(f["stats"]["rewardRerollGold"]), "%s: ouro de reroll" % name)
	assert_eq(st.stats.chain_gold, int(f["stats"]["chainGold"]), "%s: ouro de cadeia" % name)
	assert_eq(st.triggers.next_seq, int(f["triggers"]["nextSeq"]), "%s: next_seq" % name)
	assert_eq(st.triggers.next_chain_id, int(f["triggers"]["nextChainId"]), "%s: next_chain_id" % name)
	assert_eq(st.triggers.queue.size(), int(f["triggers"]["queued"]), "%s: fila de gatilhos" % name)
	assert_eq(st.triggers.dropped_total, int(f["triggers"]["dropped"]), "%s: descartados" % name)
	assert_eq(st.enemies.active_count, int(f["enemies"]), "%s: inimigos ativos" % name)
	assert_eq(st.projectiles.active_count, int(f["projectiles"]), "%s: projéteis ativos" % name)

	var towers: Array = []
	for t: Tower in st.towers:
		towers.append([t.id, t.type, t.star, t.x, t.y, t.invested, t.charges, t.trigger_counter, t.cooldown_ticks])
	var want_towers: Array = []
	for t in f["towers"]:
		want_towers.append([int(t[0]), t[1], int(t[2]), int(t[3]), int(t[4]), int(t[5]), float(t[6]), float(t[7]), int(t[8])])
	assert_eq(towers, want_towers, "%s: torres" % name)

	var shop_slots: Array = []
	for slot in st.shop.slots:
		shop_slots.append(slot)
	assert_eq(shop_slots, f["shop"]["slots"], "%s: loja" % name)
	assert_eq(st.shop.free_rerolls, int(f["shop"]["freeRerolls"]), "%s: rerolls grátis" % name)

	var taken: Array = []
	for r: RewardsState.TakenReward in st.rewards.taken:
		taken.append({"id": r.id, "classId": r.class_id, "wave": r.wave})
	var want_taken: Array = []
	for r in f["rewards"]["taken"]:
		want_taken.append({"id": r["id"], "classId": r["classId"], "wave": int(r["wave"])})
	assert_eq(taken, want_taken, "%s: recompensas" % name)
	assert_eq(st.rewards.screen != null, f["rewards"]["open"], "%s: tela aberta" % name)
	assert_eq(st.rewards.rng_state, int(f["rewards"]["rngState"]), "%s: rng das cartas" % name)
	var queue: Array = []
	for w in st.rewards.queue:
		queue.append(w)
	var want_queue: Array = []
	for w in f["rewards"]["queue"]:
		want_queue.append(int(w))
	assert_eq(queue, want_queue, "%s: fila de telas" % name)

	for id: String in f["classes"]:
		var status: ClassState.ClassStatus = st.classes[id]
		assert_eq(status.level, int(f["classes"][id][0]), "%s: nível da classe %s" % [name, id])
		var members: Array = []
		for m in status.members:
			members.append(m)
		assert_eq(members, f["classes"][id][1], "%s: membros da classe %s" % [name, id])


func test_cadeia_8_tipos_estrela_1() -> void:
	_check(_golden["scenarios"][0])


func test_cadeia_8_tipos_estrela_2() -> void:
	_check(_golden["scenarios"][1])


func test_cadeia_8_tipos_estrela_3() -> void:
	_check(_golden["scenarios"][2])


func test_ondas_tardias_estrela_3() -> void:
	_check(_golden["scenarios"][3])


func test_loja_fusao_venda_mover_nucleo() -> void:
	_check(_golden["scenarios"][4])


func test_recompensas_debug() -> void:
	_check(_golden["scenarios"][5])
