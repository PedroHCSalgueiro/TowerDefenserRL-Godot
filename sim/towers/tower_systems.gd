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


## O alvo normal da torre agora: o melhor pelo modo de mira, dentro do alcance.
static func find_tower_target(index: SpatialIndex, state: Object, tower: Tower,
		type: TowerData.TowerType, scores: Dictionary) -> Enemy:
	if type.target_mode == "first":
		return index.find_first(state, float(tower.x), float(tower.y), type.range)
	return index.find_best(state, float(tower.x), float(tower.y), type.range, scores[type.target_mode])


## Emite `towerFired` e cria o projétil da torre mirando `target`. O dano é o da estrela da
## torre vezes `damage_percent` (tiro ativado do Relé e do Relógio); no tiro em área, o bônus
## de Artilharia vigente neste tick aumenta o raio e o dano. `shot` = "normal" | "activated" | "extra".
static func fire_tower_shot(ctx: TickContext, tower: Tower, type: TowerData.TowerType, target: Enemy,
		shot: String, classes: ClassData, damage_percent: float = 100.0, chain: ChainMark = null) -> void:
	var area: bool = type.shot["kind"] == "area"
	var shot_damage := Stars.tower_damage(type, tower)
	if damage_percent != 100.0:
		shot_damage = (shot_damage * damage_percent) / 100.0
	if area:
		shot_damage *= ClassBonuses.area_damage_multiplier(classes, ctx.state, type)
	ctx.emit({
		"type": "towerFired",
		"tick": ctx.state.tick,
		"towerId": tower.id,
		"targetId": target.id,
		"shot": shot,
	})
	var area_radius := 0.0
	if area:
		area_radius = type.shot["radius"] * ClassBonuses.area_radius_multiplier(classes, ctx.state, type)
	ProjectileSystems.fire_projectile(ctx, {
		"sourceId": tower.id,
		"x": float(tower.x),
		"y": float(tower.y),
		"damage": shot_damage,
		"speed": type.projectile_speed,
		"areaRadius": area_radius,
		"chain": chain,
	}, target)


## Devolve o sistema (Callable) de ataque das torres.
static func create_tower_system(index: SpatialIndex, data: TowerData, scores: Dictionary,
		ticks_per_second: float, classes: ClassData = null) -> Callable:
	if classes == null:
		classes = ClassData.game_data()
	var cooldown_ticks := {}
	for id: String in data.types:
		var type: TowerData.TowerType = data.types[id]
		if type.attacks:
			cooldown_ticks[id] = maxi(1, SimMath.js_round(ticks_per_second / type.shots_per_second))

	return func(ctx: TickContext) -> void:
		var state := ctx.state
		for tower: Tower in state.towers:
			var type := data.get_type(tower.type)
			if not type.attacks:
				continue
			if tower.cooldown_ticks > 0:
				tower.cooldown_ticks -= 1
			if tower.cooldown_ticks > 0:
				continue

			var target := find_tower_target(index, state, tower, type, scores)
			if target == null:
				continue

			tower.cooldown_ticks = cooldown_ticks[tower.type]
			fire_tower_shot(ctx, tower, type, target, "normal", classes)
