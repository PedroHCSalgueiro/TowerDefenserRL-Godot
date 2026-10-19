class_name TriggerEffects
extends RefCounted
## Os "o quê" dos gatilhos (porte de `effects.ts`). Cada efeito age a partir da torre que o
## executa (posição, alcance, alvo normal e dano base dela); os números vêm do efeito
## (Dictionary de `TriggerData`, com "kind").
##
## - Disparo múltiplo e tiro de ativação usam projéteis normais.
## - Explosão, raio em cadeia, tiro perfurante e execução são instantâneos.
## - Todo dano passa por `Damage.damage_enemy()`, com o id da torre, e os alvos são atingidos em
##   ordem de id (o raio segue a ordem dos saltos).
## - Bônus de classe (`state.classes`): a Artilharia aumenta raio e dano da explosão; a Arcana
##   tira o teto de vizinhas ativadas do Relé.
## - O dano base é o da estrela da torre (`Stars.tower_damage`).
##
## `env` é o `TriggerEngine`, que fornece: ctx, index, enemies, towers, classes, scores,
## activation_cooldown_ticks, unlimited_line_length, neighbors_of(), reach_neighbors_of() e
## enqueue_blast().

## Reaproveitados entre chamadas (a simulação roda numa thread só).
static var _hits: Array = []
static var _struck: Array = []
static var _spread_targets: Array = []
static var _candidates: Array = []

## Ativação que o Obelisco ★3 faz ao soltar o raio: todas as vizinhas, 100%.
const DISCHARGE_ACTIVATION := {
	"kind": "activateNeighbors",
	"maxTargets": 0,
	"activatedDamagePercent": 100.0,
	"reach": 0,
	"selfToo": false,
}


## % do dano da torre (na estrela dela).
static func _percent_of(tower: Tower, type: TowerData.TowerType, percent: float) -> float:
	return (Stars.tower_damage(type, tower) * percent) / 100.0


static func _collect_sorted(env: TriggerEngine, x: float, y: float, radius: float) -> Array:
	_hits.clear()
	env.index.collect_in_range(env.ctx.state, x, y, radius, _hits)
	return EnemyOrder.sort_by_id(_hits)


## Tiros extras, sem gastar a recarga e sem contar como tiro. Todos no alvo normal; com
## `spread`, cada um num alvo diferente pela ordem de mira (o melhor primeiro), dando a volta se
## houver menos alvos que tiros.
static func _multi_shot(env: TriggerEngine, tower: Tower, type: TowerData.TowerType, e: Dictionary,
		entry: TriggerState.PendingTrigger) -> void:
	var state := env.ctx.state
	var chain := ChainMark.new(entry.chain_id, entry.origin_tower_id)
	if not e["spread"]:
		var target := TowerSystems.find_tower_target(env.index, state, tower, type, env.scores)
		if target == null:
			return
		for i in int(e["extraShots"]):
			TowerSystems.fire_tower_shot(env.ctx, tower, type, target, "extra", env.classes, 100.0, chain)
		return
	var targets := env.index.find_best_n(state, float(tower.x), float(tower.y), type.range,
			env.scores[type.target_mode], int(e["extraShots"]), _spread_targets)
	if targets.is_empty():
		return
	for i in int(e["extraShots"]):
		TowerSystems.fire_tower_shot(env.ctx, tower, type, targets[i % targets.size()], "extra",
				env.classes, 100.0, chain)


## Dano em área no ponto da morte que acionou o gatilho, ou no alvo normal.
static func _explosion(env: TriggerEngine, tower: Tower, type: TowerData.TowerType, e: Dictionary,
		entry: TriggerState.PendingTrigger) -> void:
	var x := entry.x
	var y := entry.y
	if not entry.has_point:
		var target := TowerSystems.find_tower_target(env.index, env.ctx.state, tower, type, env.scores)
		if target == null:
			return
		x = target.x
		y = target.y
	var ctx := env.ctx
	var radius: float = e["radius"] * ClassBonuses.area_radius_multiplier(env.classes, ctx.state, type)
	var event := {
		"type": "areaExploded",
		"tick": ctx.state.tick,
		"towerId": tower.id,
		"x": x,
		"y": y,
		"radius": radius,
		"trigger": true,
		"damage": 0.0,
	}
	ctx.emit(event)
	var damage := _percent_of(tower, type, e["damagePercent"]) \
			* ClassBonuses.area_damage_multiplier(env.classes, ctx.state, type)
	var options := {"killWeight": e["killWeight"]} if e["killWeight"] != 1 else {}
	for enemy: Enemy in _collect_sorted(env, x, y, radius):
		# Soma só a vida tirada (sem o excesso além da vida que o inimigo tinha).
		var before := enemy.hp
		Damage.damage_enemy(ctx, env.enemies, enemy, damage, tower.id, options)
		event["damage"] += before - enemy.hp


## Ativa uma torre: gasta a trava dela, emite `towerActivated` e, se ela ataca e tem alvo,
## dispara na hora um tiro ativado (sem gastar a recarga) com `damage_percent` do dano dela. Sem
## alvo, a ativação vale mesmo assim.
static func _activate(env: TriggerEngine, source: Tower, target: Tower, entry: TriggerState.PendingTrigger,
		damage_percent: float) -> void:
	var ctx := env.ctx
	var state := ctx.state
	target.activation_ready_tick = state.tick + env.activation_cooldown_ticks
	ctx.emit({
		"type": "towerActivated",
		"tick": state.tick,
		"towerId": target.id,
		"sourceTowerId": source.id,
		"depth": entry.depth,
	})
	var target_type := env.towers.get_type(target.type)
	if not target_type.attacks:
		return
	var enemy := TowerSystems.find_tower_target(env.index, state, target, target_type, env.scores)
	if enemy != null:
		TowerSystems.fire_tower_shot(ctx, target, target_type, enemy, "activated", env.classes,
				damage_percent, ChainMark.new(entry.chain_id, entry.origin_tower_id))


## Ativa as vizinhas em ordem de id, pulando as que ainda estão na trava de ativação. Sem
## `maxTargets`, ativa todas as da vizinhança atual (a dos dados, ampliada pela Arcana) e, com
## `reach`, as da cruz de alcance N; com `maxTargets`, só as primeiras N (a Arcana tira esse
## teto). `selfToo`: depois delas, a torre também se ativa, se a própria trava permitir.
static func _activate_neighbors(env: TriggerEngine, tower: Tower, type: TowerData.TowerType, e: Dictionary,
		entry: TriggerState.PendingTrigger) -> void:
	var state := env.ctx.state
	var capped: bool = e["maxTargets"] > 0 and ClassBonuses.neighborhood_radius(env.classes, state, type) == 0
	var list: Array = env.reach_neighbors_of(tower, e["reach"]) if e["reach"] > 0 else env.neighbors_of(tower)
	var activated := 0
	for neighbor: Tower in list:
		if capped and activated >= e["maxTargets"]:
			break
		if state.tick < neighbor.activation_ready_tick:
			continue
		activated += 1
		_activate(env, tower, neighbor, entry, e["activatedDamagePercent"])
	if e["selfToo"] and state.tick >= tower.activation_ready_tick:
		_activate(env, tower, tower, entry, e["activatedDamagePercent"])


## Raio em cadeia: começa em `first` e salta até completar `targets` inimigos no total; cada
## salto vai ao inimigo mais próximo do anterior (empate: menor id), dentro de `jumpRadius`, sem
## repetir. Com `activateOnDischarge`, ao fim ativa as vizinhas.
static func _release_lightning(env: TriggerEngine, tower: Tower, type: TowerData.TowerType, e: Dictionary,
		first: Enemy, entry: TriggerState.PendingTrigger) -> void:
	var ctx := env.ctx
	var damage := _percent_of(tower, type, e["damagePercent"])
	var skip := func(enemy: Enemy) -> bool: return _struck.has(enemy.id)
	var event := {
		"type": "lightningStruck",
		"tick": ctx.state.tick,
		"towerId": tower.id,
		"points": [],
		"damage": 0.0,
	}
	ctx.emit(event)
	_struck.clear()
	var current: Enemy = first
	var targets := int(e["targets"])
	while current != null and _struck.size() < targets:
		_struck.append(current.id)
		var x := current.x
		var y := current.y
		event["points"].append({"x": x, "y": y})
		var before := current.hp
		Damage.damage_enemy(ctx, env.enemies, current, damage, tower.id)
		event["damage"] += before - current.hp
		if _struck.size() < targets:
			current = env.index.find_nearest(ctx.state, x, y, e["jumpRadius"], skip)
	if e["activateOnDischarge"]:
		_activate_neighbors(env, tower, type, DISCHARGE_ACTIVATION, entry)


## Ganha `entry.weight` cargas; com `charges` ou mais, solta o raio no alvo normal e gasta
## `charges` (o excedente de um abate duplo fica). Sem alvo, as cargas esperam presas em
## `charges`: não acumulam acima do valor da descarga. Devolve se o raio saiu.
static func _charge_lightning(env: TriggerEngine, tower: Tower, type: TowerData.TowerType, e: Dictionary,
		entry: TriggerState.PendingTrigger) -> bool:
	tower.charges += entry.weight
	if tower.charges < e["charges"]:
		return false
	var target := TowerSystems.find_tower_target(env.index, env.ctx.state, tower, type, env.scores)
	if target == null:
		tower.charges = float(e["charges"])
		return false
	tower.charges -= e["charges"]
	_release_lightning(env, tower, type, e, target, entry)
	return true


## Linha reta da torre na direção do alvo normal, até o alcance (ou pelo mapa inteiro, se
## `unlimited`): atinge todos nela.
static func _pierce_line(env: TriggerEngine, tower: Tower, type: TowerData.TowerType, e: Dictionary) -> void:
	var ctx := env.ctx
	var target := TowerSystems.find_tower_target(env.index, ctx.state, tower, type, env.scores)
	if target == null:
		return
	var tx := float(tower.x)
	var ty := float(tower.y)
	var dx := target.x - tx
	var dy := target.y - ty
	var length := SimMath.hypot(dx, dy)
	# Alvo exatamente sobre a torre: a direção não importa, mas precisa ser fixa.
	var ux := dx / length if length > 0.0 else 1.0
	var uy := dy / length if length > 0.0 else 0.0
	var reach: float = env.unlimited_line_length if e["unlimited"] else type.range
	var half_width: float = e["halfWidth"]
	var damage := _percent_of(tower, type, e["damagePercent"])
	var in_line := _collect_sorted(env, tx, ty, reach + half_width).filter(func(enemy: Enemy) -> bool:
		var px := enemy.x - tx
		var py := enemy.y - ty
		var along := px * ux + py * uy
		return along >= 0.0 and along <= reach and absf(px * uy - py * ux) <= half_width)
	var max_targets := int(e.get("maxTargets", 0))
	if max_targets > 0 and in_line.size() > max_targets:
		in_line = in_line.slice(0, max_targets)
	var event := {
		"type": "lineFired",
		"tick": ctx.state.tick,
		"towerId": tower.id,
		"x": tx,
		"y": ty,
		"toX": tx + ux * reach,
		"toY": ty + uy * reach,
		"damage": 0.0,
	}
	ctx.emit(event)
	for enemy: Enemy in in_line:
		var before := enemy.hp
		Damage.damage_enemy(ctx, env.enemies, enemy, damage, tower.id)
		event["damage"] += before - enemy.hp


## Execução: mata na hora quem está no alcance com vida abaixo de `hpPercent`% da máxima, sem
## armadura, valendo `killWeight` nos contadores. O chefão nunca é executado: abaixo do limite,
## leva um golpe de `bossMaxHpPercent`% da vida máxima (dano normal, com armadura; se matar, é
## abate de peso 1). Com `explodeRadius`, cada execução põe uma explosão na fila, no ponto da morte.
static func _execute(env: TriggerEngine, tower: Tower, type: TowerData.TowerType, e: Dictionary,
		entry: TriggerState.PendingTrigger) -> void:
	var doomed := _collect_sorted(env, float(tower.x), float(tower.y), type.range).filter(
			func(enemy: Enemy) -> bool: return enemy.hp < (enemy.max_hp * e["hpPercent"]) / 100.0)
	for enemy: Enemy in doomed:
		if env.enemies.get_type(enemy.type).boss:
			if e["bossMaxHpPercent"] > 0.0:
				Damage.damage_enemy(env.ctx, env.enemies, enemy, (enemy.max_hp * e["bossMaxHpPercent"]) / 100.0, tower.id)
			continue
		var x := enemy.x
		var y := enemy.y
		Damage.damage_enemy(env.ctx, env.enemies, enemy, enemy.hp, tower.id,
				{"ignoreArmor": true, "killWeight": e["killWeight"]})
		if e["explodeRadius"] > 0.0:
			env.enqueue_blast(tower, x, y, e["explodeRadius"], e["explodeDamagePercent"], entry)


## A explosão de uma execução (entrada da fila): no ponto da morte, `percent` do dano da torre.
static func run_blast(env: TriggerEngine, tower: Tower, type: TowerData.TowerType,
		entry: TriggerState.PendingTrigger) -> void:
	_explosion(env, tower, type, {
		"kind": "explosion",
		"radius": entry.blast_radius,
		"damagePercent": entry.blast_percent,
		"killWeight": 1,
	}, entry)


## O efeito com o dano escalado por `power` % (só o dano; contagens e alvos ficam).
static func _scale_effect(effect: Dictionary, power: float) -> Dictionary:
	if power == 100.0:
		return effect
	match effect["kind"]:
		"explosion", "chargeLightning", "pierceLine":
			var scaled := effect.duplicate()
			scaled["damagePercent"] = (effect["damagePercent"] * power) / 100.0
			return scaled
		"activateNeighbors":
			var scaled := effect.duplicate()
			scaled["activatedDamagePercent"] = (effect["activatedDamagePercent"] * power) / 100.0
			return scaled
	return effect


## Os "o quê" que "copiar" vai repetir: o último efeito disparado por cada vizinha, os `copies`
## mais recentes (maior `seq`), de vizinhas diferentes, com o dano escalado por `powerPercent`.
## Vazio se nenhuma vizinha disparou. Devolve [{"effect": Dictionary, "fromTowerId": int}, ...].
static func resolve_copies(env: TriggerEngine, tower: Tower, e: Dictionary) -> Array:
	_candidates.clear()
	for neighbor: Tower in env.neighbors_of(tower):
		if neighbor.last_effect != null:
			_candidates.append(neighbor)
	_candidates.sort_custom(func(a: Tower, b: Tower) -> bool: return a.last_effect.seq > b.last_effect.seq)
	var out: Array = []
	for neighbor: Tower in _candidates.slice(0, int(e["copies"])):
		out.append({
			"effect": _scale_effect(neighbor.last_effect.effect, e["powerPercent"]),
			"fromTowerId": neighbor.id,
		})
	return out


## Executa um efeito pela torre. No "copiar", `effect` já vem resolvido e o raio sai na hora (as
## cargas são da torre copiada). Devolve se o efeito conta como disparado para "copiar": ganhar
## carga sem soltar o raio não conta.
static func run_effect(env: TriggerEngine, tower: Tower, type: TowerData.TowerType, effect: Dictionary,
		entry: TriggerState.PendingTrigger, copied: bool) -> bool:
	match effect["kind"]:
		"multiShot":
			_multi_shot(env, tower, type, effect, entry)
			return true
		"explosion":
			_explosion(env, tower, type, effect, entry)
			return true
		"activateNeighbors":
			_activate_neighbors(env, tower, type, effect, entry)
			return true
		"chargeLightning":
			if not copied:
				return _charge_lightning(env, tower, type, effect, entry)
			var target := TowerSystems.find_tower_target(env.index, env.ctx.state, tower, type, env.scores)
			if target != null:
				_release_lightning(env, tower, type, effect, target, entry)
			return true
		"pierceLine":
			_pierce_line(env, tower, type, effect)
			return true
		"execute":
			_execute(env, tower, type, effect, entry)
			return true
		"empoweredShot":
			return _empowered_shot(env, tower, type, effect, entry)
		"stunFront":
			return _stun_front(env, tower, type, effect)
		"stunSlowed":
			return _stun_slowed(env, tower, type, effect)
	return false


## Tiro em área extra, maior e mais forte, no alvo normal (o "tiro carregado" do Mestre Brom). Não
## conta como tiro normal. Devolve se saiu.
static func _empowered_shot(env: TriggerEngine, tower: Tower, type: TowerData.TowerType, e: Dictionary,
		entry: TriggerState.PendingTrigger) -> bool:
	var target := TowerSystems.find_tower_target(env.index, env.ctx.state, tower, type, env.scores)
	if target == null:
		return false
	TowerSystems.fire_tower_shot(env.ctx, tower, type, target, "extra", env.classes, e["damagePercent"],
			ChainMark.new(entry.chain_id, entry.origin_tower_id), e["radiusMultiplier"])
	return true


## Atordoa os `count` inimigos mais à frente (pelo modo "first") dentro do alcance. Devolve se atordoou alguém.
static func _stun_front(env: TriggerEngine, tower: Tower, type: TowerData.TowerType, e: Dictionary) -> bool:
	var ctx := env.ctx
	var targets := env.index.find_best_n(ctx.state, float(tower.x), float(tower.y), type.range,
			env.scores["first"], int(e["count"]), _spread_targets)
	if targets.is_empty():
		return false
	var ticks := env.seconds_to_ticks(e["seconds"])
	for enemy: Enemy in targets:
		Status.apply_stun(enemy, ticks)
	ctx.emit({"type": "statusApplied", "tick": ctx.state.tick, "towerId": tower.id, "status": "stun",
			"count": targets.size()})
	return true


## Atordoa os inimigos no alcance que já estão Lentos. Devolve se atordoou alguém.
static func _stun_slowed(env: TriggerEngine, tower: Tower, type: TowerData.TowerType, e: Dictionary) -> bool:
	var ctx := env.ctx
	var ticks := env.seconds_to_ticks(e["stunSeconds"])
	var count := 0
	for enemy: Enemy in _collect_sorted(env, float(tower.x), float(tower.y), type.range):
		if enemy.slow_ticks > 0:
			Status.apply_stun(enemy, ticks)
			count += 1
	if count == 0:
		return false
	ctx.emit({"type": "statusApplied", "tick": ctx.state.tick, "towerId": tower.id, "status": "stun", "count": count})
	return true
