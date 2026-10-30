class_name Route
extends RefCounted
## Rota contínua que os inimigos percorrem, medida em casas (porte de `route.ts`).
##
## É uma linha poligonal pelos centros das casas: a rota terrestre passa por
## todas as casas do caminho; a aérea é um trecho reto da entrada ao núcleo.
## A posição de um inimigo é só a distância percorrida desde o início.
## Tudo em float64 (PackedFloat64Array), nunca Vector2.

## Comprimento total, em casas.
var length: float = 0.0
## Falso se a rota foi recusada (menos de 2 pontos ou ponto repetido; push_error já emitido).
var valid := true
var _xs := PackedFloat64Array()
var _ys := PackedFloat64Array()
## Distância acumulada até cada ponto; `_cumulative[0] = 0`.
var _cumulative := PackedFloat64Array()


func _init(points: Array[Vector2i]) -> void:
	if points.size() < 2:
		push_error("Rota inválida: precisa de pelo menos 2 pontos")
		valid = false
		return
	var n := points.size()
	_xs.resize(n)
	_ys.resize(n)
	_cumulative.resize(n)
	for i in n:
		var p := points[i]
		_xs[i] = float(p.x)
		_ys[i] = float(p.y)
		if i > 0:
			var dx := float(p.x) - _xs[i - 1]
			var dy := float(p.y) - _ys[i - 1]
			var segment := SimMath.hypot(dx, dy)  # igual ao Math.hypot do V8, bit a bit
			if segment == 0.0:
				push_error("Rota inválida: ponto repetido em (%d, %d)" % [p.x, p.y])
				valid = false
				return
			_cumulative[i] = _cumulative[i - 1] + segment
	length = _cumulative[n - 1]


## Escreve em `out` o ponto a `distance` casas do início, sem alocar.
## Distâncias fora de [0, length] ficam presas nas pontas.
func sample_into(distance: float, out: MutablePoint) -> void:
	var last := _cumulative.size() - 1
	if distance <= 0.0:
		out.x = _xs[0]
		out.y = _ys[0]
		return
	if distance >= length:
		out.x = _xs[last]
		out.y = _ys[last]
		return
	# Busca binária pelo trecho [lo, lo + 1] que contém `distance`.
	var lo := 0
	var hi := last
	while hi - lo > 1:
		var mid := (lo + hi) >> 1
		if _cumulative[mid] <= distance:
			lo = mid
		else:
			hi = mid
	var start := _cumulative[lo]
	var t := (distance - start) / (_cumulative[hi] - start)
	out.x = _xs[lo] + (_xs[hi] - _xs[lo]) * t
	out.y = _ys[lo] + (_ys[hi] - _ys[lo]) * t


## Segmento que contém a distância (maior índice com distância acumulada <= distance), por busca binária.
func find_segment(distance: float) -> int:
	var last := _cumulative.size() - 1
	if distance <= 0.0:
		return 0
	if distance >= length:
		return maxi(last - 1, 0)
	var lo := 0
	var hi := last
	while hi - lo > 1:
		var mid := (lo + hi) >> 1
		if _cumulative[mid] <= distance:
			lo = mid
		else:
			hi = mid
	return lo


## Como sample_into, mas parte do segmento seg da amostra anterior (a distância só cresce):
## evita a busca binária a cada tick. Devolve o segmento novo. O resultado é idêntico ao da busca.
func sample_cursor(distance: float, out: MutablePoint, seg: int) -> int:
	var last := _cumulative.size() - 1
	if distance <= 0.0:
		out.x = _xs[0]
		out.y = _ys[0]
		return 0
	if distance >= length:
		out.x = _xs[last]
		out.y = _ys[last]
		return maxi(last - 1, 0)
	var lo := seg
	while lo + 1 < last and _cumulative[lo + 1] <= distance:
		lo += 1
	var hi := lo + 1
	var start := _cumulative[lo]
	var t := (distance - start) / (_cumulative[hi] - start)
	out.x = _xs[lo] + (_xs[hi] - _xs[lo]) * t
	out.y = _ys[lo] + (_ys[hi] - _ys[lo]) * t
	return lo


## Rotas de um mapa: {"ground": Route, "air": Route}, mais as das entradas abertas por paredes
## ("ground:1", "air:1", ...; ver `key_for`).
static func build_routes(map: SimMap) -> Dictionary:
	var air_points: Array[Vector2i] = [map.entrance, map.nexus]
	var routes := {
		"ground": Route.new(map.path_cells),
		"air": Route.new(air_points),
	}
	add_entrance_routes(map, routes)
	return routes


## Põe em `routes` as rotas das entradas do mapa que ainda não estão lá (parede aberta no meio da run).
static func add_entrance_routes(map: SimMap, routes: Dictionary) -> void:
	for index in range(1, map.entrance_count()):
		if not routes.has(key_for("ground", index)):
			set_entrance_routes(map, routes, index)


## (Re)faz as rotas da entrada `index`. A aérea das entradas abertas por paredes voa reto até a casa
## da junção e de lá reto até o núcleo: esticar a entrada só aumenta o primeiro trecho.
static func set_entrance_routes(map: SimMap, routes: Dictionary, index: int) -> void:
	if index == 0:
		var main_air: Array[Vector2i] = [map.entrance, map.nexus]
		routes["ground"] = Route.new(map.path_cells)
		routes["air"] = Route.new(main_air)
		return
	var join: Vector2i = map.path_cells[int(map.extra_entrances[index - 1]["join"])]
	var air_points: Array[Vector2i] = [map.entrance_cell(index)]
	if join != map.nexus:
		air_points.append(join)
	air_points.append(map.nexus)
	routes[key_for("ground", index)] = Route.new(map.entrance_path(index))
	routes[key_for("air", index)] = Route.new(air_points)


## Chave da rota de um movimento ("ground" ou "air") na entrada `entrance` (0 = a principal).
static func key_for(movement: String, entrance: int) -> String:
	return movement if entrance == 0 else "%s:%d" % [movement, entrance]
