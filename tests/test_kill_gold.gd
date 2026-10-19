extends GutTest
## Ouro por abate: cada inimigo dá o número da onda dele em ouro (onda 1 = 1, onda 2 = 2, ...);
## o fim da onda paga o bônus (10 na onda 1) e os juros continuam.


func _economy() -> EconomyData:
	return EconomyData.game_data()


func test_dados_do_jogo() -> void:
	var e := _economy()
	assert_eq(e.kill_gold_base, 0)
	assert_eq(e.kill_gold_per_wave, 1)
	assert_eq(Economy.wave_bonus_for(e, 1), 10, "bônus de fim da onda 1")


func test_ouro_do_abate_cresce_uma_unidade_por_onda() -> void:
	var e := _economy()
	for wave in [1, 2, 3, 10, 40]:
		assert_eq(Economy.kill_gold_for(e, 0.0, wave), float(wave), "onda %d" % wave)


func test_inimigo_sem_onda_nao_da_ouro_extra() -> void:
	assert_eq(Economy.kill_gold_for(_economy(), 0.0, 0), 0.0)
	assert_eq(Economy.kill_gold_for(_economy(), 3.0, 0), 3.0, "só o ouro do tipo")


func test_run_ouro_ganho_e_abates_mais_bonus_mais_juros() -> void:
	var map := SimMap.load_map(DataLoader.load_json("map.json"))
	var sim := Simulation.create("ouro-abate", GameSystems.create(map))
	for c in [
		{"type": "debugSetNexusInvulnerable", "value": true},
		{"type": "debugSpawnTowers", "count": 12, "towerTypes": ["mortar", "ballista", "relay"],
				"layout": "clustered", "star": 2},
		{"type": "callWave"},
	]:
		sim.enqueue(c)
	var expected := 0
	var waves_ended := 0
	var kills_by_wave := {}
	for i in 1500:
		sim.step()
		for e: Dictionary in sim.drain_events():
			if e["type"] == "enemyKilled":
				expected += int(e["wave"])
				kills_by_wave[e["wave"]] = kills_by_wave.get(e["wave"], 0) + 1
			elif e["type"] == "waveEnded":
				waves_ended += 1
				expected += int(e["interest"]) + int(e["bonus"]) + int(e["earlyBonus"])
	assert_gt(waves_ended, 0, "pelo menos uma onda fechou")
	assert_gt(kills_by_wave.get(1, 0), 0, "abates da onda 1")
	assert_eq(sim.state.stats.gold_earned, expected, "ouro ganho = abates + juros + bônus + antecipado")
