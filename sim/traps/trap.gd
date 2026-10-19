class_name Trap
extends RefCounted
## Uma armadilha no chão do caminho (Engenheira Mabel). Fica parada até um inimigo terrestre pisar
## nela (a menos de `radius` casas); aí age uma vez e some.
##  - "caltrop" (estrepes, o ataque dela): o inimigo leva `damage` de uma vez.
##  - "bear" (armadilha de urso, a habilidade): o inimigo fica preso (Atordoado) por `hold_ticks` e
##    sangra `damage` por tick nesse tempo.

var id := 0
## Id da torre que a pôs (o dano é creditado a ela).
var owner_id := 0
var kind := "caltrop"
var x := 0.0
var y := 0.0
var damage := 0.0
var hold_ticks := 0
var radius := 0.5
