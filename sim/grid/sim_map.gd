class_name SimMap
extends RefCounted
## Mapa em grade: casas, caminho fixo, entrada e núcleo (porte de `GridMap` em `map.ts`).
## (Nome `SimMap` porque `GridMap` já é uma classe 3D do Godot.)
##
## O mapa vem de dados (`data/map.json`). O caminho é descrito por pontos de
## virada: o primeiro é a entrada e o último é o núcleo. Cada trecho entre dois
## pontos é reto (horizontal ou vertical) e vira uma sequência de casas.
## Uma casa é um `Vector2i` (x, y).

var id: String
var width: int
var height: int
## Todas as casas do caminho, em ordem, da entrada até o núcleo.
var path_cells: Array[Vector2i]
var entrance: Vector2i
## O núcleo ocupa 1 casa: a última do caminho.
var nexus: Vector2i

var _path_mask: PackedByteArray


func _init(p_id: String, p_width: int, p_height: int, p_path_cells: Array[Vector2i]) -> void:
	id = p_id
	width = p_width
	height = p_height
	path_cells = p_path_cells
	entrance = p_path_cells[0]
	nexus = p_path_cells[p_path_cells.size() - 1]
	_path_mask = PackedByteArray()
	_path_mask.resize(p_width * p_height)
	for cell in p_path_cells:
		_path_mask[index_of(cell)] = 1


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


## Índice linear da casa (`y * width + x`). Só vale para casas dentro da grade.
func index_of(cell: Vector2i) -> int:
	return cell.y * width + cell.x


## Entrada e núcleo contam como caminho.
func is_path(cell: Vector2i) -> bool:
	return is_inside(cell) and _path_mask[index_of(cell)] == 1


## Torres só vão em casas dentro da grade e fora do caminho.
func can_place_tower(cell: Vector2i) -> bool:
	return is_inside(cell) and _path_mask[index_of(cell)] == 0


## Valida os dados do mapa ({id, width, height, path: [{x, y}, ...]}) e expande os
## pontos de virada em casas. Dado inválido: push_error com a mensagem e devolve null.
static func load_map(data: Dictionary) -> SimMap:
	var w: Variant = data["width"]
	var h: Variant = data["height"]
	if not _is_integer(w) or not _is_integer(h) or int(w) <= 0 or int(h) <= 0:
		push_error("Mapa inválido: tamanho %sx%s" % [w, h])
		return null
	var cells := _expand_path(data["path"], int(w), int(h))
	if cells.is_empty():
		return null
	return SimMap.new(str(data["id"]), int(w), int(h), cells)


# JSON traz todo número como float; "inteiro" = sem parte fracionária (como Number.isInteger).
static func _is_integer(v: Variant) -> bool:
	if typeof(v) == TYPE_INT:
		return true
	return typeof(v) == TYPE_FLOAT and is_finite(v) and floorf(v) == v


static func _in_bounds(p: Dictionary, width: int, height: int) -> bool:
	return (
		_is_integer(p["x"]) and _is_integer(p["y"])
		and p["x"] >= 0 and p["y"] >= 0 and p["x"] < width and p["y"] < height
	)


## Devolve as casas do caminho, ou lista vazia (com push_error) se o caminho for inválido.
static func _expand_path(waypoints: Array, width: int, height: int) -> Array[Vector2i]:
	var none: Array[Vector2i] = []
	if waypoints.size() < 2:
		push_error("Mapa inválido: o caminho precisa de pelo menos 2 pontos")
		return none
	for p: Dictionary in waypoints:
		if not _in_bounds(p, width, height):
			push_error("Mapa inválido: ponto (%s, %s) fora da grade" % [int(p["x"]), int(p["y"])])
			return none

	var first: Dictionary = waypoints[0]
	var cells: Array[Vector2i] = [Vector2i(int(first["x"]), int(first["y"]))]
	for i in range(1, waypoints.size()):
		var from := Vector2i(int(waypoints[i - 1]["x"]), int(waypoints[i - 1]["y"]))
		var to := Vector2i(int(waypoints[i]["x"]), int(waypoints[i]["y"]))
		var dx := signi(to.x - from.x)
		var dy := signi(to.y - from.y)
		if dx != 0 and dy != 0:
			push_error("Mapa inválido: trecho diagonal de (%d, %d) a (%d, %d)" % [from.x, from.y, to.x, to.y])
			return none
		if dx == 0 and dy == 0:
			push_error("Mapa inválido: trecho de tamanho zero em (%d, %d)" % [to.x, to.y])
			return none
		var cur := from
		while cur != to:
			cur += Vector2i(dx, dy)
			cells.append(cur)

	var seen := {}
	for cell in cells:
		var index := cell.y * width + cell.x
		if seen.has(index):
			push_error("Mapa inválido: o caminho passa duas vezes por (%d, %d)" % [cell.x, cell.y])
			return none
		seen[index] = true
	return cells
