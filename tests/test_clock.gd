extends GutTest
## Porte de tests/clock.test.ts + paridade com o Phaser (tests/golden/clock.json).

var _config := {"ticksPerSecond": 30, "speeds": [1, 2, 3], "maxTicksPerFrame": 1000}


func _clock(overrides: Dictionary = {}) -> FixedStepClock:
	var cfg := _config.duplicate()
	cfg.merge(overrides, true)
	return FixedStepClock.new(cfg)


func test_usa_os_valores_de_data_engine_json() -> void:
	var cfg := _load_engine()
	assert_eq(int(cfg["ticksPerSecond"]), 30)
	assert_eq(cfg["speeds"], [1.0, 2.0, 3.0])


func _load_engine() -> Dictionary:
	var json := JSON.new()
	json.parse(FileAccess.get_file_as_string("res://data/engine.json"))
	return json.data


func test_30_ticks_em_1_segundo_a_1x() -> void:
	assert_eq(_clock().advance(1000.0), 30)


func test_velocidade_multiplica_os_ticks() -> void:
	var clock := _clock()
	clock.set_speed(2.0)
	assert_eq(clock.advance(1000.0), 60)
	clock.set_speed(3.0)
	assert_eq(clock.advance(1000.0), 90)


func test_soma_quadros_de_60_fps_sem_perder_ticks() -> void:
	var clock := _clock()
	var ticks := 0
	for i in 600:
		ticks += clock.advance(1000.0 / 60.0)
	assert_eq(ticks, 300)


func test_carrega_a_fracao_do_tick_para_o_quadro_seguinte() -> void:
	var clock := _clock()
	assert_eq(clock.advance(20.0), 0)
	assert_almost_eq(clock.alpha, 0.6, 0.0001)
	assert_eq(clock.advance(20.0), 1)
	assert_almost_eq(clock.alpha, 0.2, 0.0001)


func test_alpha_fica_sempre_em_0_1() -> void:
	var clock := _clock()
	for i in 500:
		clock.advance(7.0 + float(i % 13))
		assert_true(clock.alpha >= 0.0 and clock.alpha < 1.0)


func test_limita_os_ticks_por_quadro_e_descarta_o_excedente() -> void:
	var clock := _clock({"maxTicksPerFrame": 5})
	assert_eq(clock.advance(10000.0), 5)
	assert_lt(clock.alpha, 1.0)
	assert_eq(clock.advance(1000.0 / 30.0), 1)


func test_conta_os_ticks_descartados_pelo_teto() -> void:
	var clock := _clock({"maxTicksPerFrame": 5})
	clock.advance(1000.0 / 30.0)
	assert_eq(clock.dropped_ticks, 0)
	clock.advance(10000.0)  # 300 devidos, 5 rodam
	assert_eq(clock.dropped_ticks, 295)
	clock.set_speed(3.0)
	clock.advance(100.0)  # 9 devidos, 5 rodam
	assert_eq(clock.dropped_ticks, 299)


func test_ignora_delta_zero_negativo_ou_invalido() -> void:
	var clock := _clock()
	assert_eq(clock.advance(0.0), 0)
	assert_eq(clock.advance(-50.0), 0)
	assert_eq(clock.advance(NAN), 0)
	assert_eq(clock.alpha, 0.0)


func test_rejeita_velocidade_fora_da_lista() -> void:
	var clock := _clock()
	clock.set_speed(4.0)
	assert_push_error("Velocidade inválida")
	assert_eq(clock.speed, 1.0)


func test_lerp_interpola_entre_dois_valores() -> void:
	assert_eq(FixedStepClock.lerp_value(10.0, 20.0, 0.0), 10.0)
	assert_eq(FixedStepClock.lerp_value(10.0, 20.0, 0.5), 15.0)
	assert_eq(FixedStepClock.lerp_value(10.0, 20.0, 1.0), 20.0)


# ---------------------------------------------------------------- paridade com o Phaser

func _delta(pattern: String, i: int) -> float:
	if pattern == "irregular":
		return 7.0 + float(i % 13)
	if pattern == "spike":
		return 500.0 if i % 17 == 16 else 1000.0 / 60.0
	return 1000.0 / 60.0


func test_golden_cenarios_do_relogio() -> void:
	var golden: Dictionary = Golden.load_json("clock.json")
	for s in golden["scenarios"]:
		var clock := FixedStepClock.new(golden["config"])
		clock.set_speed(float(s["speed"]))
		var tick_mismatches := 0
		var alpha_mismatches := 0
		for i in int(s["frames"]):
			var ticks := clock.advance(_delta(s["pattern"], i))
			if ticks != int(s["ticks"][i]):
				tick_mismatches += 1
			if absf(clock.alpha - float(s["alphas"][i])) > 1e-9:
				alpha_mismatches += 1
		assert_eq(tick_mismatches, 0, "%s: ticks por quadro" % s["name"])
		assert_eq(alpha_mismatches, 0, "%s: alpha por quadro" % s["name"])
		assert_eq(clock.dropped_ticks, int(s["dropped"]), "%s: ticks descartados" % s["name"])


func test_golden_duracao_do_tick_e_ciclo_de_velocidades() -> void:
	var golden: Dictionary = Golden.load_json("clock.json")
	var clock := FixedStepClock.new(golden["config"])
	assert_almost_eq(clock.tick_duration_ms, float(golden["tickDurationMs"]), 1e-9)
	var got: Array = []
	for i in 4:
		got.append(clock.cycle_speed())
	clock.set_speed(5.0)
	got.append(clock.cycle_speed())
	var expected: Array = []
	for v in golden["cycle"]:
		expected.append(float(v))
	assert_eq(got, expected)
