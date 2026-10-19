class_name Neighbors
extends RefCounted
## Vizinhança de casas na grade (porte de `neighbors.ts`).
##
## Padrão: 4 vizinhas (lados). Com 8, entram as diagonais (bônus da Arcana).
## A ordem é fixa, para manter a simulação determinística.

## Em coordenadas da grade: y−1, x+1, y+1, x−1.
const ORTHOGONAL: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const DIAGONAL: Array[Vector2i] = [Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]


## Vizinhas dentro da grade, na ordem fixa: lados primeiro, depois diagonais.
static func of(map: SimMap, cell: Vector2i, neighborhood: int = 4) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in ORTHOGONAL:
		var next := cell + offset
		if map.is_inside(next):
			result.append(next)
	if neighborhood == 8:
		for offset in DIAGONAL:
			var next := cell + offset
			if map.is_inside(next):
				result.append(next)
	return result
