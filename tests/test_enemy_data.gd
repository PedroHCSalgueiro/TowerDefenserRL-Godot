extends GutTest
## Porte de tests/enemyData.test.ts (parte de inimigos e armadura).
## A parte "dados do núcleo" entra com o porte de sim/nexus.


func test_apply_armor_sem_armadura_o_dano_passa_inteiro() -> void:
	assert_eq(Armor.apply_armor(12.0, 0.0, 100.0), 12.0)


func test_apply_armor_formula() -> void:
	assert_almost_eq(Armor.apply_armor(30.0, 50.0, 100.0), 20.0, 1e-12)
	assert_eq(Armor.apply_armor(10.0, 100.0, 100.0), 5.0)
	assert_almost_eq(Armor.apply_armor(10.0, 100.0, 50.0), 10.0 / 3.0, 1e-12)


func test_apply_armor_nunca_zera() -> void:
	assert_gt(Armor.apply_armor(1.0, 10000.0, 100.0), 0.0)


func test_enemies_json_tem_os_4_tipos_do_prototipo_e_os_dois_chefoes() -> void:
	var data := EnemyData.game_data()
	assert_eq(data.types.keys(), ["common", "fast", "armored", "flying", "boss", "bossFinal"])
	assert_eq(data.get_type("flying").movement, "air")
	assert_eq(data.get_type("armored").armor, 50.0)
	assert_eq(data.armor_scale, 100.0)
	assert_true(data.get_type("boss").boss)
	assert_false(data.get_type("common").boss)


func test_blindado_leva_cerca_de_33_por_cento_menos_dano() -> void:
	var data := EnemyData.game_data()
	var armored := data.get_type("armored")
	assert_almost_eq(1.0 - Armor.apply_armor(1.0, armored.armor, data.armor_scale), 1.0 / 3.0, 1e-12)


func test_tipo_desconhecido_e_erro() -> void:
	var data := EnemyData.game_data()
	assert_null(data.get_type("dragon"))
	assert_push_error("desconhecido")
	assert_null(data.get_type("toString"))
	assert_push_error("desconhecido")


func test_elite_e_velocidade_e_dano_no_nucleo() -> void:
	var data := EnemyData.game_data()
	var common := data.get_type("common")
	assert_eq(data.enemy_speed(common, false), 1.0)
	assert_almost_eq(data.enemy_speed(common, true), 0.8, 1e-12)
	assert_eq(data.enemy_nexus_damage(common, false), 1.0)
	assert_eq(data.enemy_nexus_damage(common, true), 5.0)


func _raw() -> Dictionary:
	return DataLoader.load_json("enemies.json").duplicate(true)


func _with_type(type: Variant) -> Dictionary:
	var raw := _raw()
	raw["types"] = {"x": type}
	return raw


func test_rejeita_dados_invalidos() -> void:
	var common: Dictionary = _raw()["types"]["common"]
	for patch: Dictionary in [{"speed": 0}, {"armor": -1}, {"movement": "swim"}, {"boss": "sim"}]:
		var bad := common.duplicate()
		bad.merge(patch, true)
		assert_null(EnemyData.load_data(_with_type(bad)), str(patch))
		assert_push_error('"x"')
	var no_hp := common.duplicate()
	no_hp.erase("hp")
	assert_null(EnemyData.load_data(_with_type(no_hp)))
	assert_push_error('"x"')

	var empty := _raw()
	empty["types"] = {}
	assert_null(EnemyData.load_data(empty))
	assert_push_error("nenhum tipo")
	var zero_scale := _raw()
	zero_scale["armor"] = {"scale": 0}
	assert_null(EnemyData.load_data(zero_scale))
	assert_push_error("scale")
	var no_armor := _raw()
	no_armor.erase("armor")
	assert_null(EnemyData.load_data(no_armor))
	assert_push_error("armor")
	var no_elite := _raw()
	no_elite.erase("elite")
	assert_null(EnemyData.load_data(no_elite))
	assert_push_error("elite")
	for patch: Dictionary in [{"hpMultiplier": 0}, {"speedMultiplier": -1}]:
		var bad_elite := _raw()
		bad_elite["elite"].merge(patch, true)
		assert_null(EnemyData.load_data(bad_elite), str(patch))
		assert_push_error("elite")
	var no_nexus_damage := _raw()
	no_nexus_damage["elite"].erase("nexusDamage")
	assert_null(EnemyData.load_data(no_nexus_damage))
	assert_push_error("elite")


func test_golden_armadura_bit_a_bit() -> void:
	var golden: Dictionary = Golden.load_json("enemies.json")
	for c: Dictionary in golden["armorCases"]:
		var got := Armor.apply_armor(float(c["raw"]), float(c["armor"]), float(c["scale"]))
		assert_eq(Golden.bits_of(got), Golden.parse_bits(c["result"]), "armadura %s" % str(c))
