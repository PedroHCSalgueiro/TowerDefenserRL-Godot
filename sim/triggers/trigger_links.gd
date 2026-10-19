class_name TriggerLinks
extends RefCounted
## Prévia das ligações de uma torre ainda na mão (T23): ao posicionar (da loja) ou mover, quais
## torres vão se ligar a ela naquela casa e como, com a mesma regra de vizinhança do motor
## (`TriggerNeighborhood.is_reach_neighbor` e o raio da Arcana) e as classes calculadas como se ela
## já estivesse no mapa (porte de `links.ts`).
##
## Tipos de ligação (a seta vai de `from` para `to`):
## - "activates": `from` ativa `to` (Relé, Relógio, Obelisco ★3);
## - "charges": os abates de `from` carregam o Obelisco `to`;
## - "copies": o Espelho `to` copia o último efeito de `from`.

## Uma ponta da ligação: a candidata (`tower_id` = -1) ou uma torre do mapa.
class LinkEnd:
	extends RefCounted
	var tower_id := -1
	var x := 0
	var y := 0

	func _init(p_tower_id: int = -1, p_x: int = 0, p_y: int = 0) -> void:
		tower_id = p_tower_id
		x = p_x
		y = p_y

class Link:
	extends RefCounted
	var from: LinkEnd
	var to: LinkEnd
	## "activates" | "charges" | "copies"
	var kind: String

## A torre na mão: tipo, estrela, casa e, se for uma torre movida, o id dela.
class Candidate:
	extends RefCounted
	var type := ""
	var star := 1
	var x := 0
	var y := 0
	## Torre do mapa sendo movida (ela não se liga a si mesma; -1 = da loja).
	var moving_id := -1

class Placed:
	extends RefCounted
	var tower_id := -1
	var type := ""
	var star := 1
	var x := 0
	var y := 0

	func _init(p_tower_id: int, p_type: String, p_star: int, p_x: int, p_y: int) -> void:
		tower_id = p_tower_id
		type = p_type
		star = p_star
		x = p_x
		y = p_y

class Role:
	extends RefCounted
	## Ativa as vizinhas; `reach` > 0 = cruz do Relé ★3.
	var activates := false
	var reach := 0
	## Ganha carga com os abates das vizinhas (Obelisco).
	var charged := false
	## Copia uma vizinha (Espelho).
	var copies := false

## Holder mínimo para `ClassBonuses` (só precisa de `classes`).
class ClassHolder:
	extends RefCounted
	var classes: Dictionary = {}

var links: Array[Link] = []
## Casas vizinhas da candidata (contorno leve), na vizinhança dela naquela casa.
var neighbor_cells: Array[Vector2i] = []


static func _role_of(towers: TowerData, placed: Placed) -> Role:
	var role := Role.new()
	var type := towers.get_type(placed.type)
	if type.trigger == null:
		return role
	var star := TriggerData.trigger_at(type.trigger, Stars.clamp_star(type, placed.star))
	var effect := star.effect
	var activate_neighbors: bool = effect["kind"] == "activateNeighbors"
	role.activates = activate_neighbors or (effect["kind"] == "chargeLightning" and effect["activateOnDischarge"])
	role.reach = int(effect["reach"]) if activate_neighbors else 0
	role.charged = star.when["kind"] == "neighborKills"
	role.copies = effect["kind"] == "copyLast"
	return role


static func _end_of(p: Placed) -> LinkEnd:
	return LinkEnd.new(p.tower_id, p.x, p.y)


static func _add(result: TriggerLinks, from: Placed, to: Placed, kind: String) -> void:
	var link := Link.new()
	link.from = _end_of(from)
	link.to = _end_of(to)
	link.kind = kind
	result.links.append(link)


## `state`: objeto com `towers` e `rewards`. `bounds`: tamanho do mapa (tem `width`/`height`).
static func preview_links(state: Object, candidate: Candidate, towers: TowerData, classes: ClassData,
		bounds: SimMap) -> TriggerLinks:
	var others: Array[Placed] = []
	for t: Tower in state.towers:
		if t.id != candidate.moving_id:
			others.append(Placed.new(t.id, t.type, t.star, t.x, t.y))
	var self_p := Placed.new(-1, candidate.type, candidate.star, candidate.x, candidate.y)
	# As classes como ficariam com a candidata no mapa (mover não muda os tipos).
	var types: Array = others.map(func(o: Placed) -> String: return o.type)
	types.append(self_p.type)
	var counted := ClassSystems.count_classes(types, towers, classes, RewardMods.of(state).wildcards)
	var class_state := ClassHolder.new()
	for id in classes.ids:
		var status := ClassState.ClassStatus.new()
		status.level = counted[id]["level"]
		class_state.classes[id] = status
	var neighborhood := towers.triggers.neighborhood
	var radius_of := func(p: Placed) -> int:
		return ClassBonuses.neighborhood_radius(classes, class_state, towers.get_type(p.type))
	# `b` está na vizinhança de `a` (com o raio de `a` e, se pedido, a cruz `reach`).
	var near := func(a: Placed, b: Placed, reach: int = 0) -> bool:
		return TriggerNeighborhood.is_reach_neighbor(a, b, neighborhood, radius_of.call(a), reach)

	var result := TriggerLinks.new()
	var self_role := _role_of(towers, self_p)
	for other in others:
		var role := _role_of(towers, other)
		# Saindo da candidata.
		if self_role.activates and near.call(self_p, other, self_role.reach):
			_add(result, self_p, other, "activates")
		if role.charged and near.call(other, self_p):
			_add(result, self_p, other, "charges")
		if role.copies and near.call(other, self_p):
			_add(result, self_p, other, "copies")
		# Chegando nela.
		if role.activates and near.call(other, self_p, role.reach):
			_add(result, other, self_p, "activates")
		if self_role.charged and near.call(self_p, other):
			_add(result, other, self_p, "charges")
		if self_role.copies and near.call(self_p, other):
			_add(result, other, self_p, "copies")

	# As casas vizinhas da candidata, na vizinhança que ela usa (com a cruz do Relé ★3).
	for y in bounds.height:
		for x in bounds.width:
			if near.call(self_p, Placed.new(-1, self_p.type, 1, x, y), self_role.reach):
				result.neighbor_cells.append(Vector2i(x, y))
	return result
