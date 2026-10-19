class_name ClassState
extends RefCounted
## Parte do `RunState` que pertence às classes: para cada uma, as torres
## diferentes que contam e o nível de bônus ativo. Vai para o save.
##
## O sistema de classes (`ClassSystems`) recalcula isto no fim de cada tick.
## Como todo o resto do tick já leu o valor antigo, posicionar, vender ou
## fundir uma torre liga ou desliga o bônus no tick seguinte.

class ClassStatus:
	extends RefCounted
	## Níveis atingidos: 0 = sem bônus, 1 = primeiro nível dos dados, e assim por diante.
	var level := 0
	## Tipos de torre diferentes no mapa que têm a classe, em ordem alfabética.
	var members: Array[String] = []


## Por id de classe, na ordem do `classes.json`: Dictionary id -> ClassStatus.
static func create(data: ClassData) -> Dictionary:
	var state := {}
	for id in data.ids:
		state[id] = ClassStatus.new()
	return state
