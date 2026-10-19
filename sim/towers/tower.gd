class_name Tower
extends RefCounted
## Uma torre no mapa (porte de `Tower` em `placement.ts`). `x`/`y` são a casa (inteiros).

## O último "o quê" que a torre disparou, para uma vizinha copiar.
class LastEffect:
	extends RefCounted
	## O efeito com os números da torre que o disparou (Dictionary com "kind" etc.).
	var effect: Dictionary
	## Ordem global de disparo (`TriggerState.next_seq`): maior = mais recente.
	var seq: int

	func _init(p_effect: Dictionary = {}, p_seq: int = 0) -> void:
		effect = p_effect
		seq = p_seq

var id: int
var type: String
## Estrela (1 a 3 no protótipo). Sobe pela fusão na compra (T11); o debug pode posicionar já com estrela.
var star: int
## Casa da torre (inteiros).
var x: int
var y: int
## Ticks até o próximo disparo; 0 = pronta.
var cooldown_ticks := 0
## Progresso do gatilho "a cada N" (tiros ou abates).
var trigger_counter: float = 0.0
## Cargas do raio em cadeia.
var charges: float = 0.0
## Primeiro tick em que a torre pode ser ativada de novo por gatilho.
var activation_ready_tick := 0
## Ouro gasto na torre. A venda devolve parte dele e a fusão (T11) soma o das cópias.
## Torres do debug e de teste têm 0.
var invested := 0
## null = ainda não disparou nenhum "o quê" copiável.
var last_effect: LastEffect = null


func _init(p_id: int = 0, p_type: String = "", cell: Vector2i = Vector2i.ZERO, p_star: int = 1) -> void:
	id = p_id
	type = p_type
	star = p_star
	x = cell.x
	y = cell.y
