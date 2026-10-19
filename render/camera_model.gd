class_name CameraModel
extends RefCounted
## Câmera do mundo (T25): zoom e deslocamento (porte de `camera.ts`). Matemática pura, sem nós.
## A câmera é estado da renderização e da interface: não entra no save e não muda a simulação.
##
## O "mundo" da câmera é o plano da vista, em "pixels" (`GroundProjection`): no zoom 1 ele
## coincide com o enquadramento padrão. A vista (`View`) é o ponto do mundo no centro da tela e o
## zoom (pixels de tela por pixel do mundo). Os limites vêm do retângulo do mapa no mundo, com uma
## margem em pixels de tela (para tirar o mapa de baixo dos painéis), e o zoom padrão e o mínimo
## descem quando o mapa inteiro não cabe na tela (mapa que cresce em salas).
##
## Pontos e retângulos aqui são Vector2/Rect2 de 32 bits: só a RENDERIZAÇÃO usa isto, nunca a
## simulação.

## Diferença de zoom (em log) abaixo da qual o zoom suave encosta no alvo.
const ZOOM_SNAP := 0.001

## A vista: zoom, centro (no mundo).
class View:
	extends RefCounted
	var zoom := 1.0
	var center := Vector2.ZERO

	func _init(p_zoom: float = 1.0, p_center: Vector2 = Vector2.ZERO) -> void:
		zoom = p_zoom
		center = p_center

## Gesto do botão direito: abaixo do limiar é um clique (cancela a torre presa ao mouse); acima,
## arrasta a tela, e o mundo acompanha o mouse.
class PanGesture:
	extends RefCounted
	var _start := Vector2.ZERO
	var _has_start := false
	var _last := Vector2.ZERO
	var _dragging := false

	## Botão direito apertado (o gesto começou no mapa e não foi solto).
	func active() -> bool:
		return _has_start

	## Já passou do limiar: está arrastando a tela.
	func panning() -> bool:
		return _dragging

	func press(point: Vector2) -> void:
		_start = point
		_last = point
		_has_start = true
		_dragging = false

	## Mouse andou com o botão apertado. Devolve quanto a tela anda (pixels de tela); ao passar do
	## limiar, já inclui o caminho desde o aperto.
	func move(point: Vector2, threshold_px: float) -> Vector2:
		if not _has_start:
			return Vector2.ZERO
		if not _dragging:
			if point.distance_to(_start) <= threshold_px:
				return Vector2.ZERO
			_dragging = true
		var delta := point - _last
		_last = point
		return delta

	## Botão solto: "click" (não passou do limiar), "drag" ou "" (sem gesto).
	func release() -> String:
		if not _has_start:
			return ""
		var result := "drag" if _dragging else "click"
		cancel()
		return result

	func cancel() -> void:
		_has_start = false
		_dragging = false

## Borda da tela com uma torre na mão: move a câmera só depois que o mouse saiu da faixa uma vez
## (o arrasto da loja começa colado na borda de baixo).
class EdgePan:
	extends RefCounted
	var _armed := false

	## Chame a cada quadro; devolve a direção do movimento (0,0 = parado).
	func update(holding: bool, pointer: Variant, viewport: Vector2, band_px: float) -> Vector2:
		if not holding or pointer == null:
			_armed = false
			return Vector2.ZERO
		var dir := CameraModel.edge_direction(pointer, viewport, band_px)
		if dir == Vector2.ZERO:
			_armed = true
			return Vector2.ZERO
		return dir if _armed else Vector2.ZERO

# Configuração (render.json → camera).
var _zoom_min: float
var _zoom_default: float
var _zoom_max: float
var _wheel_step: float
var _wheel_notch_px: float
var _wheel_lines_per_notch: float
var _smooth_ms: float
var _reset_ms: float
var _margin_px: float
var _viewport: Vector2
var _bounds: Rect2
var _limit_min: float
var _limit_default: float
var _limit_max: float
var _current: View
## Zoom suave: alvo e ponto da tela que fica parado (target_zoom < 0 = sem animação).
var _target_zoom := -1.0
var _target_anchor := Vector2.ZERO
## Volta ao padrão: vista de partida e tempo passado (_reset_from == null = sem animação).
var _reset_from: View = null
var _reset_elapsed := 0.0


func _init(config: Dictionary, viewport: Vector2, bounds: Rect2) -> void:
	var zoom: Dictionary = config["zoom"]
	_zoom_min = float(zoom["min"])
	_zoom_default = float(zoom["default"])
	_zoom_max = float(zoom["max"])
	_wheel_step = float(zoom["wheelStep"])
	_wheel_notch_px = float(zoom["wheelNotchPx"])
	_wheel_lines_per_notch = float(zoom["wheelLinesPerNotch"])
	_smooth_ms = float(zoom["smoothMs"])
	_reset_ms = float(config["resetMs"])
	_margin_px = float(config["marginPx"])
	_viewport = viewport
	_bounds = bounds
	_update_limits()
	_current = default_view()


static func _lerp_zoom(a: float, b: float, t: float) -> float:
	return exp(lerpf(log(a), log(b), t))


static func _ease_out_cubic(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)


## Zoom em que o mapa inteiro cabe na tela.
static func fit_zoom(bounds: Rect2, viewport: Vector2) -> float:
	return minf(viewport.x / bounds.size.x, viewport.y / bounds.size.y)


## Ponto do mundo sob o ponto da tela.
static func screen_to_world_in(view: View, viewport: Vector2, point: Vector2) -> Vector2:
	return view.center + (point - viewport / 2.0) / view.zoom


## Ponto da tela onde aparece o ponto do mundo.
static func world_to_screen_in(view: View, viewport: Vector2, point: Vector2) -> Vector2:
	return (point - view.center) * view.zoom + viewport / 2.0


## Troca o zoom mantendo parado o ponto do mundo que está sob `anchor` (tela).
static func zoom_around(view: View, zoom: float, anchor: Vector2, viewport: Vector2) -> View:
	var world := screen_to_world_in(view, viewport, anchor)
	return View.new(zoom, world - (anchor - viewport / 2.0) / zoom)


## Um eixo do limite: a tela não passa da margem além do mapa. Se a tela é maior que o mapa com a
## margem, o mapa fica centralizado nesse eixo.
static func _clamp_axis(center: float, start: float, length: float, viewport_length: float,
		margin_px: float, zoom: float) -> float:
	var margin := margin_px / zoom
	var half := viewport_length / zoom / 2.0
	var lo := start - margin + half
	var hi := start + length + margin - half
	return start + length / 2.0 if lo >= hi else clampf(center, lo, hi)


## Dentes da rodinha num evento (positivo = afastar). `delta_y` em pixels (modo padrão).
func wheel_notches(delta_y: float) -> float:
	return delta_y / _wheel_notch_px


## Direção das setas seguradas; as opostas se anulam. `held`: Dictionary tecla -> true.
static func arrow_direction(left: bool, right: bool, up: bool, down: bool) -> Vector2:
	return Vector2(float(right) - float(left), float(down) - float(up))


## Direção da borda da tela sob o ponto (−1, 0 ou 1 por eixo); fora da tela conta como borda.
static func edge_direction(point: Vector2, viewport: Vector2, band_px: float) -> Vector2:
	return Vector2(
		-1.0 if point.x < band_px else (1.0 if point.x > viewport.x - band_px else 0.0),
		-1.0 if point.y < band_px else (1.0 if point.y > viewport.y - band_px else 0.0))


func _update_limits() -> void:
	var fit := fit_zoom(_bounds, _viewport)
	_limit_min = minf(_zoom_min, fit)
	_limit_default = minf(_zoom_default, fit)
	_limit_max = _zoom_max


func view() -> View:
	return _current


func zoom_limits() -> Dictionary:
	return {"min": _limit_min, "default": _limit_default, "max": _limit_max}


## Zoom suave ou volta ao padrão em andamento.
func animating() -> bool:
	return _target_zoom >= 0.0 or _reset_from != null


## O mapa mudou de tamanho (salas): refaz os limites e mantém a vista dentro deles.
func set_bounds(bounds: Rect2) -> void:
	_bounds = bounds
	_update_limits()
	_target_zoom = -1.0
	_current = _clamp(_current)


## O tamanho da tela mudou.
func set_viewport(viewport: Vector2) -> void:
	_viewport = viewport
	_update_limits()
	_current = _clamp(_current)


## Zoom padrão com o mapa centralizado.
func default_view() -> View:
	return _clamp(View.new(_limit_default, _bounds.position + _bounds.size / 2.0))


func screen_to_world(point: Vector2) -> Vector2:
	return screen_to_world_in(_current, _viewport, point)


func world_to_screen(point: Vector2) -> Vector2:
	return world_to_screen_in(_current, _viewport, point)


## Rodinha: `notches` dentes (positivo = afastar) em volta do ponto `anchor` da tela.
func wheel(notches: float, anchor: Vector2) -> void:
	if notches == 0.0:
		return
	_reset_from = null
	var base := _target_zoom if _target_zoom >= 0.0 else _current.zoom
	_target_zoom = clampf(base * pow(_wheel_step, -notches), _limit_min, _limit_max)
	_target_anchor = anchor


## Arrasto da tela: o mundo acompanha o mouse (`delta` em pixels de tela).
func drag_by(delta: Vector2) -> void:
	if delta == Vector2.ZERO:
		return
	_reset_from = null
	_current = _clamp(View.new(_current.zoom, _current.center - delta / _current.zoom))


## Anda na direção (`dir`, cada eixo de −1 a 1; a diagonal é normalizada) a `speed_px` pixels de
## tela por segundo, durante `dt_ms`.
func move(dir: Vector2, speed_px: float, dt_ms: float) -> void:
	var length := dir.length()
	if length == 0.0 or dt_ms <= 0.0:
		return
	_reset_from = null
	var step := (speed_px * dt_ms) / 1000.0 / length
	drag_by(-dir * step)


## Botão do meio: volta ao padrão com uma animação de `resetMs`.
func reset() -> void:
	_target_zoom = -1.0
	_reset_from = _current
	_reset_elapsed = 0.0


## Chame a cada quadro com o tempo real passado.
func update(dt_ms: float) -> void:
	if _target_zoom >= 0.0:
		# Aproximação exponencial: ~95% do caminho em `smoothMs`.
		var k := 1.0 - exp((-3.0 * maxf(0.0, dt_ms)) / _smooth_ms)
		var zoom := _lerp_zoom(_current.zoom, _target_zoom, k)
		if absf(log(zoom / _target_zoom)) < ZOOM_SNAP:
			zoom = _target_zoom
			_target_zoom = -1.0
		_current = _clamp(zoom_around(_current, zoom, _target_anchor, _viewport))
	if _reset_from != null:
		_reset_elapsed += maxf(0.0, dt_ms)
		var t := minf(1.0, _reset_elapsed / _reset_ms)
		var to := default_view()
		if t >= 1.0:
			_current = to
			_reset_from = null
		else:
			var e := _ease_out_cubic(t)
			_current = _clamp(View.new(_lerp_zoom(_reset_from.zoom, to.zoom, e),
					_reset_from.center.lerp(to.center, e)))


## A vista dentro dos limites: zoom entre o mínimo e o máximo e a tela sem sair do mapa.
func _clamp(view: View) -> View:
	var zoom := clampf(view.zoom, _limit_min, _limit_max)
	return View.new(zoom, Vector2(
			_clamp_axis(view.center.x, _bounds.position.x, _bounds.size.x, _viewport.x, _margin_px, zoom),
			_clamp_axis(view.center.y, _bounds.position.y, _bounds.size.y, _viewport.y, _margin_px, zoom)))
