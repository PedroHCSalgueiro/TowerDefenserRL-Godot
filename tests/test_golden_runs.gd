extends GutTest
## Paridade da simulação INTEIRA com o Phaser: joga os mesmos bots, nas mesmas sementes, e exige o
## mesmo relatório de cada onda, o mesmo histograma de eventos e o mesmo estado final
## (tests/golden/runs.json, gerado por tools/golden/gen_runs.ts).

const REPORT_KEYS := ["wave", "ticks", "kills", "peakKillsPerTick", "dropped", "maxDepth",
		"peakTriggersPerTick", "towers", "nexusHp", "peakEnemies", "goldEarned", "gold", "chainGold",
		"longestChain", "nexusLevel"]


func _play(s: Dictionary) -> Dictionary:
	WaveBot.tally = {}
	var sim := WaveBot.bot_sim(s["seed"], s["invulnerable"])
	var reports: Array
	if s["bot"] == "good":
		reports = WaveBot.play_run(sim, GoodBot.bot_break, GoodBot.reward)
	else:
		reports = WaveBot.play_run(sim)
	return {"sim": sim, "reports": reports, "tally": WaveBot.tally.duplicate()}


func _compare_scenario(s: Dictionary) -> void:
	var name: String = s["name"]
	var result := _play(s)
	var sim: Simulation = result["sim"]
	var reports: Array = result["reports"]
	var expected_reports: Array = s["reports"]
	assert_eq(reports.size(), expected_reports.size(), "%s: número de ondas jogadas" % name)

	for i in mini(reports.size(), expected_reports.size()):
		for key in REPORT_KEYS:
			var got: float = float(reports[i][key])
			var want: float = float(expected_reports[i][key])
			if absf(got - want) > 1e-9:
				fail_test("%s: onda %d, '%s': %s (Godot) != %s (Phaser)" % [name, i + 1, key, got, want])
				return

	var tally: Dictionary = result["tally"]
	var expected_tally: Dictionary = s["tally"]
	for type: String in expected_tally:
		assert_eq(int(tally.get(type, 0)), int(expected_tally[type]), "%s: eventos '%s'" % [name, type])
	for type: String in tally:
		assert_true(expected_tally.has(type), "%s: tipo de evento inesperado '%s'" % [name, type])

	var f: Dictionary = s["final"]
	var st = sim.state
	assert_eq(st.tick, int(f["tick"]), "%s: tick final" % name)
	assert_eq(st.rng_state, int(f["rngState"]), "%s: rng_state final" % name)
	assert_eq(st.next_entity_id, int(f["nextEntityId"]), "%s: next_entity_id final" % name)
	assert_eq(st.status, f["status"], "%s: status final" % name)
	assert_eq(st.cheated, f["cheated"], "%s: cheated" % name)
	assert_eq(st.gold, int(f["gold"]), "%s: ouro final" % name)
	assert_eq(st.wave, int(f["wave"]), "%s: ondas fechadas" % name)
	assert_almost_eq(st.nexus.hp, float(f["nexus"]["hp"]), 1e-9, "%s: vida do núcleo" % name)
	assert_eq(st.nexus.level, int(f["nexus"]["level"]), "%s: nível do núcleo" % name)
	assert_eq(st.stats.kills, int(f["stats"]["kills"]), "%s: abates" % name)
	assert_eq(st.stats.longest_chain, int(f["stats"]["longestChain"]), "%s: maior cadeia" % name)
	assert_eq(st.stats.gold_earned, int(f["stats"]["goldEarned"]), "%s: ouro ganho" % name)
	assert_eq(st.triggers.dropped_total, int(f["droppedTotal"]), "%s: gatilhos descartados" % name)

	var towers: Array = []
	for t: Tower in st.towers:
		towers.append([t.id, t.type, t.star, t.x, t.y, t.invested])
	var expected_towers: Array = []
	for t in f["towers"]:
		expected_towers.append([int(t[0]), t[1], int(t[2]), int(t[3]), int(t[4]), int(t[5])])
	assert_eq(towers, expected_towers, "%s: torres no fim" % name)

	var taken: Array = []
	for r: RewardsState.TakenReward in st.rewards.taken:
		taken.append([r.id, r.class_id, r.wave])
	var expected_taken: Array = []
	for r in f["rewardsTaken"]:
		expected_taken.append([r[0], r[1], int(r[2])])
	assert_eq(taken, expected_taken, "%s: recompensas escolhidas" % name)


var _golden: Dictionary


func before_all() -> void:
	_golden = Golden.load_json("runs.json")


func test_wave_bot_run_invulneravel() -> void:
	_compare_scenario(_golden["scenarios"][0])


func test_wave_bot_run_normal() -> void:
	_compare_scenario(_golden["scenarios"][1])


func test_good_bot_run_invulneravel() -> void:
	_compare_scenario(_golden["scenarios"][2])


func test_good_bot_run_normal() -> void:
	_compare_scenario(_golden["scenarios"][3])
