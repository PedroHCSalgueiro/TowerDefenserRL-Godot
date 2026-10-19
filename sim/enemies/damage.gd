class_name Damage
extends RefCounted
## Aplicar dano a um inimigo: armadura, morte e evento. Toda fonte de dano
## (núcleo, projéteis das torres e efeitos de gatilho) passa por aqui.
##
## `options` (Dictionary, todas opcionais):
##   "ignoreArmor": bool   — ignora a armadura (execução)
##   "killWeight": int     — quanto o abate vale nos contadores (padrão 1)
##   "chain": ChainMark    — cadeia do tiro (projétil de gatilho); padrão: sem cadeia


## Aplica `raw_damage` já descontando a armadura e devolve o dano efetivo.
## Se a vida chegar a zero, o inimigo volta para o pool e `enemyKilled` é
## emitido, com o ponto da morte e o peso do abate. `tower_id` null = núcleo.
static func damage_enemy(ctx: TickContext, data: EnemyData, enemy: Enemy, raw_damage: float,
		tower_id: Variant, options: Dictionary = {}) -> float:
	var type := data.get_type(enemy.type)
	var damage := raw_damage if options.get("ignoreArmor", false) \
			else Armor.apply_armor(raw_damage, type.armor, data.armor_scale)
	enemy.hp -= damage
	if enemy.hp <= 0.0:
		var chain: ChainMark = options.get("chain", ChainMark.NO_CHAIN)
		enemy.hp = 0.0
		ctx.state.enemies.release(enemy)
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
			"weight": options.get("killWeight", 1),
			"chainId": chain.chain_id,
			"originTowerId": chain.origin_tower_id,
		})
	return damage
