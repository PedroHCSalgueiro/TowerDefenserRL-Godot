class_name WaveState
extends RefCounted
## Parte do `RunState` que acompanha as ondas em andamento (empilhadas desde a T14) — porte de
## `waveState.ts`.

## Uma onda chamada que ainda não fechou.
class ActiveWave:
	extends RefCounted
	## Número da onda (a primeira é a 1).
	var wave: int
	## Tick em que a onda foi chamada (os nascimentos contam a partir dele).
	var start_tick: int
	## Quantos inimigos da lista da onda já nasceram.
	var spawned := 0
	## Chefões da onda mortos até agora (a vitória pede todos).
	var bosses_killed := 0
	## Bônus da chamada antecipada, pago quando a onda fecha (0 = chamada com o mapa sem ondas).
	var early_bonus := 0

## Estatísticas da run, para as telas de vitória e derrota.
class RunStats:
	extends RefCounted
	## Todos os inimigos mortos, por qualquer autor (inclusive o núcleo).
	var kills := 0
	## Maior cadeia da run, em gatilhos com efeito visível (T16).
	var longest_chain := 0
	## Ouro ganho na run (T17): juros, bônus, bônus antecipado e ouro de abate. Fica fora a
	## devolução da venda e o "+500 ouro" do debug. Desde a T24, inclui o ouro das cadeias.
	var gold_earned := 0
	## Ouro gasto no reroll das cartas de recompensa (T24; sem o do ouro infinito).
	var reward_reroll_gold := 0
	## Ouro ganho pelo bônus "Cadeia lucrativa" (T24); também está em `gold_earned`.
	var chain_gold := 0

## Ondas chamadas que ainda não fecharam, da mais antiga para a mais nova. Fecham em ordem: a
## primeira é sempre a de número `RunState.wave + 1`.
var active: Array[ActiveWave] = []


## Número da próxima onda a chamar (a primeira é a 1). `state` tem `wave` e `waves.active`.
static func next_wave_number(state: Object) -> int:
	return state.wave + state.waves.active.size() + 1
