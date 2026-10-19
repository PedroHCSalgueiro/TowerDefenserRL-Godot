class_name Enemy
extends MutablePoint
## Um inimigo do pool (porte de `Enemy` em `pool.ts`). `x`/`y` vêm de MutablePoint.

## Índice fixo do objeto no pool.
var slot: int
var active := false
## Id único na run (eventos e alvos). Muda a cada reaproveitamento.
var id := 0
var type := ""
## Onda a que o inimigo pertence (a primeira é a 1); 0 = sem onda (debug e estresse).
var wave := 0
## Versão forte do tipo (onda de elite): vida, velocidade e dano no núcleo de `EnemyData.elite`.
var elite := false
var hp := 0.0
var max_hp := 0.0
## Distância percorrida na rota, em casas.
var distance := 0.0
## Posição no tick anterior (a atual é x/y), para a renderização interpolar.
var prev_x := 0.0
var prev_y := 0.0


func _init(p_slot: int = 0) -> void:
	slot = p_slot
