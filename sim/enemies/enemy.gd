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
## Efeitos de estado (ver `Status`): ticks que faltam, 0 = sem o efeito.
## Lento: anda `slow_percent`% mais devagar. Atordoado: não anda. Sangramento: `bleed_damage` de dano
## por tick (sem armadura), creditado à torre `bleed_source` (id; null = ninguém).
var slow_percent := 0.0
var slow_ticks := 0
var stun_ticks := 0
var bleed_damage := 0.0
var bleed_ticks := 0
var bleed_source: Variant = null
## Envenenado (nuvem de peste da Agatha): `poison_damage` por tick (sem armadura) por `poison_ticks`, creditado à
## torre `poison_source`. Separado do Sangramento: os dois podem valer ao mesmo tempo.
var poison_damage := 0.0
var poison_ticks := 0
var poison_source: Variant = null
## Marcado (Caçadores): id da torre -> ticks que faltam, uma marca por Caçador, na ordem em que foram postas.
var marks: Dictionary = {}
## Amaldiçoado (Mama Zuri): vazio = não; senão {"ticks", "duration", "percent", "spread", "radius",
## "jumps", "source"} (ver `Status.apply_curse`).
var curse: Dictionary = {}
## Entrada por onde entrou (0 = a principal; as outras, das linhas do mapa que cresce).
var entrance := 0

# Cache de desempenho (derivado; não faz parte do estado da simulação): preenchido no spawn.
## Dados do tipo, rota, comprimento da rota, segmento atual da rota e distância por tick.
var type_data: EnemyData.EnemyType = null
var route: Route = null
var route_length := 0.0
var seg := 0
var step := -1.0


func _init(p_slot: int = 0) -> void:
	slot = p_slot
