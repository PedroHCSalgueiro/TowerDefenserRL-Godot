class_name SpatialIndex
extends RefCounted
## Índice espacial dos inimigos: grade uniforme (hash espacial) reconstruída
## uma vez por tick, para achar inimigos no alcance sem testar todos
## (porte de `spatialIndex.ts`).
##
## A reconstrução é preguiçosa: a primeira consulta de cada tick monta o
## índice com as posições daquele momento. Por isso toda consulta precisa
## acontecer depois do movimento. Inimigos que morrem depois da montagem são
## ignorados (`active == false`) e saem da célula na próxima consulta que
## passar por ela (compactação que mantém a ordem). Nenhum inimigo nasce
## depois do movimento, então não há slot reaproveitado no meio do tick.
##
## O índice é derivado do estado e não entra no save. As células cobrem só a
## área ocupada pelos inimigos (limites recalculados a cada montagem).
##
## `state` das consultas: objeto com `tick` e `enemies` (EnemyPool).

var _cell_size: float
var _built_for: Object = null
var _built_tick := -1

var _min_x := 0.0
var _min_y := 0.0
var _cols := 0
var _rows := 0
## Início de cada célula em `_items`; a célula `c` começa em `_cell_start[c]`.
var _cell_start := PackedInt32Array([0])
## Fim (exclusivo) dos itens ainda não compactados da célula `c`.
var _cell_end := PackedInt32Array()
var _cursor := PackedInt32Array()
## Slots dos inimigos, agrupados por célula.
var _items := PackedInt32Array()
## Célula de cada slot na última montagem.
var _slot_cell := PackedInt32Array()
## Notas dos melhores de `find_best_n`, reaproveitado entre chamadas.
var _best_scores: Array[float] = []


func _init(cell_size: float) -> void:
	if not (cell_size > 0.0):
		push_error("SpatialIndex: tamanho de célula inválido (%s)" % cell_size)
		cell_size = 1.0
	_cell_size = cell_size


## Inimigo ativo mais próximo de (x, y) com distância ≤ `range_` (a borda conta).
## Empate na distância: vence o menor id. null se não houver.
## `skip` (Callable(enemy) -> bool, opcional) descarta candidatos.
func find_nearest(state: Object, x: float, y: float, range_: float, skip: Callable = Callable()) -> Enemy:
	_ensure(state)
	if _cols == 0:
		return null

	var slots: Array[Enemy] = state.enemies.slots
	var range_sq := range_ * range_
	var x0 := _col(x - range_)
	var x1 := _col(x + range_)
	var y0 := _row(y - range_)
	var y1 := _row(y + range_)

	var best: Enemy = null
	var best_sq := INF
	var has_skip := skip.is_valid()
	for cy in range(y0, y1 + 1):
		var row_base := cy * _cols
		for cx in range(x0, x1 + 1):
			var cell := row_base + cx
			var end := _compact(cell, slots)
			for i in range(_cell_start[cell], end):
				var enemy := slots[_items[i]]
				var dx := enemy.x - x
				var dy := enemy.y - y
				var dist_sq := dx * dx + dy * dy
				if dist_sq > range_sq:
					continue
				if has_skip and skip.call(enemy):
					continue
				if dist_sq < best_sq or (dist_sq == best_sq and best != null and enemy.id < best.id):
					best = enemy
					best_sq = dist_sq
	return best


## Inimigo ativo com distância ≤ `range_` de (x, y) que tem a menor nota
## (`score`: Callable(enemy, x, y) -> float). Empate na nota: vence o menor id.
func find_best(state: Object, x: float, y: float, range_: float, score: Callable) -> Enemy:
	var best: Enemy = null
	var best_score := INF
	_ensure(state)
	if _cols == 0:
		return null
	for enemy in _in_range(state, x, y, range_):
		var s: float = score.call(enemy, x, y)
		if best == null or s < best_score or (s == best_score and enemy.id < best.id):
			best = enemy
			best_score = s
	return best


## Os `count` melhores inimigos dentro do alcance, do melhor para o pior (mesma nota
## e desempate de `find_best`). `out` é esvaziado e preenchido (menos de `count` se
## não houver tantos). Devolve `out`.
func find_best_n(state: Object, x: float, y: float, range_: float, score: Callable,
		count: int, out: Array) -> Array:
	out.clear()
	if count <= 0:
		return out
	_best_scores.clear()
	_ensure(state)
	if _cols == 0:
		return out
	for enemy in _in_range(state, x, y, range_):
		var s: float = score.call(enemy, x, y)
		var at := out.size()
		while at > 0:
			var prev: Enemy = out[at - 1]
			var prev_score := _best_scores[at - 1]
			if prev_score < s or (prev_score == s and prev.id < enemy.id):
				break
			at -= 1
		if at >= count:
			continue
		out.insert(at, enemy)
		_best_scores.insert(at, s)
		if out.size() > count:
			out.pop_back()
			_best_scores.pop_back()
	return out


## Acrescenta em `out` os inimigos ativos com distância ≤ `range_` de (x, y),
## em ordem de célula (quem precisa de uma ordem fixa ordena depois). Devolve `out`.
func collect_in_range(state: Object, x: float, y: float, range_: float, out: Array) -> Array:
	_ensure(state)
	if _cols == 0:
		return out
	out.append_array(_in_range(state, x, y, range_))
	return out


## Inimigos ativos no alcance, em ordem de célula (a mesma varredura de todas as consultas).
func _in_range(state: Object, x: float, y: float, range_: float) -> Array[Enemy]:
	var found: Array[Enemy] = []
	var slots: Array[Enemy] = state.enemies.slots
	var range_sq := range_ * range_
	var x0 := _col(x - range_)
	var x1 := _col(x + range_)
	var y0 := _row(y - range_)
	var y1 := _row(y + range_)
	for cy in range(y0, y1 + 1):
		var row_base := cy * _cols
		for cx in range(x0, x1 + 1):
			var cell := row_base + cx
			var end := _compact(cell, slots)
			for i in range(_cell_start[cell], end):
				var enemy := slots[_items[i]]
				var dx := enemy.x - x
				var dy := enemy.y - y
				if dx * dx + dy * dy <= range_sq:
					found.append(enemy)
	return found


## Tira da célula os inimigos que morreram desde a montagem, mantendo a ordem dos
## vivos, e devolve o novo fim. Quem chama só vê inimigos ativos.
func _compact(cell: int, slots: Array[Enemy]) -> int:
	var end := _cell_end[cell]
	var write := _cell_start[cell]
	for read in range(write, end):
		var slot := _items[read]
		if not slots[slot].active:
			continue
		if write != read:
			_items[write] = slot
		write += 1
	_cell_end[cell] = write
	return write


## Força a montagem do índice com as posições atuais do pool.
func rebuild(pool: EnemyPool) -> void:
	var slots := pool.slots
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for enemy in slots:
		if not enemy.active:
			continue
		if enemy.x < min_x:
			min_x = enemy.x
		if enemy.x > max_x:
			max_x = enemy.x
		if enemy.y < min_y:
			min_y = enemy.y
		if enemy.y > max_y:
			max_y = enemy.y
	if min_x == INF:
		_cols = 0
		_rows = 0
		return

	_min_x = min_x
	_min_y = min_y
	_cols = floori((max_x - min_x) / _cell_size) + 1
	_rows = floori((max_y - min_y) / _cell_size) + 1
	var cells := _cols * _rows
	if _cell_start.size() < cells + 1:
		_cell_start.resize((cells + 1) * 2)
		_cell_end.resize((cells + 1) * 2)
		_cursor.resize((cells + 1) * 2)
	if _slot_cell.size() < slots.size():
		_slot_cell.resize(slots.size() * 2)
		_items.resize(slots.size() * 2)

	# Contagem por célula, soma acumulada e preenchimento (counting sort).
	for c in cells + 1:
		_cell_start[c] = 0
	for enemy in slots:
		if not enemy.active:
			continue
		var cell := _row(enemy.y) * _cols + _col(enemy.x)
		_slot_cell[enemy.slot] = cell
		_cell_start[cell + 1] += 1
	for c in cells:
		_cell_start[c + 1] += _cell_start[c]
	for c in cells:
		_cell_end[c] = _cell_start[c + 1]
		_cursor[c] = _cell_start[c]
	for enemy in slots:
		if not enemy.active:
			continue
		var cell := _slot_cell[enemy.slot]
		_items[_cursor[cell]] = enemy.slot
		_cursor[cell] += 1


func _ensure(state: Object) -> void:
	if _built_for == state and _built_tick == state.tick:
		return
	rebuild(state.enemies)
	_built_for = state
	_built_tick = state.tick


## Coluna da coordenada, presa à área indexada.
func _col(x: float) -> int:
	return _clamp_int(floori((x - _min_x) / _cell_size), _cols - 1)


func _row(y: float) -> int:
	return _clamp_int(floori((y - _min_y) / _cell_size), _rows - 1)


static func _clamp_int(value: int, max_value: int) -> int:
	return 0 if value < 0 else (max_value if value > max_value else value)
