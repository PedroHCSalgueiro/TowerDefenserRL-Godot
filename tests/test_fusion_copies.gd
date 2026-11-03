extends GutTest
## Fusão com 3 cópias por estrela (heróis): as cópias que ainda não sobem a estrela ficam guardadas na
## torre, a ★3 pede 9 cópias, o aviso da loja mostra o progresso e o save guarda as cópias. O Padrão
## continua com 2.

var _map: SimMap


func before_all() -> void:
	_map = SimMap.load_map(DataLoader.load_json("map.json"))


func after_each() -> void:
	GameSets.select(GameSets.DEFAULT_ID)


func _sim() -> Simulation:
	var sim := Simulation.create("copias", GameSystems.create(_map))
	sim.state.gold = 100000
	return sim


func _free_cell(sim: Simulation) -> Vector2i:
	var taken := {}
	for t: Tower in sim.state.towers:
		taken[Vector2i(t.x, t.y)] = true
	for y in _map.height:
		for x in _map.width:
			var c := Vector2i(x, y)
			if _map.can_place_tower(c) and not taken.has(c):
				return c
	return Vector2i(-1, -1)


## Compra uma cópia de `type` pelo slot 0 (posiciona numa casa livre se não fundir). Devolve os eventos.
func _buy(sim: Simulation, type: String) -> Array:
	sim.state.shop.slots[0] = type
	var cell := _free_cell(sim)
	sim.enqueue({"type": "buyTower", "slot": 0, "x": cell.x, "y": cell.y})
	sim.step()
	return sim.drain_events()


func _towers_of(sim: Simulation, type: String) -> Array:
	return sim.state.towers.filter(func(t: Tower) -> bool: return t.type == type)


func _types(events: Array) -> Array:
	return events.map(func(e: Dictionary) -> String: return e["type"])


func test_padrao_continua_com_2_copias() -> void:
	assert_eq(TowerData.game_data().copies_per_star, 2)


func test_herois_pedem_3_copias() -> void:
	GameSets.select("valcoroa_costarubra")
	assert_eq(TowerData.game_data().copies_per_star, 3)


func test_estrelas_sobem_na_3a_e_na_9a_copia() -> void:
	GameSets.select("valcoroa")
	var sim := _sim()
	var stars := []
	for i in 9:
		_buy(sim, "aldric")
		var mine := _towers_of(sim, "aldric")
		stars.append(mine.map(func(t: Tower) -> int: return t.star))
	assert_eq(stars, [[1], [1], [2], [2, 1], [2, 1], [2], [2, 1], [2, 1], [3]],
			"★2 com 3 cópias; a 2ª ★2 fica guardada na 1ª (uma torre só); a 3ª ★2 vira ★3")
	assert_eq(_towers_of(sim, "aldric")[0].copies, 0, "a ★3 não guarda cópias")


func test_copia_guardada_emite_copy_stored_e_nao_ocupa_casa() -> void:
	GameSets.select("valcoroa")
	var sim := _sim()
	_buy(sim, "lyra")
	var events := _buy(sim, "lyra")
	assert_true(_types(events).has("copyStored"))
	assert_false(_types(events).has("towersMerged"))
	assert_eq(_towers_of(sim, "lyra").size(), 1)
	assert_eq(_towers_of(sim, "lyra")[0].copies, 1)
	events = _buy(sim, "lyra")
	assert_true(_types(events).has("towersMerged"), "a 3ª cópia sobe a estrela")
	assert_eq(_towers_of(sim, "lyra")[0].star, 2)
	assert_eq(_towers_of(sim, "lyra")[0].copies, 0)


func test_investido_soma_todas_as_copias() -> void:
	GameSets.select("valcoroa")
	var sim := _sim()
	var price := Shop.shop_price(EconomyData.game_data(), TowerData.game_data(), sim.state, "tomas")
	for i in 3:
		_buy(sim, "tomas")
	assert_eq(_towers_of(sim, "tomas")[0].invested, 3 * price)


func test_aviso_da_loja_mostra_o_progresso() -> void:
	GameSets.select("valcoroa")
	var sim := _sim()
	var towers := TowerData.game_data()
	assert_eq(Fusion.plan_label(Fusion.plan_fusion(sim.state.towers, towers, "aldric")), "", "sem torre não funde")
	_buy(sim, "aldric")
	assert_eq(Fusion.plan_label(Fusion.plan_fusion(sim.state.towers, towers, "aldric")), "★2 2/3")
	_buy(sim, "aldric")
	assert_eq(Fusion.plan_label(Fusion.plan_fusion(sim.state.towers, towers, "aldric")), "★2↑")
	_buy(sim, "aldric")
	_buy(sim, "aldric")
	_buy(sim, "aldric")
	assert_eq(Fusion.plan_label(Fusion.plan_fusion(sim.state.towers, towers, "aldric")), "★3 2/3",
			"a 2ª ★2 ficaria guardada na 1ª")


func test_dica_da_torre_mostra_as_copias() -> void:
	GameSets.select("valcoroa")
	var sim := _sim()
	var towers := TowerData.game_data()
	_buy(sim, "aldric")
	_buy(sim, "aldric")
	var tower: Tower = _towers_of(sim, "aldric")[0]
	assert_eq(TowerInfo.copies_progress(towers.get_type("aldric"), tower, towers), "Cópias: 2 de 3 para ★2")


func test_save_guarda_as_copias() -> void:
	GameSets.select("valcoroa")
	var sim := _sim()
	_buy(sim, "aldric")
	_buy(sim, "aldric")
	var restored := Simulation.restore(sim.serialize(), GameSystems.create(_map), _map)
	assert_not_null(restored)
	assert_eq(_towers_of(restored, "aldric")[0].copies, 1)
	_buy(restored, "aldric")
	assert_eq(_towers_of(restored, "aldric")[0].star, 2, "a cópia guardada conta depois de abrir o save")


func test_precos_e_renda_dos_herois() -> void:
	GameSets.select("valcoroa_costarubra")
	var economy := EconomyData.game_data()
	assert_eq([economy.shop_prices["common"], economy.shop_prices["uncommon"], economy.shop_prices["rare"],
			economy.shop_prices["legendary"]], [10, 20, 30, 50])
	assert_eq(Economy.wave_bonus_for(economy, 1), 4)
	assert_eq(Economy.wave_bonus_for(economy, 10), 13)
