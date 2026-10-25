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
	var reach := ClassBonuses.tower_range(ctx.classes, state, type)
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


## Sistema de armadilhas, depois das torres e antes dos gatilhos: o primeiro inimigo terrestre que
## pisa numa armadilha a dispara (estrepes: dano; urso: prende e sangra) e ela some. O tentáculo da
## Nerea ("tentacle") não é pisado: a cada tick causa `damage` em todos os terrestres no raio, até
## acabar o tempo (`hold_ticks`).
static func create_trap_system(enemies: EnemyData, index: SpatialIndex) -> Callable:
	var not_ground := func(enemy: Enemy) -> bool:
		return enemies.get_type(enemy.type).movement != "ground"
	var grabbed: Array = []
	return func(ctx: TickContext) -> void:
		var state := ctx.state
		if state.traps.is_empty():
			return
		var kept: Array[Trap] = []
		for trap: Trap in state.traps:
			if trap.kind == "tentacle":
				grabbed.clear()
				index.collect_in_range(state, trap.x, trap.y, trap.radius, grabbed)
				for enemy: Enemy in EnemyOrder.sort_by_id(grabbed):
					if not not_ground.call(enemy):
						Damage.damage_enemy(ctx, enemies, enemy, trap.damage, trap.owner_id)
				trap.hold_ticks -= 1
				if trap.hold_ticks > 0:
					kept.append(trap)
				continue
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
		state.traps = kept
