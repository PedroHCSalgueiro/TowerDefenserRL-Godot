class_name WaveSystems
extends RefCounted
## Ondas: chamar a próxima (inclusive antecipada, com outras em andamento), fazer nascer os
## inimigos na hora certa, fechar as ondas em ordem quando acabam e declarar a vitória no fim da
## última (porte de `waves.ts`).
##
## Cada inimigo pertence à sua onda (`Enemy.wave`). Cada onda fecha pelo mesmo `Economy.end_wave`
## (juros, bônus, bônus antecipado e loja nova) que o botão "Encerrar onda" do debug.


## Chefões na lista da onda. Calculado só quando é preciso (e guardado no cronograma).
static func boss_count_of(schedule: WaveSchedule, enemies: EnemyData) -> int:
	if schedule.boss_count < 0:
		var count := 0
		for e in schedule.entries:
			if enemies.get_type(e.type).boss:
				count += 1
		schedule.boss_count = count
	return schedule.boss_count


## Por que a onda não pode ser chamada agora: "over" = run encerrada ou sem ondas restantes. Só a
## onda com chefão exige o mapa limpo: "active" = há onda em andamento; "enemies" = ainda há
## inimigo vivo no mapa. "" = pode chamar.
static func call_wave_refusal(state: Object, schedules: Array[WaveSchedule], enemies: EnemyData) -> String:
	var next := WaveState.next_wave_number(state)
	var schedule: WaveSchedule = schedules[next - 1] if next - 1 < schedules.size() else null
	if state.status != "playing" or schedule == null:
		return "over"
	if boss_count_of(schedule, enemies) > 0:
		if not state.waves.active.is_empty():
			return "active"
		if state.enemies.active_count > 0:
			return "enemies"
	return ""


## Tipo da onda pelos dados: com chefão é "boss" (mesmo com elites), com elite é "elite".
static func wave_kind_of(schedule: WaveSchedule, enemies: EnemyData) -> String:
	if boss_count_of(schedule, enemies) > 0:
		return "boss"
	for e in schedule.entries:
		if e.elite:
			return "elite"
	return "normal"


## Janela do bônus de chamada antecipada (T23), contada pelos nascimentos da onda mais recente em
## andamento. Devolve {"open": bool, "remaining": int, "spent": float}, ou {} sem onda ativa (a
## chamada não é antecipada).
## - open: ainda dá bônus chamar agora (menos de `windowPercent` da onda mais recente nasceu);
## - remaining: nascimentos que faltam para a janela fechar (0 = fechada);
## - spent: fração da janela já gasta, de 0 a 1 (para a barra do botão).
static func early_bonus_window(state: Object, schedules: Array[WaveSchedule], economy: EconomyData) -> Dictionary:
	if state.waves.active.is_empty():
		return {}
	var newest: WaveState.ActiveWave = state.waves.active[state.waves.active.size() - 1]
	var total := schedules[newest.wave - 1].entries.size() if newest.wave - 1 < schedules.size() else 0
	var percent := economy.early_window_percent
	# Fecha no primeiro nascimento que leva a onda a `percent`% ou mais.
	var closes_at := int(ceilf(float(total * percent) / 100.0))
	var remaining := maxi(0, closes_at - newest.spawned)
	return {
		"open": newest.spawned * 100 < total * percent,
		"remaining": remaining,
		"spent": minf(1.0, float(newest.spawned) / float(closes_at)) if closes_at > 0 else 1.0,
	}


## Inimigos das ondas em andamento que ainda não nasceram ou ainda estão vivos (0 sem onda).
static func wave_remaining(state: Object, schedules: Array[WaveSchedule]) -> int:
	var remaining := 0
	for wave: WaveState.ActiveWave in state.waves.active:
		var total := schedules[wave.wave - 1].entries.size() if wave.wave - 1 < schedules.size() else 0
		remaining += total - wave.spawned
	# Inimigo com onda está numa onda ativa: a onda só fecha sem nenhum vivo.
	for enemy: Enemy in state.enemies.slots:
		if enemy.active and enemy.wave != 0:
			remaining += 1
	return remaining


## Vivos por onda: `alive[n]` = inimigos vivos da onda `n` (índice 0 = sem onda).
static func _count_alive_by_wave(state: Object, wave_count: int) -> PackedInt32Array:
	var alive := PackedInt32Array()
	alive.resize(wave_count + 1)
	for enemy: Enemy in state.enemies.slots:
		if enemy.active and enemy.wave < alive.size():
			alive[enemy.wave] += 1
	return alive


static func _has_unspawned(wave: WaveState.ActiveWave, schedules: Array[WaveSchedule]) -> bool:
	var total := schedules[wave.wave - 1].entries.size() if wave.wave - 1 < schedules.size() else 0
	return wave.spawned < total


## Ação do jogador: chama a próxima onda. Com outra onda ativa é chamada antecipada: o bônus fica
## guardado na onda e só é pago quando ela fechar. O bônus só vale com a janela aberta
## (`early_bonus_window`); fora dela, a chamada antecipada sai com bônus 0.
static func call_wave(ctx: TickContext, schedules: Array[WaveSchedule], enemies: EnemyData, economy: EconomyData) -> void:
	var state := ctx.state
	var reason := call_wave_refusal(state, schedules, enemies)
	if reason != "":
		ctx.emit({"type": "callWaveRefused", "tick": state.tick, "reason": reason})
		return
	var wave := WaveState.next_wave_number(state)
	var early: bool = not state.waves.active.is_empty()
	var window := early_bonus_window(state, schedules, economy)
	var early_bonus := 0
	if not window.is_empty() and window["open"]:
		early_bonus = Economy.early_bonus_for(economy, state.waves.active.size())
	var active := WaveState.ActiveWave.new()
	active.wave = wave
	active.start_tick = state.tick
	active.early_bonus = early_bonus
	state.waves.active.append(active)
	ctx.emit({"type": "waveStarted", "tick": state.tick, "wave": wave, "early": early, "earlyBonus": early_bonus})


## Debug ("Encerrar onda"): com ondas em andamento, tira do mapa os inimigos e projéteis (sem ouro
## de abate), esquece os nascimentos que faltam e fecha todas pelo `end_wave`, em ordem, pagando os
## bônus antecipados. Sem onda, fecha a próxima. Depois da última onda, não faz nada (e nunca é
## vitória).
static func force_end_wave(ctx: TickContext, schedules: Array[WaveSchedule], economy: EconomyData, towers: TowerData) -> void:
	var state := ctx.state
	var active: Array[WaveState.ActiveWave] = state.waves.active.duplicate()
	if active.is_empty():
		if state.wave < schedules.size():
			Economy.end_wave(ctx, economy, towers)
		return
	state.enemies.release_all()
	state.projectiles.release_all()
	state.waves.active.clear()
	for wave in active:
		Economy.end_wave(ctx, economy, towers, wave.early_bonus)


## Debug ("Pular para onda"): sem ondas em andamento, fecha ondas pelo `end_wave` (com juros, bônus
## e loja nova de cada uma) até a próxima a chamar ser `target`.
static func skip_to_wave(ctx: TickContext, schedules: Array[WaveSchedule], economy: EconomyData,
		towers: TowerData, target: float) -> void:
	var state := ctx.state
	if not state.waves.active.is_empty() or not is_finite(target):
		return
	var last := mini(int(floorf(target)), schedules.size()) - 1
	while state.wave < last:
		Economy.end_wave(ctx, economy, towers)


## Nascimentos das ondas em andamento, logo depois das ações: todo inimigo cujo tick já chegou nasce
## na entrada, com a vida multiplicada pelo `hp_multiplier` da onda (o chefão fica com a vida dos
## dados) e, no elite, pelo multiplicador do elite. Entre ondas diferentes, nasce primeiro quem
## venceu antes; no empate, a onda mais antiga.
##
## Fila invisível: com `max_active_enemies` ativos, os próximos esperam na entrada, nessa mesma
## ordem, e nascem quando abrir espaço.
##
## Mapa com mais de uma entrada (salas do mapa que cresce): os inimigos de cada onda se alternam entre
## as entradas, pela posição na lista da onda (o 1º na principal, o 2º na primeira sala, ...).
static func create_wave_spawn_system(routes: Dictionary, enemies: EnemyData,
		schedules: Array[WaveSchedule], max_active_enemies: int, map: SimMap = null) -> Callable:
	return func(ctx: TickContext) -> void:
		var state := ctx.state
		if state.status != "playing":
			return
		var active: Array[WaveState.ActiveWave] = state.waves.active
		while state.enemies.active_count < max_active_enemies:
			var next: WaveState.ActiveWave = null
			var next_tick := INF
			for wave in active:
				if wave.wave - 1 >= schedules.size():
					continue
				var entries := schedules[wave.wave - 1].entries
				if wave.spawned >= entries.size():
					continue
				var due := wave.start_tick + entries[wave.spawned].tick
				if due <= state.tick and float(due) < next_tick:
					next = wave
					next_tick = float(due)
			if next == null:
				break
			var schedule := schedules[next.wave - 1]
			var entry := schedule.entries[next.spawned]
			var multiplier := 1.0 if enemies.get_type(entry.type).boss else schedule.hp_multiplier
			var entrance := next.spawned % map.entrance_count() if map != null else 0
			EnemySystems.spawn_enemy(ctx, routes, enemies, entry.type, 0.0, multiplier, next.wave, entry.elite,
					entrance)
			next.spawned += 1


## Depois do ouro: conta os abates do tick e fecha as ondas em ordem. A mais antiga fecha quando
## todos os inimigos dela já nasceram e nenhum está vivo; uma onda só fecha depois da anterior
## (várias podem fechar no mesmo tick). No fim da última onda, com os chefões mortos, a run é
## vencida (depois do `end_wave`).
static func create_wave_progress_system(enemies: EnemyData, schedules: Array[WaveSchedule],
		economy: EconomyData, towers: TowerData) -> Callable:
	return func(ctx: TickContext) -> void:
		var state := ctx.state
		var active: Array[WaveState.ActiveWave] = state.waves.active
		for event: Dictionary in ctx.tick_events:
			if event["type"] != "enemyKilled":
				continue
			state.stats.kills += 1
			# Cada morte é uma alma (Cripta Cinzenta); as almas zeram no fim da onda.
			state.souls += 1
			if event["wave"] == 0 or not enemies.get_type(event["enemyType"]).boss:
				continue
			for w in active:
				if w.wave == event["wave"]:
					w.bosses_killed += 1
					break
		if active.is_empty() or state.status != "playing":
			return
		var alive := _count_alive_by_wave(state, schedules.size())
		while not active.is_empty():
			var wave := active[0]
			if _has_unspawned(wave, schedules) or (wave.wave < alive.size() and alive[wave.wave] > 0):
				return
			active.pop_front()
			Economy.end_wave(ctx, economy, towers, wave.early_bonus)
			var boss_count := boss_count_of(schedules[wave.wave - 1], enemies) if wave.wave - 1 < schedules.size() else 0
			if state.wave == schedules.size() and wave.bosses_killed >= boss_count:
				state.status = "won"
				ctx.emit({"type": "runWon", "tick": state.tick, "wave": state.wave})
				return
