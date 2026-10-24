class_name NexusSystems
extends RefCounted
## Sistemas do núcleo: dano de quem chega, derrota e o ataque fraco (porte de `nexus/systems.ts`).


## Inimigo que chegou ao fim da rota causa `nexusDamage` (o do elite, se for) e sai do mapa. Se a
## vida do núcleo zerar, a run termina (`runLost` é emitido uma vez). O chefão que chega é derrota
## imediata, qualquer que seja a vida: o núcleo vai a 0. Com o núcleo invulnerável (debug), o
## inimigo (chefão inclusive) sai do mapa sem causar dano. O bônus do Guardião (nível 4) reduz o dano
## de quem chega (não salva do chefão).
static func create_nexus_contact_system(routes: Dictionary, data: EnemyData, classes: ClassData = null) -> Callable:
	if classes == null:
		classes = ClassData.game_data()
	return func(ctx: TickContext) -> void:
		var state := ctx.state
		var reduction := -1.0
		for enemy: Enemy in state.enemies.slots:
			if not enemy.active:
				continue
			if enemy.route != null:
				if enemy.distance < enemy.route_length:
					continue
			elif enemy.distance < (routes[data.get_type(enemy.type).movement] as Route).length:
				continue
			var type := data.get_type(enemy.type)
			var invulnerable: bool = state.debug.nexus_invulnerable
			var damage := 0.0
			if not invulnerable:
				damage = state.nexus.hp if type.boss else data.enemy_nexus_damage(type, enemy.elite)
				if not type.boss:
					if reduction < 0.0:
						reduction = ClassBonuses.nexus_damage_multiplier(classes, state)
					if reduction != 1.0:
						damage *= reduction
			state.nexus.hp = maxf(0.0, state.nexus.hp - damage)
			state.enemies.release(enemy)
			ctx.emit({"type": "enemyReachedNexus", "tick": state.tick, "enemyId": enemy.id, "damage": damage})
			if type.boss and not invulnerable:
				ctx.emit({
					"type": "bossReachedNexus",
					"tick": state.tick,
					"enemyId": enemy.id,
					"enemyType": enemy.type,
				})
		if state.nexus.hp <= 0.0 and state.status == "playing":
			state.status = "lost"
			ctx.emit({"type": "runLost", "tick": state.tick})


## Ataca o inimigo mais próximo do núcleo dentro do alcance (voadores inclusive), com desempate
## pelo menor id. Um ataque a cada `cooldownSeconds`. A busca usa o índice espacial (o mesmo das
## torres, quando compartilhado). O dano é multiplicado pelo bônus "Núcleo armado" das
## recompensas (T24).
static func create_nexus_attack_system(nexus_cell: Vector2i, enemies: EnemyData, nexus: NexusData,
		ticks_per_second: float, index: SpatialIndex = null) -> Callable:
	if index == null:
		index = SpatialIndex.new(float(EngineData.config()["spatialCellSize"]))
	var damage := nexus.attack_damage
	var range_ := nexus.attack_range
	var cooldown_ticks := maxi(1, SimMath.js_round(nexus.attack_cooldown_seconds * ticks_per_second))

	return func(ctx: TickContext) -> void:
		var state := ctx.state
		if state.status != "playing":
			return
		if state.nexus.attack_cooldown_ticks > 0:
			state.nexus.attack_cooldown_ticks -= 1
		if state.nexus.attack_cooldown_ticks > 0:
			return

		var target := index.find_nearest(state, float(nexus_cell.x), float(nexus_cell.y), range_)
		if target == null:
			return

		state.nexus.attack_cooldown_ticks = cooldown_ticks
		ctx.emit({
			"type": "nexusFired",
			"tick": state.tick,
			"targetId": target.id,
			"x": target.x,
			"y": target.y,
		})
		Damage.damage_enemy(ctx, enemies, target, damage * RewardMods.of(state).nexus_damage_multiplier, null)
