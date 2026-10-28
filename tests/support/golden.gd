class_name Golden
extends RefCounted
## Carrega os golden files gerados a partir do Phaser (tests/golden/*.json).
## Para regenerar: tools/golden/README.md.
##
## Floats que precisam bater BIT A BIT vêm gravados como texto com o padrão de
## bits IEEE-754 (inteiro de 64 bits em decimal): o parser de JSON do Godot não
## garante o último bit de um float. Compare com `bits_of(valor) == parse_bits(texto)`.

const DIR := "res://tests/golden/"


## Opções de `GameSystems.create` com a economia que o Phaser tinha quando os golden files foram gerados
## (ouro só no fim da onda, 15 + 1 × onda). A economia do jogo mudou (ouro por abate, T-ouro-por-abate);
## a paridade dos demais sistemas continua provada com esta. O mesmo vale para as ondas: `waves_phaser.json`
## é o `data/waves.json` de antes das hordas apertadas do início da run (quantidades e espaçamento novos).
static func phaser_options() -> Dictionary:
	return {
		"economy": EconomyData.load_data(load_json("economy_phaser.json")),
		"waves": WaveData.load_data(load_json("waves_phaser.json"), EnemyData.game_data()),
	}


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


## Padrão de bits IEEE-754 (64) do float, como int com sinal.
static func bits_of(value: float) -> int:
	return PackedFloat64Array([value]).to_byte_array().decode_s64(0)


## Lê um padrão de bits gravado como texto decimal.
static func parse_bits(text: Variant) -> int:
	return String(text).to_int()


## Float correspondente a um padrão de bits gravado como texto (para mensagens de erro).
static func float_of_bits(text: Variant) -> float:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_s64(0, parse_bits(text))
	return bytes.decode_double(0)
