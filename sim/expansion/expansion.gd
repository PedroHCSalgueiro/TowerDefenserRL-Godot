class_name Expansion
extends RefCounted
## Mapa que cresce (Mini-GDD, Sistema 7): no respiro depois de cada chefão (e da tela de recompensa),
## o jogador escolhe qual parede derrubar entre até `choices` salas vizinhas da área aberta. A sala
## escolhida abre casas para construir; a sala com entrada traz um caminho novo de inimigos, e as ondas
## passam a alternar as entradas (um inimigo por entrada, na ordem: principal, primeira sala, ...).
##
## Como as recompensas: com a escolha aberta a simulação fica congelada; no fim do tempo a simulação
## escolhe sozinha pelo RNG das paredes. Só vale no mapa das salas (`ExpansionData.for_map`).
##
## O mapa (`SimMap`) e as rotas são mudados no lugar quando a sala abre; o estado guarda só os ids
## das salas abertas, e `sync` reaplica no mapa o que faltar (depois de restaurar um save).


## Salas que podem ser oferecidas: fechadas e encostadas (em cima, embaixo ou dos lados) na área aberta.
static func candidates(map: SimMap, data: ExpansionData, state: Object) -> Array[String]:
	var out: Array[String] = []
	for room in data.rooms:
		if state.expansion.opened.has(room.id) or map.applied_rooms.has(room.id):
			continue
		if _touches_open(map, room):
			out.append(room.id)
	return out


static func _touches_open(map: SimMap, room: ExpansionData.Room) -> bool:
	var cells: Array[Vector2i] = []
	cells.append_array(room.cells)
	cells.append_array(room.entrance_cells)
	for cell in cells:
		for step: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			if map.is_open(cell + step):
				return true
	return false


## Abre a sala no mapa (e as rotas da entrada nova, se houver). Já aberta: nada.
static func apply_room(map: SimMap, routes: Variant, room: ExpansionData.Room) -> void:
	if room == null or map.applied_rooms.has(room.id):
		return
	map.applied_rooms.append(room.id)
	map.open_cells(room.cells)
	if room.has_entrance():
		map.add_entrance(room.entrance_cells, room.join_index)
		if routes != null:
			Route.add_entrance_routes(map, routes)


## Reaplica no mapa as salas abertas que ele ainda não tem (save restaurado), na ordem.
static func sync(map: SimMap, routes: Variant, data: ExpansionData, opened: Array[String]) -> void:
	if map.applied_rooms.size() == opened.size():
		return
	for id in opened:
		apply_room(map, routes, data.get_room(id))


static func choose_ticks(data: ExpansionData, ticks_per_second: float) -> int:
	return maxi(1, SimMath.js_round(data.choose_seconds * ticks_per_second))


## Abre a escolha com até `choices` salas sorteadas. Sem sala possível: não abre (false).
static func open_screen(ctx: TickContext, map: SimMap, data: ExpansionData, wave: int, ticks_per_second: float) -> bool:
	var state := ctx.state
	var pool: Array = candidates(map, data, state)
	if pool.is_empty():
		return false
	var options: Array = Rng.new(state.expansion).shuffle(pool.duplicate()).slice(0, data.choices)
	var screen := ExpansionState.ExpansionScreen.new()
	screen.wave = wave
	screen.options = options
	screen.ticks_left = choose_ticks(data, ticks_per_second)
	state.expansion.screen = screen
	ctx.emit({"type": "expansionOpened", "tick": state.tick, "wave": wave, "options": options.duplicate()})
	return true


## Escolhe a opção `index`: a sala abre e a escolha fecha.
static func choose(ctx: TickContext, map: SimMap, routes: Dictionary, data: ExpansionData, index: int,
		auto: bool = false) -> bool:
	var state := ctx.state
	var screen: ExpansionState.ExpansionScreen = state.expansion.screen
	if screen == null or index < 0 or index >= screen.options.size():
		return false
	var room := data.get_room(screen.options[index])
	state.expansion.opened.append(room.id)
	state.expansion.opened_waves.append(screen.wave)
	state.expansion.screen = null
	apply_room(map, routes, room)
	ctx.emit({"type": "expansionChosen", "tick": state.tick, "wave": screen.wave, "roomId": room.id,
			"entrance": room.has_entrance(), "auto": auto})
	return true


## Relógio da escolha, antes das ações: cada tick congelado gasta um tick.
static func create_clock_system() -> Callable:
	return Simulation.runs_while_frozen(func(ctx: TickContext) -> void:
		var screen: ExpansionState.ExpansionScreen = ctx.state.expansion.screen
		if screen != null and screen.ticks_left > 0:
			screen.ticks_left -= 1)


## Ações da escolha (logo depois das outras ações): `chooseExpansion{index}` e `debugOpenExpansion`.
## Antes, reaplica as salas do estado que o mapa ainda não tem.
static func create_command_system(map: SimMap, routes: Dictionary, data: ExpansionData) -> Callable:
	return Simulation.runs_while_frozen(func(ctx: TickContext) -> void:
		sync(map, routes, data, ctx.state.expansion.opened)
		Route.add_entrance_routes(map, routes)
		for command: Dictionary in ctx.commands:
			if command["type"] == "chooseExpansion":
				choose(ctx, map, routes, data, int(command["index"]))
			elif command["type"] == "debugOpenExpansion":
				# Abre no fim do tick (`create_open_system`), depois das telas que estiverem abertas.
				ctx.state.expansion.pending += 1)


## Tempo esgotado, logo depois das ações: escolhe uma sala pelo RNG das paredes.
static func create_timeout_system(map: SimMap, routes: Dictionary, data: ExpansionData) -> Callable:
	return Simulation.runs_while_frozen(func(ctx: TickContext) -> void:
		var screen: ExpansionState.ExpansionScreen = ctx.state.expansion.screen
		if screen == null or screen.ticks_left > 0:
			return
		var index := Rng.new(ctx.state.expansion).next_int(0, screen.options.size() - 1)
		choose(ctx, map, routes, data, index, true))


## A onda dá a escolha da parede ao fechar? As de `afterWaves`; sem a lista, as com chefão.
static func gives_choice(data: ExpansionData, wave: int, schedules: Array[WaveSchedule], enemies: EnemyData) -> bool:
	if not data.after_waves.is_empty():
		return data.after_waves.has(wave)
	return wave - 1 < schedules.size() and WaveSystems.boss_count_of(schedules[wave - 1], enemies) > 0


## Abertura, depois da abertura das recompensas: cada onda que dá escolha (`gives_choice`) e fechou no
## tick guarda uma escolha; ela abre quando não há tela de recompensa aberta nem na fila.
static func create_open_system(map: SimMap, data: ExpansionData, schedules: Array[WaveSchedule],
		enemies: EnemyData, ticks_per_second: float) -> Callable:
	return Simulation.runs_while_frozen(func(ctx: TickContext) -> void:
		var state := ctx.state
		for event: Dictionary in ctx.tick_events:
			if event["type"] == "waveEnded" and gives_choice(data, event["wave"], schedules, enemies):
				state.expansion.pending += 1
		if state.expansion.pending <= 0 or state.expansion.screen != null or state.status != "playing":
			return
		if state.rewards.screen != null or not state.rewards.queue.is_empty():
			return
		state.expansion.pending -= 1
		if not open_screen(ctx, map, data, state.wave, ticks_per_second):
			state.expansion.pending = 0)
