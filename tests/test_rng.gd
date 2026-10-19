extends GutTest
## Porte de tests/rng.test.ts + paridade exata com o Phaser (tests/golden/rng.json).


func _sequence(seed_text: String, count: int) -> Array:
	var rng := Rng.new(RngHolder.new(Rng.hash_seed(seed_text)))
	var out: Array = []
	for i in count:
		out.append(rng.next_float())
	return out


func test_mesma_semente_mesma_sequencia() -> void:
	assert_eq(_sequence("abc", 100), _sequence("abc", 100))


func test_sementes_diferentes_sequencias_diferentes() -> void:
	assert_ne(_sequence("abc", 10), _sequence("abd", 10))


func test_next_float_fica_em_0_1() -> void:
	for value in _sequence("range", 10000):
		assert_true(value >= 0.0 and value < 1.0)


func test_next_int_respeita_limites_e_alcanca_as_pontas() -> void:
	var rng := Rng.new(RngHolder.new(Rng.hash_seed("int")))
	var seen := {}
	for i in 1000:
		var value := rng.next_int(3, 7)
		assert_between(value, 3, 7)
		seen[value] = true
	var keys := seen.keys()
	keys.sort()
	assert_eq(keys, [3, 4, 5, 6, 7])


func test_next_int_rejeita_intervalo_invalido() -> void:
	var rng := Rng.new(RngHolder.new(1))
	assert_eq(rng.next_int(5, 4), 5)
	assert_push_error("intervalo inválido")


func test_continua_a_mesma_sequencia_apos_salvar_e_restaurar() -> void:
	var holder := RngHolder.new(Rng.hash_seed("save"))
	var rng := Rng.new(holder)
	for i in 50:
		rng.next_float()
	var restored := Rng.new(RngHolder.new(holder.rng_state))
	var expected: Array = []
	var actual: Array = []
	for i in 20:
		expected.append(rng.next_float())
		actual.append(restored.next_float())
	assert_eq(actual, expected)


func test_hash_seed_e_estavel() -> void:
	assert_eq(Rng.hash_seed(""), 0x811c9dc5)
	assert_eq(Rng.hash_seed("a"), 0xe40c292c)


func test_shuffle_e_deterministico_e_mantem_os_elementos() -> void:
	var a := Rng.new(RngHolder.new(42)).shuffle([1, 2, 3, 4, 5, 6, 7, 8])
	var b := Rng.new(RngHolder.new(42)).shuffle([1, 2, 3, 4, 5, 6, 7, 8])
	assert_eq(a, b)
	var sorted := a.duplicate()
	sorted.sort()
	assert_eq(sorted, [1, 2, 3, 4, 5, 6, 7, 8])


func test_pick_rejeita_lista_vazia() -> void:
	assert_null(Rng.new(RngHolder.new(1)).pick([]))
	assert_push_error("lista vazia")


# ---------------------------------------------------------------- paridade com o Phaser

var _golden: Dictionary


func before_all() -> void:
	_golden = Golden.load_json("rng.json")


func test_golden_hash_seed_e_next_float_exatos() -> void:
	for entry in _golden["floats"]:
		assert_eq(Rng.hash_seed(entry["seed"]), int(entry["hash"]), "hash da semente '%s'" % entry["seed"])
		var holder := RngHolder.new(int(entry["hash"]))
		var rng := Rng.new(holder)
		var values: Array = entry["values"]
		var mismatches := 0
		for i in values.size():
			if int(rng.next_float() * 4294967296.0) != int(values[i]):
				mismatches += 1
		assert_eq(mismatches, 0, "semente '%s': saídas diferentes do Phaser" % entry["seed"])
		assert_eq(holder.rng_state, int(entry["finalState"]), "estado final da semente '%s'" % entry["seed"])


func test_golden_next_int() -> void:
	for entry in _golden["ints"]:
		var holder := RngHolder.new(Rng.hash_seed("ints"))
		var rng := Rng.new(holder)
		var values: Array = entry["values"]
		var mismatches := 0
		for i in values.size():
			if rng.next_int(int(entry["min"]), int(entry["max"])) != int(values[i]):
				mismatches += 1
		assert_eq(mismatches, 0, "next_int(%d, %d)" % [entry["min"], entry["max"]])
		assert_eq(holder.rng_state, int(entry["finalState"]))


func test_golden_chance() -> void:
	var holder := RngHolder.new(Rng.hash_seed("chance"))
	var rng := Rng.new(holder)
	var entry: Dictionary = _golden["chance"]
	var mismatches := 0
	for expected in entry["values"]:
		if (1 if rng.chance(float(entry["p"])) else 0) != int(expected):
			mismatches += 1
	assert_eq(mismatches, 0)
	assert_eq(holder.rng_state, int(entry["finalState"]))


func test_golden_pick() -> void:
	var holder := RngHolder.new(Rng.hash_seed("pick"))
	var rng := Rng.new(holder)
	var entry: Dictionary = _golden["pick"]
	var items: Array = []
	for item in entry["items"]:
		items.append(int(item))
	var mismatches := 0
	for expected in entry["values"]:
		if int(rng.pick(items)) != int(expected):
			mismatches += 1
	assert_eq(mismatches, 0)
	assert_eq(holder.rng_state, int(entry["finalState"]))


func test_golden_shuffle() -> void:
	var holder := RngHolder.new(Rng.hash_seed("shuffle"))
	var rng := Rng.new(holder)
	var entry: Dictionary = _golden["shuffle"]
	var items: Array = []
	for item in entry["start"]:
		items.append(int(item))
	for expected in entry["results"]:
		rng.shuffle(items)
		var expected_ints: Array = []
		for item in expected:
			expected_ints.append(int(item))
		assert_eq(items, expected_ints)
	assert_eq(holder.rng_state, int(entry["finalState"]))
