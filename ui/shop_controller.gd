class_name ShopController
extends Node
## Controles da loja: arrastar do slot até uma casa, teclas 1 a 5 (a torre fica presa ao mouse;
## clique posiciona, Esc cancela), R para rerolar e S para vender a torre selecionada. Tudo vira
## comando da simulação; o ouro só é cobrado pela simulação, quando a torre é posicionada (porte de
## `shopController.ts`).
##
## Arrastar: soltar numa casa inválida (ou fora do mapa) cancela sem cobrar. Um clique curto no slot
## também "pega" a torre, como as teclas. Slot cuja compra funde com uma torre do mapa (T11): o
## clique, o arrasto ou a tecla compram na hora, sem pegar a torre. Slot que precisaria de casa nova
## com o mapa no limite de torres (T12): não pega a torre, e a torre já presa é cancelada se o limite
## encher. Com o jogo pausado (T14), nada disso funciona e a torre presa é cancelada. O botão direito
## (T25) também cancela, como o Esc.

## Distância, em pixels, que separa um clique curto de um arrasto.
const DRAG_THRESHOLD_PX := 6.0

var panel: ShopPanel
var _map: SimMap
var _state: Callable          # () -> RunState
var _enqueue: Callable        # (command: Dictionary)
var _evolve_nexus: Callable   # ()
var _paused: Callable         # () -> bool
var _selected_cell: Callable  # () -> Vector2i | null
var _cell_at_screen: Callable # (pos: Vector2) -> Vector2i | null

## Slot preso ao mouse (-1 = nenhum), se o botão ainda está apertado desde o slot, onde começou e
## se já se mexeu além do limiar.
var _carry_slot := -1
var _dragging := false
var _start := Vector2.ZERO
var _moved := false
var _key := ""


func setup(p_panel: ShopPanel, map: SimMap, state: Callable, enqueue: Callable, evolve_nexus: Callable,
		paused: Callable, selected_cell: Callable, cell_at_screen: Callable) -> void:
	panel = p_panel
	_map = map
	_state = state
	_enqueue = enqueue
	_evolve_nexus = evolve_nexus
	_paused = paused
	_selected_cell = selected_cell
	_cell_at_screen = cell_at_screen
	panel.slot_pressed.connect(func(slot: int, pos: Vector2) -> void: _pick_up(slot, true, pos))
	panel.reroll_pressed.connect(_reroll)
	panel.sell_pressed.connect(_sell)


## Slot preso ao mouse e o tipo ({"slot", "towerType"}), ou {} (nenhum), para a cena desenhar a
## torre fantasma.
func carrying() -> Dictionary:
	if _carry_slot < 0:
		return {}
	var tower_type: Variant = _state.call().shop.slots[_carry_slot]
	if typeof(tower_type) != TYPE_STRING:
		return {}
	return {"slot": _carry_slot, "towerType": tower_type}


## Torre do slot sob o mouse na loja ("" = nenhuma), para a janela de informações.
func hovered_tower_type() -> String:
	if panel.hovered_slot < 0:
		return ""
	var slots: Array = _state.call().shop.slots
	if panel.hovered_slot >= slots.size() or slots[panel.hovered_slot] == null:
		return ""
	return slots[panel.hovered_slot]


## Tecla do jogo (já filtrada: sem Ctrl/Alt, sem repetição). Devolve true se tratou.
func handle_key(event: InputEventKey) -> bool:
	# 1 a 5 (e 6 com a vaga extra da Costa Rubra).
	var slot_count: int = _state.call().shop.slots.size()
	if event.keycode >= KEY_1 and event.keycode < KEY_1 + mini(9, slot_count):
		_pick_up(event.keycode - KEY_1, false, Vector2.ZERO)
		return true
	match event.keycode:
		KEY_R:
			_reroll()
			return true
		KEY_S:
			_sell()
			return true
		KEY_E:
			_evolve_nexus.call()
			return true
		KEY_ESCAPE:
			cancel()
			return true
	return false


func _input(event: InputEvent) -> void:
	if _carry_slot < 0 or not _dragging:
		return
	if event is InputEventMouseMotion:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_release((event as InputEventMouseMotion).position)
			return
		if (event as InputEventMouseMotion).position.distance_to(_start) > DRAG_THRESHOLD_PX:
			_moved = true
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_release(mb.position)


func _release(pos: Vector2) -> void:
	_dragging = false
	if not _moved:
		return  # clique curto no slot: a torre segue presa ao mouse
	var cell: Variant = _cell_at_screen.call(pos)
	if cell != null and ShopModel.can_place_at(_state.call(), _map, cell):
		_buy(_carry_slot, cell)
	else:
		_carry_slot = -1  # soltou numa casa inválida: cancela sem cobrar


## Clique no mapa com a torre presa ao mouse: posiciona se a casa serve.
func click_cell(cell: Variant) -> void:
	if _carry_slot < 0 or _dragging:
		return
	if cell != null and ShopModel.can_place_at(_state.call(), _map, cell):
		_buy(_carry_slot, cell)
	# Casa inválida: a torre continua presa (Esc cancela).


func _model() -> ShopModel:
	return ShopModel.build(_state.call(), _selected_cell.call(), EconomyData.game_data(), TowerData.game_data(), ClassData.game_data())


func _pick_up(slot: int, dragging: bool, pos: Vector2) -> void:
	if _paused.call():
		return
	var model := _model()
	if slot >= model.slots.size():
		_carry_slot = -1
		return
	var entry := model.slots[slot]
	if entry.is_empty() or not entry.affordable or entry.blocked_by_limit:
		_carry_slot = -1
		return
	if entry.fuse_star > 0:
		# A compra funde com uma torre do mapa: acontece na hora, sem posicionar.
		_enqueue.call({"type": "buyTower", "slot": slot})
		_carry_slot = -1
		return
	_carry_slot = slot
	_dragging = dragging
	_start = pos
	_moved = false


func _buy(slot: int, cell: Vector2i) -> void:
	_enqueue.call({"type": "buyTower", "slot": slot, "x": cell.x, "y": cell.y})
	_carry_slot = -1


## Solta a torre da mão sem comprar (Esc e botão direito).
func cancel() -> void:
	_carry_slot = -1
	_dragging = false


func _reroll() -> void:
	if not _paused.call() and _model().can_reroll:
		_enqueue.call({"type": "rerollShop"})


func _sell() -> void:
	var target := _model().sell
	if not target.is_empty() and not _paused.call():
		_enqueue.call({"type": "sellTower", "towerId": target["towerId"]})


## Chame a cada quadro: só refaz os nós quando algo mudou.
func update() -> void:
	# A torre presa some se o slot foi trocado, o ouro acabou ou o jogo pausou.
	if _carry_slot >= 0 and (carrying().is_empty() or _paused.call()):
		_carry_slot = -1
	var model := _model()
	if _carry_slot >= 0:
		var entry := model.slots[_carry_slot]
		if not entry.affordable or entry.blocked_by_limit:
			_carry_slot = -1
	var key := model.key(_carry_slot)
	if key == _key:
		return
	_key = key
	panel.render(model, _carry_slot)
