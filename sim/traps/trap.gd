class_name Trap
extends RefCounted
## Uma invocação no mapa: armadilhas no chão do caminho e as coisas que os Invocadores e Controladores
## põem em campo. Vive em `RunState.traps` e roda no sistema de armadilhas (`TrapSystems`).
##  - "caltrop" (estrepes, o ataque da Mabel): o primeiro inimigo terrestre que pisa leva `damage` e some.
##  - "bear" (armadilha de urso da Mabel): quem pisa fica preso (Atordoado) por `hold_ticks` e sangra
##    `damage` por tick nesse tempo; some.
##  - "tentacle" (Nerea): causa `damage` por tick em todos os terrestres no raio, por `hold_ticks`.
##  - "plague" (nuvem da Agatha) e "crater" (Ciclope): zonas que deixam Lento (e Envenenado, na nuvem) os
##    terrestres no raio, por `hold_ticks`. `params`: slow, slowCap, effectTicks e poison (por tick).
##  - "sentinel" (torreta do Bolt, grifo da Kallia): atira em quem estiver no alcance a cada `interval` ticks,
##    com `damage` por tiro, por `hold_ticks`. `params`: range, interval, cooldown, speed, airMultiplier, preferAir.
##  - "skeleton" (Vex e a região Cripta): anda para trás no caminho terrestre e explode no primeiro inimigo
##    que tocar (`damage` em área). `params`: distance, step, contact, blast.

var id := 0
## Id da torre que a pôs (o dano é creditado a ela); null = ninguém (esqueleto da região).
var owner_id: Variant = 0
var kind := "caltrop"
var x := 0.0
var y := 0.0
var damage := 0.0
var hold_ticks := 0
var radius := 0.5
## Números próprios de cada tipo (ver acima); vazio nos tipos antigos.
var params: Dictionary = {}
