class_name Economy
extends RefCounted
## Regras do ouro: juros e renda de fim de onda, ouro por abate e o fechamento da onda. Sem
## estado próprio; tudo vive em `RunState` (porte de `economy.ts`).


## Juros sobre o ouro guardado: porcentagem arredondada para baixo, com teto (-1 = o da economia).
static func interest_for(economy: EconomyData, gold: int, cap: int = -1) -> int:
	if cap < 0:
		cap = economy.interest_cap
	return mini(cap, int(floorf(float(maxi(0, gold) * economy.interest_percent) / 100.0)))


## Teto dos juros na run: o da economia ou o do bônus "Cofre maior" (T24).
static func interest_cap_for(economy: EconomyData, state: Object) -> int:
	var cap: Variant = RewardMods.of(state).interest_cap
	return int(cap) if cap != null else economy.interest_cap


## Renda de fim da onda `wave` (a primeira onda é a 1): `base + perWave × wave`, mais a
## "Renda extra" das recompensas (`extra`).
static func wave_bonus_for(economy: EconomyData, wave: int, extra: int = 0) -> int:
	return economy.wave_bonus_base + economy.wave_bonus_per_wave * wave + extra


## Bônus da chamada antecipada: fixo por onda já ativa (chamada e não fechada) no momento da
## chamada. Sem onda ativa não é antecipada (0).
static func early_bonus_for(economy: EconomyData, active_waves: int) -> int:
	return economy.early_per_active_wave * maxi(0, active_waves)


## Fecha uma onda: juros primeiro, sobre o ouro guardado; depois a renda; o bônus da chamada
## antecipada daquela onda, se houver; e a loja nova grátis. É o que o fim de cada onda real e o
## "Encerrar onda" do debug chamam. Os bônus das recompensas (T24) entram no teto dos juros, na
## renda, na raridade e nos rerolls grátis da loja nova; a tela de recompensa sai do `waveEnded`
## (`Rewards.create_reward_open_system`).
static func end_wave(ctx: TickContext, economy: EconomyData, towers: TowerData, early_bonus: int = 0) -> void:
	var state := ctx.state
	state.wave += 1
	var mods := RewardMods.of(state)
	var interest := interest_for(economy, state.gold, interest_cap_for(economy, state))
	Gold.earn_gold(state, interest)
	var bonus := wave_bonus_for(economy, state.wave, mods.income_per_wave)
	Gold.earn_gold(state, bonus)
	Gold.earn_gold(state, early_bonus)
	state.shop = Shop.new_shop(ctx.rng, economy, towers, Shop.shop_rarity_level(state), false,
			mods.free_rerolls_per_shop, Shop.common_only(economy, state.wave))
	ctx.emit({
		"type": "waveEnded",
		"tick": state.tick,
		"wave": state.wave,
		"interest": interest,
		"bonus": bonus,
		"earlyBonus": early_bonus,
		"gold": state.gold,
	})
	ctx.emit({"type": "shopChanged", "tick": state.tick, "reason": "newWave"})


## Ouro de um abate: o `gold` do tipo (`enemies.json`) mais `killGold.base + killGold.perWave × ceil(onda / waveStep)`
## (com waveStep 5: 1 de ouro por inimigo nas ondas 1 a 5, 2 nas 6 a 10, ...). Inimigo sem onda (debug, onda 0) não paga o extra.
static func kill_gold_for(economy: EconomyData, type_gold: float, wave: int) -> float:
	if wave <= 0:
		return type_gold
	return type_gold + float(economy.kill_gold_base + economy.kill_gold_per_wave * ceili(float(wave) / float(economy.kill_gold_wave_step)))


## Sistema de ouro, depois dos gatilhos: soma o ouro de cada inimigo morto no tick (por qualquer
## autor, inclusive o núcleo; ver `kill_gold_for`). Emite `goldChanged` uma vez por tick com o saldo
## final, nunca um por abate. Roda também congelado (T24): o reroll das cartas gasta ouro.
static func create_gold_system(enemies: EnemyData, economy: EconomyData) -> Callable:
	return Simulation.runs_while_frozen(func(ctx: TickContext) -> void:
		var state := ctx.state
		var kill_gold := 0.0
		for event: Dictionary in ctx.tick_events:
			if event["type"] == "enemyKilled":
				kill_gold += kill_gold_for(economy, enemies.get_type(event["enemyType"]).gold, int(event["wave"]))
		if kill_gold > 0.0:
			Gold.earn_gold(state, int(kill_gold))
		if state.gold != state.reported_gold:
			ctx.emit({
				"type": "goldChanged",
				"tick": state.tick,
				"gold": state.gold,
				"delta": state.gold - state.reported_gold,
			})
			state.reported_gold = state.gold)
