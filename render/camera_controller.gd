class_name CameraController
extends Node
## Controles da câmera (T25): rodinha (zoom suave no ponto do mouse), botão direito arrastado (move a
## tela), setas, borda da tela com uma torre na mão e botão do meio (volta ao padrão). A matemática
## fica em `CameraModel`; aqui entram os eventos do Godot e a `Camera3D` (porte de
## `CameraController.ts`).
##
## A câmera é estado da renderização: não entra no save e não muda a simulação. Ela funciona com o
## jogo pausado (P), mas não com a ajuda, as cartas de recompensa ou a tela de fim (elas cobrem o
## mapa).
##
## Botão direito no meio de um arrasto de torre (esquerdo apertado): cancela o arrasto, como o Esc, e
## não move a tela. Clique curto do direito no mapa: cancela a torre presa ao mouse (sinal
## `right_clicked`).

signal right_clicked

var model: CameraModel
var _camera: Camera3D
var _gesture := CameraModel.PanGesture.new()
var _edge := CameraModel.EdgePan.new()
var _config: Dictionary
## Ajuda, cartas de recompensa ou fim da run cobrindo o mapa: a câmera não mexe.
var _blocked: Callable
## Torre na mão (arrasto do mapa, da loja ou teclas 1 a 5): liga a borda da tela.
var _holding_tower: Callable
## Botão direito com o esquerdo apertado: cancela o arrasto de torre (mover ou da loja).
var _cancel_drag: Callable
var _applied_view: CameraModel.View = null


func setup(camera: Camera3D, map: SimMap, blocked: Callable, holding_tower: Callable, cancel_drag: Callable) -> void:
	_camera = camera
	_config = RenderConfig.data()["camera"]
	_blocked = blocked
	_holding_tower = holding_tower
	_cancel_drag = cancel_drag
	var viewport := get_viewport().get_visible_rect().size
	model = CameraModel.new(_config, viewport, GroundProjection.map_view_bounds(map.width, map.height))
	get_viewport().size_changed.connect(_on_resize)
	_apply()


## A área aberta do mapa mudou (mapa que cresce): os limites passam a ser essas casas e a vista volta ao
## padrão com animação (a câmera se afasta para a sala nova caber).
func set_map_cells(cells: Rect2i) -> void:
	model.set_bounds(GroundProjection.cells_view_bounds(cells))
	model.reset()


func _on_resize() -> void:
	model.set_viewport(get_viewport().get_visible_rect().size)
	_applied_view = null


## Botão direito apertado no mapa: enquanto isso, o esquerdo é ignorado.
func panning() -> bool:
	return _gesture.active()


func _is_blocked() -> bool:
	return _blocked.is_valid() and _blocked.call()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			match mb.button_index:
				MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
					if _is_blocked():
						return
					# Cada dente: ±1 (positivo = afastar).
					model.wheel(1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1.0, mb.position)
					get_viewport().set_input_as_handled()
				MOUSE_BUTTON_MIDDLE:
					if not _is_blocked():
						model.reset()
				MOUSE_BUTTON_RIGHT:
					# Com o esquerdo apertado, o direito só cancela o arrasto de torre.
					if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
						_cancel_drag.call()
						return
					if not _is_blocked():
						_gesture.press(mb.position)


func _input(event: InputEvent) -> void:
	# Movimento e soltura do botão direito valem mesmo sobre a interface (o gesto começou no mapa).
	if not _gesture.active():
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_release_gesture()
			return
		model.drag_by(_gesture.move(mm.position, float(_config["dragThresholdPx"])))
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and not mb.pressed:
			_release_gesture()


func _release_gesture() -> void:
	if _gesture.release() == "click" and not _is_blocked():
		right_clicked.emit()


func _process(delta: float) -> void:
	var delta_ms := delta * 1000.0
	var blocked := _is_blocked()
	if blocked:
		_gesture.cancel()
	var viewport := get_viewport().get_visible_rect().size
	var mouse := get_viewport().get_mouse_position()
	var pointer: Variant = mouse if Rect2(Vector2.ZERO, viewport).has_point(mouse) else null
	var holding: bool = (not blocked) and _holding_tower.is_valid() and _holding_tower.call()
	var edge_dir := _edge.update(holding, pointer, viewport, float(_config["edgePan"]["bandPx"]))
	if not blocked:
		if not _typing():
			model.move(CameraModel.arrow_direction(
					Input.is_key_pressed(KEY_LEFT), Input.is_key_pressed(KEY_RIGHT),
					Input.is_key_pressed(KEY_UP), Input.is_key_pressed(KEY_DOWN)),
					float(_config["keyPanSpeedPx"]), delta_ms)
		model.move(edge_dir, float(_config["edgePan"]["speedPx"]), delta_ms)
	model.update(delta_ms)
	_apply()


## Foco num campo de texto (painel de debug): as setas são do campo.
func _typing() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit or focus is SpinBox


## Leva a vista para a Camera3D, se ela mudou.
func _apply() -> void:
	var view := model.view()
	if view == _applied_view:
		return
	_applied_view = view
	GroundProjection.apply_view(_camera, view, get_viewport().get_visible_rect().size.y)
