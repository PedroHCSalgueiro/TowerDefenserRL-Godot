extends GutTest
## Costa Rubra: os 8 campeões, os estados novos (Empurrado, Marcado, Amaldiçoado), o Lento do Sir Aldric,
## os bônus de classe do Guardião e do Caçador, o bônus de região e os conjuntos da tela inicial.
## Os números esperados vêm dos dados (data/sets/), não do código.

const COSTA := ["bart", "ruby", "anchor", "morgana", "pena", "kraus", "zuri", "nerea"]
const VALCOROA := ["aldric", "lyra", "tomas", "brom", "selene", "wulf", "mabel", "isolde"]

var _map: SimMap


## Um tick "de mentira" para chamar os efeitos de gatilho direto: estado da run, contexto, índice e o
## motor (que só serve de `env` para `TriggerEffects`).
class Harness:
	extends RefCounted
	var state: RunState
	var ctx: TickContext
	var engine: TriggerEngine
	var routes: Dictionary
	var index: SpatialIndex
	var enemies: EnemyData
	var towers: TowerData
	var classes: ClassData

	func _init(map: SimMap) -> void:
		state = RunState.create("costa-rubra")
		enemies = EnemyData.game_data()
		towers = TowerData.game_data()
		classes = ClassData.game_data()
		routes = Route.build_routes(map)
		index = SpatialIndex.new(1.0)
		engine = TriggerEngine.new({"index": index, "enemies": enemies, "towers": towers, "classes": classes,
				"scores": Targeting.create_target_scores(routes, enemies), "ticksPerSecond": 30.0, "routes": routes})
		next_tick()

	## Tick novo: o índice espacial é refeito na próxima consulta.
	func next_tick() -> void:
		state.tick += 1
		ctx = TickContext.new(state, Rng.new(state), [], [], EventBus.new())
		ctx.index = index
		ctx.classes = classes
		engine.ctx = ctx

	func spawn(type: String, distance: float, elite: bool = false) -> Enemy:
		return EnemySystems.spawn_enemy(ctx, routes, enemies, type, distance, 1.0, 1, elite)

	## Torre posta à mão ao lado do ponto da rota a `distance` casas (o alcance dela cobre os vizinhos).
	func tower_at(type: String, distance: float, star: int = 1, id: int = 0) -> Tower:
		var p := MutablePoint.new()
		(routes["ground"] as Route).sample_into(distance, p)
		var tower := Tower.new(id if id > 0 else 9000 + state.towers.size(), type, Vector2i(roundi(p.x), roundi(p.y) + 1), star)
		state.towers.append(tower)
		return tower

	func set_level(class_id: String, level: int) -> void:
		(state.classes[class_id] as ClassState.ClassStatus).level = level

	## O efeito do gatilho da torre, na estrela dela. Devolve o que `run_effect` devolve.
	func fire(tower: Tower) -> bool:
		var type := towers.get_type(tower.type)
		var star := Stars.tower_star(type, tower)
		return TriggerEffects.run_effect(engine, tower, type, star.effect, TriggerState.PendingTrigger.new(), false)

	func effect(tower: Tower) -> Dictionary:
		return Stars.tower_star(towers.get_type(tower.type), tower).effect

	func events_of(type: String) -> Array:
		return ctx.tick_events.filter(func(e: Dictionary) -> bool: return e["type"] == type)

	## Roda o sistema de projéteis até não sobrar projétil no ar (no máximo `ticks`).
	func fly_projectiles(ticks: int = 60) -> void:
		var system := ProjectileSystems.create_projectile_system(enemies, index, towers.projectile_retarget_radius,
				30.0, towers, classes)
		for i in ticks:
			if state.projectiles.active_count == 0:
				return
			next_tick()
			system.call(ctx)


func before_all() -> void:
	GameSets.select("costarubra")
	_map = SimMap.load_map(DataLoader.load_json("map.json"))


func before_each() -> void:
	GameSets.select("costarubra")


func after_all() -> void:
	GameSets.select(GameSets.DEFAULT_ID)


func _h() -> Harness:
	return Harness.new(_map)


func _combo() -> Harness:
	GameSets.select("valcoroa_costarubra")
	return Harness.new(_map)


# ------------------------------------------------------------------ conjuntos

func test_costa_rubra_tem_os_8_com_raridades_3_3_2_e_classe_de_regiao() -> void:
	var towers := TowerData.game_data()
	var count := {"common": 0, "uncommon": 0, "rare": 0, "legendary": 0}
	var classes := {}
	for id in COSTA:
		assert_true(towers.has_type(id), id)
		var type := towers.get_type(id)
		count[type.rarity] += 1
		assert_eq(type.classes[1], "costarubra", "%s é da Costa Rubra" % id)
		classes[type.classes[0]] = true
	assert_eq(count, {"common": 3, "uncommon": 3, "rare": 2, "legendary": 0})
	assert_eq(classes.size(), 8, "uma de cada classe")
	for id in VALCOROA:
		assert_false(towers.has_type(id), "sem os heróis do Reino")
	assert_false(towers.has_type("mortar"))
	for id in COSTA:
		assert_eq(Stars.max_stars(towers.get_type(id)), 3, "%s tem ★1 a ★3" % id)


func test_valcoroa_mais_costa_rubra_tem_os_16() -> void:
	GameSets.select("valcoroa_costarubra")
	var towers := TowerData.game_data()
	for id in COSTA + VALCOROA:
		assert_true(towers.has_type(id), id)
	var classes := ClassData.game_data()
	assert_true(classes.classes.has("valcoroa") and classes.classes.has("costarubra"))
	assert_eq(DataLoader.load_json("debug.json")["fullScenario"]["towerTypes"].size(), 16)


func test_loja_da_costa_rubra_sem_lendaria_nunca_falha() -> void:
	var towers := TowerData.game_data()
	var economy := EconomyData.game_data()
	var state := RunState.create("loja-cr")
	state.wave = 40
	var rng := Rng.new(state)
	for i in 50:
		var shop := Shop.new_shop(rng, economy, towers, Shop.chances_for_state(economy, state), false)
		assert_not_null(shop)
		for id: String in shop.slots:
			assert_true(COSTA.has(id))
	assert_eq(Shop.shop_pools(towers)["legendary"], [])


func test_primeira_loja_so_tem_comuns() -> void:
	var towers := TowerData.game_data()
	for s in ["a", "b", "c"]:
		var sim := Simulation.create("cr-loja-" + s, GameSystems.create(_map))
		for id: String in sim.state.shop.slots:
			assert_eq(towers.get_type(id).rarity, "common")


# ------------------------------------------------------------------ Marcado

func test_marca_uma_por_cacador_renova_e_expira() -> void:
	var e := Enemy.new()
	e.active = true
	Status.apply_mark(e, 7, 90)
	Status.apply_mark(e, 8, 30)
	assert_eq(e.marks.size(), 2, "uma marca por Caçador")
	Status.apply_mark(e, 8, 90)
	assert_eq(e.marks[8], 90, "acertar de novo renova")
	assert_eq(TowerData.game_data().statuses["mark"]["seconds"], 3.0, "3 s de partida")


func test_tiro_de_cacador_marca_e_a_marca_some_em_3_s() -> void:
	var h := _h()
	var enemy := h.spawn("common", 10.0)
	var kraus := h.tower_at("kraus", 10.0)
	TowerSystems.fire_tower_shot(h.ctx, kraus, h.towers.get_type("kraus"), enemy, "normal", h.classes)
	h.fly_projectiles()
	assert_true(enemy.marks.has(kraus.id), "o arpão marcou")
	var status := Status.create_status_system(h.enemies)
	for i in 89:
		h.next_tick()
		status.call(h.ctx)
	assert_true(enemy.marks.has(kraus.id), "ainda marcado")
	h.next_tick()
	status.call(h.ctx)
	assert_false(enemy.marks.has(kraus.id), "a marca durou 3 s (90 ticks)")


func test_wulf_tambem_marca() -> void:
	GameSets.select("valcoroa")
	var towers := TowerData.game_data()
	assert_true(towers.get_type("wulf").marks)
	assert_false(towers.get_type("lyra").marks, "só Caçador marca")


func _shot_damage(h: Harness, shooter: String, marks: int) -> float:
	var enemy := h.spawn("common", 10.0)
	enemy.hp = 10000.0
	enemy.max_hp = 10000.0
	for i in marks:
		Status.apply_mark(enemy, 100 + i, 90)
	var tower := h.tower_at(shooter, 10.0)
	TowerSystems.fire_tower_shot(h.ctx, tower, h.towers.get_type(shooter), enemy, "normal", h.classes)
	h.fly_projectiles()
	return 10000.0 - enemy.hp


func test_bonus_de_marca_so_com_2_cacadores_e_so_para_cacador() -> void:
	var h := _combo()
	var base: float = h.towers.get_type("kraus").damage
	assert_eq(_shot_damage(h, "kraus", 2), base, "Caçador sozinho: marca, mas sem bônus")
	h.set_level("hunter", 1)
	assert_almost_eq(_shot_damage(h, "kraus", 1), base * 1.1, 1e-9, "2 Caçadores: +10% por marca")
	assert_almost_eq(_shot_damage(h, "kraus", 2), base * 1.2, 1e-9, "2 marcas = +20%")
	var lyra: float = h.towers.get_type("lyra").damage
	assert_eq(_shot_damage(h, "lyra", 2), lyra, "quem não é Caçador não ganha bônus")
	h.set_level("hunter", 2)
	assert_almost_eq(_shot_damage(h, "kraus", 2), base * 1.3, 1e-9, "Caçador 4: +15% por marca")


func test_bonus_de_marca_nao_afeta_o_sangramento_do_wulf() -> void:
	var h := _combo()
	h.set_level("hunter", 1)
	var enemy := h.spawn("common", 10.0)
	enemy.hp = 10000.0
	Status.apply_mark(enemy, 555, 90)
	var wulf := h.tower_at("wulf", 10.0)
	var type := h.towers.get_type("wulf")
	TowerSystems.fire_tower_shot(h.ctx, wulf, type, enemy, "normal", h.classes)
	h.fly_projectiles()
	var expected: float = (type.damage * type.on_hit["bleed"]["percentPerSecond"] / 100.0) / 30.0
	assert_almost_eq(enemy.bleed_damage, expected, 1e-12, "o Sangramento sai do dano normal, sem o bônus")
	assert_eq(enemy.marks.size(), 2, "e a flecha marca")


func test_classe_cacador_liga_com_wulf_e_kraus_em_campo() -> void:
	GameSets.select("valcoroa_costarubra")
	var sim := Simulation.create("cacada", GameSystems.create(_map))
	var cells := WaveBot.bot_cells(_map)
	sim.enqueue({"type": "placeTower", "towerType": "kraus", "x": cells[0].x, "y": cells[0].y})
	sim.step()
	sim.step()
	assert_eq((sim.state.classes["hunter"] as ClassState.ClassStatus).level, 0, "um Caçador: sem bônus")
	sim.enqueue({"type": "placeTower", "towerType": "wulf", "x": cells[1].x, "y": cells[1].y})
	sim.step()
	sim.step()
	assert_eq((sim.state.classes["hunter"] as ClassState.ClassStatus).level, 1, "Wulf + Kraus: bônus de 2")


# ------------------------------------------------------------------ Empurrado (Imediato Âncora)

func test_ancora_empurra_o_primeiro_e_o_colado_2_casas() -> void:
	var h := _h()
	var front := h.spawn("common", 12.0)
	var glued := h.spawn("common", 11.25)
	var far := h.spawn("common", 10.5)
	var anchor := h.tower_at("anchor", 11.5)
	assert_true(h.fire(anchor))
	assert_eq(front.distance, 10.0, "o primeiro volta 2 casas")
	assert_eq(glued.distance, 9.25, "o colado (até 1 casa atrás) vai junto")
	assert_eq(far.distance, 10.5, "o que não está colado fica")
	var pushes: Array = h.events_of("enemiesPushed")[0]["pushes"]
	assert_eq(pushes.map(func(p: Dictionary) -> int: return p["enemyId"]), [front.id, glued.id])
	# A posição acompanha a distância (e o movimento continua dali).
	var p := MutablePoint.new()
	(h.routes["ground"] as Route).sample_into(10.0, p)
	assert_eq([front.x, front.y], [p.x, p.y])


func test_ancora_com_o_primeiro_sozinho_empurra_so_ele() -> void:
	var h := _h()
	var front := h.spawn("common", 12.0)
	var behind := h.spawn("common", 10.5)
	var anchor := h.tower_at("anchor", 11.5)
	h.fire(anchor)
	assert_eq(front.distance, 10.0)
	assert_eq(behind.distance, 10.5, "1,5 casa atrás não é colado")
	assert_eq(h.events_of("enemiesPushed")[0]["pushes"].size(), 1)


func test_ancora_empate_na_distancia_vai_pelo_menor_id() -> void:
	var h := _h()
	var a := h.spawn("common", 12.0)
	var b := h.spawn("common", 12.0)
	var anchor := h.tower_at("anchor", 12.0)
	h.fire(anchor)
	var pushes: Array = h.events_of("enemiesPushed")[0]["pushes"]
	assert_eq(pushes[0]["enemyId"], a.id, "o primeiro da fila é o de menor id")
	assert_eq(pushes[1]["enemyId"], b.id, "o outro, na mesma distância, está colado")
	assert_eq([a.distance, b.distance], [10.0, 10.0])


func test_empurrado_chefao_imune_e_elite_no_maximo_1_casa() -> void:
	var h := _h()
	var boss := h.spawn("boss", 12.0)
	var elite := h.spawn("common", 11.5, true)
	var anchor := h.tower_at("anchor", 12.0)
	h.fire(anchor)
	assert_eq(boss.distance, 12.0, "chefão imune")
	assert_eq(elite.distance, 10.5, "elite volta só 1 casa")
	var pushes: Array = h.events_of("enemiesPushed")[0]["pushes"]
	assert_eq(pushes[0]["cells"], 0.0)
	assert_eq(pushes[1]["cells"], 1.0)


func test_empurrado_nao_passa_da_entrada() -> void:
	var h := _h()
	var e := h.spawn("common", 1.0)
	var anchor := h.tower_at("anchor", 1.0)
	h.fire(anchor)
	assert_eq(e.distance, 0.0)


func test_guardiao_2_empurra_1_casa_a_mais_mas_elite_continua_1_e_chefao_imune() -> void:
	var h := _combo()
	h.set_level("guardian", 1)
	var normal := h.spawn("common", 12.0)
	var elite := h.spawn("common", 11.5, true)
	var anchor := h.tower_at("anchor", 12.0)
	h.fire(anchor)
	assert_eq(normal.distance, 9.0, "2 + 1 casas")
	assert_eq(elite.distance, 10.5, "elite no máximo 1")
	h.next_tick()
	var boss := h.spawn("boss", 14.0)
	h.fire(h.tower_at("anchor", 14.0))
	assert_eq(boss.distance, 14.0)


# ------------------------------------------------------------------ Sir Aldric (Lento) e Guardião

func test_aldric_deixa_lentos_os_3_da_frente_em_sequencia() -> void:
	var h := _combo()
	var ids: Array = []
	for d in [12.0, 11.5, 11.0, 10.5]:
		ids.append(_tough(h.spawn("common", d)))
	var aldric := h.tower_at("aldric", 11.5)
	assert_true(h.fire(aldric))
	var slow: Array = ids.map(func(e: Enemy) -> float: return e.slow_percent)
	assert_eq(slow, [30.0, 30.0, 30.0, 0.0], "os 3 mais à frente, o 4º não")
	for e: Enemy in ids:
		assert_eq(e.stun_ticks, 0, "sem atordoamento")
	assert_eq(ids[0].slow_ticks, 90, "3 s")


func test_guardiao_2_deixa_o_lento_do_aldric_20_por_cento_mais_forte() -> void:
	var h := _combo()
	h.set_level("guardian", 1)
	var e := _tough(h.spawn("common", 12.0))
	h.fire(h.tower_at("aldric", 12.0))
	assert_almost_eq(e.slow_percent, 36.0, 1e-9, "30% vira 36%")


## O raio do Aldric (250% do dano) mata um inimigo comum: os testes de Lento usam alvos resistentes.
func _tough(e: Enemy) -> Enemy:
	e.hp = 10000.0
	e.max_hp = 10000.0
	return e


func test_decreto_da_isolde_atordoa_quem_o_aldric_deixou_lento() -> void:
	var h := _combo()
	var e := _tough(h.spawn("common", 12.0))
	h.fire(h.tower_at("aldric", 12.0))
	h.next_tick()
	assert_true(h.fire(h.tower_at("isolde", 12.0)))
	assert_gt(e.stun_ticks, 0, "o Decreto atordoa o Lento do Aldric")


func test_guardiao_4_reduz_o_dano_no_nucleo() -> void:
	GameSets.select("valcoroa_costarubra")
	var sim := Simulation.create("nucleo", GameSystems.create(_map))
	(sim.state.classes["guardian"] as ClassState.ClassStatus).level = 2
	var routes := Route.build_routes(_map)
	var ctx := TickContext.new(sim.state, sim.rng, [], [], EventBus.new())
	var e := EnemySystems.spawn_enemy(ctx, routes, EnemyData.game_data(), "armored", routes["ground"].length)
	var hp: float = sim.state.nexus.hp
	var system := NexusSystems.create_nexus_contact_system(routes, EnemyData.game_data(), ClassData.game_data())
	system.call(ctx)
	assert_false(e.active)
	assert_almost_eq(hp - sim.state.nexus.hp, 2.0 * 0.8, 1e-12, "20% menos dano")


# ------------------------------------------------------------------ Bart (bala que quica)

func test_bart_quica_em_3_alvos_com_area_e_dano_pela_metade() -> void:
	var h := _h()
	var a := h.spawn("common", 12.0)
	var b := h.spawn("common", 10.0)
	var c := h.spawn("common", 8.0)
	for e: Enemy in [a, b, c]:
		e.hp = 1000.0
	var bart := h.tower_at("bart", 10.0)
	assert_true(h.fire(bart))
	var booms := h.events_of("areaExploded")
	assert_eq(booms.size(), 3)
	assert_eq(booms.map(func(x: Dictionary) -> float: return x["radius"]), [1.0, 0.5, 0.25])
	var d: float = h.towers.get_type("bart").damage * 2.0
	assert_almost_eq(1000.0 - a.hp, d, 1e-9, "100%")
	assert_almost_eq(1000.0 - b.hp, d / 2.0, 1e-9, "50%")
	assert_almost_eq(1000.0 - c.hp, d / 4.0, 1e-9, "25%")


func test_bart_nao_quica_em_quem_ja_foi_atingido() -> void:
	var h := _h()
	var a := h.spawn("common", 12.0)
	var b := h.spawn("common", 11.5)
	for e: Enemy in [a, b]:
		e.hp = 1000.0
	h.fire(h.tower_at("bart", 12.0))
	assert_eq(h.events_of("areaExploded").size(), 1, "o vizinho já levou a área do primeiro impacto")


func test_bart_tiro_normal_nao_tem_area() -> void:
	assert_eq(TowerData.game_data().get_type("bart").shot["kind"], "single")


# ------------------------------------------------------------------ Ruby (tiro duplo)

func test_ruby_abate_arma_o_tiro_duplo_e_o_segundo_vai_para_o_proximo_da_fila() -> void:
	var h := _h()
	var ruby := h.tower_at("ruby", 12.0)
	# O abate da própria Ruby arma o tiro duplo (pelo motor de gatilhos).
	h.ctx.tick_events.append({"type": "enemyKilled", "tick": h.state.tick, "enemyId": 999, "enemyType": "common",
			"wave": 1, "towerId": ruby.id, "x": 0.0, "y": 0.0, "elite": false, "marked": false, "weight": 1,
			"chainId": 0, "originTowerId": null})
	h.engine.run(h.ctx)
	assert_true(ruby.double_shot, "abate arma o próximo ataque")
	# O ataque normal agenda o segundo tiro; o primeiro alvo morre antes dele.
	var first := h.spawn("common", 12.0)
	var second := h.spawn("common", 11.0)
	var system := TowerSystems.create_tower_system(h.index, h.towers, Targeting.create_target_scores(h.routes, h.enemies),
			30.0, h.classes, h.routes)
	h.next_tick()
	system.call(h.ctx)
	assert_false(ruby.double_shot)
	assert_eq(ruby.followup_ticks, 6, "0,2 s depois")
	h.state.enemies.release(first)
	var extra: Array = []
	for i in 6:
		h.next_tick()
		system.call(h.ctx)
		extra.append_array(h.ctx.tick_events.filter(func(e: Dictionary) -> bool:
			return e["type"] == "towerFired" and e["shot"] == "extra"))
	assert_eq(extra.size(), 1, "um segundo tiro")
	assert_eq(extra[0]["targetId"], second.id, "no próximo da fila")


func test_ruby_sem_abate_nao_atira_duplo() -> void:
	var h := _h()
	var ruby := h.tower_at("ruby", 12.0)
	h.spawn("common", 12.0)
	var system := TowerSystems.create_tower_system(h.index, h.towers, Targeting.create_target_scores(h.routes, h.enemies),
			30.0, h.classes, h.routes)
	system.call(h.ctx)
	assert_eq(ruby.followup_ticks, 0)


# ------------------------------------------------------------------ Morgana (maré)

func test_mare_atinge_e_deixa_lentos_os_terrestres_no_alcance() -> void:
	var h := _h()
	var near := h.spawn("common", 12.0)
	var flyer := h.spawn("flying", 0.0)
	var morgana := h.tower_at("morgana", 12.0)
	# O voador fica em cima da torre: no alcance, mas fora do caminho da onda.
	flyer.x = float(morgana.x)
	flyer.y = float(morgana.y)
	var far := h.spawn("common", 30.0)
	var hp := near.hp
	assert_true(h.fire(morgana))
	assert_lt(near.hp, hp)
	assert_eq(near.slow_percent, 30.0)
	assert_eq(flyer.slow_percent, 0.0, "voador não")
	assert_eq(far.slow_percent, 0.0, "fora do alcance não")


func test_mare_sem_ninguem_nao_conta_na_cadeia() -> void:
	var h := _h()
	assert_false(h.fire(h.tower_at("morgana", 12.0)))


# ------------------------------------------------------------------ Capitão Pena e Kraus (ouro guardado)

func test_saque_guarda_ate_5_por_onda_e_paga_no_fim_da_onda() -> void:
	var h := _h()
	var pena := h.tower_at("pena", 12.0)
	for i in 8:
		h.fire(pena)
	assert_eq(h.state.pending_loot, 5, "teto de 5 por onda")
	assert_eq(pena.loot_count, 5)
	var gold := h.state.gold
	Economy.end_wave(h.ctx, EconomyData.game_data(), h.towers)
	var ended: Dictionary = h.events_of("waveEnded")[0]
	assert_eq(ended["loot"], 5)
	assert_eq(h.state.gold - gold, ended["interest"] + ended["bonus"] + 5, "o saque entra no fim da onda")
	assert_eq(h.state.pending_loot, 0)
	assert_eq(pena.loot_count, 0, "o teto recomeça na onda seguinte")


func test_saque_conta_so_abates_das_vizinhas() -> void:
	var h := _h()
	var pena := h.tower_at("pena", 12.0, 1, 501)
	var neighbor := Tower.new(502, "ruby", Vector2i(pena.x + 1, pena.y), 1)
	var far := Tower.new(503, "ruby", Vector2i(pena.x + 3, pena.y), 1)
	h.state.towers.append(neighbor)
	h.state.towers.append(far)
	for killer: Tower in [neighbor, far]:
		h.ctx.tick_events.append({"type": "enemyKilled", "tick": h.state.tick, "enemyId": 900 + killer.id,
				"enemyType": "common", "wave": 1, "towerId": killer.id, "x": 0.0, "y": 0.0, "elite": false,
				"marked": false, "weight": 1, "chainId": 0, "originTowerId": null})
	h.engine.run(h.ctx)
	assert_eq(h.state.pending_loot, 1, "só o abate da vizinha")


func test_recompensa_do_kraus_so_em_marcado() -> void:
	var h := _h()
	var kraus := h.tower_at("kraus", 12.0)
	for marked in [false, true, true]:
		h.ctx.tick_events.append({"type": "enemyKilled", "tick": h.state.tick, "enemyId": 800 + h.ctx.tick_events.size(),
				"enemyType": "common", "wave": 1, "towerId": kraus.id, "x": 0.0, "y": 0.0, "elite": false,
				"marked": marked, "weight": 1, "chainId": 0, "originTowerId": null})
	h.engine.run(h.ctx)
	assert_eq(h.state.pending_loot, 2, "+1 por abate de Marcado, sem teto")


func test_abate_avisa_se_o_inimigo_estava_marcado() -> void:
	var h := _h()
	var e := h.spawn("common", 12.0)
	Status.apply_mark(e, 1, 30)
	Damage.damage_enemy(h.ctx, h.enemies, e, 1000.0, 1)
	assert_true(h.events_of("enemyKilled")[0]["marked"])


# ------------------------------------------------------------------ Mama Zuri (Maldição)

func _curse(h: Harness, e: Enemy, jumps: int = 3) -> void:
	var zuri := h.tower_at("zuri", 12.0)
	var fx := h.effect(zuri)
	Status.apply_curse(e, {"percent": fx["sharePercent"], "spread": fx["spread"], "radius": fx["radius"]}, 180, jumps, zuri.id)


func test_zuri_arma_e_o_proximo_ataque_amaldicoa_por_6_s() -> void:
	var h := _h()
	var zuri := h.tower_at("zuri", 12.0)
	var e := h.spawn("common", 12.0)
	assert_false(h.fire(zuri), "armar não aparece na cadeia")
	assert_false(zuri.curse_next.is_empty())
	TowerSystems.fire_tower_shot(h.ctx, zuri, h.towers.get_type("zuri"), e, "normal", h.classes)
	assert_true(zuri.curse_next.is_empty(), "a maldição saiu com o tiro")
	h.fly_projectiles()
	assert_false(e.curse.is_empty())
	assert_eq(e.curse["ticks"], 180, "6 s")
	assert_eq(e.curse["jumps"], 3)


func test_amaldicoado_divide_30_por_cento_com_os_2_mais_proximos() -> void:
	var h := _h()
	var cursed := h.spawn("common", 12.0)
	var n1 := h.spawn("common", 12.5)
	var n2 := h.spawn("common", 11.25)
	var n3 := h.spawn("common", 10.5)
	for e: Enemy in [cursed, n1, n2, n3]:
		e.hp = 1000.0
	_curse(h, cursed)
	Damage.damage_enemy(h.ctx, h.enemies, cursed, 100.0, 1)
	assert_eq(cursed.hp, 900.0, "o alvo leva o dano todo")
	assert_eq(n1.hp, 970.0, "30% para o mais próximo")
	assert_eq(n2.hp, 970.0, "30% para o segundo")
	assert_eq(n3.hp, 1000.0, "o terceiro não")


func test_dano_dividido_nao_se_divide_de_novo() -> void:
	var h := _h()
	var a := h.spawn("common", 12.0)
	var b := h.spawn("common", 12.5)
	var c := h.spawn("common", 13.25)
	for e: Enemy in [a, b, c]:
		e.hp = 1000.0
	_curse(h, a)
	_curse(h, b)
	Damage.damage_enemy(h.ctx, h.enemies, a, 100.0, 1)
	assert_eq(b.hp, 970.0)
	assert_eq(c.hp, 970.0, "c leva só o dividido de a (b não divide o que recebeu de a)")


func test_maldicao_pula_para_os_2_mais_proximos_ate_3_saltos() -> void:
	var h := _h()
	var line: Array = []
	for i in 9:
		line.append(h.spawn("common", 20.0 - float(i) * 0.5))
	_curse(h, line[0])
	Damage.damage_enemy(h.ctx, h.enemies, line[0], 1000.0, 1)
	assert_eq(h.events_of("curseJumped").size(), 1)
	var cursed: Array = line.filter(func(e: Enemy) -> bool: return e.active and not e.curse.is_empty())
	assert_eq(cursed.size(), 2, "pulou para 2")
	for e: Enemy in cursed:
		assert_eq(e.curse["jumps"], 2, "um salto a menos")
		assert_eq(e.curse["ticks"], 180, "tempo cheio")
	# Último salto: quem chega com 0 saltos não pula mais.
	var last := h.spawn("common", 30.0)
	var friend := h.spawn("common", 30.5)
	_curse(h, last, 0)
	Damage.damage_enemy(h.ctx, h.enemies, last, 1000.0, 1)
	assert_true(friend.curse.is_empty(), "sem saltos sobrando")


func test_maldicao_empate_vai_pelo_menor_id() -> void:
	var h := _h()
	var center := h.spawn("common", 12.0)
	var ahead := h.spawn("common", 12.5)
	var behind := h.spawn("common", 11.5)
	var third := h.spawn("common", 12.5)
	for e: Enemy in [center, ahead, behind, third]:
		e.hp = 1000.0
	_curse(h, center)
	Damage.damage_enemy(h.ctx, h.enemies, center, 100.0, 1)
	var hit: Array = [ahead, behind, third].filter(func(e: Enemy) -> bool: return e.hp < 1000.0)
	assert_eq(hit.map(func(e: Enemy) -> int: return e.id), [ahead.id, behind.id], "na mesma distância, o menor id")


# ------------------------------------------------------------------ Nerea (tentáculo)

func test_tentaculo_escolhe_o_grupo_e_atordoa_chefao_imune_elite_metade() -> void:
	var h := _h()
	var lone := h.spawn("common", 13.0)
	var g1 := h.spawn("common", 11.0)
	var g2 := h.spawn("boss", 11.0)
	var g3 := h.spawn("common", 11.0, true)
	var nerea := h.tower_at("nerea", 12.0)
	assert_true(h.fire(nerea))
	assert_eq(lone.stun_ticks, 0, "o grupo vale mais que o mais à frente sozinho")
	assert_eq(g1.stun_ticks, 30, "1 s")
	assert_eq(g2.stun_ticks, 0, "chefão imune")
	assert_eq(g3.stun_ticks, 15, "elite pela metade")
	assert_eq(h.state.traps.size(), 1)
	assert_eq(h.state.traps[0].kind, "tentacle")
	assert_eq(h.state.traps[0].hold_ticks, 60, "dano por 2 s")


func test_tentaculo_sem_grupo_vai_no_mais_avancado_e_o_dano_dura_2_s() -> void:
	var h := _h()
	var front := h.spawn("common", 13.0)
	var back := h.spawn("common", 10.5)
	front.hp = 1000.0
	back.hp = 1000.0
	var nerea := h.tower_at("nerea", 12.0)
	h.fire(nerea)
	assert_eq(front.stun_ticks, 30)
	assert_eq(back.stun_ticks, 0)
	var traps := TrapSystems.create_trap_system(h.enemies, h.index)
	for i in 70:
		h.next_tick()
		traps.call(h.ctx)
	var per_tick: float = h.towers.get_type("nerea").damage * h.effect(nerea)["damagePercent"] / 100.0 / 30.0
	assert_almost_eq(1000.0 - front.hp, per_tick * 60.0, 1e-6, "dano por 60 ticks")
	assert_eq(back.hp, 1000.0)
	assert_eq(h.state.traps.size(), 0, "o tentáculo some")


# ------------------------------------------------------------------ bônus de região

func _with_costa(count: int) -> RunState:
	var sim := Simulation.create("regiao-cr", GameSystems.create(_map))
	var cells := WaveBot.bot_cells(_map)
	for i in count:
		sim.state.towers.append(Tower.new(7000 + i, COSTA[i], cells[i], 1))
	sim.step()
	return sim.state


func test_regiao_3_aumenta_o_teto_dos_juros() -> void:
	var economy := EconomyData.game_data()
	assert_eq(Economy.interest_cap_for(economy, _with_costa(2)), economy.interest_cap)
	assert_eq(Economy.interest_cap_for(economy, _with_costa(3)), economy.interest_cap + 5)


func test_regiao_5_bau_no_fim_da_onda() -> void:
	var state := _with_costa(5)
	assert_eq(ClassBonuses.wave_end_gold(ClassData.game_data(), state), 5)
	var ctx := TickContext.new(state, Rng.new(state), [], [], EventBus.new())
	var gold := state.gold
	Economy.end_wave(ctx, EconomyData.game_data(), TowerData.game_data())
	var ended: Dictionary = ctx.tick_events.filter(func(e: Dictionary) -> bool: return e["type"] == "waveEnded")[0]
	assert_eq(ended["chest"], 5)
	assert_eq(state.gold - gold, ended["interest"] + ended["bonus"] + 5)
	assert_eq(state.shop.slots.size(), 5, "com 5, a loja ainda tem 5 vagas")


func test_regiao_8_loja_com_1_vaga_extra() -> void:
	var state := _with_costa(8)
	var ctx := TickContext.new(state, Rng.new(state), [], [], EventBus.new())
	state.gold = 100
	Shop.reroll_shop(ctx, TowerData.game_data(), EconomyData.game_data())
	assert_eq(state.shop.slots.size(), 6)
	Economy.end_wave(ctx, EconomyData.game_data(), TowerData.game_data())
	assert_eq(state.shop.slots.size(), 6, "também na loja nova da onda")


# ------------------------------------------------------------------ bônus das outras 6 classes

func test_atirador_ganha_alcance_e_velocidade() -> void:
	var h := _combo()
	var lyra := h.towers.get_type("lyra")
	assert_eq(ClassBonuses.tower_range(h.classes, h.state, lyra), 4.0)
	h.set_level("shooter", 1)
	assert_eq(ClassBonuses.tower_range(h.classes, h.state, lyra), 4.5, "+0,5 de alcance")
	assert_eq(ClassBonuses.attack_speed_percent(h.classes, h.state, lyra, Tower.new(1, "lyra", Vector2i.ZERO)), 15.0)
	assert_eq(ClassBonuses.tower_range(h.classes, h.state, h.towers.get_type("bart")), 3.0, "só Atirador")
	h.set_level("shooter", 2)
	assert_eq(ClassBonuses.tower_range(h.classes, h.state, lyra), 5.0, "+1 com 4")
	# O alvo a 4,3 casas só entra no alcance com o bônus.
	h.set_level("shooter", 0)
	var tower := Tower.new(1, "lyra", Vector2i(10, 0))
	h.spawn("common", 12.0).y = 4.3
	var scores := Targeting.create_target_scores(h.routes, h.enemies)
	assert_null(TowerSystems.find_tower_target(h.index, h.state, tower, lyra, scores))
	h.set_level("shooter", 1)
	h.next_tick()
	assert_not_null(TowerSystems.find_tower_target(h.index, h.state, tower, lyra, scores))


func test_artilheiro_explosoes_maiores() -> void:
	var h := _combo()
	h.set_level("artillerist", 1)
	var e := _tough(h.spawn("common", 12.0))
	h.fire(h.tower_at("bart", 12.0))
	assert_eq(h.events_of("areaExploded")[0]["radius"], 1.25, "raio ×1,25")
	h.next_tick()
	h.set_level("artillerist", 2)
	var hp := e.hp
	h.fire(h.tower_at("bart", 12.0))
	assert_eq(h.events_of("areaExploded")[0]["radius"], 1.5, "raio ×1,5")
	assert_almost_eq(hp - e.hp, h.towers.get_type("bart").damage * 2.0 * 1.25, 1e-9, "+25% de dano")


func test_mago_carrega_mais_rapido() -> void:
	var h := _combo()
	var zuri := h.towers.get_type("zuri")
	h.set_level("mage", 1)
	assert_eq(ClassBonuses.reduced_trigger_count(h.classes, h.state, zuri, 5), 4, "5 −20% = 4")
	h.set_level("mage", 2)
	assert_eq(ClassBonuses.reduced_trigger_count(h.classes, h.state, zuri, 5), 3, "5 −40% = 3")
	assert_eq(ClassBonuses.reduced_trigger_count(h.classes, h.state, zuri, 2), 2, "mínimo 2")
	assert_eq(ClassBonuses.reduced_trigger_count(h.classes, h.state, h.towers.get_type("bart"), 5), 5, "só Mago")


func test_controlador_efeitos_duram_mais_e_afetados_levam_mais_dano() -> void:
	var h := _combo()
	h.set_level("controller", 1)
	var e := _tough(h.spawn("common", 12.0))
	h.fire(h.tower_at("morgana", 12.0))
	assert_eq(e.slow_ticks, 75, "Lento da maré: 2 s +25%")
	# O gelo da Isolde também dura mais.
	var iced := _tough(h.spawn("common", 11.0))
	var isolde := h.tower_at("isolde", 11.0)
	TowerSystems.fire_tower_shot(h.ctx, isolde, h.towers.get_type("isolde"), iced, "normal", h.classes)
	h.fly_projectiles()
	assert_eq(iced.slow_ticks, 113, "3 s +25% = 3,75 s")
	# O Lento do Aldric é de Guardião: não muda.
	var guarded := _tough(h.spawn("common", 13.0))
	h.next_tick()
	h.fire(h.tower_at("aldric", 13.0))
	assert_eq(guarded.slow_ticks, 90)
	# Inimigo Lento ou Atordoado leva +10% (de qualquer fonte); o que não está, não.
	h.ctx.afflicted_damage_percent = ClassBonuses.afflicted_damage_percent(h.classes, h.state)
	assert_eq(h.ctx.afflicted_damage_percent, 10.0)
	var calm := _tough(h.spawn("common", 20.0))
	var hp_slow := guarded.hp
	var hp_calm := calm.hp
	Damage.damage_enemy(h.ctx, h.enemies, guarded, 100.0, 1)
	Damage.damage_enemy(h.ctx, h.enemies, calm, 100.0, 1)
	assert_almost_eq(hp_slow - guarded.hp, 110.0, 1e-9)
	assert_eq(hp_calm - calm.hp, 100.0)


func test_suporte_aura_com_diagonais_e_mais_forte() -> void:
	GameSets.select("valcoroa_costarubra")
	var sim := Simulation.create("suporte", GameSystems.create(_map))
	var data := TowerData.game_data()
	var tomas := Tower.new(1, "tomas", Vector2i(5, 5), 1)
	var diagonal := Tower.new(2, "bart", Vector2i(6, 6), 1)
	sim.state.towers.append(tomas)
	sim.state.towers.append(diagonal)
	assert_eq(Auras.attack_speed_percent(sim.state, data, diagonal), 0.0, "sem bônus: só ortogonais")
	(sim.state.classes["support"] as ClassState.ClassStatus).level = 1
	var base: float = data.get_type("tomas").aura["stars"][0]["attackSpeedPercent"]
	assert_eq(Auras.attack_speed_percent(sim.state, data, diagonal), base, "Suporte 2: diagonal entra")
	(sim.state.classes["support"] as ClassState.ClassStatus).level = 2
	assert_almost_eq(Auras.attack_speed_percent(sim.state, data, diagonal), base * 1.5, 1e-9, "Suporte 4: +50%")


func test_suporte_saque_conta_vizinha_na_diagonal() -> void:
	var h := _combo()
	h.set_level("support", 1)
	var pena := h.tower_at("pena", 12.0, 1, 601)
	var diagonal := Tower.new(602, "bart", Vector2i(pena.x + 1, pena.y + 1), 1)
	h.state.towers.append(diagonal)
	h.ctx.tick_events.append({"type": "enemyKilled", "tick": h.state.tick, "enemyId": 999, "enemyType": "common",
			"wave": 1, "towerId": diagonal.id, "x": 0.0, "y": 0.0, "elite": false, "marked": false, "weight": 1,
			"chainId": 0, "originTowerId": null})
	h.engine.run(h.ctx)
	assert_eq(h.state.pending_loot, 1)


func test_invocador_invocacoes_duram_mais_e_batem_mais_forte() -> void:
	var h := _combo()
	h.set_level("summoner", 1)
	h.spawn("common", 12.0)
	var nerea := h.tower_at("nerea", 12.0)
	h.fire(nerea)
	var tentacle: Trap = h.state.traps[0]
	assert_eq(tentacle.hold_ticks, 75, "2 s +25%")
	var per_tick: float = h.towers.get_type("nerea").damage * h.effect(nerea)["damagePercent"] / 100.0 / 30.0
	assert_almost_eq(tentacle.damage, per_tick * 1.25, 1e-12, "+25% de dano")
	# A armadilha de urso e os estrepes da Mabel também.
	var mabel := h.tower_at("mabel", 12.0)
	h.fire(mabel)
	var bear: Trap = h.state.traps.filter(func(t: Trap) -> bool: return t.kind == "bear")[0]
	assert_eq(bear.hold_ticks, 150, "4 s +25%")
	assert_true(TrapSystems.place_caltrop(h.ctx, h.routes, mabel, h.towers.get_type("mabel")))
	var caltrop: Trap = h.state.traps.filter(func(t: Trap) -> bool: return t.kind == "caltrop")[0]
	assert_almost_eq(caltrop.damage, h.towers.get_type("mabel").damage * 3.0 * 1.25, 1e-9)


# ------------------------------------------------------------------ textos e carga no tooltip

func test_textos_das_habilidades_e_carga_so_no_tooltip() -> void:
	var towers := TowerData.game_data()
	var classes := ClassData.game_data()
	for id in COSTA:
		var info := TowerInfo.describe_tower(towers.get_type(id), 1, classes, id)
		assert_ne(info.trigger, "", "%s descreve a habilidade" % id)
		assert_ne(info.summary, "", "%s tem frase simples" % id)
	var state := RunState.create("tooltip")
	var bart := Tower.new(1, "bart", Vector2i(0, 0), 1)
	bart.trigger_counter = 2.0
	assert_eq(TowerInfo.charge_progress(towers.get_type("bart"), bart, classes, state), "Carga: 2 de 5 ataques")
	assert_eq(TowerInfo.charge_progress(towers.get_type("morgana"), Tower.new(2, "morgana", Vector2i(0, 0), 1), classes, state), "",
			"habilidade por tempo não mostra carga")


# ------------------------------------------------------------------ runs completas e save no meio

func _full_run(set_id: String, types: Array, seed_text: String) -> void:
	GameSets.select(set_id)
	var map := SimMap.load_map(DataLoader.load_json("map.json"))
	var straight := Simulation.create(seed_text, GameSystems.create(map))
	var split := Simulation.create(seed_text, GameSystems.create(map))
	for sim in [straight, split]:
		for c in [
			{"type": "debugSetNexusInvulnerable", "value": true},
			{"type": "debugSpawnTowers", "count": types.size() * 2, "towerTypes": types, "layout": "clustered", "star": 2},
			{"type": "callWave"},
		]:
			sim.enqueue(c.duplicate(true))
	var tally := {}
	for i in 1200:
		straight.step()
		for e: Dictionary in straight.drain_events():
			tally[e["type"]] = tally.get(e["type"], 0) + 1
		if i < 600:
			split.step()
			split.drain_events()
	# Save no meio da run, com estados vivos: volta igual e segue igual.
	var restored := Simulation.restore(split.serialize(), GameSystems.create(map), map)
	assert_eq(restored.serialize(), split.serialize(), "%s: save no meio volta igual" % set_id)
	for i in 600:
		restored.step()
		restored.drain_events()
	assert_eq(restored.serialize(), straight.serialize(), "%s: e a run segue igual" % set_id)
	assert_gt(tally.get("enemyKilled", 0), 0, "%s: os campeões abatem" % set_id)
	assert_eq(straight.state.triggers.dropped_total, 0, "%s: nenhum gatilho descartado" % set_id)


func test_run_da_costa_rubra_com_save_no_meio() -> void:
	_full_run("costarubra", COSTA, "cr-run")


func test_run_valcoroa_mais_costa_rubra_com_save_no_meio() -> void:
	_full_run("valcoroa_costarubra", COSTA + VALCOROA, "vc-cr-run")
