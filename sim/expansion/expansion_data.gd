class_name ExpansionData
extends RefCounted
## Mapa que cresce com moldes (Mini-GDD, Sistema 7), lido de `data/expansion.json`.
##
## O mapa é feito de pedaços quadrados de `pieceSize` casas (ímpar: o centro fica no meio exato).
## Em coordenadas locais de um pedaço, d = profundidade a partir da borda por onde a linha entrou e
## l = lateral; a porta de entrada é (0, c) e o centro é (c, c), com c = pieceSize / 2.
## - A base é fixa (`base`): um zigue-zague do núcleo até o centro.
## - Cada pedaço tem um molde de entrada (da porta até o centro, na metade de perto).
## - O centro do último pedaço de cada linha é a entrada dos inimigos; a metade de longe dele fica
##   reservada (sem construir) até a próxima parede.
## - A parede escolhe a direção: um molde de saída liga o centro à porta daquele lado (frente ou
##   lados) e o pedaço novo abre do outro lado da porta, com o seu molde de entrada.
## Todas as portas ficam no meio da borda, então qualquer molde encaixa com qualquer outro. Os moldes
## são sorteados (por peso) quando a parede cai; a escolha mostra já o molde sorteado de cada direção.
## O mapa só cresce para a direita, para cima e para baixo; nas `forwardOnlyWalls` primeiras paredes,
## só para a frente. Dividir (só no debug) abre duas direções de uma vez: a segunda vira uma linha
## nova, com entrada própria, que se junta à principal no centro daquele pedaço.
##
## Id de uma abertura: "linha:direção:molde de saída:molde de entrada" (moldes espelhados com "~"),
## por exemplo "0:cima:gancho~:u-largo". Dividir junta duas partes com "+"; a segunda usa a linha "n"
## (nova): "0:direita:s:reto+n:cima:reto:u-pequeno~".

## Uma abertura possível (ou já feita): os pedaços que abrem e o caminho novo.
class Opening:
	extends RefCounted
	var id: String
	var name: String
	## Casas dos pedaços novos (todas, inclusive as do caminho novo).
	var cells: Array[Vector2i] = []
	## Casas novas de caminho (as de todas as partes), para mostrar e contar.
	var path_cells: Array[Vector2i] = []
	## Traz uma entrada nova de inimigos (dividir).
	var new_entrance := false
	## Linha que muda: 0 = a principal, 1 = a segunda... (= índice da entrada no `SimMap`).
	var line := 0
	## Partes, na ordem: {"line": índice da linha (-1 = nova), "cells": casas novas da entrada para
	## dentro, "join": casa da linha principal onde a linha nova se junta}.
	var steps: Array[Dictionary] = []

## A ponta de uma linha: o último pedaço dela e a direção em que ela entrou nele.
class Line:
	extends RefCounted
	var piece: Vector2i
	var dir: String

## Pedaços e linhas abertos por uma lista de aberturas.
class Layout:
	extends RefCounted
	## Pedaço -> ordem em que abriu (0 = a base).
	var pieces := {}
	var lines: Array[Line] = []
	var walls := 0

const RIGHT := "direita"
const UP := "cima"
const DOWN := "baixo"
const LEFT := "esquerda"
## Direções para onde o mapa cresce, na ordem das opções (nunca para a esquerda, para o lado do núcleo).
const GROW_DIRS: Array[String] = [RIGHT, UP, DOWN]
const STEP := {RIGHT: Vector2i(1, 0), UP: Vector2i(0, -1), DOWN: Vector2i(0, 1), LEFT: Vector2i(-1, 0)}
const NEW_LINE := "n"
const MIRROR := "~"
const MOLD_KINDS: Array[String] = ["entry", "forward", "side"]
## Tentativas de sortear moldes de saída que não se encostam ao dividir.
const SPLIT_TRIES := 12

var enabled := false
var map_id := ""
var piece_size := 11
## Ondas que derrubam uma parede ao fechar.
var after_waves: Array[int] = []
var forward_only_walls := 2
## Tempo da escolha; no zero, a simulação escolhe sozinha.
var choose_seconds := 20.0
## Pontos de virada do caminho da base (locais), do núcleo até o centro.
var base: Array[Vector2i] = []
## "entry" / "forward" / "side" -> [{"id", "weight", "cells": Array[Vector2i] locais, já expandidas}].
var molds := {}
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


## Quantos pedaços o mapa pode subir ou descer a partir da base.
func vertical_pieces() -> int:
	return maxi(0, max_walls() - forward_only_walls)


func base_piece() -> Vector2i:
	return Vector2i(0, vertical_pieces())


func map_width() -> int:
	return piece_size * (1 + max_walls())


func map_height() -> int:
	return piece_size * (1 + 2 * vertical_pieces())


func _piece_inside(piece: Vector2i) -> bool:
	return piece.x >= 0 and piece.y >= 0 and piece.x <= max_walls() and piece.y <= 2 * vertical_pieces()


## Casas do pedaço.
func piece_cells(piece: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(piece.y * piece_size, (piece.y + 1) * piece_size):
		for x in range(piece.x * piece_size, (piece.x + 1) * piece_size):
			out.append(Vector2i(x, y))
	return out


## Casa local (d, l) do pedaço em que a linha entrou pela direção `dir`, na grade do mapa.
func to_global(piece: Vector2i, dir: String, local: Vector2i) -> Vector2i:
	var s := piece_size
	var o := piece * s
	match dir:
		RIGHT:
			return o + Vector2i(local.x, local.y)
		LEFT:
			return o + Vector2i(s - 1 - local.x, local.y)
		DOWN:
			return o + Vector2i(local.y, local.x)
		_:
			return o + Vector2i(local.y, s - 1 - local.x)


func _to_global_all(piece: Vector2i, dir: String, cells: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell in cells:
		out.append(to_global(piece, dir, cell))
	return out


## Direção (global) de quem sai do centro pela porta lateral (c, `l`), com l = 0 ou a última.
func side_dir(piece: Vector2i, dir: String, l: int) -> String:
	var delta := to_global(piece, dir, Vector2i(center(), l)) - to_global(piece, dir, Vector2i(center(), center()))
	var unit := Vector2i(signi(delta.x), signi(delta.y))
	for key: String in STEP:
		if STEP[key] == unit:
			return key
	return ""


## Mapa novo, só com o pedaço da base aberto. Cada run precisa do seu: o mapa muda quando uma parede cai.
func build_map() -> SimMap:
	var points: Array = []
	for i in range(base.size() - 1, -1, -1):
		var cell := to_global(base_piece(), RIGHT, base[i])
		points.append({"x": cell.x, "y": cell.y})
	var map := SimMap.load_map({"id": map_id, "width": map_width(), "height": map_height(), "path": points})
	if map == null:
		return null
	map.set_start_cells(piece_cells(base_piece()))
	map.set_reserved(reserved_cells([]))
	return map


## Pedaços e linhas depois das aberturas `actions` (na ordem). Ids inválidos são ignorados.
func layout(actions: Array) -> Layout:
	var out := Layout.new()
	out.pieces[base_piece()] = 0
	var main := Line.new()
	main.piece = base_piece()
	main.dir = RIGHT
	out.lines.append(main)
	for id: String in actions:
		var parts := _parse(id)
		if parts.is_empty() or int(parts[0]["line"]) >= out.lines.size():
			continue
		out.walls += 1
		var from: Line = out.lines[int(parts[0]["line"])]
		var origin := from.piece
		for part: Dictionary in parts:
			var piece: Vector2i = origin + STEP[part["dir"]]
			out.pieces[piece] = out.walls
			var line := Line.new()
			line.piece = piece
			line.dir = part["dir"]
			if part["line"] == -1:
				out.lines.append(line)
			else:
				out.lines[int(part["line"])] = line
	return out


## Partes do id: [{"line": int (-1 = nova), "dir", "exit": [molde, espelho], "entry": [molde, espelho]}],
## ou [] se o formato for inválido.
func _parse(id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var texts := id.split("+")
	if texts.size() > 2:
		return out
	for i in texts.size():
		var f := texts[i].split(":")
		if f.size() != 4 or not STEP.has(f[1]):
			return [] as Array[Dictionary]
		var line := -1
		if i == 0 and f[0].is_valid_int() and int(f[0]) >= 0:
			line = int(f[0])
		elif not (i == 1 and f[0] == NEW_LINE):
			return [] as Array[Dictionary]
		out.append({"line": line, "dir": f[1], "exit": _mold_ref(f[2]), "entry": _mold_ref(f[3])})
	return out


static func _mold_ref(text: String) -> Array:
	return [text.trim_suffix(MIRROR), text.ends_with(MIRROR)]


static func _ref_text(id: String, mirrored: bool) -> String:
	return id + (MIRROR if mirrored else "")


## Casas locais do molde (espelhado se pedido), ou [] se não existe.
func _mold_cells(kind: String, ref: Array) -> Array[Vector2i]:
	for mold: Dictionary in molds.get(kind, []):
		if mold["id"] == ref[0]:
			var cells: Array[Vector2i] = mold["cells"]
			return _mirror(cells) if ref[1] else cells.duplicate()
	return [] as Array[Vector2i]


func _mirror(cells: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell in cells:
		out.append(Vector2i(cell.x, piece_size - 1 - cell.y))
	return out


## Direções para onde a linha `index` pode crescer (pedaço livre e dentro do mapa). Nas primeiras
## paredes, só para a frente (a não ser com `any_dir`, para dividir no debug).
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
		var piece: Vector2i = line.piece + STEP[dir]
		if _piece_inside(piece) and not lay.pieces.has(piece):
			out.append(dir)
	return out


static func _back(dir: String) -> String:
	return {RIGHT: LEFT, LEFT: RIGHT, UP: DOWN, DOWN: UP}[dir]


## A abertura `id` depois de `actions`, ou null se não der (formato, molde, direção ou pedaço).
func opening(actions: Array, id: String) -> Opening:
	var parts := _parse(id)
	if parts.is_empty():
		return null
	var lay := layout(actions)
	var index := int(parts[0]["line"])
	if index < 0 or index >= lay.lines.size():
		return null
	var split := parts.size() == 2
	var dirs := free_dirs(lay, index, split)
	if split and (index != 0 or parts[0]["dir"] == parts[1]["dir"]):
		return null
	var line: Line = lay.lines[index]
	var o := Opening.new()
	o.id = id
	o.name = option_name(id)
	o.line = index
	o.new_entrance = split
	var c := center()
	var exits: Array = []
	for part: Dictionary in parts:
		var dir: String = part["dir"]
		if not dirs.has(dir):
			return null
		var forward: bool = dir == line.dir
		var exit_local := _mold_cells("forward" if forward else "side", part["exit"])
		var entry_local := _mold_cells("entry", part["entry"])
		if exit_local.is_empty() or entry_local.is_empty():
			return null
		var door := exit_local[exit_local.size() - 1]
		if not forward and side_dir(line.piece, line.dir, door.y) != dir:
			return null
		var exit_cells := _to_global_all(line.piece, line.dir, exit_local)
		var piece: Vector2i = line.piece + STEP[dir]
		var entry_cells := _to_global_all(piece, dir, entry_local)
		var cells: Array[Vector2i] = []
		for i in range(entry_cells.size() - 1, -1, -1):
			cells.append(entry_cells[i])
		for i in range(exit_cells.size() - 1, 0, -1):
			cells.append(exit_cells[i])
		exits.append(exit_cells.slice(1))
		o.cells.append_array(piece_cells(piece))
		o.path_cells.append_array(cells)
		o.steps.append({"line": int(part["line"]), "cells": cells, "join": exit_cells[0]})
	if split and _touch(exits[0], exits[1]):
		return null
	return o


## Os dois caminhos se encostam (ou se cruzam)?
static func _touch(a: Array, b: Array) -> bool:
	var set_b := {}
	for cell: Vector2i in b:
		set_b[cell] = true
	for cell: Vector2i in a:
		if set_b.has(cell):
			return true
		for n in [cell + Vector2i.RIGHT, cell + Vector2i.LEFT, cell + Vector2i.UP, cell + Vector2i.DOWN]:
			if set_b.has(n):
				return true
	return false


## Sorteia as opções da próxima parede: uma por linha e direção livre, cada uma com os moldes já
## sorteados (vazia = acabaram as paredes).
func roll_options(actions: Array, rng: Rng) -> Array[String]:
	var out: Array[String] = []
	var lay := layout(actions)
	for index in lay.lines.size():
		for dir in free_dirs(lay, index):
			out.append(_roll_part(str(index), lay.lines[index], dir, rng))
	return out


## Sorteia as opções de dividir a linha principal (debug): cada par de direções livres, com moldes de
## saída que não se encostam (no último caso, os retos).
func roll_split_options(actions: Array, rng: Rng) -> Array[String]:
	var out: Array[String] = []
	var lay := layout(actions)
	var dirs := free_dirs(lay, 0, true)
	var line: Line = lay.lines[0]
	for i in dirs.size():
		for j in range(i + 1, dirs.size()):
			var found := ""
			for t in SPLIT_TRIES:
				var id := "%s+%s" % [_roll_part("0", line, dirs[i], rng), _roll_part(NEW_LINE, line, dirs[j], rng)]
				if opening(actions, id) != null:
					found = id
					break
			if found == "":
				found = "0:%s:%s:%s+%s:%s:%s:%s" % [dirs[i], _straight(line, dirs[i]), _straight_entry(), NEW_LINE,
						dirs[j], _straight(line, dirs[j]), _straight_entry()]
			if opening(actions, found) != null:
				out.append(found)
	return out


func _roll_part(line_tag: String, line: Line, dir: String, rng: Rng) -> String:
	var exit_ref: String
	if dir == line.dir:
		exit_ref = _roll_mold("forward", rng, -1)
	else:
		var mirrored := side_dir(line.piece, line.dir, 0) != dir
		exit_ref = _roll_mold("side", rng, 1 if mirrored else 0)
	return "%s:%s:%s:%s" % [line_tag, dir, exit_ref, _roll_mold("entry", rng, -1)]


## Molde sorteado por peso; `mirror` -1 = sorteia o espelho (se o molde não for simétrico), 0/1 = fixo.
func _roll_mold(kind: String, rng: Rng, mirror: int) -> String:
	var list: Array = molds[kind]
	var total := 0
	for mold: Dictionary in list:
		total += int(mold["weight"])
	var r := rng.next_int(0, total - 1)
	var pick: Dictionary = list[list.size() - 1]
	for mold: Dictionary in list:
		r -= int(mold["weight"])
		if r < 0:
			pick = mold
			break
	var mirrored := mirror == 1
	if mirror == -1:
		var cells: Array[Vector2i] = pick["cells"]
		mirrored = _mirror(cells) != cells and rng.next_int(0, 1) == 1
	return _ref_text(pick["id"], mirrored)


func _straight(line: Line, dir: String) -> String:
	if dir == line.dir:
		return "reto"
	return _ref_text("reto", side_dir(line.piece, line.dir, 0) != dir)


func _straight_entry() -> String:
	return "reto"


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


## Casas sem construir depois de `actions`: enquanto houver parede, a metade de longe do último pedaço de
## cada linha que ainda pode crescer (menos o centro, que é a entrada).
func reserved_cells(actions: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var lay := layout(actions)
	var c := center()
	for index in lay.lines.size():
		if free_dirs(lay, index, true).is_empty():
			continue
		var line: Line = lay.lines[index]
		for d in range(c, piece_size):
			for l in piece_size:
				if d != c or l != c:
					out.append(to_global(line.piece, line.dir, Vector2i(d, l)))
	return out


static func _fail(message: String) -> ExpansionData:
	push_error("Expansão inválida: %s" % message)
	return null


## Pontos de virada [[d, l], ...] expandidos em casas, ou [] se tiver diagonal, ponto repetido ou casa
## fora do pedaço.
static func _expand(points: Variant, size: int) -> Array[Vector2i]:
	var none: Array[Vector2i] = []
	if not (points is Array) or points.size() < 2:
		return none
	var out: Array[Vector2i] = []
	for p: Variant in points:
		if not (p is Array) or p.size() != 2 or not SimMap._is_integer(p[0]) or not SimMap._is_integer(p[1]):
			return none
		var cell := Vector2i(int(p[0]), int(p[1]))
		if cell.x < 0 or cell.y < 0 or cell.x >= size or cell.y >= size:
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
			if out.has(last):
				return none
			out.append(last)
	return out


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
	var base_cells := _expand(raw.get("base"), s)
	if base_cells.is_empty() or base_cells[base_cells.size() - 1] != Vector2i(c, c):
		return _fail('"base" precisa ir do núcleo até o centro do pedaço, sem diagonal')
	for p: Array in raw["base"]:
		data.base.append(Vector2i(int(p[0]), int(p[1])))
	var raw_molds: Variant = raw.get("molds")
	if not (raw_molds is Dictionary):
		return _fail('falta "molds"')
	var ends := {
		"entry": [Vector2i(0, c), Vector2i(c, c)],
		"forward": [Vector2i(c, c), Vector2i(s - 1, c)],
		"side": [Vector2i(c, c), Vector2i(c, 0)],
	}
	for kind in MOLD_KINDS:
		var list: Variant = raw_molds.get(kind)
		if not (list is Array) or list.is_empty():
			return _fail('"molds.%s" vazio' % kind)
		var parsed: Array = []
		for mold: Variant in list:
			if not (mold is Dictionary) or not SimMap._is_integer(mold.get("weight")) or int(mold["weight"]) < 1:
				return _fail('molde de "%s" sem "weight" inteiro >= 1' % kind)
			var cells := _expand(mold.get("points"), s)
			var id := str(mold.get("id", ""))
			if id.is_empty() or id.contains(":") or id.contains("+") or id.ends_with(MIRROR):
				return _fail('molde de "%s" com "id" inválido' % kind)
			if cells.is_empty() or cells[0] != ends[kind][0] or cells[cells.size() - 1] != ends[kind][1]:
				return _fail('molde "%s" de "%s" precisa ir de %s a %s, sem diagonal' % [id, kind, ends[kind][0], ends[kind][1]])
			parsed.append({"id": id, "weight": int(mold["weight"]), "cells": cells})
		data.molds[kind] = parsed
	return data
