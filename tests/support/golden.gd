class_name Golden
extends RefCounted
## Carrega os golden files gerados a partir do Phaser (tests/golden/*.json).
## Para regenerar: tools/golden/README.md.

const DIR := "res://tests/golden/"


static func load_json(file_name: String) -> Variant:
	var path := DIR + file_name
	if not FileAccess.file_exists(path):
		push_error("golden file ausente: %s (veja tools/golden/README.md)" % path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_error("golden file inválido: %s (linha %d)" % [path, json.get_error_line()])
		return null
	return json.data
