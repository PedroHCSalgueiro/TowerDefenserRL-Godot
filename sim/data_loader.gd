class_name DataLoader
extends RefCounted
## Carrega os JSON de data/ (copiados do Phaser, mesma estrutura e chaves em camelCase).
##
## ATENÇÃO: o JSON do Godot devolve todo número como float (como o JS, que não
## distingue int de float). Converta com int() onde o valor é inteiro e NUNCA
## divida dois ints com `/` (no GDScript isso é divisão inteira; no JS não é).

const DIR := "res://data/"

static var _cache: Dictionary = {}


## Lê data/<file_name> e devolve o conteúdo (Dictionary/Array), ou null com push_error.
static func load_json(file_name: String) -> Variant:
	if _cache.has(file_name):
		return _cache[file_name]
	var path := DIR + file_name
	if not FileAccess.file_exists(path):
		push_error("arquivo de dados ausente: %s" % path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_error("JSON inválido em %s (linha %d): %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	_cache[file_name] = json.data
	return json.data
