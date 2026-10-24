class_name DataLoader
extends RefCounted
## Carrega os JSON de data/ (copiados do Phaser, mesma estrutura e chaves em camelCase).
##
## Conjuntos de torres (`GameSets`): o conjunto é uma lista de camadas (pastas de data/sets/), aplicadas
## em ordem sobre data/. Para cada camada que tem um arquivo com o mesmo nome, ele é combinado com o
## resultado até ali: objetos se mesclam em profundidade (a camada vence), qualquer outro valor é
## trocado. Com `"$replace": true` no objeto de cima, o arquivo da camada substitui tudo que veio antes
## (é assim que a camada "heroes" troca as torres do protótipo pelas regras dos heróis).
##
## ATENÇÃO: o JSON do Godot devolve todo número como float (como o JS, que não
## distingue int de float). Converta com int() onde o valor é inteiro e NUNCA
## divida dois ints com `/` (no GDScript isso é divisão inteira; no JS não é).

const DIR := "res://data/"
const SETS_DIR := "res://data/sets/"
const REPLACE_KEY := "$replace"

static var _cache: Dictionary = {}
static var _set_id := "default"
## Pastas de data/sets/ aplicadas, em ordem (vazio = só data/).
static var _layers: Array = []


## Conjunto de torres em uso ("default" = só data/).
static func set_id() -> String:
	return _set_id


## Troca o conjunto e esquece tudo que foi lido. `layers`: as pastas do conjunto, em ordem (sem
## a lista, a pasta com o id do conjunto; "default" não tem nenhuma). Quem guarda dados já tratados
## (`TowerData.game_data()` etc.) precisa esquecê-los também: use `GameSets.select`.
static func use_set(id: String, layers: Variant = null) -> void:
	_set_id = id
	if layers is Array:
		_layers = layers.duplicate()
	else:
		_layers = [] if id == "default" else [id]
	_cache.clear()


## Lê data/<file_name> (com o complemento do conjunto, se houver) e devolve o conteúdo
## (Dictionary/Array), ou null com push_error.
static func load_json(file_name: String) -> Variant:
	var key := _set_id + "/" + file_name
	if _cache.has(key):
		return _cache[key]
	var base: Variant = _read(DIR + file_name)
	if base == null:
		return null
	var data: Variant = base
	for layer: String in _layers:
		var override_path := SETS_DIR + layer + "/" + file_name
		if FileAccess.file_exists(override_path):
			var override: Variant = _read(override_path)
			if override == null:
				return null
			data = _combine(data, override)
	_cache[key] = data
	return data


static func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("arquivo de dados ausente: %s" % path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_error("JSON inválido em %s (linha %d): %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


static func _combine(base: Variant, override: Variant) -> Variant:
	if not (base is Dictionary) or not (override is Dictionary):
		return override
	if override.get(REPLACE_KEY, false):
		var whole: Dictionary = override.duplicate(true)
		whole.erase(REPLACE_KEY)
		return whole
	var out: Dictionary = base.duplicate(true)
	for key in override:
		out[key] = _combine(base[key], override[key]) if base.has(key) else override[key]
	return out
