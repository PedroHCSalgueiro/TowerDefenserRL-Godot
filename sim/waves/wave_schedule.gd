class_name WaveSchedule
extends RefCounted
## Expande cada onda dos dados numa lista fixa de nascimentos: em que tick (contado do início da
## onda) nasce cada inimigo. Sem RNG: a mesma onda gera sempre a mesma lista, e o save só precisa
## guardar quantos já nasceram (porte de `schedule.ts`).

class SpawnEntry:
	extends RefCounted
	## Ticks desde o início da onda (0 = o tick em que ela foi chamada).
	var tick: int
	var type: String
	var elite: bool

	func _init(p_tick: int, p_type: String, p_elite: bool) -> void:
		tick = p_tick
		type = p_type
		elite = p_elite

var hp_multiplier: float
var entries: Array[SpawnEntry] = []
## Chefões na lista da onda (calculado sob demanda por `WaveSystems.boss_count_of`; -1 = ainda não).
var boss_count := -1


## Fila única: o primeiro nasce no tick da chamada e cada um dos seguintes `spawn_seconds` depois
## do anterior, na ordem dos grupos. Os segundos são convertidos para ticks a partir da posição na
## fila, para o arredondamento não acumular erro.
static func build_wave_schedule(wave: WaveData.WaveDef, ticks_per_second: float) -> WaveSchedule:
	var schedule := WaveSchedule.new()
	schedule.hp_multiplier = wave.hp_multiplier
	for group in wave.enemies:
		for i in group.count:
			var seconds := float(schedule.entries.size()) * wave.spawn_seconds
			# O epsilon evita que 0,15 × 3 = 0,44999... arredonde para baixo.
			schedule.entries.append(SpawnEntry.new(
					SimMath.js_round(seconds * ticks_per_second + 1e-9), group.type, group.elite))
	return schedule


static func build_wave_schedules(data: WaveData, ticks_per_second: float) -> Array[WaveSchedule]:
	var out: Array[WaveSchedule] = []
	for wave in data.waves:
		out.append(build_wave_schedule(wave, ticks_per_second))
	return out
