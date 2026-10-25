class_name Status
extends RefCounted
## Efeitos de estado dos inimigos (Notion, "Efeitos de estado"): **Lento** (anda mais devagar,
## empilha até um teto), **Atordoado** (para por um instante), **Sangramento** (perde vida aos
## poucos, sem armadura), **Envenenado** (igual, num campo separado), **Marcado** (uma marca por Caçador; só os
## Caçadores tiram proveito),
## **Empurrado** (volta casas no caminho) e **Amaldiçoado** (divide o dano que recebe com os vizinhos e
## pula para eles ao morrer). Os campos ficam no `Enemy` (ticks que faltam); o movimento lê Lento e
## Atordoado, e o sistema de estados (`create_status_system`) conta o tempo e aplica o Sangramento.
##
## As torres aplicam estado de dois jeitos: no acerto dos tiros (`onHit` em `towers.json` e a marca
## dos Caçadores, ver `apply_on_hit`) e por gatilho (`stunFront`, `stunSlowed`, `frontBeam` com Lento,
## `tide`, `tentacle`, `curseNext`). Sem nenhuma dessas torres nos dados, o sistema de estados nem entra
## na lista de sistemas (`TowerData.uses_statuses`). O Empurrado é instantâneo (não tem tempo).

## Vizinhos da Maldição (reaproveitado; a simulação roda numa thread só).
static var _near: Array = []


static func seconds_to_ticks(seconds: float, ticks_per_second: float) -> int:
	return maxi(1, SimMath.js_round(seconds * ticks_per_second))


## Tira todo efeito do inimigo (o slot do pool é reaproveitado no spawn).
static func clear(enemy: Enemy) -> void:
	enemy.slow_percent = 0.0
	enemy.slow_ticks = 0
	enemy.stun_ticks = 0
	enemy.bleed_damage = 0.0
	enemy.bleed_ticks = 0
	enemy.bleed_source = null
	enemy.poison_damage = 0.0
	enemy.poison_ticks = 0
	enemy.poison_source = null
	if not enemy.marks.is_empty():
		enemy.marks.clear()
	if not enemy.curse.is_empty():
		enemy.curse = {}


## Soma `percent` de lentidão (até `cap`) e renova a duração se a nova for maior.
static func apply_slow(enemy: Enemy, percent: float, cap: float, ticks: int) -> void:
	enemy.slow_percent = minf(cap, enemy.slow_percent + percent) if enemy.slow_ticks > 0 else minf(cap, percent)
	enemy.slow_ticks = maxi(enemy.slow_ticks, ticks)


static func apply_stun(enemy: Enemy, ticks: int) -> void:
	enemy.stun_ticks = maxi(enemy.stun_ticks, ticks)


## Sangramento de `damage_per_tick` por `ticks`. Já sangrando: fica o mais forte e a duração
## renova (não soma, para não virar bola de neve).
static func apply_bleed(enemy: Enemy, damage_per_tick: float, ticks: int, source_id: Variant) -> void:
	if enemy.bleed_ticks == 0 or damage_per_tick >= enemy.bleed_damage:
		enemy.bleed_damage = damage_per_tick
		enemy.bleed_source = source_id
	enemy.bleed_ticks = maxi(enemy.bleed_ticks, ticks)


## Envenenado: como o Sangramento (fica o mais forte e a duração renova), num campo separado.
static func apply_poison(enemy: Enemy, damage_per_tick: float, ticks: int, source_id: Variant) -> void:
	if enemy.poison_ticks == 0 or damage_per_tick >= enemy.poison_damage:
		enemy.poison_damage = damage_per_tick
		enemy.poison_source = source_id
	enemy.poison_ticks = maxi(enemy.poison_ticks, ticks)


## Move o inimigo para `target` casas da rota (para a frente ou para trás), com as regras do Empurrado: o
## chefão não se move e o elite anda no máximo `eliteMaxCells`. Devolve quantas casas ele andou.
static func move_to(enemy: Enemy, target: float, rules: Dictionary, routes: Dictionary, data: EnemyData) -> float:
	if not enemy.active:
		return 0.0
	var type := enemy.type_data if enemy.type_data != null else data.get_type(enemy.type)
	if type.boss and rules.get("bossImmune", true):
		return 0.0
	var delta := target - enemy.distance
	if enemy.elite:
		var cap := float(rules.get("eliteMaxCells", absf(delta)))
		delta = clampf(delta, -cap, cap)
	var route: Route = enemy.route if enemy.route != null else routes[type.movement]
	enemy.distance = clampf(enemy.distance + delta, 0.0, route.length)
	route.sample_into(enemy.distance, enemy)
	enemy.seg = route.find_segment(enemy.distance)
	return absf(delta)


## Marca do Caçador `tower_id` por `ticks`: acertar de novo renova (cada Caçador tem a sua marca).
static func apply_mark(enemy: Enemy, tower_id: int, ticks: int) -> void:
	enemy.marks[tower_id] = maxi(int(enemy.marks.get(tower_id, 0)), ticks)


## Empurra o inimigo `cells` casas para trás no caminho dele (nunca antes da entrada). `rules`:
## `TowerData.statuses["push"]` ({"eliteMaxCells", "bossImmune"}): o chefão é imune e o elite volta
## no máximo `eliteMaxCells`. Devolve quantas casas ele voltou (0 = nada).
static func push(enemy: Enemy, cells: float, rules: Dictionary, routes: Dictionary, data: EnemyData) -> float:
	if not enemy.active or cells <= 0.0:
		return 0.0
	var type := enemy.type_data if enemy.type_data != null else data.get_type(enemy.type)
	if type.boss and rules.get("bossImmune", true):
		return 0.0
	var amount := minf(cells, float(rules.get("eliteMaxCells", cells))) if enemy.elite else cells
	var before := enemy.distance
	enemy.distance = maxf(0.0, enemy.distance - amount)
	var route: Route = enemy.route if enemy.route != null else routes[type.movement]
	route.sample_into(enemy.distance, enemy)
	# O cursor do movimento só anda para a frente: volta a buscar o segmento.
	enemy.seg = route.find_segment(enemy.distance)
	return before - enemy.distance


## Amaldiçoa o inimigo por `ticks` com os números da Maldição (`curse`: {"percent", "spread", "radius"};
## `jumps` = saltos que ainda restam; `source` = torre que amaldiçoou). Cada salto dura `ticks` de novo.
## Já amaldiçoado: fica o tempo e os saltos maiores.
static func apply_curse(enemy: Enemy, curse: Dictionary, ticks: int, jumps: int, source: Variant) -> void:
	if not enemy.active:
		return
	if not enemy.curse.is_empty():
		enemy.curse["ticks"] = maxi(int(enemy.curse["ticks"]), ticks)
		enemy.curse["jumps"] = maxi(int(enemy.curse["jumps"]), jumps)
		return
	enemy.curse = {
		"ticks": ticks,
		"duration": ticks,
		"percent": float(curse["percent"]),
		"spread": int(curse["spread"]),
		"radius": float(curse["radius"]),
		"jumps": jumps,
		"source": source,
	}


## Os `spread` inimigos vivos mais próximos de `enemy` (dentro do raio da Maldição), do mais perto para o
## mais longe, sem ele mesmo. Empate: menor id.
static func _curse_neighbors(index: SpatialIndex, state: Object, enemy: Enemy, curse: Dictionary) -> Array:
	var spread := int(curse["spread"])
	index.find_best_n(state, enemy.x, enemy.y, float(curse["radius"]), _distance_sq, spread + 1, _near)
	var out: Array = []
	for other: Enemy in _near:
		if other != enemy and out.size() < spread:
			out.append(other)
	return out


static func _distance_sq(enemy: Enemy, x: float, y: float) -> float:
	var dx := enemy.x - x
	var dy := enemy.y - y
	return dx * dx + dy * dy


## O amaldiçoado levou `damage` de vida: cada um dos vizinhos dele leva `percent`% disso (com a armadura
## de cada um), creditado a quem causou o dano. O dano dividido não se divide de novo.
static func share_curse(ctx: TickContext, data: EnemyData, enemy: Enemy, damage: float, tower_id: Variant,
		chain: ChainMark) -> void:
	var curse := enemy.curse
	var shared := damage * float(curse["percent"]) / 100.0
	if shared <= 0.0:
		return
	var options := {"shared": true, "chain": chain}
	for other: Enemy in _curse_neighbors(ctx.index, ctx.state, enemy, curse):
		Damage.damage_enemy(ctx, data, other, shared, tower_id, options)


## O amaldiçoado morreu: com saltos sobrando, a Maldição pula para os vizinhos vivos mais próximos do
## ponto da morte, com um salto a menos e o tempo cheio. Emite `curseJumped`.
static func jump_curse(ctx: TickContext, enemy: Enemy, curse: Dictionary) -> void:
	var jumps := int(curse["jumps"])
	if jumps <= 0:
		return
	var targets := _curse_neighbors(ctx.index, ctx.state, enemy, curse)
	if targets.is_empty():
		return
	var points: Array = []
	for other: Enemy in targets:
		apply_curse(other, curse, int(curse["duration"]), jumps - 1, curse["source"])
		points.append({"x": other.x, "y": other.y})
	ctx.emit({"type": "curseJumped", "tick": ctx.state.tick, "towerId": curse["source"], "x": enemy.x, "y": enemy.y,
			"points": points})


## Efeitos do acerto de um tiro cujo tipo tem `onHit` ou marca (Caçador): Lento (e o ricochete para
## trás), Sangramento, a marca do Caçador e a Maldição que o tiro carrega.
static func apply_on_hit(ctx: TickContext, towers: TowerData, index: SpatialIndex, enemy: Enemy,
		projectile: Projectile, ticks_per_second: float) -> void:
	if not enemy.active:
		return
	if not projectile.curse.is_empty():
		apply_curse(enemy, projectile.curse, seconds_to_ticks(projectile.curse["seconds"], ticks_per_second),
				int(projectile.curse["jumps"]), projectile.source_id)
		ctx.emit({"type": "statusApplied", "tick": ctx.state.tick, "towerId": projectile.source_id,
				"status": "curse", "count": 1})
	# A flecha da Nyx depois de um abate marca o alvo, mesmo ela não sendo Caçadora.
	if projectile.force_mark and not towers.statuses["mark"].is_empty():
		apply_mark(enemy, projectile.source_id, seconds_to_ticks(towers.statuses["mark"]["seconds"], ticks_per_second))
	var type: TowerData.TowerType = towers.types.get(projectile.status_type)
	if type == null:
		return
	if type.marks:
		apply_mark(enemy, projectile.source_id, seconds_to_ticks(towers.statuses["mark"]["seconds"], ticks_per_second))
	var slow: Dictionary = type.on_hit.get("slow", {})
	if not slow.is_empty():
		# Bônus do Controlador: o Lento dura mais.
		var seconds: float = slow["seconds"] * ClassBonuses.status_duration_multiplier(ctx.classes, ctx.state, type)
		apply_slow(enemy, slow["percent"], slow["cap"], seconds_to_ticks(seconds, ticks_per_second))
		if slow["bounces"] > 0:
			_bounce_slow(ctx, index, enemy, slow, seconds, ticks_per_second)
	var bleed: Dictionary = type.on_hit.get("bleed", {})
	if not bleed.is_empty():
		apply_bleed(enemy, (projectile.damage * bleed["percentPerSecond"] / 100.0) / ticks_per_second,
				seconds_to_ticks(bleed["seconds"], ticks_per_second), projectile.source_id)


## O gelo ricocheteia para trás: a partir do inimigo acertado, salta até `bounces` vezes para o
## mais próximo (dentro de `bounceRadius`) que está atrás dele na rota, sem repetir, e soma Lento.
static func _bounce_slow(ctx: TickContext, index: SpatialIndex, first: Enemy, slow: Dictionary, seconds: float,
		ticks_per_second: float) -> void:
	var ticks := seconds_to_ticks(seconds, ticks_per_second)
	var visited: Array[int] = [first.id]
	var current := first
	for i in int(slow["bounces"]):
		var from := current
		var skip := func(candidate: Enemy) -> bool:
			return visited.has(candidate.id) or candidate.distance >= from.distance
		var next := index.find_nearest(ctx.state, from.x, from.y, slow["bounceRadius"], skip)
		if next == null:
			return
		apply_slow(next, slow["percent"], slow["cap"], ticks)
		visited.append(next.id)
		current = next


## Sistema de estados: conta o tempo de Atordoado, Lento, Sangramento, das marcas e da Maldição e aplica
## o dano do Sangramento (creditado à torre de origem; mata como qualquer dano). Roda depois das torres
## e antes dos gatilhos, para os abates dele entrarem nos gatilhos do mesmo tick.
static func create_status_system(enemies: EnemyData) -> Callable:
	var bleed_options := {"ignoreArmor": true}
	return func(ctx: TickContext) -> void:
		for enemy: Enemy in ctx.state.enemies.slots:
			if not enemy.active:
				continue
			if enemy.stun_ticks > 0:
				enemy.stun_ticks -= 1
			if enemy.slow_ticks > 0:
				enemy.slow_ticks -= 1
				if enemy.slow_ticks == 0:
					enemy.slow_percent = 0.0
			if not enemy.marks.is_empty():
				for id: int in enemy.marks.keys():
					var left: int = enemy.marks[id] - 1
					if left <= 0:
						enemy.marks.erase(id)
					else:
						enemy.marks[id] = left
			if not enemy.curse.is_empty():
				var curse_left: int = enemy.curse["ticks"] - 1
				if curse_left <= 0:
					enemy.curse = {}
				else:
					enemy.curse["ticks"] = curse_left
			if enemy.bleed_ticks > 0:
				enemy.bleed_ticks -= 1
				var damage := enemy.bleed_damage
				var source: Variant = enemy.bleed_source
				if enemy.bleed_ticks == 0:
					enemy.bleed_damage = 0.0
					enemy.bleed_source = null
				Damage.damage_enemy(ctx, enemies, enemy, damage, source, bleed_options)
			if enemy.poison_ticks > 0 and enemy.active:
				enemy.poison_ticks -= 1
				var poison := enemy.poison_damage
				var poisoner: Variant = enemy.poison_source
				if enemy.poison_ticks == 0:
					enemy.poison_damage = 0.0
					enemy.poison_source = null
				Damage.damage_enemy(ctx, enemies, enemy, poison, poisoner, bleed_options)
