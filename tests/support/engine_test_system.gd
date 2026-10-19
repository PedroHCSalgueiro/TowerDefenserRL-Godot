class_name EngineTestSystem
extends RefCounted
## Sistema de teste do motor (igual ao `testSystem` de simulation.test.ts):
## consome o RNG, aloca ids e reage às ações, para que o estado dependa da
## semente, do número de ticks e das ações enfileiradas.


static func system(ctx: TickContext) -> void:
	for command: Dictionary in ctx.commands:
		if command["type"] == "spawnEnemy":
			ctx.emit({
				"type": "enemySpawned",
				"tick": ctx.state.tick,
				"enemyId": ctx.allocate_id(),
				"enemyType": "common",
			})
	if ctx.rng.chance(0.3):
		ctx.emit({
			"type": "enemySpawned",
			"tick": ctx.state.tick,
			"enemyId": ctx.allocate_id(),
			"enemyType": "common",
		})


## Ações aplicadas em ticks fixos, simulando o jogador. Devolve os eventos emitidos.
static func run_with_actions(sim: Simulation, ticks: int) -> Array:
	var events: Array = []
	for i in ticks:
		if sim.state.tick % 7 == 0:
			sim.enqueue({"type": "spawnEnemy", "enemyType": "common"})
		sim.step()
		events.append_array(sim.drain_events())
	return events
