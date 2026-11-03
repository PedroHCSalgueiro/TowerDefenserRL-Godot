class_name Fusion
extends RefCounted
## Fusão de torres (T11). Só acontece na compra: comprar uma cópia de um tipo que já tem uma
## ★1 no mapa funde na hora, sem posicionar. Se já existir uma ★2 do mesmo tipo, as duas viram
## ★3 no mesmo ato (cascata). O limite é a última estrela do tipo (★3 no protótipo).
##
## Quantas cópias da mesma estrela sobem uma estrela vem dos dados (`copiesPerStar` em
## `towers.json`: 2 no Padrão, 3 nos heróis). Com 3, a cópia que ainda não sobe a estrela fica
## guardada na torre (`Tower.copies`) e a compra emite `copyStored` em vez de `towersMerged`.
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
	## Cópias guardadas na sobrevivente depois da compra (sempre 0 com 2 cópias por estrela).
	var copies := 0
	## Cópias por estrela da regra, para o aviso da loja ("★2 2/3").
	var copies_per_star := 2
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
	var plan := FusionPlan.new()
	plan.copies_per_star = data.copies_per_star
	if data.copies_per_star > 2:
		return _plan_slow(towers, tower_type, max_star, one, plan)
	var two := _lowest_id(towers, tower_type, 2) if max_star >= 3 else null
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


## Plano com mais de 2 cópias por estrela: a cópia comprada fica guardada na ★1 até ela juntar as
## cópias da estrela; a ★2 nova, se já houver outra ★2, fica guardada nela do mesmo jeito.
static func _plan_slow(towers: Array, tower_type: String, max_star: int, one: Tower, plan: FusionPlan) -> FusionPlan:
	plan.survivor_id = one.id
	if one.copies + 2 < plan.copies_per_star:
		plan.star = 1
		plan.copies = one.copies + 1
		return plan
	var two := _lowest_id(towers, tower_type, 2) if max_star >= 3 else null
	if two == null:
		plan.star = 2
		plan.steps = [{"towerId": one.id, "stars": 2, "absorbedIds": [] as Array[int]}]
		return plan
	plan.survivor_id = two.id
	plan.absorbed_ids = [one.id]
	if two.copies + 2 < plan.copies_per_star:
		plan.star = 2
		plan.copies = two.copies + 1
		return plan
	plan.star = 3
	plan.steps = [
		{"towerId": one.id, "stars": 2, "absorbedIds": [] as Array[int]},
		{"towerId": two.id, "stars": 3, "absorbedIds": [one.id] as Array[int]},
	]
	return plan


## Estrela que a compra do tipo daria ao fundir (0 = não funde). Quando a cópia só fica guardada, é a
## estrela que a torre já tem.
static func fusion_star(towers: Array, data: TowerData, tower_type: String) -> int:
	var plan := plan_fusion(towers, data, tower_type)
	return plan.star if plan != null else 0


## Aviso da compra: "★2↑" quando sobe a estrela, "★2 2/3" quando a cópia fica guardada (2 das 3
## cópias para a ★2). "" = não funde.
static func plan_label(plan: FusionPlan) -> String:
	if plan == null:
		return ""
	if not plan.steps.is_empty():
		return "★%d↑" % plan.star
	return "★%d %d/%d" % [plan.star + 1, plan.copies + 1, plan.copies_per_star]


static func _find(towers: Array, id: int) -> Tower:
	for t: Tower in towers:
		if t.id == id:
			return t
	return null


## Executa o plano: a sobrevivente sobe de estrela e soma o `invested` das cópias (mais
## `paid`, o preço da cópia comprada); as absorvidas saem do mapa. Devolve a sobrevivente.
## Emite um `towersMerged` por fusão, ou um `copyStored` quando a cópia só fica guardada.
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
	survivor.copies = plan.copies
	# As cargas do raio em cadeia ficam limitadas ao teto da nova estrela.
	var star := Stars.tower_star(data.get_type(survivor.type), survivor)
	if star != null and star.effect["kind"] == "chargeLightning":
		survivor.charges = minf(survivor.charges, float(star.effect["charges"]))
	if plan.steps.is_empty():
		ctx.emit({
			"type": "copyStored",
			"tick": state.tick,
			"towerId": survivor.id,
			"towerType": survivor.type,
			"stars": survivor.star,
			"copies": survivor.copies,
			"x": survivor.x,
			"y": survivor.y,
			"absorbedIds": plan.absorbed_ids.duplicate(),
		})
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
