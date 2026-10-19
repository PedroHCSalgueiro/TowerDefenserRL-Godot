class_name EnemySim
extends RefCounted
## Apoio aos testes de inimigos: mapa pequeno e números "redondos" (porte de
## tests/support/enemySim.ts). Com 8 ticks/s e velocidade 2, cada tick anda
## exatamente 0,25 casa, o que evita erro de ponto flutuante nas comparações.

const TPS := 8
const STEP := 0.25


## Entra em (0,1), vai até (3,1), desce até (3,3) e termina no núcleo em (1,3).
## Rota terrestre: 7 casas. Rota aérea: reta de (0,1) a (1,3), √5 casas.
static func small_map() -> SimMap:
	return SimMap.load_map({
		"id": "small", "width": 5, "height": 4,
		"path": [{"x": 0, "y": 1}, {"x": 3, "y": 1}, {"x": 3, "y": 3}, {"x": 1, "y": 3}],
	})


static func test_enemies() -> EnemyData:
	return EnemyData.load_data({
		"armor": {"scale": 100},
		"elite": {"hpMultiplier": 6, "speedMultiplier": 0.8, "nexusDamage": 5},
		"types": {
			"walker": {"hp": 10, "speed": 2, "armor": 0, "nexusDamage": 2, "gold": 1, "movement": "ground"},
			"flyer": {"hp": 10, "speed": 2, "armor": 0, "nexusDamage": 1, "gold": 1, "movement": "air"},
			"tank": {"hp": 10, "speed": 2, "armor": 50, "nexusDamage": 3, "gold": 2, "movement": "ground"},
			"titan": {"hp": 100, "speed": 2, "armor": 50, "nexusDamage": 5, "gold": 5, "movement": "ground", "boss": true},
			"brick": {"hp": 1e9, "speed": 2, "armor": 0, "nexusDamage": 2, "gold": 0, "movement": "ground"},
		},
	})


## Simulação com spawn por ação (`spawnEnemy`) e movimento, sobre o mapa pequeno.
static func make_sim() -> Simulation:
	var data := test_enemies()
	var routes := Route.build_routes(small_map())
	var spawn_system := func(ctx: TickContext) -> void:
		for command: Dictionary in ctx.commands:
			if command["type"] == "spawnEnemy":
				EnemySystems.spawn_enemy(ctx, routes, data, command["enemyType"])
	var movement := EnemySystems.create_movement_system(routes, data, float(TPS))
	return Simulation.new(TestRunState.new("test"), [spawn_system, movement])


## Coloca um inimigo direto no estado, numa posição exata (sem passar pelo spawn).
static func place(state: Object, type: String, x: float, y: float, hp: float = 10.0) -> Enemy:
	var enemy: Enemy = state.enemies.acquire()
	enemy.id = state.next_entity_id
	state.next_entity_id += 1
	enemy.type = type
	enemy.hp = hp
	enemy.max_hp = hp
	enemy.distance = 0.0
	enemy.x = x
	enemy.prev_x = x
	enemy.y = y
	enemy.prev_y = y
	return enemy


static func spawn(sim: Simulation, enemy_type: String, count: int = 1) -> void:
	for i in count:
		sim.enqueue({"type": "spawnEnemy", "enemyType": enemy_type})


static func active_enemies(state: Object) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for enemy in state.enemies.slots:
		if enemy.active:
			out.append(enemy)
	return out


static func run(sim: Simulation, ticks: int, events: Array = []) -> Array:
	for i in ticks:
		sim.step()
		events.append_array(sim.drain_events())
	return events
