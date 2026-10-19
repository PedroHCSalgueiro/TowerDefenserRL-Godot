class_name SimDebugData
extends RefCounted
## Números das ferramentas de debug da simulação, lidos de `data/debug.json`: limite de spawn e de
## ouro por ação (porte de `sim/debug/debugData.ts`).

## Teto de inimigos ou torres criados por uma única ação de debug.
var max_spawn_per_command: int
## Teto de ouro somado por um único "+ouro" do debug (T17).
var max_gold_per_command: int

static var _default: SimDebugData = null


## Esquece os dados carregados (troca de conjunto de torres; ver `GameSets`).
static func reset_cache() -> void:
	_default = null


static func game_data() -> SimDebugData:
	if _default == null:
		_default = load_data(DataLoader.load_json("debug.json"))
	return _default


static func load_data(raw: Variant) -> SimDebugData:
	var data := SimDebugData.new()
	for key: String in ["maxSpawnPerCommand", "maxGoldPerCommand"]:
		var value: Variant = raw.get(key) if raw is Dictionary else null
		if not SimMap._is_integer(value) or int(value) <= 0:
			push_error('Dados de debug inválidos: "%s" precisa ser inteiro positivo' % key)
			return null
		if key == "maxSpawnPerCommand":
			data.max_spawn_per_command = int(value)
		else:
			data.max_gold_per_command = int(value)
	return data
