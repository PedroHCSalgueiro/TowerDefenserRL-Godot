class_name Rewards
extends RefCounted
## Recompensas de escolha (T24): ao fechar as ondas de `rewards.json`, o jogador escolhe 1 de
## N bônus permanentes para a run (porte de `rewards.ts`).
##
## - **Fila:** cada onda com recompensa que fecha entra na fila, na ordem em que fechou (várias
##   no mesmo tick = várias telas, uma depois da outra).
## - **Tela:** as cartas são sorteadas quando a tela abre, pelo RNG próprio das recompensas, com
##   chance igual entre os bônus disponíveis e sem repetir na tela. Não repetíveis já escolhidos e
##   bônus que não podem mais ter efeito ficam de fora.
## - **Pausa:** com a tela aberta a simulação fica congelada (`Simulation`): o tick não anda e só
##   rodam os sistemas marcados com `runs_while_frozen`.
## - **Tempo:** cada tick congelado gasta um tick da tela; no zero, a simulação escolhe uma carta
##   pelo RNG das recompensas.
## - **Reroll:** `baseCost` + `costStep` × rerolls já feitos na tela; volta ao custo base na tela
##   nova e reinicia o tempo. Não repete as cartas que estavam na tela quando há outras suficientes.
##
## Sistemas, na ordem do tick: relógio (antes das ações), tempo esgotado (logo depois das ações,
## para a escolha do jogador valer no mesmo tick) e abertura (depois do fim das ondas). Uma tela
## aberta só começa a contar no tick seguinte, então toda tela tem o tempo inteiro.


## Tempo da tela, em ticks.
static func choose_ticks(data: RewardData, ticks_per_second: float) -> int:
	return maxi(1, SimMath.js_round(data.choose_seconds * ticks_per_second))


## Custo do próximo reroll da tela.
static func reward_reroll_cost(data: RewardData, screen: RewardsState.RewardScreen) -> int:
	return data.reroll_base_cost + data.reroll_cost_step * screen.rerolls


## Classes que ainda podem sair no coringa (sem coringa escolhido, se não for repetível).
static func free_wildcard_classes(state: Object, reward: RewardData.RewardDef, classes: ClassData) -> Array[String]:
	var out: Array[String] = []
	if reward.repeatable:
		out.assign(classes.ids)
		return out
	var used := {}
	for t: RewardsState.TakenReward in state.rewards.taken:
		if t.id == reward.id:
			used[t.class_id] = true
	for id in classes.ids:
		if not used.has(id):
			out.append(id)
	return out


## Bônus que podem sair agora, na ordem dos dados. Fora: não repetíveis já escolhidos (o coringa,
## por classe), a raridade com o núcleo já no último nível da tabela de chances, e o coringa sem
## classe livre.
static func available_rewards(state: Object, data: RewardData, economy: EconomyData, classes: ClassData) -> Array[RewardData.RewardDef]:
	var taken := {}
	for t: RewardsState.TakenReward in state.rewards.taken:
		taken[t.id] = true
	var out: Array[RewardData.RewardDef] = []
	for reward in data.rewards:
		if reward.effect["kind"] == "classWildcard":
			if not free_wildcard_classes(state, reward, classes).is_empty():
				out.append(reward)
			continue
		if not reward.repeatable and taken.has(reward.id):
			continue
		if reward.effect["kind"] == "shopRarityLevels":
			if state.nexus.level < economy.shop_rarity_chances.size():
				out.append(reward)
			continue
		out.append(reward)
	return out


## Sorteia as cartas: embaralha os disponíveis e pega as primeiras. Com `exclude` (reroll), tira
## essas cartas se ainda sobrarem `choices` outras. O coringa sorteia a classe entre as livres.
## Devolve [{"id": String, "classId": String|null}, ...].
static func draw_reward_options(rng: Rng, state: Object, data: RewardData, economy: EconomyData,
		classes: ClassData, exclude: Array = []) -> Array:
	var pool: Array = available_rewards(state, data, economy, classes)
	var fresh := pool.filter(func(r: RewardData.RewardDef) -> bool: return not exclude.has(r.id))
	if fresh.size() >= data.choices:
		pool = fresh
	var shuffled := rng.shuffle(pool.duplicate())
	var picked := shuffled.slice(0, data.choices)
	var options: Array = []
	for reward: RewardData.RewardDef in picked:
		var class_id: Variant = null
		if reward.effect["kind"] == "classWildcard":
			class_id = rng.pick(free_wildcard_classes(state, reward, classes))
		options.append({"id": reward.id, "classId": class_id})
	return options


## Abre a próxima tela da fila, se não houver nenhuma aberta.
static func open_next_reward_screen(ctx: TickContext, data: RewardData, economy: EconomyData,
		classes: ClassData, ticks_per_second: float) -> bool:
	var state := ctx.state
	var rewards: RewardsState = state.rewards
	if rewards.screen != null or rewards.queue.is_empty() or state.status != "playing":
		return false
	var wave: int = rewards.queue.pop_front()
	var options := draw_reward_options(Rng.new(rewards), state, data, economy, classes)
	var screen := RewardsState.RewardScreen.new()
	screen.wave = wave
	screen.options = options
	screen.rerolls = 0
	screen.ticks_left = choose_ticks(data, ticks_per_second)
	rewards.screen = screen
	ctx.emit({
		"type": "rewardOpened",
		"tick": state.tick,
		"wave": wave,
		"options": options.duplicate(true),
		"queued": rewards.queue.size(),
	})
	return true


## Escolhe a carta `index` da tela: o bônus entra na run e a tela fecha. Os efeitos de uma vez
## valem na hora (+vida com cura total, reroll grátis na loja aberta); os outros são lidos dos
## escolhidos (`RewardMods`).
static func choose_reward(ctx: TickContext, data: RewardData, index: int, auto: bool = false) -> bool:
	var state := ctx.state
	var screen: RewardsState.RewardScreen = state.rewards.screen
	if screen == null or index < 0 or index >= screen.options.size():
		return false
	var option: Dictionary = screen.options[index]
	state.rewards.taken.append(RewardsState.TakenReward.new(option["id"], option["classId"], screen.wave))
	state.rewards.screen = null
	var effect: Dictionary = data.get_reward(option["id"]).effect
	if effect["kind"] == "nexusMaxHp":
		state.nexus.max_hp += effect["amount"]
		state.nexus.hp = state.nexus.max_hp
	elif effect["kind"] == "freeRerollsPerShop":
		state.shop.free_rerolls += effect["count"]
	ctx.emit({
		"type": "rewardChosen",
		"tick": state.tick,
		"wave": screen.wave,
		"rewardId": option["id"],
		"classId": option["classId"],
		"auto": auto,
	})
	return true


## Troca as cartas pagando o custo atual (com o ouro infinito do debug, o ouro precisa bastar,
## mas não diminui). Reinicia o tempo da tela.
static func reroll_rewards(ctx: TickContext, data: RewardData, economy: EconomyData,
		classes: ClassData, ticks_per_second: float) -> bool:
	var state := ctx.state
	var screen: RewardsState.RewardScreen = state.rewards.screen
	if screen == null:
		return false
	var cost := reward_reroll_cost(data, screen)
	if state.gold < cost:
		return false
	if not state.debug.infinite_gold:
		state.stats.reward_reroll_gold += cost
	Gold.spend_gold(state, cost)
	var exclude: Array = screen.options.map(func(o: Dictionary) -> String: return o["id"])
	screen.options = draw_reward_options(Rng.new(state.rewards), state, data, economy, classes, exclude)
	screen.rerolls += 1
	screen.ticks_left = choose_ticks(data, ticks_per_second)
	ctx.emit({
		"type": "rewardRerolled",
		"tick": state.tick,
		"wave": screen.wave,
		"cost": cost,
		"options": screen.options.duplicate(true),
	})
	return true


## Relógio da tela, antes das ações: cada tick congelado gasta um tick da tela.
static func create_reward_clock_system() -> Callable:
	return Simulation.runs_while_frozen(func(ctx: TickContext) -> void:
		var screen: RewardsState.RewardScreen = ctx.state.rewards.screen
		if screen != null and screen.ticks_left > 0:
			screen.ticks_left -= 1)


## Tempo esgotado, logo depois das ações: a simulação escolhe uma carta pelo RNG das recompensas.
static func create_reward_timeout_system(data: RewardData) -> Callable:
	return Simulation.runs_while_frozen(func(ctx: TickContext) -> void:
		var screen: RewardsState.RewardScreen = ctx.state.rewards.screen
		if screen == null or screen.ticks_left > 0:
			return
		var index := Rng.new(ctx.state.rewards).next_int(0, screen.options.size() - 1)
		choose_reward(ctx, data, index, true))


## Abertura, depois do fim das ondas: as ondas com recompensa fechadas no tick (`waveEnded`, em
## ordem) entram na fila, e a primeira da fila abre se não houver tela aberta. Roda também
## congelado (a fila anda depois de cada escolha).
static func create_reward_open_system(data: RewardData, economy: EconomyData, classes: ClassData,
		ticks_per_second: float) -> Callable:
	return Simulation.runs_while_frozen(func(ctx: TickContext) -> void:
		var state := ctx.state
		for event: Dictionary in ctx.tick_events:
			if event["type"] == "waveEnded" and data.waves.has(event["wave"]):
				state.rewards.queue.append(event["wave"])
		open_next_reward_screen(ctx, data, economy, classes, ticks_per_second))


## Ouro do bônus de cadeia: quanto a cadeia rende ao chegar a `length` gatilhos visíveis.
static func chain_gold_at(state: Object, length: int) -> int:
	var chain: Variant = RewardMods.of(state).chain_gold
	if chain != null and length > 0 and length % int(chain["every"]) == 0:
		return int(chain["gold"])
	return 0
