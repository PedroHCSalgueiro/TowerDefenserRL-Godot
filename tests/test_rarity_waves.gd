extends GutTest
## Raridade da loja por onda (Valcoroa): quando cada raridade começa a aparecer e que o conjunto Padrão
## continua pelo nível do núcleo.

var _map: SimMap


func before_all() -> void:
	_map = SimMap.load_map(DataLoader.load_json("map.json"))


func after_each() -> void:
	GameSets.select(GameSets.DEFAULT_ID)


func _sim_at_wave(wave: int) -> Simulation:
	var sim := Simulation.create("raridade-%d" % wave, GameSystems.create(_map))
	sim.state.wave = wave
	return sim


## Todas as raridades vistas em `rolls` rerolls da loja na onda `wave` (a próxima a jogar é wave + 1).
func _seen(wave: int, rolls: int = 120) -> Dictionary:
	var sim := _sim_at_wave(wave)
	var towers := TowerData.game_data()
	sim.state.gold = 1000000
	sim.state.debug.infinite_gold = true
	var seen := {}
	for i in rolls:
		sim.enqueue({"type": "rerollShop"})
		sim.step()
		for id: String in sim.state.shop.slots:
			var rarity: String = towers.get_type(id).rarity
			seen[rarity] = seen.get(rarity, 0) + 1
	return seen


func test_padrao_continua_pelo_nivel_do_nucleo() -> void:
	var economy := EconomyData.game_data()
	assert_eq(economy.rarity_mode, "nexusLevel")
	assert_eq(economy.shop_prices["legendary"], 0, "o Padrão não tem lendário")


func test_valcoroa_tabela_por_onda() -> void:
	GameSets.select("valcoroa")
	var economy := EconomyData.game_data()
	assert_eq(economy.rarity_mode, "wave")
	assert_eq(economy.shop_prices["legendary"], 40)
	var expected := {0: [100, 0, 0, 0], 7: [100, 0, 0, 0], 8: [70, 30, 0, 0], 15: [70, 30, 0, 0], 16: [50, 35, 15, 0],
			23: [50, 35, 15, 0], 24: [35, 35, 25, 5], 31: [35, 35, 25, 5], 32: [25, 30, 30, 15], 39: [25, 30, 30, 15]}
	for waves_done: int in expected:
		var state := _sim_at_wave(waves_done).state
		var c := Shop.chances_for_state(economy, state)
		assert_eq([c["common"], c["uncommon"], c["rare"], c["legendary"]], expected[waves_done],
				"próxima onda %d" % (waves_done + 1))


func test_nada_alem_de_comum_ate_a_onda_8() -> void:
	GameSets.select("valcoroa")
	for wave in [0, 3, 7]:
		var seen := _seen(wave)
		assert_eq(seen.keys(), ["common"], "onda %d" % (wave + 1))


func test_incomum_a_partir_da_onda_9_raro_da_17_lendario_da_25() -> void:
	GameSets.select("valcoroa")
	var s9 := _seen(8)
	assert_true(s9.has("uncommon") and not s9.has("rare") and not s9.has("legendary"), "onda 9: %s" % s9)
	var s17 := _seen(16)
	assert_true(s17.has("rare") and not s17.has("legendary"), "onda 17: %s" % s17)
	var s25 := _seen(24, 400)
	assert_true(s25.has("legendary"), "onda 25: %s" % s25)


func test_o_nivel_do_nucleo_nao_mexe_na_loja() -> void:
	GameSets.select("valcoroa")
	var economy := EconomyData.game_data()
	var state := _sim_at_wave(3).state
	var before := Shop.chances_for_state(economy, state)
	state.nexus.level = 12
	assert_eq(Shop.chances_for_state(economy, state), before)


func test_proxima_faixa_e_carta_loja_melhor() -> void:
	GameSets.select("valcoroa")
	var economy := EconomyData.game_data()
	var state := _sim_at_wave(3).state
	var next := Shop.next_rarity_row(economy, state)
	assert_eq(next["fromWave"], 9)
	assert_true(Shop.can_improve_rarity(economy, state))
	# A carta empurra uma faixa à frente.
	RewardMods.of(state).shop_rarity_levels = 1
	var c := Shop.chances_for_state(economy, state)
	assert_eq(c["uncommon"], 30, "faixa 9–16 já na onda 4")
	var last := _sim_at_wave(35).state
	assert_true(Shop.next_rarity_row(economy, last).is_empty(), "a última faixa não tem próxima")
	assert_false(Shop.can_improve_rarity(economy, last))


func test_primeira_loja_so_tem_comuns() -> void:
	GameSets.select("valcoroa")
	var towers := TowerData.game_data()
	for s in ["a", "b", "c", "d", "e"]:
		var sim := Simulation.create("loja-r-" + s, GameSystems.create(_map))
		for id: String in sim.state.shop.slots:
			assert_eq(towers.get_type(id).rarity, "common")


func test_vida_das_ondas_de_valcoroa_cresce_6_por_cento_por_onda() -> void:
	GameSets.select("valcoroa")
	var waves := WaveData.game_data()
	assert_eq(waves.hp_growth, 0.06)
	for wave in [1, 3, 12, 25, 40]:
		var def := waves.waves[wave - 1]
		assert_almost_eq(def.hp_multiplier, def.base_hp_multiplier * pow(1.06, float(wave - 1)), 1e-9, "onda %d" % wave)
	assert_eq(WaveData.hp_scale_at([[3.0, 1.0], [13.0, 2.0]], 8), 1.5, "curva de pontos: interpolação linear")
	GameSets.select(GameSets.DEFAULT_ID)
	assert_eq(WaveData.game_data().hp_growth, 0.0, "o Padrão não tem crescimento extra")
