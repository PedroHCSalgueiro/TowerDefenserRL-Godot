class_name Fusion
extends RefCounted
## Fusão de torres (T11). Só acontece na compra: comprar uma cópia de um tipo que já tem uma
## ★1 no mapa funde na hora, sem posicionar. Se já existir uma ★2 do mesmo tipo, as duas viram
## ★3 no mesmo ato (cascata). O limite é a última estrela do tipo (★3 no protótipo).
##
## `plan_fusion` só lê o estado e é usada tanto pela compra quanto pelo aviso do slot da loja,
## para o aviso sempre bater com o resultado real (porte de `fusion.ts`).

## Plano de uma fusão.
class FusionPlan:
	extends RefCounted
	## Torre que fica no mapa (mantém id, casa e estado).
	var survivor_id: int
	## Torres que saem do mapa (a cópia comprada não tem id e não entra aqui).
	var absorbed_ids: Array[int] = []
	## Estrela da sobrevivente depois da compra.
	var star: int
	## Uma entrada por fusão (a cascata tem duas), na ordem em que acontecem:
	## [{"towerId": int, "stars": int, "absorbedIds": Array[int]}, ...]
	var steps: Array = []


static func _lowest_id(towers: Array, type: String, star: int) -> Tower:
	var best: Tower = null
	for t: Tower in towers:
		if t.type == type and t.star == star and (best == null or t.id < best.id):
			best = t
	return best


## Plano da compra de uma cópia ★1 de `tower_type`, ou null se ela não funde (sem ★1 do tipo
## no mapa, ou tipo com uma estrela só). Com várias candidatas da mesma estrela (só por
## debug), vale a de menor id.
static func plan_fusion(towers: Array, data: TowerData, tower_type: String) -> FusionPlan:
	if not data.has_type(tower_type):
		return null
	var max_star := Stars.max_stars(data.get_type(tower_type))
	if max_star < 2:
		return null
	var one := _lowest_id(towers, tower_type, 1)
	if one == null:
		return null
	var two := _lowest_id(towers, tower_type, 2) if max_star >= 3 else null
	var plan := FusionPlan.new()
	if two == null:
		plan.survivor_id = one.id
		plan.star = 2
		plan.steps = [{"towerId": one.id, "stars": 2, "absorbedIds": [] as Array[int]}]
		return plan
	# Cascata: a ★1 vira ★2 e encontra a ★2; fica a ★2 original, na casa dela.
	plan.survivor_id = two.id
	plan.absorbed_ids = [one.id]
	plan.star = 3
	plan.steps = [
		{"towerId": one.id, "stars": 2, "absorbedIds": [] as Array[int]},
		{"towerId": two.id, "stars": 3, "absorbedIds": [one.id] as Array[int]},
	]
	return plan


## Estrela que a compra do tipo daria ao fundir (0 = não funde).
static func fusion_star(towers: Array, data: TowerData, tower_type: String) -> int:
	var plan := plan_fusion(towers, data, tower_type)
	return plan.star if plan != null else 0


static func _find(towers: Array, id: int) -> Tower:
	for t: Tower in towers:
		if t.id == id:
			return t
	return null


## Executa o plano: a sobrevivente sobe de estrela e soma o `invested` das cópias (mais
## `paid`, o preço da cópia comprada); as absorvidas saem do mapa. Devolve a sobrevivente.
## Emite um `towersMerged` por fusão.
static func apply_fusion(ctx: TickContext, data: TowerData, plan: FusionPlan, paid: int) -> Tower:
	var state := ctx.state
	var survivor := _find(state.towers, plan.survivor_id)
	for id in plan.absorbed_ids:
		survivor.invested += _find(state.towers, id).invested
	survivor.invested += paid
	if not plan.absorbed_ids.is_empty():
		var kept: Array[Tower] = []
		for t: Tower in state.towers:
			if not plan.absorbed_ids.has(t.id):
				kept.append(t)
		state.towers = kept
	survivor.star = plan.star
	# As cargas do raio em cadeia ficam limitadas ao teto da nova estrela.
	var star := Stars.tower_star(data.get_type(survivor.type), survivor)
	if star != null and star.effect["kind"] == "chargeLightning":
		survivor.charges = minf(survivor.charges, float(star.effect["charges"]))
	for step: Dictionary in plan.steps:
		var home := _find(state.towers, step["towerId"])
		if home == null:
			home = survivor
		ctx.emit({
			"type": "towersMerged",
			"tick": state.tick,
			"towerId": step["towerId"],
			"towerType": survivor.type,
			"stars": step["stars"],
			"x": home.x,
			"y": home.y,
			"absorbedIds": step["absorbedIds"],
		})
	return survivor
