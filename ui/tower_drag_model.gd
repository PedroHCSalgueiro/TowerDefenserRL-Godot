class_name TowerDragModel
extends RefCounted
## Arrastar torres do mapa (T15), sem nós: só decide o que cada gesto vira. O clique continua
## selecionando; só um arrasto acima do limiar move. Soltar numa casa válida vira o comando
## `moveTower` (a simulação faz a troca, se a casa tiver outra torre); numa casa inválida ou na
## própria casa, o arrasto é cancelado sem comando (porte de `towerDragModel.ts`).
##
## Com onda ativa, passar do limiar não começa o arrasto: devolve "locked" para a interface mostrar
## a trava. Pausado, ou com a run encerrada, nada começa e o arrasto em curso é cancelado em
## silêncio. Chamar uma onda no meio do arrasto também cancela.

var _has_press := false
var _tower_id := 0
var _tower_type := ""
var _start := Vector2.ZERO
## Passou do limiar com as torres livres: é um arrasto.
var _dragging := false


## A casa serve para soltar: livre ou com outra torre (troca). Mesma regra da simulação.
static func can_drop_at(map: SimMap, cell: Variant) -> bool:
	return cell != null and map.can_place_tower(cell)


## Torre sendo arrastada ({"towerId", "towerType"}) ou {} (nenhuma, inclusive durante um clique
## ainda curto).
func dragging() -> Dictionary:
	return {"towerId": _tower_id, "towerType": _tower_type} if _has_press and _dragging else {}


## Botão apertado sobre uma torre. Pausado ou com a run encerrada, não faz nada.
func begin(state: Object, paused: bool, tower_id: int, tower_type: String, pos: Vector2) -> bool:
	_has_press = false
	if paused or state.status != "playing":
		return false
	_has_press = true
	_tower_id = tower_id
	_tower_type = tower_type
	_start = pos
	_dragging = false
	return true


## Mouse andou com o botão apertado: "none" | "started" | "locked".
func pointer_move(state: Object, pos: Vector2, threshold_px: float) -> String:
	if not _has_press or _dragging:
		return "none"
	if pos.distance_to(_start) <= threshold_px:
		return "none"
	if TowerMove.towers_locked(state):
		_has_press = false
		return "locked"
	_dragging = true
	return "started"


## Botão solto sobre a casa `cell` (null = fora do mapa). Devolve o comando de mover ({} se clique
## curto, casa inválida ou própria casa).
func release(state: Object, map: SimMap, cell: Variant) -> Dictionary:
	var was_dragging := _has_press and _dragging
	var id := _tower_id
	_has_press = false
	_dragging = false
	if not was_dragging or cell == null or not can_drop_at(map, cell):
		return {}
	var tower: Tower = null
	for t: Tower in state.towers:
		if t.id == id:
			tower = t
			break
	if tower == null or (tower.x == cell.x and tower.y == cell.y):
		return {}
	return {"type": "moveTower", "towerId": id, "x": cell.x, "y": cell.y}


## Chame a cada quadro: cancela em silêncio se pausou, se uma onda foi chamada, se a run acabou ou
## se a torre saiu do mapa. Devolve true se cancelou.
func update(state: Object, paused: bool) -> bool:
	if not _has_press:
		return false
	var gone := true
	for t: Tower in state.towers:
		if t.id == _tower_id:
			gone = false
			break
	if paused or state.status != "playing" or gone or (_dragging and TowerMove.towers_locked(state)):
		_has_press = false
		_dragging = false
		return true
	return false


func cancel() -> void:
	_has_press = false
	_dragging = false
