extends GutTest
## Porte de tests/events.test.ts.


func test_entrega_os_eventos_em_ordem_e_esvazia_o_buffer() -> void:
	var bus := EventBus.new()
	bus.emit({"type": "waveStarted", "tick": 1, "wave": 1})
	bus.emit({"type": "enemySpawned", "tick": 1, "enemyId": 7, "enemyType": "common"})

	assert_eq(bus.drain(), [
		{"type": "waveStarted", "tick": 1, "wave": 1},
		{"type": "enemySpawned", "tick": 1, "enemyId": 7, "enemyType": "common"},
	])
	assert_eq(bus.drain(), [])


func test_assinantes_recebem_so_o_tipo_assinado_no_drain() -> void:
	var bus := EventBus.new()
	var received: Array = []
	bus.on("enemyKilled", func(event: Dictionary) -> void: received.append(event))

	bus.emit({"type": "towerFired", "tick": 2, "towerId": 1, "targetId": 3, "shot": "normal"})
	var killed := {"type": "enemyKilled", "tick": 2, "enemyId": 3, "enemyType": "common", "towerId": 1, "x": 0, "y": 0, "weight": 1}
	bus.emit(killed)
	assert_eq(received, [])

	bus.drain()
	assert_eq(received, [killed])


func test_cancelar_a_assinatura_para_de_entregar_eventos() -> void:
	var bus := EventBus.new()
	var count := [0]
	var off := bus.on("waveStarted", func(_event: Dictionary) -> void: count[0] += 1)
	bus.emit({"type": "waveStarted", "tick": 1, "wave": 1})
	bus.drain()
	off.call()
	bus.emit({"type": "waveStarted", "tick": 2, "wave": 2})
	bus.drain()
	assert_eq(count[0], 1)


func test_handler_que_cancela_durante_o_drain_nao_recebe_os_proximos() -> void:
	var bus := EventBus.new()
	var count := [0]
	var off_holder: Array = []
	off_holder.append(bus.on("waveStarted", func(_event: Dictionary) -> void:
		count[0] += 1
		off_holder[0].call()))
	bus.emit({"type": "waveStarted", "tick": 1, "wave": 1})
	bus.emit({"type": "waveStarted", "tick": 2, "wave": 2})
	bus.drain()
	assert_eq(count[0], 1)
