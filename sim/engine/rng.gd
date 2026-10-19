class_name Rng
extends RefCounted
## RNG determinístico com semente (mulberry32), idêntico ao `rng.ts` do Phaser.
##
## Todo o estado do gerador é um inteiro de 32 bits em `holder.rng_state`
## (normalmente o próprio RunState). Qualquer objeto com a propriedade
## `rng_state` serve de holder; `RngHolder` é o mais simples.
##
## Aritmética: o JS trabalha em módulo 2^32 (Math.imul, >>>0). Aqui os valores
## ficam sempre mascarados em 32 bits sem sinal; o int de 64 bits do GDScript
## faz o produto transbordar sem erro e os 32 bits baixos continuam corretos.

const MASK32 := 0xFFFFFFFF
const FNV_OFFSET := 0x811c9dc5
const FNV_PRIME := 0x01000193
const INCREMENT := 0x6d2b79f5

var holder: Object


func _init(p_holder: Object) -> void:
	holder = p_holder


## Converte uma semente em texto num inteiro de 32 bits (FNV-1a).
## O JS percorre unidades UTF-16 (`charCodeAt`), então aqui também.
static func hash_seed(seed_text: String) -> int:
	var h := FNV_OFFSET
	var bytes := seed_text.to_utf16_buffer()
	for i in range(0, bytes.size(), 2):
		var unit := bytes[i] | (bytes[i + 1] << 8)
		h = ((h ^ unit) * FNV_PRIME) & MASK32
	return h


## Equivalente a Math.imul para operandos de 32 bits sem sinal (resultado sem sinal).
static func imul(a: int, b: int) -> int:
	return (a * b) & MASK32


## Número em [0, 1).
func next_float() -> float:
	return float(_next_u32()) / 4294967296.0


## Inteiro em [min_value, max_value], inclusive nas duas pontas.
## Intervalo inválido: push_error e devolve min_value.
func next_int(min_value: int, max_value: int) -> int:
	if max_value < min_value:
		push_error("next_int: intervalo inválido [%d, %d]" % [min_value, max_value])
		return min_value
	return min_value + int(floor(next_float() * float(max_value - min_value + 1)))


## Verdadeiro com probabilidade `p` (0 a 1).
func chance(p: float) -> bool:
	return next_float() < p


## Item aleatório. Lista vazia: push_error e devolve null.
func pick(items: Array) -> Variant:
	if items.is_empty():
		push_error("pick: lista vazia")
		return null
	return items[next_int(0, items.size() - 1)]


## Embaralha no lugar (Fisher-Yates) e devolve o próprio array.
func shuffle(items: Array) -> Array:
	for i in range(items.size() - 1, 0, -1):
		var j := next_int(0, i)
		var tmp: Variant = items[i]
		items[i] = items[j]
		items[j] = tmp
	return items


## Próxima saída bruta de 32 bits sem sinal (o numerador de next_float).
func _next_u32() -> int:
	var t: int = (int(holder.rng_state) + INCREMENT) & MASK32
	holder.rng_state = t
	var r := imul(t ^ (t >> 15), t | 1)
	r ^= (r + imul(r ^ (r >> 7), r | 61)) & MASK32
	return (r ^ (r >> 14)) & MASK32
