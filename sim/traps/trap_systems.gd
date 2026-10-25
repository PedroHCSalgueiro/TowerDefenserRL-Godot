class_name TrapSystems
extends RefCounted
## Armadilhas da Engenheira Mabel: onde pôr, quem pisa e o que acontece (ver `Trap`).
##
## Onde: a posição do caminho terrestre, dentro do alcance da torre, mais perto do núcleo que ainda
## não tem armadilha por perto ("última linha de defesa", como no Notion). Cada torre tem um teto de
## armadilhas vivas de cada tipo; no teto, não põe mais (o ataque espera pronto).

## Passo, em casas, da busca de um ponto livre ao longo da rota.
const SEARCH_STEP := 0.5


## Quantas armadilhas desse tipo a torre tem no chão.
static func owned_count(state: Object, tower_id: int, kind: String) -> int:
	var count := 0
	for trap: Trap in state.traps:
		if trap.owner_id == tower_id and trap.kind == kind:
			count += 1
	return count


## Põe uma armadilha de `kind` no melhor ponto livre. Devolve se pôs (teto cheio ou nenhum ponto livre
## no alcance = false).
static func place_trap(ctx: TickContext, routes: Dictionary, tower: Tower, type: TowerData.TowerType,
		kind: String, damage: float, hold_ticks: int, radius: float, max_traps: int) -> bool:
	var state := ctx.state
	if owned_count(state, tower.id, kind) >= max_traps:
		return false
	var route: Route = routes["ground"]
	var point := MutablePoint.new()
	var reach := ClassBonuses.tower_range(ctx.classes, state, type, tower)
	var range_sq := reach * reach
	var tx := float(tower.x)
	var ty := float(tower.y)
	var distance := route.length
	while distance >= 0.0:
		route.sample_into(distance, point)
		var dx := point.x - tx
		var dy := point.y - ty
		if dx * dx + dy * dy <= range_sq and not _near_trap(state, point.x, point.y, radius * 1.5):
			var trap := Trap.new()
			trap.id = ctx.allocate_id()
			trap.owner_id = tower.id
			trap.kind = kind
			trap.x = point.x
			trap.y = point.y
			trap.damage = damage
			trap.hold_ticks = hold_ticks
			trap.radius = radius
			state.traps.append(trap)
			ctx.emit({"type": "trapPlaced", "tick": state.tick, "towerId": tower.id, "trapId": trap.id,
					"kind": kind, "x": trap.x, "y": trap.y})
			return true
		distance -= SEARCH_STEP
	return false


static func _near_trap(state: Object, x: float, y: float, radius: float) -> bool:
	for trap: Trap in state.traps:
		var dx := trap.x - x
		var dy := trap.y - y
		if dx * dx + dy * dy <= radius * radius:
			return true
	return false


## O ataque de uma torre cujo tiro é armadilha ("shot": {"kind": "trap"}): estrepes (o bônus do Invocador
## aumenta o dano).
static func place_caltrop(ctx: TickContext, routes: Dictionary, tower: Tower, type: TowerData.TowerType) -> bool:
	var shot: Dictionary = type.shot
	var damage := Stars.tower_damage(type, tower) * float(shot["damagePercent"]) / 100.0 \
			* ClassBonuses.summon_damage_multiplier(ctx.classes, ctx.state, type)
	return place_trap(ctx, routes, tower, type, "caltrop", damage, 0, shot["radius"], int(shot["maxTraps"]))


## Esqueleto aliado (Vex, região Cripta) no ponto `distance` do caminho terrestre: anda para trás e explode
## no primeiro inimigo terrestre que tocar, com `damage` em área. Movimento e raios: `summons.skeleton` de
## `towers.json`. `owner_id` null = da região (o abate não é de nenhuma torre).
static func spawn_skeleton(ctx: TickContext, routes: Dictionary, towers: TowerData, distance: float, damage: float,
		owner_id: Variant, ticks_per_second: float) -> void:
	var cfg: Dictionary = towers.summons.get("skeleton", {})
	if cfg.is_empty() or not routes.has("ground"):
		return
	# Teto de esqueletos vivos de cada dono (o da região, `owner_id` null, tem o seu).
	var alive := 0
	for trap: Trap in ctx.state.traps:
		if trap.kind == "skeleton" and trap.owner_id == owner_id:
			alive += 1
	if alive >= int(cfg["maxRegion"] if owner_id == null else cfg["maxPerTower"]):
		return
	var route: Route = routes["ground"]
	var point := MutablePoint.new()
	route.sample_into(distance, point)
	var trap := Trap.new()
	trap.id = ctx.allocate_id()
	trap.owner_id = owner_id
	trap.kind = "skeleton"
	trap.x = point.x
	trap.y = point.y
	trap.damage = damage
	trap.hold_ticks = maxi(1, SimMath.js_round(float(cfg["seconds"]) * ticks_per_second))
	trap.radius = float(cfg["blastRadius"])
	trap.params = {"distance": distance, "step": float(cfg["speed"]) / ticks_per_second,
			"contact": float(cfg["contactRadius"])}
	ctx.state.traps.append(trap)
	ctx.emit({"type": "trapPlaced", "tick": ctx.state.tick, "towerId": owner_id, "trapId": trap.id,
			"kind": "skeleton", "x": trap.x, "y": trap.y})


## A distância no caminho terrestre do ponto mais perto de (x, y) (busca de 0,25 em 0,25 casa).
static func route_distance_near(route: Route, x: float, y: float) -> float:
	var point := MutablePoint.new()
	var best := 0.0
	var best_sq := INF
	var d := 0.0
	while d <= route.length:
		route.sample_into(d, point)
		var dx := point.x - x
		var dy := point.y - y
		if dx * dx + dy * dy < best_sq:
			best_sq = dx * dx + dy * dy
			best = d
		d += 0.25
	return best


## Sistema de armadilhas, depois das torres e antes dos gatilhos: o primeiro inimigo terrestre que
## pisa numa armadilha a dispara (estrepes: dano; urso: prende e sangra) e ela some. As outras invocações
## (ver `Trap`) agem a cada tick até acabar o tempo (`hold_ticks`): tentáculo (dano), nuvem de peste e
## cratera (Lento e Envenenado), torreta e grifo (atiram) e esqueleto (anda e explode).
static func create_trap_system(enemies: EnemyData, index: SpatialIndex, routes: Dictionary = {},
		ticks_per_second: float = 30.0) -> Callable:
	var not_ground := func(enemy: Enemy) -> bool:
		return enemies.get_type(enemy.type).movement != "ground"
	var not_air := func(enemy: Enemy) -> bool:
		return enemies.get_type(enemy.type).movement != "air"
	var grabbed: Array = []
	# Os terrestres no raio da invocação, em ordem de id.
	var ground_in := func(state: Object, trap: Trap, radius: float) -> Array:
		grabbed.clear()
		index.collect_in_range(state, trap.x, trap.y, radius, grabbed)
		return EnemyOrder.sort_by_id(grabbed).filter(func(e: Enemy) -> bool: return not not_ground.call(e))
	return func(ctx: TickContext) -> void:
		var state := ctx.state
		if state.traps.is_empty():
			return
		var kept: Array[Trap] = []
		for trap: Trap in state.traps:
			match trap.kind:
				"tentacle":
					for enemy: Enemy in ground_in.call(state, trap, trap.radius):
						Damage.damage_enemy(ctx, enemies, enemy, trap.damage, trap.owner_id)
				"plague", "crater":
					var p := trap.params
					for enemy: Enemy in ground_in.call(state, trap, trap.radius):
						Status.apply_slow(enemy, p["slow"], p["slowCap"], int(p["effectTicks"]))
						if float(p.get("poison", 0.0)) > 0.0:
							Status.apply_poison(enemy, p["poison"], int(p["effectTicks"]), trap.owner_id)
				"sentinel":
					var p := trap.params
					p["cooldown"] = int(p["cooldown"]) - 1
					if int(p["cooldown"]) <= 0:
						var target: Enemy = null
						if p["preferAir"]:
							target = index.find_nearest(state, trap.x, trap.y, p["range"], not_air)
						if target == null:
							target = index.find_nearest(state, trap.x, trap.y, p["range"])
						if target != null:
							var air: bool = enemies.get_type(target.type).movement == "air"
							ProjectileSystems.fire_projectile(ctx, {"sourceId": trap.owner_id, "x": trap.x, "y": trap.y,
									"damage": trap.damage * (float(p["airMultiplier"]) if air else 1.0), "speed": p["speed"],
									"areaRadius": 0.0}, target)
							p["cooldown"] = int(p["interval"])
				"skeleton":
					var p := trap.params
					p["distance"] = float(p["distance"]) - float(p["step"])
					var route: Route = routes.get("ground")
					if route == null or float(p["distance"]) <= 0.0:
						continue
					var point := MutablePoint.new()
					route.sample_into(p["distance"], point)
					trap.x = point.x
					trap.y = point.y
					if index.find_nearest(state, trap.x, trap.y, p["contact"], not_ground) != null:
						ctx.emit({"type": "areaExploded", "tick": state.tick, "towerId": trap.owner_id, "x": trap.x,
								"y": trap.y, "radius": trap.radius, "trigger": false, "damage": 0.0})
						for enemy: Enemy in ground_in.call(state, trap, trap.radius):
							Damage.damage_enemy(ctx, enemies, enemy, trap.damage, trap.owner_id)
						continue
				_:
					var victim := index.find_nearest(state, trap.x, trap.y, trap.radius, not_ground)
					if victim == null:
						kept.append(trap)
						continue
					ctx.emit({"type": "trapSprung", "tick": state.tick, "towerId": trap.owner_id, "trapId": trap.id,
							"kind": trap.kind, "x": trap.x, "y": trap.y, "enemyId": victim.id})
					if trap.kind == "bear":
						Status.apply_stun(victim, trap.hold_ticks)
						Status.apply_bleed(victim, trap.damage, trap.hold_ticks, trap.owner_id)
					else:
						Damage.damage_enemy(ctx, enemies, victim, trap.damage, trap.owner_id)
					continue
			trap.hold_ticks -= 1
			if trap.hold_ticks > 0:
				kept.append(trap)
		state.traps = kept
