class_name ExpansionData
extends RefCounted
## Mapa que cresce em salas (Mini-GDD, Sistema 7), lido de `data/expansion.json`.
##
## O mapa das salas é um mapa próprio (`map`, mesmo formato de `map.json`). No começo só ficam abertas
## as casas a até `startMargin` casas do caminho (distância de xadrez); o resto fica no escuro, dividido
## em salas (`rooms`). Cada sala é um retângulo; as casas dela são as do retângulo que ainda não são do
## começo, do caminho, de uma entrada ou de uma sala anterior da lista (a primeira da lista ganha).
##
## Sala com `entrance` (pontos de virada, como o caminho) traz uma entrada nova de inimigos: o trecho
## vai da borda até uma casa do caminho principal (o último ponto), onde se junta. As casas da entrada
## (menos a da junção) nunca abrem antes da sala, nem no começo (o "portão" fica no escuro).

class Room:
	extends RefCounted
	var id: String
	var name: String
	## Casas novas para construir.
	var cells: Array[Vector2i] = []
	## Entrada nova, da borda até a casa antes do caminho principal ([] = sala sem entrada).
	var entrance_cells: Array[Vector2i] = []
	## Índice, no caminho principal, da casa onde a entrada se junta (-1 sem entrada).
	var join_index := -1

	func has_entrance() -> bool:
		return not entrance_cells.is_empty()

var enabled := false
## Dados do mapa das salas (formato de `map.json`) e o id dele: a expansão só vale nesse mapa.
var map_data: Dictionary = {}
var map_id := ""
var start_margin := 1
## Ondas que dão a escolha da parede ao fechar ([] = as ondas com chefão).
var after_waves: Array[int] = []
## Quantas paredes a escolha mostra (no máximo).
var choices := 3
## Tempo da escolha; no zero, a simulação escolhe sozinha.
var choose_seconds := 20.0
var rooms: Array[Room] = []
## Casas abertas no começo (fora o caminho).
var start_cells: Array[Vector2i] = []
var _by_id := {}

static var _default: ExpansionData = null


static func reset_cache() -> void:
	_default = null


static func game_data() -> ExpansionData:
	if _default == null:
		_default = load_data(DataLoader.load_json("expansion.json"))
		if _default == null:
			_default = disabled()
	return _default


## Sem expansão (o mapa fica como está).
static func disabled() -> ExpansionData:
	return ExpansionData.new()


## Os dados da expansão que valem para este mapa, ou null (mapa sem salas).
static func for_map(map: SimMap, data: ExpansionData = null) -> ExpansionData:
	var d := data if data != null else game_data()
	return d if d.enabled and d.map_id == map.id else null


## Mapa novo das salas, com só o começo aberto. Cada run precisa do seu: o mapa muda quando uma sala abre.
func build_map() -> SimMap:
	var map := SimMap.load_map(map_data)
	if map != null:
		map.set_start_cells(start_cells)
	return map


func get_room(id: String) -> Room:
	return _by_id.get(id)


static func _fail(message: String) -> ExpansionData:
	push_error("Expansão inválida: %s" % message)
	return null


static func _rect_cells(raw: Variant, map: SimMap) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not (raw is Dictionary):
		return out
	for key in ["x", "y", "w", "h"]:
		if not SimMap._is_integer(raw.get(key)):
			return out
	for y in range(int(raw["y"]), int(raw["y"]) + int(raw["h"])):
		for x in range(int(raw["x"]), int(raw["x"]) + int(raw["w"])):
			var cell := Vector2i(x, y)
			if map.is_inside(cell):
				out.append(cell)
	return out


## Valida e monta as salas. Inválido: push_error e null. Sem arquivo ou `enabled: false`: desligada.
static func load_data(raw: Variant) -> ExpansionData:
	if raw == null:
		return disabled()
	if not (raw is Dictionary):
		return _fail("não é um objeto")
	if not raw.get("enabled", false):
		return disabled()
	if not (raw.get("map") is Dictionary) or not (raw.get("rooms") is Array):
		return _fail('precisa de "map" e "rooms"')
	var map := SimMap.load_map(raw["map"])
	if map == null:
		return _fail("mapa das salas inválido")
	var data := ExpansionData.new()
	data.enabled = true
	data.map_data = raw["map"]
	data.map_id = map.id
	data.start_margin = int(raw.get("startMargin", 1))
	data.choices = int(raw.get("choices", 3))
	data.choose_seconds = float(raw.get("chooseSeconds", 20.0))
	if data.start_margin < 0 or data.choices < 1 or data.choose_seconds <= 0.0:
		return _fail('"startMargin" >= 0, "choices" >= 1 e "chooseSeconds" > 0')
	for wave in raw.get("afterWaves", []):
		if not SimMap._is_integer(wave) or int(wave) < 1:
			return _fail('"afterWaves" precisa de números de onda (>= 1)')
		data.after_waves.append(int(wave))

	# Entradas primeiro: as casas delas ficam fora do começo e de todas as salas.
	var gate := {}
	for raw_room in raw["rooms"]:
		if not (raw_room is Dictionary) or typeof(raw_room.get("id")) != TYPE_STRING:
			return _fail("sala sem id")
		var room := Room.new()
		room.id = raw_room["id"]
		room.name = str(raw_room.get("name", room.id))
		if data._by_id.has(room.id):
			return _fail('sala repetida "%s"' % room.id)
		if raw_room.has("entrance"):
			var cells := SimMap._expand_path(raw_room["entrance"], map.width, map.height)
			if cells.is_empty():
				return _fail('entrada inválida na sala "%s"' % room.id)
			var join := cells[cells.size() - 1]
			room.join_index = map.path_cells.find(join)
			if room.join_index < 0:
				return _fail('a entrada da sala "%s" não termina no caminho' % room.id)
			cells.remove_at(cells.size() - 1)
			for cell in cells:
				if map.is_path(cell) or gate.has(cell):
					return _fail('a entrada da sala "%s" cruza outro caminho em (%d, %d)' % [room.id, cell.x, cell.y])
				gate[cell] = true
			room.entrance_cells = cells
		data.rooms.append(room)
		data._by_id[room.id] = room

	# Começo: em volta do caminho, menos os portões.
	var taken := {}
	for y in map.height:
		for x in map.width:
			var cell := Vector2i(x, y)
			if map.is_path(cell) or gate.has(cell):
				continue
			for p in map.path_cells:
				if maxi(absi(p.x - x), absi(p.y - y)) <= data.start_margin:
					data.start_cells.append(cell)
					taken[cell] = true
					break

	for i in data.rooms.size():
		var room := data.rooms[i]
		for cell in _rect_cells(raw["rooms"][i].get("rect"), map):
			if map.is_path(cell) or gate.has(cell) or taken.has(cell):
				continue
			room.cells.append(cell)
			taken[cell] = true
		if room.cells.is_empty() and not room.has_entrance():
			return _fail('a sala "%s" não tem casas' % room.id)
	return data
