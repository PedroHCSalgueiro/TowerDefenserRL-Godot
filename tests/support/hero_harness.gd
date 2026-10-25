class_name HeroHarness
extends RefCounted
## Apoio aos testes dos heróis: um tick "de mentira" para chamar os efeitos de gatilho direto, com o estado
## da run, o contexto (índice espacial, classes e o resto que a partida põe), as rotas do mapa e o motor de
## gatilhos (que só serve de `env` para `TriggerEffects`). Os dados são os do conjunto selecionado.

var state: RunState
var ctx: TickContext
var engine: TriggerEngine
var routes: Dictionary
var index: SpatialIndex
var enemies: EnemyData
var towers: TowerData
var classes: ClassData
var map: SimMap


func _init(p_map: SimMap) -> void:
	map = p_map
	state = RunState.create("herois")
	enemies = EnemyData.game_data()
	towers = TowerData.game_data()
	classes = ClassData.game_data()
	routes = Route.build_routes(map)
	index = SpatialIndex.new(1.0)
	engine = TriggerEngine.new({"index": index, "enemies": enemies, "towers": towers, "classes": classes,
			"scores": Targeting.create_target_scores(routes, enemies), "ticksPerSecond": 30.0, "routes": routes,
			"map": map})
	next_tick()


## Tick novo: o índice espacial é refeito na próxima consulta.
func next_tick() -> void:
	state.tick += 1
	ctx = TickContext.new(state, Rng.new(state), [], [], EventBus.new())
	ctx.index = index
	ctx.classes = classes
	ctx.routes = routes
	ctx.towers = towers
	engine.ctx = ctx


func spawn(type: String, distance: float, elite: bool = false) -> Enemy:
	return EnemySystems.spawn_enemy(ctx, routes, enemies, type, distance, 1.0, 1, elite)


## Torre posta à mão ao lado do ponto da rota a `distance` casas (o alcance dela cobre os vizinhos).
func tower_at(type: String, distance: float, star: int = 1, id: int = 0) -> Tower:
	var p := MutablePoint.new()
	(routes["ground"] as Route).sample_into(distance, p)
	var tower := Tower.new(id if id > 0 else 9000 + state.towers.size(), type, Vector2i(roundi(p.x), roundi(p.y) + 1), star)
	state.towers.append(tower)
	return tower


func set_level(class_id: String, level: int) -> void:
	(state.classes[class_id] as ClassState.ClassStatus).level = level


## O efeito do gatilho da torre, na estrela dela. Devolve o que `run_effect` devolve.
func fire(tower: Tower, entry: TriggerState.PendingTrigger = null) -> bool:
	var type := towers.get_type(tower.type)
	var star := Stars.tower_star(type, tower)
	return TriggerEffects.run_effect(engine, tower, type, star.effect,
			entry if entry != null else TriggerState.PendingTrigger.new(), false)


func effect(tower: Tower) -> Dictionary:
	return Stars.tower_star(towers.get_type(tower.type), tower).effect


func events_of(type: String) -> Array:
	return ctx.tick_events.filter(func(e: Dictionary) -> bool: return e["type"] == type)


## Um abate "de mentira" de `tower_id` no tick, para o motor de gatilhos ler.
func kill_event(tower_id: Variant, marked: bool = false) -> void:
	ctx.tick_events.append({"type": "enemyKilled", "tick": state.tick, "enemyId": 900000 + ctx.tick_events.size(),
			"enemyType": "common", "wave": 1, "towerId": tower_id, "x": 0.0, "y": 0.0, "elite": false, "marked": marked,
			"weight": 1, "chainId": 0, "originTowerId": null})


## Roda o sistema de projéteis até não sobrar projétil no ar (no máximo `ticks`).
func fly_projectiles(ticks: int = 60) -> void:
	var system := ProjectileSystems.create_projectile_system(enemies, index, towers.projectile_retarget_radius,
			30.0, towers, classes)
	for i in ticks:
		if state.projectiles.active_count == 0:
			return
		next_tick()
		system.call(ctx)


## Roda o sistema de invocações (`TrapSystems`) por `ticks`.
func run_summons(ticks: int) -> void:
	var system := TrapSystems.create_trap_system(enemies, index, routes, 30.0)
	for i in ticks:
		next_tick()
		system.call(ctx)
