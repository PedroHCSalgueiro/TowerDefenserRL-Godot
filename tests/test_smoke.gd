extends GutTest
# Teste de fumaça: o GUT roda e todos os JSON de data/ (copiados do Phaser) são válidos.

const DATA_DIR := "res://data/"


func test_gut_roda() -> void:
	assert_true(true)


func test_todos_os_json_de_data_sao_validos() -> void:
	var dir := DirAccess.open(DATA_DIR)
	assert_not_null(dir, "pasta data/ deve existir")
	var achados := 0
	for nome in dir.get_files():
		if not nome.ends_with(".json"):
			continue
		achados += 1
		var texto := FileAccess.get_file_as_string(DATA_DIR + nome)
		var json := JSON.new()
		assert_eq(json.parse(texto), OK, "%s deve ser JSON válido" % nome)
	assert_gt(achados, 0, "deve haver arquivos .json em data/")
