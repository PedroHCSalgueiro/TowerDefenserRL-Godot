class_name TickContext
extends RefCounted
## O que um sistema recebe a cada tick (porte de `TickContext` em `simulation.ts`).

var state: Object
var rng: Rng
## Ações aplicadas neste tick, na ordem em que foram enfileiradas.
var commands: Array
## Eventos emitidos neste tick até agora, em ordem. É por aqui que o motor de
## gatilhos enxerga tiros e abates do próprio tick. Não vai para o save.
var tick_events: Array
## Índice espacial da partida (o mesmo das torres e dos gatilhos), posto pelo primeiro sistema de
## `GameSystems`; null fora dela (testes com sistemas avulsos). A Maldição usa para achar os vizinhos.
var index: SpatialIndex = null
## Classes da partida e o bônus do Controlador deste tick (% de dano a mais em inimigo Lento ou Atordoado),
## postos pelo mesmo sistema; null e 0 fora da partida.
var classes: ClassData = null
var afflicted_damage_percent := 0.0

var _bus: EventBus


func _init(p_state: Object, p_rng: Rng, p_commands: Array, p_tick_events: Array, p_bus: EventBus) -> void:
	state = p_state
	rng = p_rng
	commands = p_commands
	tick_events = p_tick_events
	_bus = p_bus


func emit(event: Dictionary) -> void:
	tick_events.append(event)
	_bus.emit(event)


func allocate_id() -> int:
	var id: int = state.next_entity_id
	state.next_entity_id = id + 1
	return id
