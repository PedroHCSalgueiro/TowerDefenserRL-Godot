class_name Simulation
extends RefCounted
## Núcleo da simulação: avança o estado um tick por vez, aplicando as ações
## enfileiradas e rodando os sistemas em ordem fixa (porte de `simulation.ts`).
##
## O estado é qualquer objeto com: `tick`, `rng_state`, `next_entity_id`, `status`
## ("playing" | "lost" | "won"), `command_queue` (Array) e `rewards.screen`.
## Um sistema é um Callable que recebe um `TickContext`.
##
## Ainda não portado: `restore(json)` e `serialize()` (entram com o save, Fase 4).

var rng: Rng
var _events := EventBus.new()
var _state: Object
var _systems: Array
var _tick_events: Array = []

static var _frozen_safe: Dictionary = {}


func _init(run_state: Object, systems: Array = []) -> void:
	_state = run_state
	_systems = systems
	rng = Rng.new(run_state)


var state: Object:
	get:
		return _state


## Simulação nova com o RunState inicial da semente (porte de `Simulation.create`).
static func create(seed_text: String, systems: Array = []) -> Simulation:
	return Simulation.new(RunState.create(seed_text), systems)


## Marca o sistema para rodar também nos ticks congelados pela tela de
## recompensa (T24): ações, relógio e abertura da tela, ouro e classes.
static func runs_while_frozen(system: Callable) -> Callable:
	_frozen_safe[system] = true
	return system


## Tela de recompensa aberta (T24): o tick fica congelado. O número do tick não
## anda (os nascimentos das ondas empilhadas e as travas de ativação não
## "atrasam") e só rodam os sistemas marcados com `runs_while_frozen`.
static func is_frozen(run_state: Object) -> bool:
	return run_state.rewards.screen != null


func enqueue(command: Dictionary) -> void:
	_state.command_queue.append(command)


## Avança um tick. Depois da derrota ou da vitória a run fica congelada.
## Com a tela de recompensa aberta no começo do tick, o tick é congelado
## (ver `is_frozen`).
func step() -> void:
	if _state.status != "playing":
		return
	var commands: Array = _state.command_queue.duplicate()
	_state.command_queue.clear()
	var frozen := is_frozen(_state)
	if not frozen:
		_state.tick += 1
	_tick_events.clear()
	var ctx := TickContext.new(_state, rng, commands, _tick_events, _events)
	for system: Callable in _systems:
		if frozen and not _frozen_safe.has(system):
			continue
		system.call(ctx)


func drain_events() -> Array:
	return _events.drain()


func on(type: String, handler: Callable) -> Callable:
	return _events.on(type, handler)
