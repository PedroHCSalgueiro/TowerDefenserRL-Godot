class_name SimulationRunner
extends RefCounted
## Liga a simulação ao relógio de passo fixo (porte de `SimulationRunner`).
## A renderização só repassa o delta de cada quadro e lê `alpha` para interpolar.

var sim: Simulation
var clock: FixedStepClock
## Mede cada tick. Objeto com `now() -> float` e `record_tick(duration_ms: float)`.
## O relógio vem de fora, para a simulação não depender de tempo real: medir não muda o estado.
var profiler: Object = null
## Pausa: nenhum tick roda e o tempo real não acumula. Fica fora do estado
## (não vai para o save) e não muda o resultado da simulação.
var paused := false


func _init(p_sim: Simulation, config: Dictionary = {}) -> void:
	sim = p_sim
	clock = FixedStepClock.new(config if not config.is_empty() else EngineData.config())


## Roda os ticks devidos neste quadro e devolve os eventos emitidos. Com a tela
## de recompensa aberta, o relógio anda na velocidade base (1x), para o tempo
## de escolha ser o tempo real.
func update(delta_ms: float) -> Array:
	var speed := clock.base_speed if Simulation.is_frozen(sim.state) else NAN
	var ticks := 0 if paused else clock.advance(delta_ms, speed)
	for i in ticks:
		if profiler != null:
			var start: float = profiler.now()
			sim.step()
			profiler.record_tick(profiler.now() - start)
		else:
			sim.step()
	return sim.drain_events()


var alpha: float:
	get:
		return clock.alpha
