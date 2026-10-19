class_name TowerDragController
extends Node
## Controles de mover torres (T15): o botão é apertado sobre uma torre do mapa (a cena avisa por
## `press`), e o arrasto é acompanhado aqui, como o arrasto dos slots da loja. A decisão fica no
## `TowerDragModel`; aqui só entram o mouse do Godot e o aviso de "travada" (porte de
## `towerDragController.ts`). O botão direito no meio do arrasto cancela, como o Esc (T25).

signal started(tower_id: int)
signal locked(tower_id: int)

var _drag := TowerDragModel.new()
var _map: SimMap
var _state: Callable          # () -> RunState
var _paused: Callable         # () -> bool
var _enqueue: Callable        # (command: Dictionary)
var _cell_at_screen: Callable # (pos) -> Vector2i | null
var _pressed_tower := -1
var _threshold: float


func setup(map: SimMap, state: Callable, paused: Callable, enqueue: Callable, cell_at_screen: Callable) -> void:
	_map = map
	_state = state
	_paused = paused
	_enqueue = enqueue
	_cell_at_screen = cell_at_screen
	_threshold = float(DataLoader.load_json("ui.json")["towerDrag"]["thresholdPx"])


## Torre sendo arrastada ({"towerId", "towerType"}) ou {}, para o fantasma e para esconder a janela
## de informações.
func dragging() -> Dictionary:
	return _drag.dragging()


## Botão esquerdo apertado sobre a torre.
func press(tower: Tower, pos: Vector2) -> void:
	if _drag.begin(_state.call(), _paused.call(), tower.id, tower.type, pos):
		_pressed_tower = tower.id


## Cancela o arrasto (Esc e botão direito): a torre fica onde estava.
func cancel() -> void:
	_drag.cancel()
	_pressed_tower = -1


func _input(event: InputEvent) -> void:
	if _pressed_tower < 0:
		return
	if event is InputEventMouseMotion:
		var pos := (event as InputEventMouseMotion).position
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_release(pos)
			return
		var result := _drag.pointer_move(_state.call(), pos, _threshold)
		if result == "started":
			started.emit(_pressed_tower)
		elif result == "locked":
			locked.emit(_pressed_tower)
			_pressed_tower = -1
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_release(mb.position)


func _release(pos: Vector2) -> void:
	var cell: Variant = _cell_at_screen.call(pos)
	var command := _drag.release(_state.call(), _map, cell)
	_pressed_tower = -1
	if not command.is_empty() and not _paused.call():
		_enqueue.call(command)


## Chame a cada quadro: cancela o arrasto na pausa, ao chamar onda ou se a torre sumir.
func update() -> void:
	if _drag.update(_state.call(), _paused.call()):
		_pressed_tower = -1
