extends GutTest
## Fumaça da simulação completa: o RunState nasce, os sistemas do jogo rodam e as primeiras
## ondas terminam sem erro. A paridade com o Phaser fica em test_golden_runs.gd.


func test_run_state_nasce_como_o_phaser() -> void:
	var state := RunState.create("smoke")
	assert_eq(state.version, 17)
	assert_eq(state.gold, 10)
	assert_eq(state.nexus.level, 1)
	assert_eq(state.nexus.max_hp, 20)
	assert_eq(state.shop.slots.size(), 5)
	assert_eq(state.status, "playing")
	assert_eq(state.classes.keys(), ["artillery", "mechanical", "arcane", "shadow"])


func test_primeiras_ondas_do_bot_terminam() -> void:
	var sim := WaveBot.bot_sim("smoke-run")
	var reports: Array = []
	for i in 3:
		WaveBot.bot_break(sim)
		sim.drain_events()
		reports.append(WaveBot.play_wave(sim))
	assert_eq(reports.size(), 3)
	assert_eq(sim.state.wave, 3)
	assert_gt(sim.state.towers.size(), 0, "o bot comprou torres")
	assert_gt(reports[0]["kills"], 0)
