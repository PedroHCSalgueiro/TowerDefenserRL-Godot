class_name TriggerNeighborhood
extends RefCounted
## Vizinhança dos gatilhos, em funções puras: o motor usa no tick e a janela de
## informações (T16) usa para destacar as vizinhas que a torre afeta, com a mesma
## regra (porte de `neighborhood.ts`).
##
## - Sem bônus: a vizinhança dos dados (4 casas de lado ou 8 com diagonais).
## - Com o bônus da Arcana (`radius` > 0): o quadrado de lado 2·raio+1.
## - Com `reach` (Relé ★3): as vizinhas mais as casas em cruz até `reach`.
##
## `a` e `b` são qualquer objeto com `x` e `y` inteiros (Tower, ou Vector2i via `at()`).


## `b` é vizinha de `a`? `radius` > 0: quadrado da Arcana; senão, a vizinhança dos dados.
static func is_neighbor(a: Object, b: Object, neighborhood: int, radius: int) -> bool:
	var dx := absi(a.x - b.x)
	var dy := absi(a.y - b.y)
	if radius > 0:
		return dx + dy > 0 and maxi(dx, dy) <= radius
	return dx + dy == 1 if neighborhood == 4 else maxi(dx, dy) == 1


## Vizinha ou na cruz até `reach` casas (Relé ★3).
static func is_reach_neighbor(a: Object, b: Object, neighborhood: int, radius: int, reach: int) -> bool:
	if is_neighbor(a, b, neighborhood, radius):
		return true
	var dx := absi(a.x - b.x)
	var dy := absi(a.y - b.y)
	return dx + dy > 0 and (dx == 0 or dy == 0) and dx + dy <= reach


## As vizinhas que o gatilho da torre envolve, em ordem de id, com a vizinhança atual
## (bônus da Arcana de `state.classes` e a cruz do Relé ★3): as que ela ativa (ativar
## vizinhas, Obelisco ★3), as que ela copia e as cujos abates a carregam. Torre sem
## gatilho de vizinhança: lista vazia.
static func affected_neighbors(state: Object, tower: Tower, towers: TowerData, classes: ClassData) -> Array[Tower]:
	var type := towers.get_type(tower.type)
	var result: Array[Tower] = []
	if type.trigger == null:
		return result
	var star := TriggerData.trigger_at(type.trigger, Stars.clamp_star(type, tower.star))
	var when: Dictionary = star.when
	var effect: Dictionary = star.effect
	var uses_neighbors: bool = effect["kind"] == "activateNeighbors" or effect["kind"] == "copyLast" \
			or when["kind"] == "neighborKills" \
			or (effect["kind"] == "chargeLightning" and effect["activateOnDischarge"])
	if not uses_neighbors:
		return result
	var radius := ClassBonuses.neighborhood_radius(classes, state, type)
	var reach: int = effect["reach"] if effect["kind"] == "activateNeighbors" else 0
	var neighborhood := towers.triggers.neighborhood
	for t: Tower in state.towers:
		if t != tower and is_reach_neighbor(tower, t, neighborhood, radius, reach):
			result.append(t)
	result.sort_custom(func(a: Tower, b: Tower) -> bool: return a.id < b.id)
	return result
