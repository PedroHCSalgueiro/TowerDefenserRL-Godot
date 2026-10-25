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
##
## Amaldiçoado (`Enemy.curse`, com o índice espacial no contexto): parte do dano vai para os vizinhos e,
## na morte, a Maldição pula (ver `Status.share_curse` e `Status.jump_curse`). Lento ou Atordoado, com o
## bônus do Controlador (`TickContext.afflicted_damage_percent`): o dano bruto cresce antes da armadura.


## Sem opções (compartilhado, só leitura): evita criar um Dictionary vazio a cada chamada.
const NO_OPTIONS := {}

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
	var damage := raw_damage if options.get("ignoreArmor", false) \
			else Armor.apply_armor(raw_damage, type.armor, data.armor_scale)
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
	return damage
