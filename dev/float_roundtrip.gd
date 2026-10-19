extends SceneTree
## Checa se JSON.stringify(full_precision) + parse devolve exatamente o mesmo double.

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var bad := 0
	var total := 200000
	for i in total:
		var x: float = rng.randf_range(-1000.0, 1000.0) * pow(10.0, rng.randi_range(-8, 8))
		var text := JSON.stringify({"v": x}, "", true, true)
		var back: float = JSON.parse_string(text)["v"]
		if Golden.bits_of(back) != Golden.bits_of(x):
			bad += 1
			if bad < 4:
				print("difere: ", x, " -> ", text, " -> ", back)
	print("mudaram: %d de %d" % [bad, total])
	quit()
