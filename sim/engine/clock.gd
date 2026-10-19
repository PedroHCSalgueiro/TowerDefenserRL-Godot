class_name FixedStepClock
extends RefCounted
## Relógio de passo fixo, idêntico ao `clock.ts` do Phaser.
##
## Recebe o tempo real de cada quadro, multiplica pela velocidade (1x/2x/3x)
## e diz quantos ticks da simulação devem rodar. A duração do tick nunca muda,
## então o resultado da simulação é o mesmo em qualquer velocidade.
##
## `config` é o Dictionary de data/engine.json (chaves em camelCase, como no JSON):
## ticksPerSecond, speeds, debugSpeeds (opcional), maxTicksPerFrame.

const MS_PER_SECOND := 1000.0
## Tolerância para erro de ponto flutuante ao somar deltas fracionários.
const EPSILON := 1e-9

# Acumulador em "ms × ticks por segundo": um tick = MS_PER_SECOND unidades.
# Evita dividir por 1000/30, que não é exato em ponto flutuante.
var _accumulator := 0.0
var _current_speed := 1.0
var _dropped := 0
var _config: Dictionary
# Normalizadas para float: o JSON traz floats e Array.has/find distinguem 2 de 2.0.
var _speeds: Array[float] = []
var _debug_speeds: Array[float] = []


func _init(p_config: Dictionary) -> void:
	_config = p_config
	for v in _config.get("speeds", []):
		_speeds.append(float(v))
	for v in _config.get("debugSpeeds", []):
		_debug_speeds.append(float(v))
	if _speeds.is_empty():
		push_error("EngineConfig.speeds não pode ser vazio")
		return
	_current_speed = _speeds[0]


var speed: float:
	get:
		return _current_speed


## A primeira velocidade da lista (1x).
var base_speed: float:
	get:
		return _speeds[0]


func set_speed(p_speed: float) -> void:
	if not _speeds.has(p_speed) and not _debug_speeds.has(p_speed):
		push_error("Velocidade inválida: %s" % p_speed)
		return
	_current_speed = p_speed


## Passa para a próxima velocidade da lista (depois da última, volta à primeira).
## Numa velocidade do debug (5x, 10x), volta à primeira.
func cycle_speed() -> float:
	var next := _speeds[(_speeds.find(_current_speed) + 1) % _speeds.size()]
	_current_speed = next
	return next


## Total de ticks descartados pelo teto `maxTicksPerFrame` desde a criação.
var dropped_ticks: int:
	get:
		return _dropped


var tick_duration_ms: float:
	get:
		return MS_PER_SECOND / float(_config["ticksPerSecond"])


## Fração do próximo tick já decorrida, em [0, 1). A renderização desenha
## em lerp(estado_anterior, estado_atual, alpha).
var alpha: float:
	get:
		return _accumulator / MS_PER_SECOND


## Avança o tempo real do quadro e devolve quantos ticks rodar. `speed_override`
## (se informado) troca a velocidade só neste quadro; a escolhida fica guardada.
func advance(delta_ms: float, speed_override: float = NAN) -> int:
	if not is_finite(delta_ms) or delta_ms <= 0.0:
		return 0
	var used_speed := _current_speed if is_nan(speed_override) else speed_override
	_accumulator += delta_ms * used_speed * float(_config["ticksPerSecond"])

	var due := int(floor(_accumulator / MS_PER_SECOND + EPSILON))
	# Acima do teto o excedente é descartado (a simulação desacelera em vez
	# de travar o quadro); a fração do tick seguinte é preservada.
	var ticks := mini(due, int(_config["maxTicksPerFrame"]))
	_dropped += due - ticks
	_accumulator = maxf(0.0, _accumulator - float(due) * MS_PER_SECOND)
	return ticks


## Interpolação linear entre o valor do tick anterior e o do atual.
static func lerp_value(from: float, to: float, p_alpha: float) -> float:
	return from + (to - from) * p_alpha
