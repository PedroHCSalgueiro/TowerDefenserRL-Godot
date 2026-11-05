class_name Map2DBuilders
extends RefCounted
## Montagem do mapa 2D em etapas separadas, todas a partir do `SimMap` e de `data/scenery2d.json`:
## terreno, caminho, muralha e saia, peças (por conjuntos com regra) e decoração. Nada aqui muda uma casa.
## A muralha reaproveita a classificação do 3D (`FortressWalls.wall_cells`: alta atrás, baixa na frente).

## Deslocamento no plano 2D (em pixels da arte) de um vetor do chão (x, z em casas): diamond down, x desce para a direita
## e z para a esquerda. É só a direção e a escala: NÃO é a posição de uma casa (a casa (0, 0) não fica em (0, 0) no
## TileMapLayer). Para posicionar algo no mapa, use `cell_point`.
static func iso(gx: float, gz: float) -> Vector2:
	return Vector2((gx - gz) * 24.0, (gx + gz) * 12.0)


## Ponto do chão (x, z em casas, com fração) -> posição local no `layer`, alinhada com o centro das casas do TileMap.
## A casa inteira mais próxima vem do `TileMapLayer.map_to_local()` (que no isométrico 48x24 põe o centro da casa (0, 0)
## em (24, 12), meia casa a mais que o `iso`), e a fração (0,25, 0,3...) é somada com o `iso`.
static func cell_point(layer: TileMapLayer, gx: float, gz: float) -> Vector2:
	var cell := Vector2i(floori(gx + 0.5), floori(gz + 0.5))
	return layer.map_to_local(cell) + iso(gx - cell.x, gz - cell.y)


static func _open(map: SimMap, c: Vector2i) -> bool:
	return map.is_inside(c) and map.is_open(c)


# ------------------------------------------------------------------ terreno
## Tipo do terreno de cada casa livre: "laje", "grama" ou "terra", por manchas grandes de ruído (fixo pela semente).
static func terrain_kinds(map: SimMap, cfg: Dictionary) -> Dictionary:
	var noise := FastNoiseLite.new()
	noise.seed = int(cfg["seed"])
	noise.frequency = float(cfg["frequency"])
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var out := {}
	for y in map.height:
		for x in map.width:
			var c := Vector2i(x, y)
			if not map.is_open(c) or map.is_path(c):
				continue
			var n := noise.get_noise_2d(x, y)
			out[c] = "laje" if n > float(cfg["slabAbove"]) else ("grama" if n < float(cfg["grassBelow"]) else "terra")
	return out


static func paint_terrain(layer: TileMapLayer, assets: Map2DAssets, map: SimMap, kinds: Dictionary, cfg: Dictionary) -> void:
	for c: Vector2i in kinds:
		var name := ""
		match kinds[c]:
			"laje":
				name = "laje_%d_%d" % [posmod(c.x, 4), posmod(c.y, 4)]
			"grama":
				var list: Array = cfg["grass"]
				name = list[_hash(c, 1) % list.size()]
			_:
				var list: Array = cfg["dirt"]
				name = list[_hash(c, 2) % list.size()]
		layer.set_cell(c, Map2DAssets.SRC_CHAO, assets.tile("chao", name))


# ------------------------------------------------------------------ caminho
static func paint_path(layer: TileMapLayer, assets: Map2DAssets, map: SimMap) -> void:
	for y in map.height:
		for x in map.width:
			var c := Vector2i(x, y)
			if map.is_open(c) and map.is_path(c):
				layer.set_cell(c, Map2DAssets.SRC_CHAO, assets.tile("chao", "caminho_%d_%d" % [posmod(c.x, 4), posmod(c.y, 4)]))


# ------------------------------------------------------------------ muralha e saia
## Peça de muralha de cada casa alta: "z_<v>" (corre ao longo de z, aberta em +x), "x_<v>", com "_ponta" onde encontra
## a saia da frente, ou "canto". A variante v segue a posição ao longo da parede (a textura continua).
## A casa do portal também recebe a muralha: o portal (28x38, mais baixo que os 40 px da muralha) é desenhado na frente
## dela, então a parede faz o batente dos lados e a verga em cima, com as ameias seguindo sem buraco. `portals` fica na
## assinatura para quem precisar saber quais casas são portal.
static func wall_tiles(map: SimMap, cells: Dictionary, _portals: Dictionary) -> Dictionary:
	var out := {}
	for c: Vector2i in cells:
		if not cells[c]:
			continue
		var ox := _open(map, c + Vector2i(1, 0))
		var oz := _open(map, c + Vector2i(0, 1))
		if ox:
			out[c] = "z_%d" % posmod(c.y, 4) + ("_ponta" if FortressWalls._corner_low(map, cells, c + Vector2i(0, 1)) else "")
		elif oz:
			out[c] = "x_%d" % posmod(c.x, 4) + ("_ponta" if FortressWalls._corner_low(map, cells, c + Vector2i(1, 0)) else "")
		else:
			out[c] = "canto"
	return out


## Saia embaixo das casas abertas da borda da frente: "z_<v>", "x_<v>" ou "zx_<v>".
static func edge_tiles(map: SimMap, cells: Dictionary) -> Dictionary:
	var out := {}
	for y in map.height:
		for x in map.width:
			var c := Vector2i(x, y)
			if not map.is_open(c):
				continue
			var z: bool = cells.has(c + Vector2i(0, 1)) and not cells[c + Vector2i(0, 1)]
			var xx: bool = cells.has(c + Vector2i(1, 0)) and not cells[c + Vector2i(1, 0)]
			if z or xx:
				out[c] = ("zx" if z and xx else ("z" if z else "x")) + "_%d" % posmod(c.x if z else c.y, 4)
	return out


# ------------------------------------------------------------------ portal
## Ponto do portal (em casas): na face de dentro da muralha (a muralha ocupa a metade de dentro da casa, então a face fica
## a 0,5 do centro), centrado na casa ao longo da parede. No 2D o portal é desenhado por cima da muralha: no meio da
## espessura (0,25) a base dele ficaria 3 px acima da linha onde a parede encontra o chão, mostrando tijolo embaixo dos
## pilares; na face, os pilares encostam no chão e a parede faz o batente e a verga em volta.
const PORTAL_DEPTH := 0.5


static func portal_point(cell: Vector2i, outward: Vector2i) -> Vector2:
	return Vector2(cell) - Vector2(outward) * PORTAL_DEPTH


## Soleira de cada portal: o chão do caminho só na metade de dentro da casa (a espessura da muralha), para o caminho
## atravessar o vão sem mostrar o fundo e sem passar para fora da muralha. "soleira_z_<x>_<y>" na parede que corre ao
## longo de z (saída em -x), "soleira_x_<x>_<y>" na que corre ao longo de x (saída em -z).
static func threshold_tiles(portals: Dictionary) -> Dictionary:
	var out := {}
	for c: Vector2i in portals:
		var outward: Vector2i = portals[c]
		out[c] = "soleira_%s_%d_%d" % ["z" if outward.x != 0 else "x", posmod(c.x, 4), posmod(c.y, 4)]
	return out


# ------------------------------------------------------------------ peças
## Lista de peças {name, at (Vector2 em casas), flip, light} montada por regras, nesta ordem (cada uma respeita o espaço
## das anteriores):
## 1. portal na parede de cada entrada, com braseiros dos dois lados;
## 2. torre no canto de trás;
## 3. núcleo: o cristal, com braseiros nas casas livres vizinhas;
## 4. tochas na beira do caminho, alternando os lados;
## 5. conjuntos no pé da muralha alta (depósito, jardim, santuário, ruína, guarda), um a cada `clusterEvery` casas,
##    sem repetir o vizinho;
## 6. uma peça central em cada área livre fechada pelo caminho (`minRegion` casas ou mais).
static func place_props(map: SimMap, cells: Dictionary, portals: Dictionary, cfg: Dictionary) -> Array:
	var out: Array = []
	var gap := float(cfg["spacing"]["props"])
	# 1. portal: na face de dentro da muralha, centrado na casa (`portal_point`); o pé é o meio entre os dois pilares
	for c: Vector2i in portals:
		var outward: Vector2i = portals[c]
		var at := portal_point(c, outward)
		out.append({"name": "portal", "at": at, "flip": outward.x != 0, "light": "portal"})
		var along := Vector2(0, 1) if outward.x != 0 else Vector2(1, 0)
		for s in [-1.0, 1.0]:
			_try(out, "braseiro", Vector2(c) - Vector2(outward) * 0.75 + along * s * 0.9, 0.3, "braseiro")
	# 2. torre no canto de trás (casa alta sem vizinha aberta nos lados)
	for c: Vector2i in cells:
		if cells[c] and not _open(map, c + Vector2i(1, 0)) and not _open(map, c + Vector2i(0, 1)) and _open(map, c + Vector2i(1, 1)):
			out.append({"name": "torre", "at": Vector2(c) + Vector2(0.25, 0.25), "flip": false, "light": ""})
	# 3. núcleo
	var n := Vector2(map.nexus)
	out.append({"name": "cristal_nucleo", "at": n, "flip": false, "light": "nucleo"})
	var lados := 0
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if lados < 2 and map.can_place_tower(map.nexus + d):
			if _try(out, "braseiro", n + Vector2(d) * 0.75, 0.3, "braseiro"):
				lados += 1
	# 4. tochas na beira do caminho
	var path := map.path_cells
	var side := 1
	for k in range(2, path.size() - 2, int(cfg["torchEvery"])):
		var dir: Vector2i = path[k + 1] - path[k - 1]
		var perp := Vector2i(-dir.y, dir.x)
		perp = Vector2i(signi(perp.x), signi(perp.y))
		for s in [side, -side]:
			var free: Vector2i = path[k] + perp * s
			if map.can_place_tower(free):
				_try(out, "tocha", Vector2(path[k]) + Vector2(perp * s) * float(cfg["torchInset"]), 0.4, "torch")
				break
		side = -side
	# 5. conjuntos no pé da muralha alta
	var order: Array = cfg["clusterOrder"]
	var clusters: Dictionary = cfg["clusters"]
	var feet := _wall_feet(map, cells, portals)
	var turn := 0
	for i in range(1, feet.size(), int(cfg["clusterEvery"])):
		var foot: Array = feet[i]
		var at: Vector2 = Vector2(foot[0]) + Vector2(foot[1]) * float(cfg["wallInset"])
		var name: String = order[turn % order.size()]
		turn += 1
		_cluster(out, clusters[name], at, foot[1], gap)
	# 6. peça central de cada área livre fechada
	var pieces: Array = cfg["centerpieces"]
	var k2 := 0
	for region: Array in _free_regions(map, cells):
		if region.size() < int(cfg["minRegion"]):
			continue
		var center := Vector2.ZERO
		for c: Vector2i in region:
			center += Vector2(c)
		center /= region.size()
		var best: Vector2i = region[0]
		for c: Vector2i in region:
			if Vector2(c).distance_to(center) < Vector2(best).distance_to(center):
				best = c
		_cluster(out, pieces[k2 % pieces.size()], Vector2(best), Vector2i.ZERO, gap)
		k2 += 1
	return out


static func _try(out: Array, name: String, at: Vector2, gap: float, light: String) -> bool:
	for p: Dictionary in out:
		if (p["at"] as Vector2).distance_to(at) < gap:
			return false
	out.append({"name": name, "at": at, "flip": false, "light": light})
	return true


## Um conjunto: a primeira peça é a âncora (precisa de espaço `gap` das outras); as demais ficam encostadas nela.
static func _cluster(out: Array, items: Array, at: Vector2, toward_wall: Vector2i, gap: float) -> void:
	for p: Dictionary in out:
		if (p["at"] as Vector2).distance_to(at) < gap:
			return
	# o desenho do conjunto é pensado para a parede de cima-direita (atrás em -z); na outra parede, troca x por z
	var rot := toward_wall.x != 0
	for item: Array in items:
		var d := Vector2(float(item[1]), float(item[2]))
		if rot:
			d = Vector2(d.y, d.x)
		var light := ""
		match String(item[0]):
			"braseiro":
				light = "braseiro"
			"tocha":
				light = "torch"
			"cristal":
				light = "cristal"
			"cogumelo":
				light = "cogumelo"
		out.append({"name": String(item[0]), "at": at + d, "flip": false, "light": light})


## Casas livres encostadas na muralha alta, em ordem ao longo da parede, com a direção da parede ([casa, para_parede]).
static func _wall_feet(map: SimMap, cells: Dictionary, portals: Dictionary) -> Array:
	var out: Array = []
	for y in map.height:
		for x in map.width:
			var c := Vector2i(x, y)
			if not map.can_place_tower(c):
				continue
			for d: Vector2i in [Vector2i(-1, 0), Vector2i(0, -1)]:
				var w := c + d
				if cells.get(w, false) and not portals.has(w):
					out.append([c, d])
					break
	# primeiro a parede de cima-direita (ao longo de x), depois a de cima-esquerda (ao longo de z), cada uma em ordem
	out.sort_custom(func(a: Array, b: Array) -> bool:
		var ka := Vector2i(0 if (a[1] as Vector2i).y != 0 else 1, (a[0] as Vector2i).x if (a[1] as Vector2i).y != 0 else (a[0] as Vector2i).y)
		var kb := Vector2i(0 if (b[1] as Vector2i).y != 0 else 1, (b[0] as Vector2i).x if (b[1] as Vector2i).y != 0 else (b[0] as Vector2i).y)
		return ka.x < kb.x or (ka.x == kb.x and ka.y < kb.y))
	return out


## Áreas de casas livres (sem caminho) que não encostam na muralha, separadas pelo caminho.
static func _free_regions(map: SimMap, cells: Dictionary) -> Array:
	var seen := {}
	var out: Array = []
	for y in map.height:
		for x in map.width:
			var s := Vector2i(x, y)
			if seen.has(s) or not map.can_place_tower(s):
				continue
			var region: Array = []
			var stack: Array = [s]
			seen[s] = true
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				var near_wall := false
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if cells.has(c + d):
						near_wall = true
				if not near_wall:
					region.append(c)
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n := c + d
					if not seen.has(n) and map.can_place_tower(n):
						seen[n] = true
						stack.append(n)
			out.append(region)
	return out


# ------------------------------------------------------------------ decoração
## Miudezas nas casas livres, mais perto do caminho e nas trocas de terreno (escondem a emenda dos losangos), com
## espaço entre elas e longe das peças.
static func scatter_decor(map: SimMap, kinds: Dictionary, props: Array, cfg: Dictionary) -> Array:
	var d_cfg: Dictionary = cfg["decor"]
	var weights: Dictionary = d_cfg["pieces"]
	var gap := float(cfg["spacing"]["decor"])
	var gap_prop := float(cfg["spacing"]["decorToProp"])
	var out: Array = []
	for y in map.height:
		for x in map.width:
			var c := Vector2i(x, y)
			if not map.can_place_tower(c):
				continue
			var chance := float(d_cfg["chance"])
			var at := Vector2(c)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := c + d
				if _open(map, n) and map.is_path(n):
					chance += float(d_cfg["nearPathBonus"])
					at += Vector2(d) * 0.35     # na beira do caminho
					break
				if kinds.has(n) and kinds[n] != kinds.get(c, ""):
					at += Vector2(d) * 0.45     # em cima da emenda entre dois terrenos
					break
			if float(_hash(c, 7) % 1000) / 1000.0 >= chance:
				continue
			at += Vector2(float(_hash(c, 8) % 100) / 100.0 - 0.5, float(_hash(c, 9) % 100) / 100.0 - 0.5) * 0.25
			var ok := true
			for p: Dictionary in props:
				if (p["at"] as Vector2).distance_to(at) < gap_prop:
					ok = false
			for p: Dictionary in out:
				if (p["at"] as Vector2).distance_to(at) < gap:
					ok = false
			if ok:
				var name := SceneryProps.pick(weights, _hash(c, 10))
				out.append({"name": name, "at": at, "flip": false, "light": "cogumelo" if name == "cogumelo" else ""})
	return out


static func _hash(c: Vector2i, salt: int) -> int:
	return SceneryProps.cell_hash(c, salt + 100)
