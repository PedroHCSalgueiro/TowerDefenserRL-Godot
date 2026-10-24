class_name TriggerEngine
extends RefCounted
## Motor de gatilhos, o último sistema do tick (porte de `engine.ts`).
##
## 1. **Fatos:** lê os eventos do tick (`ctx.tick_events`), na ordem em que foram emitidos:
##    `towerFired` (tiro normal ou de ativação), `towerActivated` e `enemyKilled`. Cada fato vira
##    entradas na fila para as torres cujo "quando" ele cumpre; se servir para várias torres, elas
##    entram em ordem de id. Contadores "a cada N" andam aqui.
## 2. **Fila FIFO** (`state.triggers.queue`): a entrada da frente executa o "o quê" da torre, e os
##    fatos gerados por essa execução entram no fim, com profundidade + 1.
## 3. **Limites:** o tick para quando a entrada da frente passa de `maxChainDepthPerTick` ou quando
##    `maxActivationsPerTick` entradas já rodaram. O resto fica na fila, na mesma ordem, e vai
##    primeiro no tick seguinte (com a profundidade do tick zerada). Acima de `maxQueueSize`,
##    entradas novas são descartadas (as mais novas) e contadas.
##
## Cada torre usa o gatilho da estrela dela (`Tower.star`). A explosão de uma execução do Carrasco
## ★3 é uma entrada própria da fila (`blast_radius` > 0): conta no orçamento e na profundidade,
## como qualquer gatilho.
##
## Bônus de classe (`state.classes`, lidos por torre a cada tick): a Mecânica reduz o N dos "a cada
## N"; a Arcana amplia a vizinhança de quem a tem; a Sombria multiplica o peso das mortes para as
## torres Sombria.
##
## Recompensas (T24, lidas a cada tick): trava de ativação menor ("Fluxo arcano"), morte de elite ou
## chefão ×3 para a Sombria ("Colheita sombria") e +1 de ouro a cada 10 gatilhos visíveis de uma
## cadeia ("Cadeia lucrativa").
##
## **Cadeia (T16):** cada fato de fora do motor (tiro normal, morte) abre uma cadeia nova, com id
## sequencial (`TriggerState.next_chain_id`), alocada só se o fato puser alguma entrada na fila; a
## origem é a torre que atirou ou que matou (null = núcleo). Tudo que nasce de uma entrada herda a
## cadeia dela: fatos novos, explosões da execução, sobras para o tick seguinte e os projéteis dos
## tiros de ativação e extras (a morte causada por eles continua a cadeia). `ChainRecord.length`
## conta só os gatilhos com efeito visível; a maior cadeia vai para `state.stats.longest_chain`.
## Uma cadeia sai de `TriggerState.chains` quando não sobra entrada dela na fila nem projétil dela
## no ar.
##
## Não existe loop infinito: toda entrada vem de um tiro normal (limitado pela cadência), de uma
## ativação (no máximo 1 por `activationCooldownSeconds` por torre) ou de uma morte (cada inimigo
## morre uma vez). Os tiros extras do disparo múltiplo não contam como tiro. Não há sorteio:
## empates vão para o menor id.

## Torre com gatilho, já com o tipo e a estrela resolvidos para o tick.
class Armed:
	extends RefCounted
	var tower: Tower
	var type: TowerData.TowerType
	var star: TriggerData.TriggerStar
	## Contagem do "a cada N" neste tick, já com o desconto da Mecânica (0 = sem contagem).
	var count: int
	## Raio da vizinhança quadrada dada pela Arcana (0 = vizinhança dos dados).
	var neighbor_radius: int

# Dependências (fixas).
var index: SpatialIndex
var enemies: EnemyData
var towers: TowerData
var classes: ClassData
var scores: Dictionary
## Rotas do mapa por tipo de movimento (as armadilhas escolhem o ponto na rota terrestre).
var routes: Dictionary
## Trava de ativação do tick (a dos dados ou a do bônus "Fluxo arcano").
var activation_cooldown_ticks: int
var unlimited_line_length: float
var _rules: TriggerData.TriggerRules
var _ticks_per_second: float

# Montados a cada tick a partir do estado (nada disso vai para o save).
var ctx: TickContext = null
var _sorted: Array[Tower] = []
var _armed_by_id := {}  # int -> Armed
var _tower_by_id := {}  # int -> Tower
var _armed: Array[Armed] = []
## Torres com gatilho que escutam abates ("morre no alcance", "a cada N abates", "vizinha abate").
var _kill_listeners: Array[Armed] = []
var _neighbor_cache := {}  # int -> Array[Tower]
var _reach_cache := {}  # int -> Array[Tower]

## Cadeias vivas, por id (montadas de `TriggerState.chains` a cada tick). Dictionary mantém a
## ordem de inserção.
var _chains := {}  # int -> ChainRecord
## Ids das cadeias vivas no fim do tick (reaproveitado).
var _live_chains := {}
## Cadeia das entradas que vão para a fila agora (`chain_id` 0 = abrir uma nova).
var _mark := ChainMark.new(0, null)

var _queue: Array[TriggerState.PendingTrigger] = []
var _head := 0
var _stats: TriggerState.TriggerTickStats
var _state: TriggerState


## `deps` (Dictionary): index, enemies, towers, scores, ticksPerSecond e, opcional, classes.
func _init(deps: Dictionary) -> void:
	index = deps["index"]
	enemies = deps["enemies"]
	towers = deps["towers"]
	classes = deps["classes"] if deps.get("classes") != null else ClassData.game_data()
	scores = deps["scores"]
	routes = deps.get("routes", {})
	_rules = towers.triggers
	_ticks_per_second = deps["ticksPerSecond"]
	activation_cooldown_ticks = _cooldown_ticks_for(_rules.activation_cooldown_seconds)
	unlimited_line_length = _rules.unlimited_line_length


## Devolve o sistema (Callable) do motor de gatilhos.
static func create_trigger_system(deps: Dictionary) -> Callable:
	var engine := TriggerEngine.new(deps)
	return func(tick_ctx: TickContext) -> void: engine.run(tick_ctx)


## Vizinhas da torre (pela vizinhança dos dados e pelo bônus da Arcana), em ordem de id.
func neighbors_of(tower: Tower) -> Array:
	if _neighbor_cache.has(tower.id):
		return _neighbor_cache[tower.id]
	var radius := _radius_for(tower)
	var list: Array[Tower] = []
	for t in _sorted:
		if t != tower and TriggerNeighborhood.is_neighbor(tower, t, _rules.neighborhood, radius):
			list.append(t)
	_neighbor_cache[tower.id] = list
	return list


## As vizinhas mais as casas em cruz até `reach` de distância, em ordem de id.
func reach_neighbors_of(tower: Tower, reach: int) -> Array:
	var key := tower.id * 16 + reach
	if _reach_cache.has(key):
		return _reach_cache[key]
	var radius := _radius_for(tower)
	var list: Array[Tower] = []
	for t in _sorted:
		if t != tower and TriggerNeighborhood.is_reach_neighbor(tower, t, _rules.neighborhood, radius, reach):
			list.append(t)
	_reach_cache[key] = list
	return list


func _radius_for(tower: Tower) -> int:
	var armed: Armed = _armed_by_id.get(tower.id)
	return armed.neighbor_radius if armed != null else _radius_of(tower)


## Põe na fila a explosão de uma execução (uma entrada própria por explosão).
func enqueue_blast(tower: Tower, x: float, y: float, radius: float, percent: float,
		entry: TriggerState.PendingTrigger) -> void:
	var armed: Armed = _armed_by_id.get(tower.id)
	if armed == null:
		return
	_enqueue(armed, tower.id, 1.0, entry.depth + 1, entry.tick_depth + 1, true, x, y, radius, percent)


## Segundos em ticks (no mínimo 1), como a trava de ativação.
func seconds_to_ticks(seconds: float) -> int:
	return _cooldown_ticks_for(seconds)


func _cooldown_ticks_for(seconds: float) -> int:
	return maxi(1, SimMath.js_round(seconds * _ticks_per_second))


func _radius_of(tower: Tower) -> int:
	return ClassBonuses.neighborhood_radius(classes, ctx.state, towers.get_type(tower.type))


func run(tick_ctx: TickContext) -> void:
	var triggers: TriggerState = tick_ctx.state.triggers
	var stats := triggers.last_tick
	stats.fired = 0
	stats.max_depth = 0
	stats.deferred = 0
	stats.dropped = 0

	# O estado do tick precisa existir já na preparação (vizinhanças leem `ctx`).
	ctx = tick_ctx
	_prepare(tick_ctx)
	if _armed.is_empty() and triggers.queue.is_empty():
		ctx = null
		return

	_state = triggers
	_stats = stats
	_queue = triggers.queue
	_head = 0
	_chains.clear()
	for chain in triggers.chains:
		_chains[chain.id] = chain

	# Relógios das torres "a cada N segundos": andam a cada tick e, ao completar, abrem uma cadeia nova.
	for armed in _armed:
		if armed.star.when["kind"] == "everyNSeconds":
			var timed := armed.tower
			timed.trigger_counter += 1.0
			if timed.trigger_counter >= armed.count:
				timed.trigger_counter -= armed.count
				_mark_fact(0, timed.id)
				_enqueue(armed, timed.id, 1.0, 1, 1, false, 0.0, 0.0)

	# Sobras do tick anterior já estão na frente; os fatos deste tick entram atrás.
	var cursor := _convert_facts(0, 1, 1, false)
	var processed := 0
	while _head < _queue.size():
		var entry := _queue[_head]
		if entry.tick_depth > _rules.max_chain_depth_per_tick:
			break
		if processed >= _rules.max_activations_per_tick:
			break
		_head += 1
		processed += 1
		_mark.chain_id = entry.chain_id
		_mark.origin_tower_id = entry.origin_tower_id
		_execute(entry)
		cursor = _convert_facts(cursor, entry.depth + 1, entry.tick_depth + 1, true)

	if _head > 0:
		_queue.assign(_queue.slice(_head))
	_head = 0
	for entry in _queue:
		entry.tick_depth = 1
	stats.deferred = _queue.size()
	_prune_chains(tick_ctx)
	ctx = null


## Guarda em `TriggerState.chains` só as cadeias com entrada na fila ou projétil no ar.
func _prune_chains(tick_ctx: TickContext) -> void:
	var triggers: TriggerState = tick_ctx.state.triggers
	if _chains.is_empty():
		triggers.chains = []
		return
	# A fila pode ter milhares de entradas de poucas cadeias: entradas vizinhas costumam ser da
	# mesma cadeia, e a busca para quando todas foram achadas.
	var live := _live_chains
	live.clear()
	var total := _chains.size()
	var last := 0
	for entry in _queue:
		if entry.chain_id == last:
			continue
		last = entry.chain_id
		live[last] = true
		if live.size() == total:
			break
	if live.size() < total:
		for projectile: Projectile in tick_ctx.state.projectiles.slots:
			if projectile.active and projectile.chain_id > 0:
				live[projectile.chain_id] = true
	# O Dictionary guarda a ordem de inserção: as do save (em ordem) e depois as novas (ids crescentes).
	var kept: Array[TriggerState.ChainRecord] = []
	for chain: TriggerState.ChainRecord in _chains.values():
		if live.has(chain.id):
			kept.append(chain)
	triggers.chains = kept
	_chains.clear()


## A cadeia `id`, criando o registro se ainda não existir.
func _chain_record(id: int, origin_tower_id: Variant) -> TriggerState.ChainRecord:
	var chain: TriggerState.ChainRecord = _chains.get(id)
	if chain == null:
		chain = TriggerState.ChainRecord.new(id, origin_tower_id)
		_chains[id] = chain
	return chain


## Marca dos fatos de fora do motor: a cadeia do projétil, se houver; senão, uma nova.
func _mark_fact(chain_id: int, origin_tower_id: Variant) -> void:
	_mark.chain_id = chain_id
	_mark.origin_tower_id = origin_tower_id


## Índices do tick: torres por id, torres com gatilho e vizinhanças.
func _prepare(tick_ctx: TickContext) -> void:
	var tower_list: Array = tick_ctx.state.towers
	var seconds: float = RewardMods.of(tick_ctx.state).activation_cooldown_seconds \
			if RewardMods.of(tick_ctx.state).activation_cooldown_seconds != null \
			else _rules.activation_cooldown_seconds
	activation_cooldown_ticks = _cooldown_ticks_for(seconds)
	_sorted.clear()
	_sorted.assign(tower_list)
	if _sorted.size() > 1:
		_sorted.sort_custom(func(a: Tower, b: Tower) -> bool: return a.id < b.id)
	_tower_by_id.clear()
	_armed_by_id.clear()
	_neighbor_cache.clear()
	_reach_cache.clear()
	_armed = []
	_kill_listeners = []
	for tower in _sorted:
		_tower_by_id[tower.id] = tower
		var type := towers.get_type(tower.type)
		if type.trigger == null:
			continue
		var star := TriggerData.trigger_at(type.trigger, Stars.clamp_star(type, tower.star))
		var when := star.when
		var base_count := 0
		if when["kind"] == "everyNShots":
			base_count = when["shots"]
		elif when["kind"] == "everyNKillsInRange":
			base_count = when["kills"]
		var armed := Armed.new()
		armed.tower = tower
		armed.type = type
		armed.star = star
		armed.count = ClassBonuses.reduced_trigger_count(classes, tick_ctx.state, type, base_count) if base_count > 0 else 0
		if when["kind"] == "everyNSeconds":
			armed.count = _cooldown_ticks_for(when["seconds"])
		armed.neighbor_radius = ClassBonuses.neighborhood_radius(classes, tick_ctx.state, type)
		_armed.append(armed)
		_armed_by_id[tower.id] = armed
		if when["kind"] == "enemyDiesInRange" or when["kind"] == "everyNKillsInRange" or when["kind"] == "neighborKills" \
				or when["kind"] == "ownKill":
			_kill_listeners.append(armed)


func _enqueue(armed: Armed, source_tower_id: Variant, weight: float, depth: int, tick_depth: int,
		has_point: bool, x: float, y: float, blast_radius: float = 0.0, blast_percent: float = 0.0) -> void:
	if _queue.size() - _head >= _rules.max_queue_size:
		_stats.dropped += 1
		_state.dropped_total += 1
		return
	if _mark.chain_id == 0:
		_mark.chain_id = _state.next_chain_id
		_state.next_chain_id += 1
		_chain_record(_mark.chain_id, _mark.origin_tower_id)
	var entry := TriggerState.PendingTrigger.new()
	entry.tower_id = armed.tower.id
	entry.source_tower_id = source_tower_id
	entry.weight = weight
	entry.depth = depth
	entry.tick_depth = tick_depth
	entry.has_point = has_point
	entry.x = x if has_point else 0.0
	entry.y = y if has_point else 0.0
	entry.blast_radius = blast_radius
	entry.blast_percent = blast_percent
	entry.chain_id = _mark.chain_id
	entry.origin_tower_id = _mark.origin_tower_id
	_queue.append(entry)


## Transforma os eventos a partir de `from` em entradas; devolve o novo cursor. `inherit`: os fatos
## nasceram da entrada que acabou de executar e ficam na cadeia dela (`_mark`); senão, cada fato
## abre a própria.
func _convert_facts(from: int, depth: int, tick_depth: int, inherit: bool) -> int:
	var events := ctx.tick_events
	var i := from
	while i < events.size():
		var event: Dictionary = events[i]
		i += 1
		match event["type"]:
			"towerFired":
				if event["shot"] == "extra":
					continue
				if not inherit:
					_mark_fact(0, event["towerId"])
				_on_shot(event["towerId"], depth, tick_depth)
			"towerActivated":
				var armed: Armed = _armed_by_id.get(event["towerId"])
				if armed != null and armed.star.when["kind"] == "onActivated":
					if not inherit:
						_mark_fact(0, event["sourceTowerId"])
					_enqueue(armed, event["sourceTowerId"], 1.0, depth, tick_depth, false, 0.0, 0.0)
			"enemyKilled":
				if not inherit:
					# Morte por tiro de um gatilho: continua a cadeia que disparou o tiro.
					if event["chainId"] > 0:
						_chain_record(event["chainId"], event["originTowerId"])
						_mark_fact(event["chainId"], event["originTowerId"])
					else:
						_mark_fact(0, event["towerId"])
				_on_kill(event, depth, tick_depth)
	return events.size()


## Tiro normal ou de ativação da torre.
func _on_shot(tower_id: int, depth: int, tick_depth: int) -> void:
	var armed: Armed = _armed_by_id.get(tower_id)
	if armed == null:
		return
	var tower := armed.tower
	var when := armed.star.when
	var enqueued := false
	if when["kind"] == "onFire":
		_enqueue(armed, tower.id, 1.0, depth, tick_depth, false, 0.0, 0.0)
		enqueued = true
	elif when["kind"] == "everyNShots":
		# Contador acima do novo N (a Mecânica baixou o N): completa neste fato, não sozinho.
		tower.trigger_counter += 1.0
		while tower.trigger_counter >= armed.count:
			tower.trigger_counter -= armed.count
			_enqueue(armed, tower.id, 1.0, depth, tick_depth, false, 0.0, 0.0)
			enqueued = true
	# Cargas cheias esperando alvo: o raio sai no próximo tiro da própria torre.
	var effect := armed.star.effect
	if not enqueued and effect["kind"] == "chargeLightning" and tower.charges >= effect["charges"]:
		_enqueue(armed, tower.id, 0.0, depth, tick_depth, false, 0.0, 0.0)


func _in_range(armed: Armed, x: float, y: float) -> bool:
	var dx := x - float(armed.tower.x)
	var dy := y - float(armed.tower.y)
	return dx * dx + dy * dy <= armed.type.range * armed.type.range


## Um inimigo morreu: "morre no alcance", "a cada N abates no alcance" e "vizinha abate".
func _on_kill(event: Dictionary, depth: int, tick_depth: int) -> void:
	var killer: Tower = null
	if event["towerId"] != null:
		killer = _tower_by_id.get(event["towerId"])
	var killer_type: TowerData.TowerType = towers.get_type(killer.type) if killer != null else null
	var elite_or_boss: bool = event["elite"] or enemies.get_type(event["enemyType"]).boss
	for armed in _kill_listeners:
		var when := armed.star.when
		match when["kind"]:
			"enemyDiesInRange":
				if _in_range(armed, event["x"], event["y"]):
					_enqueue(armed, event["towerId"], 1.0, depth, tick_depth, true, event["x"], event["y"])
			"everyNKillsInRange":
				if not _in_range(armed, event["x"], event["y"]):
					continue
				var tower := armed.tower
				tower.trigger_counter += _weight_for(armed, killer_type, event["weight"], elite_or_boss)
				while tower.trigger_counter >= armed.count:
					tower.trigger_counter -= armed.count
					_enqueue(armed, event["towerId"], 1.0, depth, tick_depth, true, event["x"], event["y"])
			"neighborKills":
				if killer != null and TriggerNeighborhood.is_neighbor(armed.tower, killer, _rules.neighborhood, armed.neighbor_radius):
					var weight := _weight_for(armed, killer_type, event["weight"], elite_or_boss)
					_enqueue(armed, killer.id, weight, depth, tick_depth, true, event["x"], event["y"])
			"ownKill":
				if killer == armed.tower and (not when["markedOnly"] or event.get("marked", false)):
					_enqueue(armed, killer.id, 1.0, depth, tick_depth, true, event["x"], event["y"])


## Peso da morte para o contador ou as cargas de `armed`, com o bônus da Sombria.
func _weight_for(armed: Armed, killer_type: TowerData.TowerType, base: float, elite_or_boss: bool) -> float:
	return ClassBonuses.kill_weight(classes, ctx.state, armed.type, killer_type, base, elite_or_boss)


func _execute(entry: TriggerState.PendingTrigger) -> void:
	var armed: Armed = _armed_by_id.get(entry.tower_id)
	# A torre saiu do mapa (ou trocou de tipo) desde que a entrada foi criada.
	if armed == null:
		return
	var tower := armed.tower
	var type := armed.type
	var own := armed.star.effect

	if entry.blast_radius > 0.0:
		_fired(armed, entry, "explosion", true, null)
		TriggerEffects.run_blast(self, tower, type, entry)
		return

	if own["kind"] == "copyLast":
		var copies := TriggerEffects.resolve_copies(self, tower, own)
		# Nada para copiar: o gatilho disparou, mas não há efeito (não conta na cadeia).
		if copies.is_empty():
			_fired(armed, entry, "copyLast", false, null)
		for copy: Dictionary in copies:
			var effect: Dictionary = copy["effect"]
			_fired(armed, entry, effect["kind"], true, copy["fromTowerId"])
			if TriggerEffects.run_effect(self, tower, type, effect, entry, true):
				tower.last_effect = Tower.LastEffect.new(effect, _state.next_seq)
				_state.next_seq += 1
		return

	# Descarga de carga guardada: sem carga suficiente ou sem alvo, não faz nada.
	if entry.weight == 0.0 and own["kind"] == "chargeLightning":
		if tower.charges < own["charges"]:
			return
		if TowerSystems.find_tower_target(index, ctx.state, tower, type, scores) == null:
			return

	# O raio em cadeia só é visível se sair: ganhar carga sem soltar não conta na cadeia. O mesmo vale
	# para os efeitos de estado: sem ninguém para atordoar, o gatilho não aparece na cadeia.
	var lazy: bool = own["kind"] == "chargeLightning" or TriggerData.LAZY_EFFECTS.has(own["kind"])
	var event := _fired(armed, entry, own["kind"], not lazy, null)
	if TriggerEffects.run_effect(self, tower, type, own, entry, false):
		tower.last_effect = Tower.LastEffect.new(own, _state.next_seq)
		_state.next_seq += 1
		if lazy:
			_count_visible(event, entry)


## Registra um gatilho executado: evento e contadores. Devolve o evento, que pode virar visível
## depois do efeito (`_count_visible`).
func _fired(armed: Armed, entry: TriggerState.PendingTrigger, effect: String, visible: bool,
		copied_from_tower_id: Variant) -> Dictionary:
	var chain := _chain_record(entry.chain_id, entry.origin_tower_id)
	var event := {
		"type": "triggerFired",
		"tick": ctx.state.tick,
		"towerId": armed.tower.id,
		"sourceTowerId": entry.source_tower_id,
		"when": armed.star.when["kind"],
		"effect": effect,
		"depth": entry.depth,
		"chainId": chain.id,
		"originTowerId": chain.origin_tower_id,
		"visible": false,
		"chainLength": chain.length,
		"copiedFromTowerId": copied_from_tower_id,
	}
	ctx.emit(event)
	if visible:
		_count_visible(event, entry)
	_stats.fired += 1
	if entry.depth > _stats.max_depth:
		_stats.max_depth = entry.depth
	return event


## O gatilho teve efeito visível: conta na cadeia (o "x7") e na maior cadeia da run. Com o bônus
## "Cadeia lucrativa" (T24), cada 10 gatilhos visíveis da cadeia rendem ouro (no ouro ganho).
func _count_visible(event: Dictionary, entry: TriggerState.PendingTrigger) -> void:
	var chain := _chain_record(entry.chain_id, entry.origin_tower_id)
	chain.length += 1
	event["visible"] = true
	event["chainLength"] = chain.length
	var state := ctx.state
	var stats = state.stats
	if chain.length > stats.longest_chain:
		stats.longest_chain = chain.length
	var gold := Rewards.chain_gold_at(state, chain.length)
	if gold > 0:
		Gold.earn_gold(state, gold)
		stats.chain_gold += gold
		ctx.emit({
			"type": "chainGold",
			"tick": state.tick,
			"chainId": chain.id,
			"chainLength": chain.length,
			"gold": gold,
		})
