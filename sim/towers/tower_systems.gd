class_name TowerSystems
extends RefCounted
## Ataque das torres: com a recarga pronta, a torre escolhe o alvo pelo seu modo de mira
## (dentro do alcance) e dispara um projétil. O dano só acontece no impacto
## (`ProjectileSystems`), sempre por `Damage.damage_enemy()` com o id da torre (porte de
## `towers/systems.ts`).
##
## A cadência vira um número inteiro de ticks entre disparos (arredondado, no mínimo 1). Sem
## alvo, a torre espera pronta.
##
## `find_tower_target` e `fire_tower_shot` também são usados pelo motor de gatilhos (tiro de
## ativação e disparo múltiplo).


## O alvo normal da torre agora: o melhor pelo modo de mira, dentro do alcance (com o bônus do Atirador).
static func find_tower_target(index: SpatialIndex, state: Object, tower: Tower,
		type: TowerData.TowerType, scores: Dictionary) -> Enemy:
	var reach := ClassBonuses.tower_range(ClassData.game_data(), state, type, tower)
	if type.target_mode == "first":
		return index.find_first(state, float(tower.x), float(tower.y), reach)
	return index.find_best(state, float(tower.x), float(tower.y), reach, scores[type.target_mode])


## Emite `towerFired` e cria o projétil da torre mirando `target`. O dano é o da estrela da
## torre vezes `damage_percent` (tiro ativado do Relé e do Relógio); no tiro em área, o bônus
## de Artilharia vigente neste tick aumenta o raio e o dano. `shot` = "normal" | "activated" | "extra".
static func fire_tower_shot(ctx: TickContext, tower: Tower, type: TowerData.TowerType, target: Enemy,
		shot: String, classes: ClassData, damage_percent: float = 100.0, chain: ChainMark = null,
		radius_multiplier: float = 1.0) -> void:
	var area: bool = type.shot["kind"] == "area"
	var shot_damage := Stars.tower_damage(type, tower)
	if damage_percent != 100.0:
		shot_damage = (shot_damage * damage_percent) / 100.0
	if area:
		shot_damage *= ClassBonuses.area_damage_multiplier(classes, ctx.state, type)
	var region_damage := ClassBonuses.damage_multiplier(classes, ctx.state, type, tower)
	if region_damage != 1.0:
		shot_damage *= region_damage
	var buffs := TowerBuffs.damage_multiplier(ctx.state, ctx.towers if ctx.towers != null else TowerData.game_data(), tower, type)
	if buffs != 1.0:
		shot_damage *= buffs
	# Golem de Ossos: a área cresce com as almas da onda.
	if area and not type.soul_radius.is_empty() and "souls" in ctx.state:
		radius_multiplier *= 1.0 + minf(type.soul_radius["maxPercent"],
				type.soul_radius["percentPer10"] * floorf(float(ctx.state.souls) / 10.0)) / 100.0
	ctx.emit({
		"type": "towerFired",
		"tick": ctx.state.tick,
		"towerId": tower.id,
		"targetId": target.id,
		"shot": shot,
	})
	var area_radius := 0.0
	if area:
		area_radius = type.shot["radius"] * ClassBonuses.area_radius_multiplier(classes, ctx.state, type) * radius_multiplier
	# A Maldição armada (Mama Zuri) vai no próximo ataque que não é tiro extra.
	var curse := ProjectileSystems.NO_CURSE
	if not tower.curse_next.is_empty() and shot != "extra":
		curse = tower.curse_next
		tower.curse_next = {}
	# A marca armada (Nyx) vai no próximo ataque que não é tiro extra.
	var force_mark := false
	if tower.mark_next and shot != "extra":
		force_mark = true
		tower.mark_next = false
	ProjectileSystems.fire_projectile(ctx, {
		"sourceId": tower.id,
		"x": float(tower.x),
		"y": float(tower.y),
		"damage": shot_damage,
		"speed": type.projectile_speed,
		"areaRadius": area_radius,
		"chain": chain,
		"statusType": tower.type if not type.on_hit.is_empty() or type.marks else "",
		"curse": curse,
		"forceMark": force_mark,
	}, target)


## Devolve o sistema (Callable) de ataque das torres.
static func create_tower_system(index: SpatialIndex, data: TowerData, scores: Dictionary,
		ticks_per_second: float, classes: ClassData = null, routes: Dictionary = {}) -> Callable:
	if classes == null:
		classes = ClassData.game_data()
	var cooldown_ticks := {}
	for id: String in data.types:
		var type: TowerData.TowerType = data.types[id]
		if type.attacks:
			cooldown_ticks[id] = maxi(1, SimMath.js_round(ticks_per_second / type.shots_per_second))
	var has_auras := data.has_auras()
	var has_speed_bonus := has_auras or classes.has_attack_speed_bonus

	return func(ctx: TickContext) -> void:
		var state := ctx.state
		for tower: Tower in state.towers:
			var type := data.get_type(tower.type)
			if not type.attacks:
				continue
			if tower.followup_ticks > 0:
				_followup_shot(ctx, index, tower, type, scores, classes)
			if tower.cooldown_ticks > 0:
				tower.cooldown_ticks -= 1
			if tower.cooldown_ticks > 0:
				continue

			var is_trap: bool = type.shot["kind"] == "trap"
			var target: Enemy = null
			if not is_trap:
				target = find_tower_target(index, state, tower, type, scores)
				if target == null:
					continue
			elif not TrapSystems.place_caltrop(ctx, routes, tower, type):
				# Teto de armadilhas no chão (ou nenhum ponto livre): espera pronta.
				continue

			tower.cooldown_ticks = cooldown_ticks[tower.type]
			if has_speed_bonus:
				var haste := ClassBonuses.attack_speed_percent(classes, state, type, tower)
				if has_auras:
					haste += Auras.attack_speed_percent(state, data, tower)
				if haste > 0.0:
					tower.cooldown_ticks = maxi(1, SimMath.js_round(float(tower.cooldown_ticks) / (1.0 + haste / 100.0)))
			if not is_trap:
				fire_tower_shot(ctx, tower, type, target, "normal", classes)
				if tower.double_shot:
					_arm_followup(tower, type, ticks_per_second)


## Tiro duplo (Ruby): o ataque normal com o tiro duplo armado agenda o segundo tiro para daqui a
## `delaySeconds` (pelo menos 1 tick).
static func _arm_followup(tower: Tower, type: TowerData.TowerType, ticks_per_second: float) -> void:
	tower.double_shot = false
	var star := Stars.tower_star(type, tower)
	var delay: float = star.effect.get("delaySeconds", 0.0) if star != null else 0.0
	tower.followup_ticks = maxi(1, SimMath.js_round(delay * ticks_per_second))


## O segundo tiro do tiro duplo: conta o tempo e, na hora, atira no alvo do momento (se o primeiro matou,
## é o próximo da fila). É tiro extra: não gasta a recarga nem conta como tiro. Sem alvo, se perde.
static func _followup_shot(ctx: TickContext, index: SpatialIndex, tower: Tower, type: TowerData.TowerType,
		scores: Dictionary, classes: ClassData) -> void:
	tower.followup_ticks -= 1
	if tower.followup_ticks > 0:
		return
	var target := find_tower_target(index, ctx.state, tower, type, scores)
	if target != null:
		fire_tower_shot(ctx, tower, type, target, "extra", classes)
