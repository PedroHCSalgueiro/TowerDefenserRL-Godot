class_name ProjectileSystems
extends RefCounted
## Projéteis teleguiados: disparar, mover até o alvo e causar o dano.
##
## O projétil persegue a posição atual do alvo. Ao alcançá-lo, aplica o dano
## por `Damage.damage_enemy()` (armadura, morte e evento, com o id da torre) e
## volta para o pool. No tiro em área, o dano vai para todos os inimigos no raio
## do ponto de impacto, em ordem de id.
##
## Alvo que some antes do impacto (morreu ou chegou ao núcleo): o projétil
## troca uma única vez para o inimigo mais próximo do ponto em que o alvo
## sumiu, dentro de `retarget_radius` (empate para o menor id). Sem ninguém no
## raio, ou se o alvo novo também sumir, o projétil some sem causar dano.
##
## O ponto em que o alvo sumiu é exato: enquanto o slot do alvo ainda tem o id
## dele (nenhum inimigo nasce no meio do tick), a posição vem do slot; depois
## que o slot é reaproveitado, vale a última posição guardada no projétil.


## Cria um projétil na posição de quem disparou, mirando `target`.
## `params` (Dictionary): sourceId, x, y, damage, speed, areaRadius (0 = tiro único),
## chain (ChainMark, opcional — padrão: sem cadeia).
static func fire_projectile(ctx: TickContext, params: Dictionary, target: Enemy) -> void:
	var projectile: Projectile = ctx.state.projectiles.acquire()
	projectile.id = ctx.allocate_id()
	projectile.source_id = params["sourceId"]
	var chain: ChainMark = params.get("chain")
	projectile.chain_id = chain.chain_id if chain != null else 0
	projectile.origin_tower_id = chain.origin_tower_id if chain != null else null
	_aim(projectile, target)
	projectile.retargeted = false
	projectile.damage = params["damage"]
	projectile.status_type = params.get("statusType", "")
	projectile.area_radius = params["areaRadius"]
	projectile.speed = params["speed"]
	projectile.x = params["x"]
	projectile.prev_x = projectile.x
	projectile.y = params["y"]
	projectile.prev_y = projectile.y


static func _aim(projectile: Projectile, target: Enemy) -> void:
	projectile.target_id = target.id
	projectile.target_slot = target.slot
	projectile.target_x = target.x
	projectile.target_y = target.y


## Atualiza a última posição conhecida do alvo e devolve o alvo se ele ainda
## estiver no mapa, ou null se já sumiu.
static func _track_target(state: Object, projectile: Projectile) -> Enemy:
	var slots: Array[Enemy] = state.enemies.slots
	if projectile.target_slot >= slots.size():
		return null
	var enemy := slots[projectile.target_slot]
	if enemy.id != projectile.target_id:
		return null
	projectile.target_x = enemy.x
	projectile.target_y = enemy.y
	return enemy if enemy.active else null


## Devolve o sistema (Callable) que move os projéteis e aplica o dano.
static func create_projectile_system(enemies: EnemyData, index: SpatialIndex,
		retarget_radius: float, ticks_per_second: float, towers: TowerData = null) -> Callable:
	if towers == null:
		towers = TowerData.game_data()
	var hits: Array = []
	# Cadeia do projétil que está causando dano (reaproveitada).
	var mark := ChainMark.new(0, null)
	var damage_options := {"chain": mark}

	# Dano em área: todos no raio do ponto de impacto, em ordem de id.
	var explode := func(ctx: TickContext, projectile: Projectile, x: float, y: float) -> void:
		var event := {
			"type": "areaExploded",
			"tick": ctx.state.tick,
			"towerId": projectile.source_id,
			"x": x,
			"y": y,
			"radius": projectile.area_radius,
			"trigger": false,
			"damage": 0.0,
		}
		ctx.emit(event)
		hits.clear()
		index.collect_in_range(ctx.state, x, y, projectile.area_radius, hits)
		for enemy: Enemy in EnemyOrder.sort_by_id(hits):
			var before := enemy.hp
			Damage.damage_enemy(ctx, enemies, enemy, projectile.damage, projectile.source_id, damage_options)
			event["damage"] += before - enemy.hp
			if projectile.status_type != "":
				Status.apply_on_hit(ctx, towers, index, enemy, projectile, ticks_per_second)

	return func(ctx: TickContext) -> void:
		var state := ctx.state
		var pool: ProjectilePool = state.projectiles
		for projectile: Projectile in pool.slots:
			if not projectile.active:
				continue

			var target := _track_target(state, projectile)
			if target == null and not projectile.retargeted:
				target = index.find_nearest(state, projectile.target_x, projectile.target_y, retarget_radius)
				if target != null:
					projectile.retargeted = true
					_aim(projectile, target)
			if target == null:
				pool.release(projectile)
				continue

			projectile.prev_x = projectile.x
			projectile.prev_y = projectile.y
			var dx := target.x - projectile.x
			var dy := target.y - projectile.y
			var dist := SimMath.hypot(dx, dy)
			var step := projectile.speed / ticks_per_second
			if dist <= step:
				projectile.x = target.x
				projectile.y = target.y
				pool.release(projectile)
				mark.chain_id = projectile.chain_id
				mark.origin_tower_id = projectile.origin_tower_id
				if projectile.area_radius > 0.0:
					explode.call(ctx, projectile, target.x, target.y)
				else:
					Damage.damage_enemy(ctx, enemies, target, projectile.damage, projectile.source_id, damage_options)
					if projectile.status_type != "":
						Status.apply_on_hit(ctx, towers, index, target, projectile, ticks_per_second)
			else:
				projectile.x += (dx / dist) * step
				projectile.y += (dy / dist) * step
