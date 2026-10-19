class_name Status
extends RefCounted
## Efeitos de estado dos inimigos (Notion, "Efeitos de estado"): **Lento** (anda mais devagar,
## empilha até um teto), **Atordoado** (para por um instante) e **Sangramento** (perde vida aos
## poucos, sem armadura). Os campos ficam no `Enemy` (ticks que faltam); o movimento lê Lento e
## Atordoado, e o sistema de estados (`create_status_system`) conta o tempo e aplica o Sangramento.
##
## As torres aplicam estado de dois jeitos: no acerto dos tiros (`onHit` em `towers.json`, ver
## `apply_on_hit`) e por gatilho (`stunFront`, `stunSlowed`). Sem nenhuma dessas torres nos dados, o
## sistema de estados nem entra na lista de sistemas (`TowerData.uses_statuses`).


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


## Efeitos do acerto de um tiro cujo tipo tem `onHit`: Lento (e o ricochete para trás) e Sangramento.
static func apply_on_hit(ctx: TickContext, towers: TowerData, index: SpatialIndex, enemy: Enemy,
		projectile: Projectile, ticks_per_second: float) -> void:
	if not enemy.active:
		return
	var type: TowerData.TowerType = towers.types.get(projectile.status_type)
	if type == null:
		return
	var slow: Dictionary = type.on_hit.get("slow", {})
	if not slow.is_empty():
		apply_slow(enemy, slow["percent"], slow["cap"], seconds_to_ticks(slow["seconds"], ticks_per_second))
		if slow["bounces"] > 0:
			_bounce_slow(ctx, index, enemy, slow, ticks_per_second)
	var bleed: Dictionary = type.on_hit.get("bleed", {})
	if not bleed.is_empty():
		apply_bleed(enemy, (projectile.damage * bleed["percentPerSecond"] / 100.0) / ticks_per_second,
				seconds_to_ticks(bleed["seconds"], ticks_per_second), projectile.source_id)


## O gelo ricocheteia para trás: a partir do inimigo acertado, salta até `bounces` vezes para o
## mais próximo (dentro de `bounceRadius`) que está atrás dele na rota, sem repetir, e soma Lento.
static func _bounce_slow(ctx: TickContext, index: SpatialIndex, first: Enemy, slow: Dictionary,
		ticks_per_second: float) -> void:
	var ticks := seconds_to_ticks(slow["seconds"], ticks_per_second)
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


## Sistema de estados: conta o tempo de Atordoado, Lento e Sangramento e aplica o dano do
## Sangramento (creditado à torre de origem; mata como qualquer dano). Roda depois das torres e antes
## dos gatilhos, para os abates dele entrarem nos gatilhos do mesmo tick.
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
			if enemy.bleed_ticks > 0:
				enemy.bleed_ticks -= 1
				var damage := enemy.bleed_damage
				var source: Variant = enemy.bleed_source
				if enemy.bleed_ticks == 0:
					enemy.bleed_damage = 0.0
					enemy.bleed_source = null
				Damage.damage_enemy(ctx, enemies, enemy, damage, source, bleed_options)
