class_name TowerMove
extends RefCounted
## Mover e trocar torres já posicionadas (T15). Fora da onda é grátis: a torre vai para a casa
## livre pedida, ou troca de lugar com a torre que estiver nela. Com qualquer onda na lista
## ativa (`waves.active`), inclusive empilhada ou já limpa esperando a anterior fechar, as
## torres ficam travadas (porte de `move.ts`).
##
## A torre é o mesmo objeto: leva junto id, estrela, `invested`, recarga, contadores, cargas,
## trava de ativação e último efeito. A ordem em `state.towers` (ordem de disparo) não muda.
## Os bônus de classe e a vizinhança dos gatilhos são recalculados a cada tick.


## As torres posicionadas estão travadas: há onda na lista ativa.
static func towers_locked(state: Object) -> bool:
	return not state.waves.active.is_empty()


static func _refuse(ctx: TickContext, tower_id: int, reason: String) -> bool:
	ctx.emit({"type": "moveRefused", "tick": ctx.state.tick, "towerId": tower_id, "reason": reason})
	return false


## Move a torre para a casa (troca, se houver outra torre nela). Torre inexistente ou a própria
## casa: nada acontece, sem evento. Torres travadas ou casa inválida (fora do mapa, caminho,
## núcleo): emite `moveRefused`.
static func move_tower(ctx: TickContext, map: SimMap, tower_id: int, cell: Vector2i) -> bool:
	var state := ctx.state
	var tower: Tower = null
	for t: Tower in state.towers:
		if t.id == tower_id:
			tower = t
			break
	if tower == null or (tower.x == cell.x and tower.y == cell.y):
		return false
	if towers_locked(state):
		return _refuse(ctx, tower_id, "locked")
	if not map.can_place_tower(cell):
		return _refuse(ctx, tower_id, "invalid")

	var other: Tower = null
	for t: Tower in state.towers:
		if t.x == cell.x and t.y == cell.y:
			other = t
			break
	var from_x := tower.x
	var from_y := tower.y
	if other != null:
		other.x = from_x
		other.y = from_y
	tower.x = cell.x
	tower.y = cell.y
	ctx.emit({
		"type": "towerMoved",
		"tick": state.tick,
		"towerId": tower_id,
		"fromX": from_x,
		"fromY": from_y,
		"x": cell.x,
		"y": cell.y,
		"swappedWithId": other.id if other != null else null,
	})
	return true
