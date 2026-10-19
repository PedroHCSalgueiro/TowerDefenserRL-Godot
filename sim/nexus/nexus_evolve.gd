class_name NexusEvolve
extends RefCounted
## Evoluir o núcleo (T12): paga o custo do próximo nível, sobe o nível, a vida máxima e cura a
## diferença entre as vidas máximas (5 na tabela atual, sem encher a barra). As chances de
## raridade novas valem a partir do próximo reroll ou da próxima loja; a loja atual não é sorteada
## de novo. A vida a mais do bônus "Núcleo reforçado" (T24) continua somada no nível novo
## (porte de `evolve.ts`).


## Custo para chegar ao próximo nível (-1 = já está no máximo).
static func next_level_cost(data: NexusData, level: int) -> int:
	return -1 if float(level) >= data.max_level() else data.level_data(level + 1).cost


## Não faz nada, sem cobrar, se faltar ouro, no nível máximo ou com a run perdida.
static func evolve_nexus(ctx: TickContext, data: NexusData) -> bool:
	var state := ctx.state
	if state.status != "playing":
		return false
	var cost := next_level_cost(data, state.nexus.level)
	if cost < 0 or state.gold < cost:
		return false
	var current := data.level_data(state.nexus.level)
	var next := data.level_data(state.nexus.level + 1)
	Gold.spend_gold(state, cost)
	var max_hp := next.max_hp + RewardMods.of(state).nexus_max_hp
	state.nexus.level += 1
	state.nexus.max_hp = max_hp
	state.nexus.hp = minf(float(max_hp), state.nexus.hp + float(next.max_hp - current.max_hp))
	ctx.emit({
		"type": "nexusEvolved",
		"tick": state.tick,
		"level": state.nexus.level,
		"hp": state.nexus.hp,
		"maxHp": state.nexus.max_hp,
		"cost": cost,
	})
	return true
