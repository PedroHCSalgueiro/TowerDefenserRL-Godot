class_name SimMath
extends RefCounted
## Funções numéricas que precisam dar o MESMO resultado bit a bit que o JavaScript
## (o Phaser usa `Math.hypot` e `Math.round` na simulação).


## Equivalente a `Math.hypot(x, y)` do V8: soma dos quadrados escalonada pelo
## maior valor, com compensação de Kahan. `sqrt(x*x + y*y)` pode errar o último bit.
static func hypot(x: float, y: float) -> float:
	var ax := absf(x)
	var ay := absf(y)
	var maximum := maxf(ax, ay)
	if maximum == 0.0:
		return 0.0
	var sum := 0.0
	var compensation := 0.0
	for v in [ax, ay]:
		var n: float = v / maximum
		var summand := n * n - compensation
		var preliminary := sum + summand
		compensation = (preliminary - sum) - summand
		sum = preliminary
	return sqrt(sum) * maximum


## Equivalente a `Math.round(x)` do JS: arredonda para o inteiro mais próximo e, no
## meio (.5), para cima (+∞) — inclusive nos negativos. `roundf` do Godot arredonda
## o meio para longe do zero.
static func js_round(x: float) -> int:
	return int(floor(x + 0.5))
