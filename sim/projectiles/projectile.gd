class_name Projectile
extends MutablePoint
## Um projétil do pool (porte de `Projectile` em `projectiles/pool.ts`). `x`/`y` vêm de MutablePoint.

## Índice fixo do objeto no pool.
var slot: int
var active := false
var id := 0
## Quem disparou (id da torre).
var source_id := 0
## Cadeia do gatilho que disparou o tiro (0 = tiro normal, sem cadeia).
var chain_id := 0
## Torre que começou essa cadeia (null = núcleo ou sem cadeia).
var origin_tower_id: Variant = null
## Alvo: id do inimigo e o slot onde ele mora (o id confirma que é o mesmo).
var target_id := 0
var target_slot := 0
## Última posição conhecida do alvo. Se ele morrer (ou chegar ao núcleo) antes do
## impacto, é o ponto de onde sai a busca por um alvo novo.
var target_x := 0.0
var target_y := 0.0
## Já trocou de alvo uma vez (não troca de novo).
var retargeted := false
var damage := 0.0
## Tipo da torre que atirou, quando o tipo aplica efeitos no acerto (`onHit`); "" = nenhum.
var status_type := ""
## Raio do tiro em área, em casas; 0 = tiro único.
var area_radius := 0.0
## Velocidade em casas por segundo.
var speed := 0.0
## Posição no tick anterior (a atual é x/y).
var prev_x := 0.0
var prev_y := 0.0


func _init(p_slot: int = 0) -> void:
	slot = p_slot
