class_name Stress
extends RefCounted
## Modo estresse (debug): mantém `count` inimigos ativos. No início de cada tick, repõe quem
## morreu ou chegou ao núcleo, sorteando o tipo com o RNG da run (por isso continua determinístico
## em qualquer velocidade) — porte de `sim/debug/stress.ts`.

## Cache dos tipos sorteáveis por EnemyData (instance id -> Array[String]).
static var _random_type_cache := {}


## Tipos sorteáveis pelo debug e pelo estresse: todos menos os chefões.
static func random_types(data: EnemyData) -> Array:
	var key := data.get_instance_id()
	if not _random_type_cache.has(key):
		var types: Array = []
		for id: String in data.types:
			if not data.types[id].boss:
				types.append(id)
		_random_type_cache[key] = types
	return _random_type_cache[key]


## Cria um inimigo segundo a disposição ("clustered" nasce na entrada; "spread" nasce num ponto
## sorteado da sua rota). `enemy_type` null sorteia o tipo entre os que não são chefão (o chefão só
## vem pelas ondas ou pelo tipo escolhido no painel).
static func spawn_debug_enemy(ctx: TickContext, routes: Dictionary, data: EnemyData,
		enemy_type: Variant, layout: String) -> void:
	var type_id: String = enemy_type if enemy_type != null else ctx.rng.pick(random_types(data))
	var route: Route = routes[data.get_type(type_id).movement]
	var distance := ctx.rng.next_float() * route.length if layout == "spread" else 0.0
	EnemySystems.spawn_enemy(ctx, routes, data, type_id, distance)


static func create_stress_system(routes: Dictionary, data: EnemyData) -> Callable:
	return func(ctx: TickContext) -> void:
		var stress: Variant = ctx.state.debug.stress
		if stress == null:
			return
		var enemies: EnemyPool = ctx.state.enemies
		while enemies.active_count < int(stress["count"]):
			spawn_debug_enemy(ctx, routes, data, null, stress["layout"])
