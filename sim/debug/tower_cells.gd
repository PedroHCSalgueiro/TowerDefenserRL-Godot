class_name TowerCells
extends RefCounted
## Escolha de casas para o spawn de torres em massa do debug (modo estresse e painel). As torres em
## si são as reais (`sim/towers/`) — porte de `sim/debug/towerCells.ts`.


## Tipo da torre de uma casa quando o debug mistura vários tipos: o índice é `(x + 2y) mod n`. Com
## 4 tipos, as 4 vizinhas de lado de uma casa caem nos outros 3 tipos (x±1 → ±1, y±1 → ±2), então
## num bloco compacto cada torre encosta em todos os outros tipos. "" se a lista estiver vazia.
static func pattern_tower_type(types: Array, cell: Vector2i) -> String:
	if types.is_empty():
		return ""
	var n := types.size()
	return types[(((cell.x + 2 * cell.y) % n) + n) % n]


static func _by_row_then_column(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)


## Escolhe até `count` casas livres (fora do caminho e sem torre), em ordem determinística:
## - "clustered": as mais próximas da entrada.
## - "spread": as casas vizinhas do caminho (8 direções), distribuídas por igual do começo ao fim do
##   caminho; se faltar, completa pelas mais próximas da entrada.
## `occupied`: Dictionary com os índices (`map.index_of`) das casas ocupadas.
static func pick_tower_cells(map: SimMap, occupied: Dictionary, count: int, layout: String) -> Array[Vector2i]:
	var free: Array[Vector2i] = []
	for y in map.height:
		for x in map.width:
			var cell := Vector2i(x, y)
			if map.can_place_tower(cell) and not occupied.has(map.index_of(cell)):
				free.append(cell)
	var entrance := map.entrance
	var entrance_dist_sq := func(c: Vector2i) -> int:
		return (c.x - entrance.x) * (c.x - entrance.x) + (c.y - entrance.y) * (c.y - entrance.y)
	var by_entrance := free.duplicate()
	by_entrance.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = entrance_dist_sq.call(a)
		var db: int = entrance_dist_sq.call(b)
		return da < db or (da == db and _by_row_then_column(a, b)))
	if layout == "clustered" or count <= 0:
		var out: Array[Vector2i] = []
		out.assign(by_entrance.slice(0, maxi(0, count)))
		return out

	# Índice, no caminho, da primeira casa de caminho vizinha de cada casa.
	var path_index := {}
	for i in map.path_cells.size():
		path_index[map.index_of(map.path_cells[i])] = i
	var along_path: Array = []
	for cell in free:
		var order := INF
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n := Vector2i(cell.x + dx, cell.y + dy)
				# Só o caminho principal conta (as entradas das salas do mapa que cresce ficam de fora).
				if not map.is_path(n) or not path_index.has(map.index_of(n)):
					continue
				order = minf(order, float(path_index[map.index_of(n)]))
		if order != INF:
			along_path.append({"cell": cell, "order": order})
	along_path.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["order"] < b["order"] or (a["order"] == b["order"] and _by_row_then_column(a["cell"], b["cell"])))

	var picked: Array[Vector2i] = []
	if count >= along_path.size():
		for c: Dictionary in along_path:
			picked.append(c["cell"])
	else:
		# Passo uniforme que inclui a primeira e a última casa ao longo do caminho.
		for i in count:
			var at := 0 if count == 1 else SimMath.js_round(float(i * (along_path.size() - 1)) / float(count - 1))
			picked.append(along_path[at]["cell"])
	var taken := {}
	for c in picked:
		taken[map.index_of(c)] = true
	for cell: Vector2i in by_entrance:
		if picked.size() >= count:
			break
		if not taken.has(map.index_of(cell)):
			picked.append(cell)
	return picked
