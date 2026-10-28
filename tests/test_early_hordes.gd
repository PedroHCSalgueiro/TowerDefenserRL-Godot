extends GutTest
## O início da run é horda: inimigos juntos, um atrás do outro, e a onda acaba rápido (as ondas
## 1 a 9 não podem voltar a "pingar" um inimigo a cada 2 s).

const HORDE_WAVES := 9
const MAX_SPAWN_SECONDS := 0.5
const MAX_SPAWN_DURATION := 10.0


func _count(def: WaveData.WaveDef) -> int:
	var total := 0
	for group in def.enemies:
		total += group.count
	return total


func test_early_waves_come_as_tight_hordes() -> void:
	var data := WaveData.game_data()
	for i in HORDE_WAVES:
		var def := data.waves[i]
		assert_lte(def.spawn_seconds, MAX_SPAWN_SECONDS, "onda %d: espaçamento" % (i + 1))
		var duration := float(_count(def) - 1) * def.spawn_seconds
		assert_lte(duration, MAX_SPAWN_DURATION, "onda %d: duração do nascimento" % (i + 1))


func test_first_wave_is_not_a_trickle() -> void:
	var first := WaveData.game_data().waves[0]
	assert_gte(_count(first), 12, "onda 1 tem horda de verdade")


func test_horde_grows_over_the_first_waves() -> void:
	var data := WaveData.game_data()
	assert_gt(_count(data.waves[3]), _count(data.waves[0]), "onda 4 maior que a onda 1")
