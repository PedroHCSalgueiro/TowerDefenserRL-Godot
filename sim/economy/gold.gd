class_name Gold
extends RefCounted
## Entrada e saída de ouro que dependem das trapaças (T17): gastar respeita o "ouro infinito"
## e ganhar soma em `stats.gold_earned` (porte de `gold.ts`).


## Paga `amount`; com o "ouro infinito" do debug ligado, o ouro não diminui.
static func spend_gold(state: Object, amount: int) -> void:
	if not state.debug.infinite_gold:
		state.gold -= amount


## Ouro ganho na run (juros, bônus e abates): entra no saldo e no total da run.
static func earn_gold(state: Object, amount: int) -> void:
	state.gold += amount
	state.stats.gold_earned += amount
