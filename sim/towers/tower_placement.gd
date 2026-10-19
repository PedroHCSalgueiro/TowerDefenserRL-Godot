class_name TowerPlacement
extends RefCounted
## Torres no mapa e a regra de posicionamento. É chamado pela ação `placeTower` e pelo spawn
## em massa do debug, sempre dentro de um tick (porte de `placement.ts`).


## Posiciona uma torre do tipo pedido. A casa precisa estar dentro do mapa, fora do caminho e
## sem torre, e o tipo precisa existir. Se não der, nada muda (nem um id é gasto) e devolve
## null; se der, emite `towerPlaced`. `star` só é diferente de 1 no spawn do debug; é preso ao
## máximo do tipo.
static func place_tower(ctx: TickContext, map: SimMap, data: TowerData, tower_type: String,
		cell: Vector2i, star: int = 1) -> Tower:
	var state := ctx.state
	if not data.has_type(tower_type) or not map.can_place_tower(cell):
		return null
	for t: Tower in state.towers:
		if t.x == cell.x and t.y == cell.y:
			return null

	var tower := Tower.new(ctx.allocate_id(), tower_type, cell,
			Stars.clamp_star(data.get_type(tower_type), star))
	state.towers.append(tower)
	ctx.emit({
		"type": "towerPlaced",
		"tick": state.tick,
		"towerId": tower.id,
		"towerType": tower_type,
		"x": tower.x,
		"y": tower.y,
	})
	return tower
