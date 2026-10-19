class_name EventBus
extends RefCounted
## Eventos emitidos pela simulação (porte de `events.ts`).
##
## Cada evento é um Dictionary com `type` (String) e `tick` (int) mais o payload,
## com as MESMAS chaves do Phaser (camelCase), ex.:
##   {"type": "enemySpawned", "tick": 3, "enemyId": 7, "enemyType": "common"}
## O catálogo completo de tipos e payloads está em `events.ts` do Phaser; os
## tipos são adicionados aqui conforme cada sistema é portado.
##
## Os eventos ficam num buffer durante os ticks. A renderização e a UI chamam
## `drain()` uma vez por quadro (que pode ter rodado vários ticks). Eventos são
## passageiros e não fazem parte do estado salvo.

var _buffer: Array = []
var _handlers: Dictionary = {}  # type -> Array[Callable]


func emit(event: Dictionary) -> void:
	_buffer.append(event)


## Assina um tipo de evento. Devolve o Callable que cancela a assinatura.
func on(type: String, handler: Callable) -> Callable:
	if not _handlers.has(type):
		_handlers[type] = []
	var list: Array = _handlers[type]
	if not list.has(handler):
		list.append(handler)
	return func() -> void: list.erase(handler)


## Entrega os eventos acumulados aos assinantes, em ordem, e esvazia o buffer.
func drain() -> Array:
	var events := _buffer
	_buffer = []
	for event in events:
		var list: Variant = _handlers.get(event["type"])
		if list == null:
			continue
		# Cópia: um handler pode cancelar a assinatura durante a entrega.
		for handler in (list as Array).duplicate():
			if (list as Array).has(handler):
				handler.call(event)
	return events
