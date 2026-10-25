class_name Damage
extends RefCounted
## Aplicar dano a um inimigo: armadura, morte e evento. Toda fonte de dano
## (núcleo, projéteis das torres e efeitos de gatilho) passa por aqui.
##
## `options` (Dictionary, todas opcionais):
##   "ignoreArmor": bool   — ignora a armadura (execução)
##   "killWeight": int     — quanto o abate vale nos contadores (padrão 1)
##   "chain": ChainMark    — cadeia do tiro (projétil de gatilho); padrão: sem cadeia
##   "shared": bool        — dano dividido pela Maldição (não se divide de novo)
##   "deathBlast": bool    — dano da explosão de quem morre (região Cripta; quem morre dela não explode)
##
## Amaldiçoado (`Enemy.curse`, com o índice espacial no contexto): parte do dano vai para os vizinhos e,
## na morte, a Maldição pula (ver `Status.share_curse` e `Status.jump_curse`). Lento ou Atordoado, com o
## bônus do Controlador (`TickContext.afflicted_damage_percent`): o dano bruto cresce antes da armadura.


## Sem opções (compartilhado, só leitura): evita criar um Dictionary vazio a cada chamada.
const NO_OPTIONS := {}
## Dano da explosão de quem morre (região Cripta): quem morre dela não explode de novo.
const DEATH_BLAST := {"deathBlast": true}

## Estatística opcional para o playtest (`dev/playtest.gd`): dano efetivo por torre (id; -1 = núcleo). Desligada
## por padrão: com `track` falso a única coisa que sobra é essa leitura de uma variável.
static var track := false
static var dealt: Dictionary = {}


## Aplica `raw_damage` já descontando a armadura e devolve o dano efetivo.
## Se a vida chegar a zero, o inimigo volta para o pool e `enemyKilled` é
## emitido, com o ponto da morte e o peso do abate. `tower_id` null = núcleo.
static func damage_enemy(ctx: TickContext, data: EnemyData, enemy: Enemy, raw_damage: float,
		tower_id: Variant, options: Dictionary = NO_OPTIONS) -> float:
	# Já morto no mesmo golpe (o dano dividido da Maldição pode matar quem estava na lista de uma área).
	if not enemy.active:
		return 0.0
	var type := enemy.type_data if enemy.type_data != null else data.get_type(enemy.type)
	# Bônus do Controlador: inimigo Lento ou Atordoado recebe mais dano, de qualquer fonte.
	if ctx.afflicted_damage_percent > 0.0 and (enemy.slow_ticks > 0 or enemy.stun_ticks > 0):
		raw_damage *= 1.0 + ctx.afflicted_damage_percent / 100.0
	var armor := type.armor
	# Panteão: a torre de origem ignora parte da armadura.
	if not ctx.armor_pierce.is_empty() and tower_id != null:
		armor *= 1.0 - float(ctx.armor_pierce.get(tower_id, 0.0))
	var damage := raw_damage if options.get("ignoreArmor", false) \
			else Armor.apply_armor(raw_damage, armor, data.armor_scale)
	if track:
		var who: int = -1 if tower_id == null else int(tower_id)
		dealt[who] = dealt.get(who, 0.0) + minf(damage, maxf(enemy.hp, 0.0))
	var before := enemy.hp
	enemy.hp -= damage
	var curse := enemy.curse
	var cursed: bool = not curse.is_empty() and ctx.index != null
	if cursed and not options.get("shared", false):
		Status.share_curse(ctx, data, enemy, minf(damage, maxf(before, 0.0)), tower_id,
				options.get("chain", ChainMark.NO_CHAIN))
	if enemy.hp <= 0.0:
		var chain: ChainMark = options.get("chain", ChainMark.NO_CHAIN)
		enemy.hp = 0.0
		ctx.state.enemies.release(enemy)
		if cursed:
			Status.jump_curse(ctx, enemy, curse)
		ctx.emit({
			"type": "enemyKilled",
			"tick": ctx.state.tick,
			"enemyId": enemy.id,
			"enemyType": enemy.type,
			"wave": enemy.wave,
			"towerId": tower_id,
			"x": enemy.x,
			"y": enemy.y,
			"elite": enemy.elite,
			"marked": not enemy.marks.is_empty(),
			"weight": options.get("killWeight", 1),
			"chainId": chain.chain_id,
			"originTowerId": chain.origin_tower_id,
		})
		if not options.get("deathBlast", false):
			_after_death(ctx, data, enemy, tower_id)
	return damage


## Região Cripta: quem morre explode fraco (sem explodir de novo quem morrer da explosão) e às vezes volta
## como esqueleto aliado. Os dois só existem com o nível da região ativo.
static func _after_death(ctx: TickContext, data: EnemyData, enemy: Enemy, tower_id: Variant) -> void:
	var blast_percent: float = ctx.death_blast.get("percent", 0.0)
	if blast_percent > 0.0 and ctx.index != null:
		var radius: float = ctx.death_blast["radius"]
		var blast := enemy.max_hp * blast_percent / 100.0
		ctx.emit({"type": "areaExploded", "tick": ctx.state.tick, "towerId": null, "x": enemy.x, "y": enemy.y,
				"radius": radius, "trigger": false, "damage": 0.0})
		var hits: Array = []
		ctx.index.collect_in_range(ctx.state, enemy.x, enemy.y, radius, hits)
		# A explosão é da região, não de uma torre: quem morre dela não alimenta os gatilhos de abate (sem isso,
		# explosão, esqueleto e o raio do Lich viram uma reação em cadeia).
		for other: Enemy in EnemyOrder.sort_by_id(hits):
			damage_enemy(ctx, data, other, blast, null, DEATH_BLAST)
	var chance: float = ctx.skeleton_rise.get("chance", 0.0)
	if chance > 0.0 and ctx.towers != null and enemy.route != null and enemy.type_data.movement == "ground" \
			and ctx.rng.next_float() * 100.0 < chance:
		TrapSystems.spawn_skeleton(ctx, ctx.routes, ctx.towers, enemy.distance,
				enemy.max_hp * float(ctx.skeleton_rise["damage"]) / 100.0, null, ctx.ticks_per_second)
