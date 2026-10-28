class_name ExpansionScreenModel
extends RefCounted
## Modelo da escolha da parede (mapa que cresce): as opções prontas para mostrar e o tempo. Sem nós.

class Option:
	extends RefCounted
	var index: int
	var room_id: String
	var name: String
	## "18 casas"
	var cells: String
	## A sala traz uma entrada nova de inimigos.
	var entrance := false
	## Tecla (1, 2, 3).
	var key: String

var options: Array[Option] = []
## Fração do tempo que resta, de 1 a 0.
var time_left := 1.0
var seconds := 0


## Null com a escolha fechada (ou no mapa sem salas).
static func build(state: Object, data: ExpansionData, ticks_per_second: float) -> ExpansionScreenModel:
	if state.expansion == null or state.expansion.screen == null or not data.enabled:
		return null
	var texts: Dictionary = DataLoader.load_json("ui.json")["expansionScreen"]
	var screen: ExpansionState.ExpansionScreen = state.expansion.screen
	var model := ExpansionScreenModel.new()
	for i in screen.options.size():
		var room := data.get_room(screen.options[i])
		if room == null:
			continue
		var option := Option.new()
		option.index = i
		option.room_id = room.id
		option.name = room.name
		option.cells = String(texts["cells"]).replace("{n}", str(room.cells.size()))
		option.entrance = room.has_entrance()
		option.key = str(i + 1)
		model.options.append(option)
	var total := Expansion.choose_ticks(data, ticks_per_second)
	model.time_left = float(screen.ticks_left) / float(total)
	model.seconds = int(ceilf(float(screen.ticks_left) / ticks_per_second))
	return model


## Assinatura: a interface só refaz as opções quando elas mudam.
static func key(model: ExpansionScreenModel) -> String:
	if model == null:
		return ""
	return ",".join(model.options.map(func(o: Option) -> String: return o.room_id))
