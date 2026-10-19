class_name EnemyOrder
extends RefCounted
## Ordenação de listas de inimigos por id (a ordem determinística de dano em
## área e dos efeitos de gatilho). Os ids são únicos, então o resultado não
## depende de a ordenação ser estável.


static func _by_id(a: Enemy, b: Enemy) -> bool:
	return a.id < b.id


## Ordena `list` por id, no próprio array, e o devolve. Lista já em ordem fica como está.
static func sort_by_id(list: Array) -> Array:
	for i in range(1, list.size()):
		if list[i - 1].id > list[i].id:
			list.sort_custom(_by_id)
			break
	return list
