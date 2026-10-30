class_name Expansion
extends RefCounted
## Mapa que cresce com moldes (Mini-GDD, Sistema 7; regras em `ExpansionData`): depois das ondas de
## `afterWaves` (e da tela de recompensa) cai uma parede. As opções (uma por direção livre de cada
## linha) já vêm com os moldes sorteados pelo RNG das paredes. Com uma opção só (as primeiras paredes,
## que só seguem para a frente), o pedaço abre na hora; com mais, o jogador escolhe e a simulação fica
## congelada, como nas recompensas; no fim do tempo a simulação escolhe sozinha pelo mesmo RNG.
## No debug, a próxima parede pode dividir a linha principal (duas direções de uma vez).
##
## O mapa (`SimMap`) e as rotas são mudados no lugar; o estado guarda só os ids das aberturas, e `sync`
## reaplica no mapa o que faltar (depois de restaurar um save). Esticar uma linha põe casas no começo da
## rota dela: quem já está andando nela ganha a mesma distância a mais e fica no mesmo lugar.


## Aplica a abertura `id` no mapa (e nas rotas e no estado, se vierem). Impossível: false.
static func apply(map: SimMap, routes: Variant, data: ExpansionData, id: String, state: Object = null) -> bool:
	var o := data.opening(map.applied, id)
	if o == null:
		return false
	map.applied.append(id)
	map.open_cells(o.cells)
	var changed: Array[int] = []
	for step: Dictionary in o.steps:
		var cells: Array[Vector2i] = step["cells"]
		var line: int = step["line"]
		if line == -1:
			map.add_entrance(cells, map.path_cells.find(step["join"]))
			changed.append(map.entrance_count() - 1)
		elif line == 0:
			map.extend_main(cells)
			changed.append(0)
		else:
			map.extend_entrance(line, cells)
			changed.append(line)
	map.set_reserved(data.reserved_cells(map.applied))
	if routes != null:
		for i in o.steps.size():
			Route.set_entrance_routes(map, routes, changed[i])
			if state != null and int(o.steps[i]["line"]) != -1:
				_shift_line(state, routes, changed[i], float(o.steps[i]["cells"].size()))
	return true


## Quem anda na linha esticada (inimigos e, na principal, os esqueletos) ganha `added` casas de distância
## e passa para a rota nova: a rota velha é o fim da nova, então a posição não muda.
static func _shift_line(state: Object, routes: Dictionary, line: int, added: float) -> void:
	for enemy: Enemy in state.enemies.slots:
		if not enemy.active or enemy.entrance != line or enemy.route == null:
			continue
		var route: Route = routes[Route.key_for(enemy.type_data.movement, line)]
		enemy.distance += added
		enemy.route = route
		enemy.route_length = route.length
		enemy.seg = route.find_segment(enemy.distance)
	if line != 0:
		return
	for trap: Trap in state.traps:
		if trap.kind == "skeleton":
			trap.params["distance"] = float(trap.params["distance"]) + added


## Reaplica no mapa as aberturas que ele ainda não tem (save restaurado), na ordem.
static func sync(map: SimMap, routes: Variant, data: ExpansionData, opened: Array[String], state: Object = null) -> void:
	for i in range(map.applied.size(), opened.size()):
		apply(map, routes, data, opened[i], state)


static func choose_ticks(data: ExpansionData, ticks_per_second: float) -> int:
	return maxi(1, SimMath.js_round(data.choose_seconds * ticks_per_second))


## Derruba a próxima parede: sorteia as opções (com `split`, as de dividir a linha principal); com uma
## opção, abre na hora; com mais, abre a escolha. Sem parede (ou sem opção): false.
static func open_wall(ctx: TickContext, map: SimMap, routes: Dictionary, data: ExpansionData, wave: int,
		ticks_per_second: float, split: bool = false) -> bool:
	var state := ctx.state
	var rng := Rng.new(state.expansion)
	var options: Array = data.roll_split_options(state.expansion.opened, rng) if split \
			else data.roll_options(state.expansion.opened, rng)
	if options.is_empty():
		return false
	var screen := ExpansionState.ExpansionScreen.new()
	screen.wave = wave
	screen.options = options
	screen.ticks_left = choose_ticks(data, ticks_per_second)
	state.expansion.screen = screen
	if options.size() == 1:
		return choose(ctx, map, routes, data, 0, true)
	ctx.emit({"type": "expansionOpened", "tick": state.tick, "wave": wave, "options": options.duplicate()})
	return true


## Escolhe a opção `index`: o pedaço abre e a escolha fecha.
static func choose(ctx: TickContext, map: SimMap, routes: Dictionary, data: ExpansionData, index: int,
		auto: bool = false) -> bool:
	var state := ctx.state
	var screen: ExpansionState.ExpansionScreen = state.expansion.screen
	if screen == null or index < 0 or index >= screen.options.size():
		return false
	var id: String = screen.options[index]
	state.expansion.screen = null
	if not apply(map, routes, data, id, state):
		return false
	state.expansion.opened.append(id)
	state.expansion.opened_waves.append(screen.wave)
	ctx.emit({"type": "expansionChosen", "tick": state.tick, "wave": screen.wave, "optionId": id,
			"entrance": id.contains("+"),
			"auto": auto})
	return true


## Relógio da escolha, antes das ações: cada tick congelado gasta um tick.
static func create_clock_system() -> Callable:
	return Simulation.runs_while_frozen(func(ctx: TickContext) -> void:
		var screen: ExpansionState.ExpansionScreen = ctx.state.expansion.screen
		if screen != null and screen.ticks_left > 0:
			screen.ticks_left -= 1)


## Ações da escolha (logo depois das outras ações): `chooseExpansion{index}` e
## `debugOpenExpansion{split?}` (com `split`, a parede divide a linha principal).
## Antes, reaplica as aberturas do estado que o mapa ainda não tem.
static func create_command_system(map: SimMap, routes: Dictionary, data: ExpansionData) -> Callable:
	return Simulation.runs_while_frozen(func(ctx: TickContext) -> void:
		sync(map, routes, data, ctx.state.expansion.opened, ctx.state)
		Route.add_entrance_routes(map, routes)
		for command: Dictionary in ctx.commands:
			if command["type"] == "chooseExpansion":
				choose(ctx, map, routes, data, int(command["index"]))
			elif command["type"] == "debugOpenExpansion":
				# Abre no fim do tick (`create_open_system`), depois das telas que estiverem abertas.
				ctx.state.expansion.pending += 1
				if command.get("split", false):
					ctx.state.expansion.split_next = true)


## Tempo esgotado, logo depois das ações: escolhe uma opção pelo RNG das paredes.
static func create_timeout_system(map: SimMap, routes: Dictionary, data: ExpansionData) -> Callable:
	return Simulation.runs_while_frozen(func(ctx: TickContext) -> void:
		var screen: ExpansionState.ExpansionScreen = ctx.state.expansion.screen
		if screen == null or screen.ticks_left > 0:
			return
		var index := Rng.new(ctx.state.expansion).next_int(0, screen.options.size() - 1)
		choose(ctx, map, routes, data, index, true))


## A onda derruba uma parede ao fechar?
static func gives_choice(data: ExpansionData, wave: int) -> bool:
	return data.after_waves.has(wave)


## Abertura, depois da abertura das recompensas: cada onda de `afterWaves` que fechou no tick guarda uma
## parede; ela cai quando não há tela de recompensa aberta nem na fila.
static func create_open_system(map: SimMap, routes: Dictionary, data: ExpansionData, ticks_per_second: float) -> Callable:
	return Simulation.runs_while_frozen(func(ctx: TickContext) -> void:
		var state := ctx.state
		for event: Dictionary in ctx.tick_events:
			if event["type"] == "waveEnded" and gives_choice(data, event["wave"]):
				state.expansion.pending += 1
		if state.expansion.pending <= 0 or state.expansion.screen != null or state.status != "playing":
			return
		if state.rewards.screen != null or not state.rewards.queue.is_empty():
			return
		state.expansion.pending -= 1
		var split: bool = state.expansion.split_next
		state.expansion.split_next = false
		# Onda da parede: a de `afterWaves` que a deu (várias de uma vez ao pular ondas no debug).
		var wave: int = state.wave
		var k: int = state.expansion.opened.size()
		if k < data.after_waves.size() and data.after_waves[k] <= wave:
			wave = data.after_waves[k]
		if not open_wall(ctx, map, routes, data, wave, ticks_per_second, split):
			state.expansion.pending = 0)
