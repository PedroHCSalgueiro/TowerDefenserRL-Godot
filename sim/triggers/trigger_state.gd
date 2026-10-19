class_name TriggerState
extends RefCounted
## Parte do `RunState` que pertence ao motor de gatilhos: a fila de gatilhos pendentes
## (que atravessa ticks e vai para o save), a ordem global de disparo e os contadores do
## último tick, lidos pelo painel de debug (porte de `triggerState.ts`).

## Um gatilho que já foi acionado ("quando" cumprido) e espera executar o "o quê".
class PendingTrigger:
	extends RefCounted
	## Torre cujo gatilho vai executar (destino).
	var tower_id: int
	## Quem causou (origem): a própria torre, a vizinha que abateu ou ativou; null = núcleo.
	var source_tower_id: Variant = null
	## Peso do fato: 1 normal, 2 no abate duplo (vale para as cargas). 0 = só descarregar
	## cargas guardadas (próximo tiro da própria torre com alvo).
	var weight: float
	## Profundidade na cadeia: 1 = causado por algo fora do motor (tiro normal, projétil, núcleo).
	var depth: int
	## Profundidade contada só neste tick (limite `maxChainDepthPerTick`).
	var tick_depth: int
	## Ponto do fato (onde o inimigo morreu), se houver.
	var has_point: bool
	var x: float
	var y: float
	## > 0: não é o "o quê" da torre, é a explosão de uma execução (Carrasco ★3) no ponto
	## (x, y), com este raio e `blast_percent` do dano da torre. Cada explosão é uma entrada
	## própria: conta no orçamento e na profundidade.
	var blast_radius: float
	var blast_percent: float
	## Cadeia a que a entrada pertence (`TriggerState.chains`).
	var chain_id: int
	## Torre que começou a cadeia (null = núcleo).
	var origin_tower_id: Variant = null

## Uma cadeia viva: tudo que nasceu de um mesmo fato inicial (tiro normal, morte ou
## ativação). Fica em `TriggerState.chains` enquanto houver entrada dela na fila ou
## projétil dela no ar.
class ChainRecord:
	extends RefCounted
	var id: int
	var origin_tower_id: Variant = null
	## Gatilhos com efeito visível executados na cadeia até agora (o "x7").
	var length := 0

	func _init(p_id: int = 0, p_origin: Variant = null) -> void:
		id = p_id
		origin_tower_id = p_origin

class TriggerTickStats:
	extends RefCounted
	## Gatilhos executados no tick (`triggerFired`).
	var fired := 0
	## Maior profundidade de cadeia executada no tick (0 = nenhuma).
	var max_depth := 0
	## Gatilhos que ficaram na fila para o tick seguinte.
	var deferred := 0
	## Gatilhos descartados no tick por passar do teto da fila.
	var dropped := 0

## Fila FIFO dos gatilhos pendentes (sobras do tick anterior primeiro).
var queue: Array[PendingTrigger] = []
## Próximo número da ordem global de disparo (`Tower.last_effect.seq`).
var next_seq := 1
var last_tick := TriggerTickStats.new()
## Total de descartados na run (deve ficar em zero).
var dropped_total := 0
## Próximo id de cadeia (começa em 1; 0 = sem cadeia).
var next_chain_id := 1
## Cadeias vivas, em ordem de id.
var chains: Array[ChainRecord] = []
