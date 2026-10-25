extends GutTest
## Conjuntos de torres (Padrão e Reino de Valcoroa): troca de dados, mesclagem dos arquivos do conjunto
## e uma run de ponta a ponta com as torres de Valcoroa.

const VALCOROA := ["aldric", "lyra", "tomas", "brom", "selene", "wulf", "mabel", "isolde"]


func after_each() -> void:
	GameSets.select(GameSets.DEFAULT_ID)


func test_lista_tem_padrao_as_cinco_regioes_e_as_combinacoes() -> void:
	var ids := GameSets.list().map(func(s: Dictionary) -> String: return s["id"])
	assert_eq(ids, ["default", "valcoroa", "costarubra", "valcoroa_costarubra", "forjaferro", "cripta", "panteao", "todas"])
	assert_true(GameSets.has_set("valcoroa"))
	assert_true(GameSets.has_set("costarubra"))
	assert_false(GameSets.has_set("nao-existe"))


func test_conjunto_desconhecido_e_recusado() -> void:
	assert_false(GameSets.select("nao-existe"))
	assert_push_error("desconhecido")
	assert_eq(GameSets.current(), "default")


func test_padrao_nao_tem_torres_de_valcoroa() -> void:
	var towers := TowerData.game_data()
	assert_true(towers.has_type("mortar"))
	assert_false(towers.has_type("aldric"))


func test_valcoroa_troca_torres_classes_e_recompensas() -> void:
	assert_true(GameSets.select("valcoroa"))
	var towers := TowerData.game_data()
	for id in VALCOROA:
		assert_true(towers.has_type(id), id)
	assert_false(towers.has_type("mortar"), "o conjunto substitui as torres")
	assert_true(towers.has_type("basic"), "torres de teste continuam")
	var classes := ClassData.game_data()
	assert_true(classes.classes.has("guardian") and classes.classes.has("valcoroa"))
	assert_false(classes.classes.has("artillery"))
	for id: String in RewardData.game_data().by_id:
		assert_ne(id, "artilleryArea", "sem recompensas de classes que não existem no conjunto")


func test_volta_ao_padrao() -> void:
	GameSets.select("valcoroa")
	GameSets.select("default")
	assert_true(TowerData.game_data().has_type("mortar"))
	assert_false(TowerData.game_data().has_type("aldric"))


func test_valcoroa_tem_8_herois_com_raridades_3_2_2_1() -> void:
	GameSets.select("valcoroa")
	var towers := TowerData.game_data()
	var count := {"common": 0, "uncommon": 0, "rare": 0, "legendary": 0}
	for id in VALCOROA:
		count[towers.get_type(id).rarity] += 1
	assert_eq(count, {"common": 3, "uncommon": 2, "rare": 2, "legendary": 1})


func test_mesclagem_dos_arquivos_do_conjunto() -> void:
	GameSets.select("valcoroa")
	var ui: Dictionary = DataLoader.load_json("ui.json")
	assert_true(ui["texts"]["towerSummaries"].has("aldric"), "texto novo do conjunto")
	assert_true(ui["texts"]["towerSummaries"].has("mortar"), "o resto de ui.json continua")
	assert_true(ui.has("shop"))
	var render: Dictionary = DataLoader.load_json("render.json")
	assert_true(render["towers"]["classColors"].has("guardian"))
	assert_true(render["towers"]["classColors"].has("artillery"), "cores antigas continuam")


func test_combine_substitui_com_replace() -> void:
	var out: Dictionary = DataLoader._combine({"a": 1, "b": {"c": 2}}, {"$replace": true, "x": 9})
	assert_eq(out, {"x": 9})
	out = DataLoader._combine({"a": 1, "b": {"c": 2, "d": 3}}, {"b": {"c": 5}})
	assert_eq(out, {"a": 1, "b": {"c": 5, "d": 3}})


func test_run_com_torres_de_valcoroa() -> void:
	GameSets.select("valcoroa")
	var map := SimMap.load_map(DataLoader.load_json("map.json"))
	var sim := Simulation.create("valcoroa-run", GameSystems.create(map))
	for c in [
		{"type": "debugSetNexusInvulnerable", "value": true},
		{"type": "debugSpawnTowers", "count": 16, "towerTypes": VALCOROA, "layout": "clustered", "star": 2},
		{"type": "callWave"},
	]:
		sim.enqueue(c)
	var kills := 0
	for i in 900:
		sim.step()
		for e: Dictionary in sim.drain_events():
			if e["type"] == "enemyKilled":
				kills += 1
	assert_gt(kills, 0, "as torres de Valcoroa abatem inimigos")
	# O save de uma run de Valcoroa volta igual.
	var restored := Simulation.restore(sim.serialize(), GameSystems.create(map), map)
	assert_eq(restored.serialize(), sim.serialize())


func test_primeira_loja_de_valcoroa_so_tem_comuns() -> void:
	GameSets.select("valcoroa")
	var towers := TowerData.game_data()
	var map := SimMap.load_map(DataLoader.load_json("map.json"))
	for s in ["a", "b", "c", "d"]:
		var sim := Simulation.create("loja-" + s, GameSystems.create(map))
		for id: String in sim.state.shop.slots:
			assert_eq(towers.get_type(id).rarity, "common")


func test_menu_instancia_e_joga() -> void:
	var menu: MainMenu = load("res://scenes/menu.tscn").instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame
	assert_gt(menu.get_child_count(), 0, "a tela inicial foi montada")
