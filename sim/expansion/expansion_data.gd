class_name ExpansionData
extends RefCounted
## Mapa que cresce com moldes (Mini-GDD, Sistema 7), lido de `data/expansion.json`.
##
## O mapa é feito de pedaços quadrados de `pieceSize` casas (ímpar: as portas ficam no meio exato da
## borda). Todo pedaço abre inteiro e o caminho dele vai de borda a borda: entra pela porta de trás e sai
## pela da frente, onde fica a entrada dos inimigos. Em coordenadas locais, d = profundidade a partir da
## borda por onde a linha entrou e l = lateral; a porta de entrada de uma peça de largura w é (0, w / 2).
## - A base é fixa (`base`): um zigue-zague do núcleo até a porta da frente.
## - Cada parede escolhe a direção da linha (frente ou um dos lados; nunca para trás):
##   - frente: um pedaço colado na porta, com um molde sorteado (`molds`);
##   - lado: uma ligação (`link`, menor) que anda um pouco e vira para aquele lado e, colado na saída
##     dela, um pedaço na direção nova. Os pedaços saem da grade e o mapa fica irregular.
## - Um pedaço nunca cobre outro, e o caminho novo nunca encosta no velho; a direção que não cabe não
##   aparece. Os moldes são sorteados (por peso) quando a parede cai; a escolha mostra já o sorteado.
## O mapa só cresce para a direita, para cima e para baixo; nas `forwardOnlyWalls` primeiras paredes,
## só para a frente. Dividir (só no debug) abre duas direções de uma vez por um cruzamento (um pedaço
## com o caminho até o centro e de lá para as duas saídas): a segunda vira uma linha nova, com entrada
## própria, que se junta à principal no centro do cruzamento.
##
## Id de uma abertura: "linha:direção:molde" (molde espelhado com "~"), por exemplo "0:cima:u~".
## Dividir junta duas partes com "+"; a segunda usa a linha "n" (nova): "0:direita:s+n:cima:reto".

## Uma abertura possível (ou já feita): as casas que abrem e o caminho novo.
class Opening:
	extends RefCounted
	var id: String
	var name: String
	## Casas das peças novas (todas, inclusive as do caminho novo).
	var cells: Array[Vector2i] = []
	## Casas novas de caminho (as de todas as partes), para mostrar e contar.
	var path_cells: Array[Vector2i] = []
	## Traz uma entrada nova de inimigos (dividir).
	var new_entrance := false
	## Linha que muda: 0 = a principal, 1 = a segunda... (= índice da entrada no `SimMap`).
	var line := 0
	## Partes, na ordem: {"line": índice da linha (-1 = nova), "cells": casas novas da entrada para
	## dentro, "join": casa da linha principal onde a linha nova se junta, "dir": direção nova da linha}.
	var steps: Array[Dictionary] = []

## A ponta de uma linha: a casa da entrada (na borda) e a direção em que a linha anda para fora.
class Line:
	extends RefCounted
	var tip: Vector2i
	var dir: String

## Casas e linhas abertas por uma lista de aberturas.
class Layout:
	extends RefCounted
	## Casas abertas e casas de caminho (casa -> true).
	var cells := {}
	var path := {}
	var lines: Array[Line] = []
	var walls := 0

const RIGHT := "direita"
const UP := "cima"
const DOWN := "baixo"
const LEFT := "esquerda"
## Direções para onde o mapa cresce, na ordem das opções (nunca para a esquerda, para o lado do núcleo).
const GROW_DIRS: Array[String] = [RIGHT, UP, DOWN]
const STEP := {RIGHT: Vector2i(1, 0), UP: Vector2i(0, -1), DOWN: Vector2i(0, 1), LEFT: Vector2i(-1, 0)}
## Para onde cresce a lateral l de uma peça que anda em cada direção.
const LATERAL := {RIGHT: Vector2i(0, 1), UP: Vector2i(1, 0), DOWN: Vector2i(1, 0), LEFT: Vector2i(0, 1)}
const NEW_LINE := "n"
const MIRROR := "~"
## Tentativas de sortear um molde que caiba (só a porta pode encostar em outro caminho, então quase
## sempre o primeiro serve) e de sortear moldes que não se encostam ao dividir.
const ROLL_TRIES := 8
const SPLIT_TRIES := 12

var enabled := false
var map_id := ""
var piece_size := 11
## Ondas que derrubam uma parede ao fechar.
var after_waves: Array[int] = []
var forward_only_walls := 2
## Tempo da escolha; no zero, a simulação escolhe sozinha.
var choose_seconds := 20.0
## Pontos de virada do caminho da base (locais), do núcleo até a porta da frente, e as casas dele.
var base: Array[Vector2i] = []
var base_cells: Array[Vector2i] = []
## Ligação da virada: tamanho (x = fundo, y = largura) e casas locais do caminho, da porta de trás até a
## saída do lado l = 0 (o outro lado usa o espelho).
var link_size := Vector2i(7, 5)
var link_cells: Array[Vector2i] = []
## [{"id", "weight", "cells": Array[Vector2i] locais, já expandidas}], da porta de trás à da frente.
var molds: Array = []
var names: Dictionary = {}

static var _default: ExpansionData = null


static func reset_cache() -> void:
	_default = null


static func game_data() -> ExpansionData:
	if _default == null:
		_default = load_data(DataLoader.load_json("expansion.json"))
		if _default == null:
			_default = disabled()
	return _default


## Sem expansão (o mapa fica como está).
static func disabled() -> ExpansionData:
	return ExpansionData.new()


## Os dados da expansão que valem para este mapa, ou null (mapa que não cresce).
static func for_map(map: SimMap, data: ExpansionData = null) -> ExpansionData:
	var d := data if data != null else game_data()
	return d if d.enabled and d.map_id == map.id else null


## Quantas paredes a run tem.
func max_walls() -> int:
	return after_waves.size()


func center() -> int:
	return piece_size / 2


## O máximo que uma parede leva a ponta de uma linha para longe (virando: ligação + pedaço).
func _reach() -> int:
	return piece_size + link_size.y / 2


## Folga acima e abaixo da base: as paredes que podem virar, cada uma no máximo `_reach`.
func _margin() -> int:
	return maxi(0, max_walls() - forward_only_walls) * _reach()


func map_width() -> int:
	return piece_size + max_walls() * _reach() + center()


func map_height() -> int:
	return piece_size + 2 * _margin()


## Porta de trás da base (na borda esquerda do mapa).
func base_start() -> Vector2i:
	return Vector2i(0, _margin() + center())


## Casa local (d, l) de uma peça de largura `width` que anda para `dir`, com a porta de trás em `start`.
static func to_global(start: Vector2i, dir: String, width: int, local: Vector2i) -> Vector2i:
	var forward: Vector2i = STEP[dir]
	var lateral: Vector2i = LATERAL[dir]
	return start + forward * local.x + lateral * (local.y - width / 2)


static func _to_global_all(start: Vector2i, dir: String, width: int, cells: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell in cells:
		out.append(to_global(start, dir, width, cell))
	return out


## Todas as casas de uma peça (`size`: x = fundo, y = largura).
static func _rect(start: Vector2i, dir: String, size: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in size.x:
		for l in size.y:
			out.append(to_global(start, dir, size.y, Vector2i(d, l)))
	return out


## Direção (global) do lado l = 0 de quem anda para `dir`.
static func _low_side(dir: String) -> String:
	var unit: Vector2i = -LATERAL[dir]
	for key: String in STEP:
		if STEP[key] == unit:
			return key
	return ""


static func _back(dir: String) -> String:
	return {RIGHT: LEFT, LEFT: RIGHT, UP: DOWN, DOWN: UP}[dir]


## Mapa novo, só com o pedaço da base aberto. Cada run precisa do seu: o mapa muda quando uma parede cai.
func build_map() -> SimMap:
	var points: Array = []
	for i in range(base.size() - 1, -1, -1):
		var cell := to_global(base_start(), RIGHT, piece_size, base[i])
		points.append({"x": cell.x, "y": cell.y})
	var map := SimMap.load_map({"id": map_id, "width": map_width(), "height": map_height(), "path": points})
	if map == null:
		return null
	map.set_start_cells(_rect(base_start(), RIGHT, Vector2i(piece_size, piece_size)))
	return map


## Casas e linhas depois das aberturas `actions` (na ordem). Ids inválidos são ignorados.
func layout(actions: Array) -> Layout:
	var out := Layout.new()
	for cell in _rect(base_start(), RIGHT, Vector2i(piece_size, piece_size)):
		out.cells[cell] = true
	var base_path := _to_global_all(base_start(), RIGHT, piece_size, base_cells)
	for cell in base_path:
		out.path[cell] = true
	var main := Line.new()
	main.tip = base_path[base_path.size() - 1]
	main.dir = RIGHT
	out.lines.append(main)
	for id: String in actions:
		var o := _build(out, id)
		if o == null:
			continue
		out.walls += 1
		for cell in o.cells:
			out.cells[cell] = true
		for cell in o.path_cells:
			out.path[cell] = true
		for step: Dictionary in o.steps:
			var line := Line.new()
			var cells: Array[Vector2i] = step["cells"]
			line.tip = cells[0]
			line.dir = step["dir"]
			if step["line"] == -1:
				out.lines.append(line)
			else:
				out.lines[int(step["line"])] = line
	return out


## Partes do id: [{"line": int (-1 = nova), "dir", "mold": [molde, espelho]}], ou [] se o formato for
## inválido.
func _parse(id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var texts := id.split("+")
	if texts.size() > 2:
		return out
	for i in texts.size():
		var f := texts[i].split(":")
		if f.size() != 3 or not STEP.has(f[1]):
			return [] as Array[Dictionary]
		var line := -1
		if i == 0 and f[0].is_valid_int() and int(f[0]) >= 0:
			line = int(f[0])
		elif not (i == 1 and f[0] == NEW_LINE):
			return [] as Array[Dictionary]
		out.append({"line": line, "dir": f[1], "mold": [f[2].trim_suffix(MIRROR), f[2].ends_with(MIRROR)]})
	return out


static func _ref_text(id: String, mirrored: bool) -> String:
	return id + (MIRROR if mirrored else "")


## Casas locais do molde (espelhado se pedido), ou [] se não existe.
func _mold_cells(ref: Array) -> Array[Vector2i]:
	for mold: Dictionary in molds:
		if mold["id"] == ref[0]:
			var cells: Array[Vector2i] = mold["cells"]
			return _mirror(cells, piece_size) if ref[1] else cells.duplicate()
	return [] as Array[Vector2i]


static func _mirror(cells: Array[Vector2i], width: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell in cells:
		out.append(Vector2i(cell.x, width - 1 - cell.y))
	return out


## Direções para onde a linha `index` pode crescer: nunca para trás; nas primeiras paredes, só para a
## frente (a não ser com `any_dir`, para dividir no debug); e só se as peças couberem no mapa sem cobrir
## outras (ao dividir, cada direção pelo cruzamento).
func free_dirs(lay: Layout, index: int, any_dir: bool = false) -> Array[String]:
	var out: Array[String] = []
	if lay.walls >= max_walls() or index >= lay.lines.size():
		return out
	var line: Line = lay.lines[index]
	for dir in GROW_DIRS:
		if dir == _back(line.dir):
			continue
		if not any_dir and lay.walls < forward_only_walls and dir != line.dir:
			continue
		var rects := _split_rects(line, dir) if any_dir else _rects(line, dir)
		if _rects_fit(lay, rects):
			out.append(dir)
	return out


## Peças de uma parede que leva a linha para `dir`: [pedaço] para a frente, [ligação, pedaço] para o lado.
## Cada uma é {"start", "dir", "size"}.
func _rects(line: Line, dir: String) -> Array[Dictionary]:
	var square := Vector2i(piece_size, piece_size)
	var first: Vector2i = line.tip + STEP[line.dir]
	if dir == line.dir:
		return [{"start": first, "dir": dir, "size": square}] as Array[Dictionary]
	var exit := to_global(first, line.dir, link_size.y, _link_for(line.dir, dir)[link_cells.size() - 1])
	return [{"start": first, "dir": line.dir, "size": link_size},
			{"start": exit + STEP[dir], "dir": dir, "size": square}] as Array[Dictionary]


## Peças de uma parte de dividir: [cruzamento, pedaço].
func _split_rects(line: Line, dir: String) -> Array[Dictionary]:
	var square := Vector2i(piece_size, piece_size)
	var first: Vector2i = line.tip + STEP[line.dir]
	var branch := _branch(line.dir, dir)
	var exit := to_global(first, line.dir, piece_size, branch[branch.size() - 1])
	return [{"start": first, "dir": line.dir, "size": square},
			{"start": exit + STEP[dir], "dir": dir, "size": square}] as Array[Dictionary]


## Caminho da ligação que vira de `from` para `to` (espelhado se `to` for o lado l alto).
func _link_for(from: String, to: String) -> Array[Vector2i]:
	return link_cells.duplicate() if _low_side(from) == to else _mirror(link_cells, link_size.y)


## Caminho do cruzamento do centro até a saída para `to` (sem o centro).
func _branch(from: String, to: String) -> Array[Vector2i]:
	var c := center()
	var end := Vector2i(piece_size - 1, c)
	if to != from:
		end = Vector2i(c, 0 if _low_side(from) == to else piece_size - 1)
	return _expand([[c, c], [end.x, end.y]], Vector2i(piece_size, piece_size)).slice(1)


## As peças cabem no mapa sem cobrir casas abertas nem umas às outras.
func _rects_fit(lay: Layout, rects: Array) -> bool:
	var seen := {}
	for rect: Dictionary in rects:
		for cell in _rect(rect["start"], rect["dir"], rect["size"]):
			if cell.x < 0 or cell.y < 0 or cell.x >= map_width() or cell.y >= map_height():
				return false
			if lay.cells.has(cell) or seen.has(cell):
				return false
			seen[cell] = true
	return true


## A abertura `id` depois de `actions`, ou null se não der (formato, molde, direção ou espaço).
func opening(actions: Array, id: String) -> Opening:
	return _build(layout(actions), id)


func _build(lay: Layout, id: String) -> Opening:
	var parts := _parse(id)
	if parts.is_empty():
		return null
	var index := int(parts[0]["line"])
	if index < 0 or index >= lay.lines.size():
		return null
	var split := parts.size() == 2
	if split and (index != 0 or parts[0]["dir"] == parts[1]["dir"]):
		return null
	var dirs := free_dirs(lay, index, split)
	var line: Line = lay.lines[index]
	var o := Opening.new()
	o.id = id
	o.name = option_name(id)
	o.line = index
	o.new_entrance = split
	var c := center()
	var first: Vector2i = line.tip + STEP[line.dir]
	var rects: Array[Dictionary] = []
	## Caminho de cada parte, de dentro para fora.
	var outward: Array = []
	var join := Vector2i.ZERO
	for i in parts.size():
		var part := parts[i]
		var dir: String = part["dir"]
		if not dirs.has(dir):
			return null
		var mold := _mold_cells(part["mold"])
		if mold.is_empty():
			return null
		var cells: Array[Vector2i] = []
		var piece_rects := _split_rects(line, dir) if split else _rects(line, dir)
		if split:
			var entry := _expand([[0, c], [c, c]], Vector2i(piece_size, piece_size))
			join = to_global(first, line.dir, piece_size, Vector2i(c, c))
			if i == 0:
				cells.append_array(_to_global_all(first, line.dir, piece_size, entry))
				rects.append(piece_rects[0])
			cells.append_array(_to_global_all(first, line.dir, piece_size, _branch(line.dir, dir)))
		elif dir != line.dir:
			cells.append_array(_to_global_all(first, line.dir, link_size.y, _link_for(line.dir, dir)))
			rects.append(piece_rects[0])
		var piece: Dictionary = piece_rects[piece_rects.size() - 1]
		rects.append(piece)
		cells.append_array(_to_global_all(piece["start"], dir, piece_size, mold))
		outward.append(cells)
	if not _rects_fit(lay, rects):
		return null
	for i in outward.size():
		var cells: Array[Vector2i] = outward[i]
		# A primeira casa da linha principal encosta na ponta velha; a linha nova, no centro do cruzamento.
		if _touching_itself(cells) or _touches(cells.slice(1) if i == 0 else cells, lay.path):
			return null
	if split:
		var main_cells: Array[Vector2i] = outward[0]
		var without_center := {}
		for cell in main_cells:
			if cell != join:
				without_center[cell] = true
		if _touches(outward[1], without_center):
			return null
	for rect in rects:
		o.cells.append_array(_rect(rect["start"], rect["dir"], rect["size"]))
	for i in outward.size():
		var cells: Array[Vector2i] = outward[i]
		cells.reverse()
		o.path_cells.append_array(cells)
		o.steps.append({"line": int(parts[i]["line"]), "cells": cells, "join": join, "dir": parts[i]["dir"]})
	return o


## Alguma casa de `cells` é vizinha (ou igual) a uma de `others`?
static func _touches(cells: Array, others: Dictionary) -> bool:
	for cell: Vector2i in cells:
		if others.has(cell):
			return true
		for n in [cell + Vector2i.RIGHT, cell + Vector2i.LEFT, cell + Vector2i.UP, cell + Vector2i.DOWN]:
			if others.has(n):
				return true
	return false


## O caminho repete casa, pula casa ou encosta nele mesmo fora da ordem?
static func _touching_itself(cells: Array[Vector2i]) -> bool:
	var index := {}
	for i in cells.size():
		if index.has(cells[i]):
			return true
		index[cells[i]] = i
	for i in cells.size():
		if i > 0 and absi(cells[i].x - cells[i - 1].x) + absi(cells[i].y - cells[i - 1].y) != 1:
			return true
		for n in [cells[i] + Vector2i.RIGHT, cells[i] + Vector2i.LEFT, cells[i] + Vector2i.UP, cells[i] + Vector2i.DOWN]:
			if index.has(n) and absi(int(index[n]) - i) != 1:
				return true
	return false


## Sorteia as opções da próxima parede: uma por linha e direção que cabe, cada uma com o molde já
## sorteado (vazia = acabaram as paredes).
func roll_options(actions: Array, rng: Rng) -> Array[String]:
	var out: Array[String] = []
	var lay := layout(actions)
	for index in lay.lines.size():
		for dir in free_dirs(lay, index):
			for t in ROLL_TRIES:
				var id := _roll_part(str(index), dir, rng)
				if _build(lay, id) != null:
					out.append(id)
					break
	return out


## Sorteia as opções de dividir a linha principal (debug): cada par de direções que cabe, com moldes que
## não se encostam (no último caso, os retos).
func roll_split_options(actions: Array, rng: Rng) -> Array[String]:
	var out: Array[String] = []
	var lay := layout(actions)
	var dirs := free_dirs(lay, 0, true)
	for i in dirs.size():
		for j in range(i + 1, dirs.size()):
			var found := ""
			for t in SPLIT_TRIES:
				var id := "%s+%s" % [_roll_part("0", dirs[i], rng), _roll_part(NEW_LINE, dirs[j], rng)]
				if _build(lay, id) != null:
					found = id
					break
			if found == "":
				found = "0:%s:%s+%s:%s:%s" % [dirs[i], molds[0]["id"], NEW_LINE, dirs[j], molds[0]["id"]]
			if _build(lay, found) != null:
				out.append(found)
	return out


func _roll_part(line_tag: String, dir: String, rng: Rng) -> String:
	return "%s:%s:%s" % [line_tag, dir, _roll_mold(rng)]


## Molde sorteado por peso, e o espelho sorteado (se o molde não for simétrico).
func _roll_mold(rng: Rng) -> String:
	var total := 0
	for mold: Dictionary in molds:
		total += int(mold["weight"])
	var r := rng.next_int(0, total - 1)
	var pick: Dictionary = molds[molds.size() - 1]
	for mold: Dictionary in molds:
		r -= int(mold["weight"])
		if r < 0:
			pick = mold
			break
	var cells: Array[Vector2i] = pick["cells"]
	var mirrored := _mirror(cells, piece_size) != cells and rng.next_int(0, 1) == 1
	return _ref_text(pick["id"], mirrored)


func option_name(id: String) -> String:
	var parts := _parse(id)
	if parts.is_empty():
		return id
	var dir_names: Array[String] = []
	for part: Dictionary in parts:
		dir_names.append(str(names.get(part["dir"], part["dir"])))
	var text := dir_names[0]
	if parts.size() == 2:
		text = str(names.get("split", "{a} + {b}")).replace("{a}", dir_names[0]).replace("{b}", dir_names[1])
	var index := int(parts[0]["line"])
	if index > 0:
		text = str(names.get("line", "{n}: {name}")).replace("{n}", str(index + 1)).replace("{name}", text)
	return text


static func _fail(message: String) -> ExpansionData:
	push_error("Expansão inválida: %s" % message)
	return null


## Pontos de virada [[d, l], ...] expandidos em casas, ou [] se tiver diagonal, casa fora da peça
## (`size`: x = fundo, y = largura) ou se o caminho repetir casa ou encostar nele mesmo.
static func _expand(points: Variant, size: Vector2i) -> Array[Vector2i]:
	var none: Array[Vector2i] = []
	if not (points is Array) or points.size() < 2:
		return none
	var out: Array[Vector2i] = []
	for p: Variant in points:
		if not (p is Array) or p.size() != 2 or not SimMap._is_integer(p[0]) or not SimMap._is_integer(p[1]):
			return none
		var cell := Vector2i(int(p[0]), int(p[1]))
		if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
			return none
		if out.is_empty():
			out.append(cell)
			continue
		var last := out[out.size() - 1]
		var delta := cell - last
		if (delta.x != 0 and delta.y != 0) or delta == Vector2i.ZERO:
			return none
		var unit := Vector2i(signi(delta.x), signi(delta.y))
		while last != cell:
			last += unit
			out.append(last)
	return none if _touching_itself(out) else out


## Valida os dados. Inválido: push_error e null. Sem arquivo ou `enabled: false`: desligada.
static func load_data(raw: Variant) -> ExpansionData:
	if raw == null:
		return disabled()
	if not (raw is Dictionary):
		return _fail("não é um objeto")
	if not raw.get("enabled", false):
		return disabled()
	var data := ExpansionData.new()
	data.enabled = true
	data.map_id = str(raw.get("mapId", ""))
	for key in ["pieceSize", "forwardOnlyWalls"]:
		if not SimMap._is_integer(raw.get(key)):
			return _fail('"%s" precisa ser um número inteiro' % key)
	data.piece_size = int(raw["pieceSize"])
	data.forward_only_walls = int(raw["forwardOnlyWalls"])
	data.choose_seconds = float(raw.get("chooseSeconds", 20.0))
	data.names = raw.get("names", {})
	if data.map_id.is_empty():
		return _fail('falta "mapId"')
	if data.piece_size < 7 or data.piece_size % 2 == 0:
		return _fail('"pieceSize" precisa ser ímpar e >= 7 (as portas ficam no meio exato da borda)')
	if data.forward_only_walls < 0 or data.choose_seconds <= 0.0:
		return _fail('"forwardOnlyWalls" >= 0 e "chooseSeconds" > 0')
	for wave in raw.get("afterWaves", []):
		if not SimMap._is_integer(wave) or int(wave) < 1:
			return _fail('"afterWaves" precisa de números de onda (>= 1)')
		data.after_waves.append(int(wave))
	if data.after_waves.is_empty():
		return _fail('"afterWaves" vazio: o tamanho do mapa sai do número de paredes')
	var s := data.piece_size
	var c := s / 2
	var square := Vector2i(s, s)
	var base_cells := _expand(raw.get("base"), square)
	if base_cells.is_empty() or base_cells[base_cells.size() - 1] != Vector2i(s - 1, c):
		return _fail('"base" precisa ir do núcleo até a porta da frente (%d, %d), sem diagonal nem encostar' % [s - 1, c])
	data.base_cells = base_cells
	for p: Array in raw["base"]:
		data.base.append(Vector2i(int(p[0]), int(p[1])))
	var link: Variant = raw.get("link")
	if not (link is Dictionary) or not SimMap._is_integer(link.get("depth")) or not SimMap._is_integer(link.get("width")):
		return _fail('falta "link" com "depth" e "width" inteiros')
	data.link_size = Vector2i(int(link["depth"]), int(link["width"]))
	if data.link_size.x < 2 or data.link_size.y < 3 or data.link_size.y % 2 == 0:
		return _fail('"link" precisa de "depth" >= 2 e "width" ímpar >= 3')
	data.link_cells = _expand(link.get("points"), data.link_size)
	var link_end := data.link_cells[data.link_cells.size() - 1] if not data.link_cells.is_empty() else Vector2i(-1, -1)
	if data.link_cells.is_empty() or data.link_cells[0] != Vector2i(0, data.link_size.y / 2) or link_end.y != 0:
		return _fail('"link" precisa ir da porta de trás (0, %d) até o lado l = 0, sem diagonal nem encostar' % (data.link_size.y / 2))
	var list: Variant = raw.get("molds")
	if not (list is Array) or list.is_empty():
		return _fail('"molds" vazio')
	for mold: Variant in list:
		if not (mold is Dictionary) or not SimMap._is_integer(mold.get("weight")) or int(mold["weight"]) < 1:
			return _fail('molde sem "weight" inteiro >= 1')
		var cells := _expand(mold.get("points"), square)
		var id := str(mold.get("id", ""))
		if id.is_empty() or id.contains(":") or id.contains("+") or id.ends_with(MIRROR):
			return _fail('molde com "id" inválido')
		if cells.is_empty() or cells[0] != Vector2i(0, c) or cells[cells.size() - 1] != Vector2i(s - 1, c):
			return _fail('molde "%s" precisa ir de (0, %d) a (%d, %d), sem diagonal nem encostar' % [id, c, s - 1, c])
		data.molds.append({"id": id, "weight": int(mold["weight"]), "cells": cells})
	return data
