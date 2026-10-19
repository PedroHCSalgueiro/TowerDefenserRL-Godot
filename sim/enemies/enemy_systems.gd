class_name EnemySystems
extends RefCounted
## Inimigos: spawn (chamado pelas ações e pelo modo estresse) e movimento.


## Coloca um inimigo do tipo pedido a `distance` casas do início da sua rota
## (0 = na entrada) e emite `enemySpawned`. `hp_multiplier` multiplica a vida
## dos dados (o multiplicador da onda); `wave` é a onda dona do inimigo (0 = sem onda).
## O elite tem ainda a vida multiplicada por `EnemyData.elite_hp_multiplier`.
## Tipo desconhecido: push_error e devolve null.
static func spawn_enemy(ctx: TickContext, routes: Dictionary, data: EnemyData, enemy_type: String,
		distance: float = 0.0, hp_multiplier: float = 1.0, wave: int = 0, elite: bool = false) -> Enemy:
	var type := data.get_type(enemy_type)
	if type == null:
		return null
	var enemy: Enemy = ctx.state.enemies.acquire()
	enemy.id = ctx.allocate_id()
	enemy.type = enemy_type
	enemy.wave = wave
	enemy.elite = elite
	enemy.hp = type.hp * hp_multiplier * (data.elite_hp_multiplier if elite else 1.0)
	enemy.max_hp = enemy.hp
	enemy.distance = distance
	var route: Route = routes[type.movement]
	route.sample_into(distance, enemy)
	enemy.type_data = type
	enemy.route = route
	enemy.route_length = route.length
	enemy.seg = route.find_segment(distance)
	enemy.step = -1.0
	Status.clear(enemy)
	# Sem isso, um slot reaproveitado seria interpolado a partir da posição antiga.
	enemy.prev_x = enemy.x
	enemy.prev_y = enemy.y
	ctx.emit({
		"type": "enemySpawned",
		"tick": ctx.state.tick,
		"enemyId": enemy.id,
		"enemyType": enemy.type,
	})
	return enemy


## Anda `speed / ticks_per_second` casas por tick (o elite, mais devagar), guardando
## a posição anterior para a renderização interpolar. Devolve o sistema (Callable).
static func create_movement_system(routes: Dictionary, data: EnemyData, ticks_per_second: float) -> Callable:
	return func(ctx: TickContext) -> void:
		for enemy: Enemy in ctx.state.enemies.slots:
			if not enemy.active:
				continue
			var route := enemy.route
			if route == null:
				# Inimigo posto à mão (testes): sem cache, usa o caminho lento.
				var slow_type := data.get_type(enemy.type)
				enemy.prev_x = enemy.x
				enemy.prev_y = enemy.y
				enemy.distance += data.enemy_speed(slow_type, enemy.elite) / ticks_per_second
				(routes[slow_type.movement] as Route).sample_into(enemy.distance, enemy)
				continue
			if enemy.step < 0.0:
				enemy.step = data.enemy_speed(enemy.type_data, enemy.elite) / ticks_per_second
			enemy.prev_x = enemy.x
			enemy.prev_y = enemy.y
			if enemy.stun_ticks > 0:
				# Atordoado: fica parado 
				pass
			elif enemy.slow_ticks > 0:
				enemy.distance += enemy.step * (1.0 - enemy.slow_percent / 100.0)
			else:
				enemy.distance += enemy.step
			enemy.seg = route.sample_cursor(enemy.distance, enemy, enemy.seg)
