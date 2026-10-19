class_name TriggerFx
extends RefCounted
## Modelos do feedback visual dos gatilhos (T16), sem nós, para testar direto (porte de
## `fx/triggerFx.ts`). Tudo em coordenadas da grade; a view converte para o mundo 3D.
##
## - **Pulsos:** uma linha da torre que disparou o gatilho até o destino (vizinha ativada, ponto da
##   explosão, alvos do raio, linha perfurante, vizinha copiada). No máximo `maxActive` ao mesmo
##   tempo, as mais recentes.
## - **Flash:** a torre que disparou um gatilho com efeito visível pisca.
## - **Números:** a soma do dano de cada explosão, raio ou linha de gatilho, só acima de
##   `minDamage`, no máximo `maxActive` na tela.
## - **Cadeias:** "Cadeia xN!" sobre a torre que começou (ou o núcleo), para as cadeias com mais de
##   `minLength` gatilhos visíveis; no máximo `maxLabels`, as maiores, uma por origem.

class Pulse:
	extends RefCounted
	var from: Vector2
	var to: Vector2
	var color: Color
	var ms_left: float


## Os segmentos de linha de um evento de gatilho: [{"from": Vector2, "to": Vector2, "color": Color}].
## `tower_at`: Callable(tower_id) -> {"x","y","color"} ou {} (torre desconhecida).
static func segments_of(event: Dictionary, tower_at: Callable) -> Array:
	var out: Array = []
	match event["type"]:
		"towerActivated":
			if event["sourceTowerId"] == event["towerId"]:
				return out
			var from: Dictionary = tower_at.call(event["sourceTowerId"])
			var to: Dictionary = tower_at.call(event["towerId"])
			if not from.is_empty() and not to.is_empty():
				out.append({"from": Vector2(from["x"], from["y"]), "to": Vector2(to["x"], to["y"]), "color": from["color"]})
		"areaExploded":
			if not event["trigger"]:
				return out
			var from: Dictionary = tower_at.call(event["towerId"])
			if not from.is_empty():
				out.append({"from": Vector2(from["x"], from["y"]), "to": Vector2(event["x"], event["y"]), "color": from["color"]})
		"lightningStruck":
			var tower: Dictionary = tower_at.call(event["towerId"])
			if tower.is_empty():
				return out
			var from := Vector2(tower["x"], tower["y"])
			for point: Dictionary in event["points"]:
				var to := Vector2(point["x"], point["y"])
				out.append({"from": from, "to": to, "color": tower["color"]})
				from = to
		"lineFired":
			var tower: Dictionary = tower_at.call(event["towerId"])
			if not tower.is_empty():
				out.append({"from": Vector2(tower["x"], tower["y"]), "to": Vector2(event["toX"], event["toY"]), "color": tower["color"]})
		"triggerFired":
			if event["copiedFromTowerId"] == null:
				return out
			var from: Dictionary = tower_at.call(event["copiedFromTowerId"])
			var to: Dictionary = tower_at.call(event["towerId"])
			if not from.is_empty() and not to.is_empty():
				out.append({"from": Vector2(from["x"], from["y"]), "to": Vector2(to["x"], to["y"]), "color": to["color"]})
	return out


## Pulsos ativos. `add` lê os eventos do quadro de trás para a frente e só monta os `maxActive`
## segmentos mais recentes: numa avalanche chegam milhares de eventos por quadro.
class PulseModel:
	extends RefCounted
	var pulses: Array[Pulse] = []
	var _duration_ms: float
	var _max_active: int

	func _init(config: Dictionary) -> void:
		_duration_ms = float(config["durationMs"])
		_max_active = int(config["maxActive"])

	func add(events: Array, tower_at: Callable) -> void:
		var fresh: Array[Pulse] = []
		var i := events.size() - 1
		while i >= 0 and fresh.size() < _max_active:
			var segments := TriggerFx.segments_of(events[i], tower_at)
			var j := segments.size() - 1
			while j >= 0 and fresh.size() < _max_active:
				var p := Pulse.new()
				p.from = segments[j]["from"]
				p.to = segments[j]["to"]
				p.color = segments[j]["color"]
				p.ms_left = _duration_ms
				fresh.append(p)
				j -= 1
			i -= 1
		if fresh.is_empty():
			return
		fresh.reverse()
		var kept := maxi(0, _max_active - fresh.size())
		var old := pulses.slice(maxi(0, pulses.size() - kept))
		pulses.clear()
		pulses.append_array(old)
		pulses.append_array(fresh)

	## Avança o tempo e tira os pulsos que acabaram.
	func advance(delta_ms: float) -> void:
		var alive: Array[Pulse] = []
		for p in pulses:
			p.ms_left -= delta_ms
			if p.ms_left > 0.0:
				alive.append(p)
		pulses = alive


## Torres que disparam um gatilho visível no quadro (cada uma uma vez, na ordem).
static func flashed_towers(events: Array) -> Array[int]:
	var seen := {}
	var out: Array[int] = []
	for event: Dictionary in events:
		if event["type"] == "triggerFired" and event["visible"] and not seen.has(event["towerId"]):
			seen[event["towerId"]] = true
			out.append(event["towerId"])
	return out


class DamageNumber:
	extends RefCounted
	## Id crescente: a view prende cada número a um texto só (não refaz o texto).
	var id := 0
	var at := Vector2.ZERO
	var value := 0.0
	var ms_left := 0.0


## Soma do dano de um efeito de gatilho (0 = não é efeito de gatilho com número).
static func _damage_of(event: Dictionary) -> float:
	match event["type"]:
		"areaExploded":
			return event["damage"] if event["trigger"] else 0.0
		"lightningStruck":
			return event["damage"] if not event["points"].is_empty() else 0.0
		"lineFired":
			return event["damage"]
	return 0.0


## Ponto do número: a explosão, o primeiro alvo do raio ou o meio da linha.
static func _point_of(event: Dictionary) -> Vector2:
	match event["type"]:
		"areaExploded":
			return Vector2(event["x"], event["y"])
		"lightningStruck":
			return Vector2(event["points"][0]["x"], event["points"][0]["y"])
		"lineFired":
			return Vector2((event["x"] + event["toX"]) / 2.0, (event["y"] + event["toY"]) / 2.0)
	return Vector2.ZERO


## Números de dano agregados por efeito. Os mais novos ficam: acima de `maxActive`, os mais antigos
## saem. Desligado (tecla N), nada entra e os da tela somem.
class DamageNumberModel:
	extends RefCounted
	var numbers: Array[DamageNumber] = []
	var enabled := true
	var _min_damage: float
	var _max_active: int
	var _duration_ms: float
	var _next_id := 1

	func _init(config: Dictionary) -> void:
		_min_damage = float(config["minDamage"])
		_max_active = int(config["maxActive"])
		_duration_ms = float(config["durationMs"])

	func toggle() -> bool:
		enabled = not enabled
		if not enabled:
			numbers.clear()
		return enabled

	func add(events: Array) -> void:
		if not enabled:
			return
		var fresh: Array[DamageNumber] = []
		var i := events.size() - 1
		while i >= 0 and fresh.size() < _max_active:
			var event: Dictionary = events[i]
			var value := TriggerFx._damage_of(event)
			if value > _min_damage:
				var n := DamageNumber.new()
				n.at = TriggerFx._point_of(event)
				n.value = value
				n.ms_left = _duration_ms
				fresh.append(n)
			i -= 1
		if fresh.is_empty():
			return
		fresh.reverse()
		for n in fresh:
			n.id = _next_id
			_next_id += 1
		var kept := maxi(0, _max_active - fresh.size())
		var old := numbers.slice(maxi(0, numbers.size() - kept))
		numbers.clear()
		numbers.append_array(old)
		numbers.append_array(fresh)

	func advance(delta_ms: float) -> void:
		var alive: Array[DamageNumber] = []
		for n in numbers:
			n.ms_left -= delta_ms
			if n.ms_left > 0.0:
				alive.append(n)
		numbers = alive


class ChainLabel:
	extends RefCounted
	var chain_id := 0
	## Torre que começou a cadeia; null = núcleo (sem anel).
	var origin_tower_id: Variant = null
	var length := 0
	## A cadeia ainda está viva (fila ou projétil no ar).
	var alive := true


## Acompanha as cadeias que passam de `minLength`. A cadeia está viva enquanto aparece em
## `state.triggers.chains`; depois disso fica `lingerMs`.
class ChainModel:
	extends RefCounted
	var _min_length: int
	var _max_labels: int
	var _linger_ms: float
	## id -> {"origin": Variant, "length": int, "dead_ms": float}
	var _chains := {}

	func _init(config: Dictionary) -> void:
		_min_length = int(config["minLength"])
		_max_labels = int(config["maxLabels"])
		_linger_ms = float(config["lingerMs"])

	func add(events: Array) -> void:
		for event: Dictionary in events:
			if event["type"] != "triggerFired" or not event["visible"]:
				continue
			if event["chainLength"] <= _min_length:
				continue
			var id: int = event["chainId"]
			if _chains.has(id):
				_chains[id]["length"] = event["chainLength"]
				_chains[id]["dead_ms"] = 0.0
			else:
				_chains[id] = {"origin": event["originTowerId"], "length": event["chainLength"], "dead_ms": 0.0}

	## `live_ids`: Dictionary de ids em `state.triggers.chains` agora.
	func advance(delta_ms: float, live_ids: Dictionary) -> void:
		for id: int in _chains.keys():
			var chain: Dictionary = _chains[id]
			if live_ids.has(id):
				chain["dead_ms"] = 0.0
				continue
			chain["dead_ms"] += delta_ms
			if chain["dead_ms"] > _linger_ms:
				_chains.erase(id)

	## Os rótulos a mostrar: as maiores cadeias, uma por origem, no máximo `maxLabels`.
	func labels() -> Array[ChainLabel]:
		var best := {}  # origem (ou "núcleo") -> ChainLabel
		for id: int in _chains:
			var chain: Dictionary = _chains[id]
			var key: Variant = chain["origin"] if chain["origin"] != null else -1
			var current: ChainLabel = best.get(key)
			if current == null or chain["length"] > current.length \
					or (chain["length"] == current.length and id > current.chain_id):
				var label := ChainLabel.new()
				label.chain_id = id
				label.origin_tower_id = chain["origin"]
				label.length = chain["length"]
				label.alive = chain["dead_ms"] == 0.0
				best[key] = label
		var list: Array[ChainLabel] = []
		for label: ChainLabel in best.values():
			list.append(label)
		list.sort_custom(func(a: ChainLabel, b: ChainLabel) -> bool:
			return a.length > b.length or (a.length == b.length and a.chain_id > b.chain_id))
		return list.slice(0, _max_labels)
