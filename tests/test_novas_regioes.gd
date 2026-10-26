extends GutTest
## Forjaferro, Cripta Cinzenta e Panteão: os 24 heróis, as mecânicas novas (torreta, puxão, eco, flecha que
## atravessa, bônus do Acólito, almas, esqueletos, Envenenado, raio do Lich, Falange, aura de alcance,
## cratera, Julgamento, raios, grifo), os bônus de região e runs com save no meio. Os números vêm dos dados.

const FORJA := ["bolt", "vapora", "caldeira", "tic", "greta", "volta", "engrena", "ferro"]
const CRIPTA := ["morn", "nyx", "acolito", "ossos", "vex", "agatha", "grim", "lich"]
const PANTEAO := ["dorian", "iliria", "amunet", "ciclope", "pitia", "sigrun", "tritao", "kallia"]

var _map: SimMap


func before_all() -> void:
	_map = SimMap.load_map(DataLoader.load_json("map.json"))


func after_each() -> void:
	GameSets.select(GameSets.DEFAULT_ID)


func _h(set_id: String) -> HeroHarness:
	GameSets.select(set_id)
	return HeroHarness.new(_map)


func _tough(e: Enemy, hp: float = 10000.0) -> Enemy:
	e.hp = hp
	e.max_hp = hp
	return e


# ------------------------------------------------------------------ conjuntos

func test_cada_regiao_tem_8_herois_3_3_2_uma_classe_de_cada_e_3_estrelas() -> void:
	for pair in [["forjaferro", FORJA], ["cripta", CRIPTA], ["panteao", PANTEAO]]:
		GameSets.select(pair[0])
		var towers := TowerData.game_data()
		var count := {"common": 0, "uncommon": 0, "rare": 0, "legendary": 0}
		var classes := {}
		for id: String in pair[1]:
			assert_true(towers.has_type(id), "%s: %s" % [pair[0], id])
			var type := towers.get_type(id)
			count[type.rarity] += 1
			classes[type.classes[0]] = true
			assert_eq(type.classes[1], pair[0])
			assert_eq(Stars.max_stars(type), 3, "%s tem ★1 a ★3" % id)
		assert_eq(count, {"common": 3, "uncommon": 3, "rare": 2, "legendary": 0}, pair[0])
		assert_eq(classes.size(), 8, "%s: uma de cada classe" % pair[0])


func test_todas_as_regioes_tem_40_e_cinco_de_cada_classe() -> void:
	GameSets.select("todas")
	var towers := TowerData.game_data()
	var per_class := {}
	var heroes := 0
	for id: String in towers.types:
		var type: TowerData.TowerType = towers.types[id]
		if type.rarity == null:
			continue
		heroes += 1
		per_class[type.classes[0]] = per_class.get(type.classes[0], 0) + 1
	assert_eq(heroes, 40)
	for c in per_class:
		assert_eq(per_class[c], 5, c)
	assert_eq(GameSets.list().size(), 8, "8 cartões na tela inicial")


# ------------------------------------------------------------------ Forjaferro

func test_bolt_monta_torreta_vizinha_que_atira_e_some() -> void:
	var h := _h("forjaferro")
	var e := _tough(h.spawn("common", 12.0))
	var bolt := h.tower_at("bolt", 12.0)
	assert_true(h.fire(bolt))
	assert_false(h.fire(bolt), "uma torreta viva por vez")
	var sentinel: Trap = h.state.traps[0]
	assert_eq(sentinel.kind, "sentinel")
	assert_eq(absi(int(sentinel.x) - bolt.x) + absi(int(sentinel.y) - bolt.y), 1, "numa casa vizinha")
	assert_true(_map.can_place_tower(Vector2i(int(sentinel.x), int(sentinel.y))), "livre e construível")
	h.run_summons(2)
	assert_gt(h.state.projectiles.active_count, 0, "a torreta atirou")
	h.fly_projectiles()
	assert_lt(e.hp, 10000.0)
	h.run_summons(400)
	assert_eq(h.state.traps.size(), 0, "a torreta some depois de 10 s")


func test_vapora_terceiro_tiro_dobrado() -> void:
	var h := _h("forjaferro")
	h.spawn("common", 12.0)
	var vapora := h.tower_at("vapora", 12.0)
	assert_true(h.fire(vapora))
	var extra := h.events_of("towerFired").filter(func(e: Dictionary) -> bool: return e["shot"] == "extra")
	assert_eq(extra.size(), 1, "um tiro extra junto do terceiro")
	assert_eq(h.state.projectiles.active_count, 1)
	assert_eq(h.state.projectiles.slots[0].damage, h.towers.get_type("vapora").damage, "100% = dano dobrado no 3º tiro")


func test_golem_caldeira_vapor_com_bonus_do_guardiao() -> void:
	var h := _h("forjaferro")
	var e := _tough(h.spawn("common", 12.0))
	h.fire(h.tower_at("caldeira", 12.0))
	assert_eq(e.slow_percent, 30.0)
	GameSets.select("todas")
	h = HeroHarness.new(_map)
	h.set_level("guardian", 1)
	e = _tough(h.spawn("common", 12.0))
	h.fire(h.tower_at("caldeira", 12.0))
	assert_almost_eq(e.slow_percent, 36.0, 1e-9, "Guardião 2: +20%")


func test_engrena_puxa_para_o_centro_chefao_nao_elite_1_casa_e_atordoa() -> void:
	var h := _h("forjaferro")
	var far := _tough(h.spawn("common", 10.5))
	var boss := h.spawn("boss", 13.5)
	var elite := _tough(h.spawn("common", 10.5, true))
	var engrena := h.tower_at("engrena", 12.0)
	var center := TrapSystems.route_distance_near(h.routes["ground"], float(engrena.x), float(engrena.y))
	assert_true(h.fire(engrena))
	assert_eq(far.distance, center, "puxado até o ponto do caminho mais perto da torre")
	assert_eq(boss.distance, 13.5, "chefão não é puxado")
	assert_eq(elite.distance, minf(center, 11.5), "elite anda no máximo 1 casa")
	for e: Enemy in [far, boss, elite]:
		assert_eq(e.stun_ticks, 30, "todos atordoados por 1 s")


func _vapora_shots(h: HeroHarness, vapora: Tower, shots: int) -> int:
	for i in shots:
		h.ctx.tick_events.append({"type": "towerFired", "tick": h.state.tick, "towerId": vapora.id, "targetId": 1,
				"shot": "normal"})
	h.engine.run(h.ctx)
	return h.events_of("abilityEchoed").size()


func test_eco_do_forjaferro_a_cada_3_a_seguinte_dispara_2_vezes() -> void:
	var h := _h("forjaferro")
	h.set_level("forjaferro", 1)
	h.spawn("common", 12.0)
	var vapora := h.tower_at("vapora", 12.0)
	# 4 habilidades (12 tiros, uma a cada 3): a 4ª ecoa.
	assert_eq(_vapora_shots(h, vapora, 12), 1)
	h.next_tick()
	h.set_level("forjaferro", 2)
	h.state.echo_counter = 0
	# A cada 2: a 3ª e a 6ª ecoam.
	assert_eq(_vapora_shots(h, vapora, 18), 2)


func test_eco_com_chance_e_deterministico() -> void:
	var counts: Array = []
	for i in 2:
		var h := _h("forjaferro")
		h.set_level("forjaferro", 3)
		h.spawn("common", 12.0)
		counts.append(_vapora_shots(h, h.tower_at("vapora", 12.0), 60))
	assert_eq(counts[0], counts[1], "mesma semente, mesmo resultado")
	assert_true(counts[0] > 0 and counts[0] < 20, "50% de 20 habilidades")


# ------------------------------------------------------------------ Cripta Cinzenta

func test_nyx_atravessa_um_inimigo_e_marca_depois_de_abater() -> void:
	var h := _h("cripta")
	var front := _tough(h.spawn("common", 12.0))
	var behind := _tough(h.spawn("common", 11.5))
	var far := _tough(h.spawn("common", 10.0))
	var nyx := h.tower_at("nyx", 12.0)
	TowerSystems.fire_tower_shot(h.ctx, nyx, h.towers.get_type("nyx"), front, "normal", h.classes)
	h.fly_projectiles()
	assert_lt(front.hp, 10000.0)
	assert_lt(behind.hp, 10000.0, "atravessa e acerta o de trás")
	assert_eq(far.hp, 10000.0, "só um")
	assert_true(front.marks.is_empty(), "sem abate, não marca")
	h.kill_event(nyx.id)
	h.engine.run(h.ctx)
	assert_true(nyx.mark_next, "o abate arma a marca")
	TowerSystems.fire_tower_shot(h.ctx, nyx, h.towers.get_type("nyx"), front, "normal", h.classes)
	h.fly_projectiles()
	assert_true(front.marks.has(nyx.id), "a flecha seguinte marca")
	assert_false(nyx.mark_next)


func test_acolito_fortalece_quem_abate_ate_o_teto_e_zera_no_fim_da_onda() -> void:
	var h := _h("cripta")
	var acolito := h.tower_at("acolito", 12.0, 1, 701)
	var killer := Tower.new(702, "morn", Vector2i(acolito.x + 1, acolito.y), 1)
	h.state.towers.append(killer)
	for i in 12:
		h.kill_event(killer.id)
	h.engine.run(h.ctx)
	assert_eq(killer.wave_buff_percent, 50.0, "+5% por abate, até 50%")
	assert_almost_eq(TowerBuffs.damage_multiplier(h.state, h.towers, killer, h.towers.get_type("morn")), 1.5, 1e-12)
	Economy.end_wave(h.ctx, EconomyData.game_data(), h.towers)
	assert_eq(killer.wave_buff_percent, 0.0, "zera no fim da onda")


func test_golem_de_ossos_cresce_com_as_almas() -> void:
	var h := _h("cripta")
	var e := _tough(h.spawn("common", 12.0))
	var ossos := h.tower_at("ossos", 12.0)
	h.state.souls = 25
	TowerSystems.fire_tower_shot(h.ctx, ossos, h.towers.get_type("ossos"), e, "normal", h.classes)
	assert_almost_eq(h.state.projectiles.slots[0].area_radius, 1.2, 1e-12, "20 almas completas: +20%")
	h.state.souls = 1000
	TowerSystems.fire_tower_shot(h.ctx, ossos, h.towers.get_type("ossos"), e, "normal", h.classes)
	assert_almost_eq(h.state.projectiles.slots[1].area_radius, 1.5, 1e-12, "teto de +50%")


func test_vex_ergue_esqueleto_que_anda_para_tras_e_explode() -> void:
	var h := _h("cripta")
	var vex := h.tower_at("vex", 12.0)
	var entry := TriggerState.PendingTrigger.new()
	var p := MutablePoint.new()
	(h.routes["ground"] as Route).sample_into(13.0, p)
	entry.has_point = true
	entry.x = p.x
	entry.y = p.y
	assert_true(h.fire(vex, entry))
	var skeleton: Trap = h.state.traps[0]
	assert_eq(skeleton.kind, "skeleton")
	assert_almost_eq(float(skeleton.params["distance"]), 13.0, 0.25, "no ponto do abate")
	var victim := _tough(h.spawn("common", 10.0), 1000.0)
	var behind_blast := _tough(h.spawn("common", 9.5), 1000.0)
	h.run_summons(60)
	assert_eq(h.state.traps.size(), 0, "explodiu no primeiro que tocou")
	var blast: float = h.towers.get_type("vex").damage * 3.0
	assert_almost_eq(1000.0 - victim.hp, blast, 1e-9)
	assert_almost_eq(1000.0 - behind_blast.hp, blast, 1e-9, "a explosão é em área")
	for i in 5:
		h.fire(vex, entry)
	assert_eq(h.state.traps.size(), 3, "no máximo 3 vivos por Vex")


func test_agatha_nuvem_deixa_lento_e_envenena() -> void:
	var h := _h("cripta")
	var a := _tough(h.spawn("common", 12.0), 1000.0)
	var b := _tough(h.spawn("common", 12.25), 1000.0)
	var lone := _tough(h.spawn("common", 14.5), 1000.0)
	var agatha := h.tower_at("agatha", 12.0)
	assert_true(h.fire(agatha))
	var cloud: Trap = h.state.traps[0]
	assert_eq(cloud.kind, "plague")
	assert_almost_eq(cloud.x, a.x, 1e-9, "no grupo")
	h.run_summons(1)
	assert_eq(a.slow_percent, 25.0)
	assert_gt(b.poison_ticks, 0, "envenenado")
	assert_eq(lone.poison_ticks, 0, "longe da nuvem, não")
	var status := Status.create_status_system(h.enemies)
	var hp := a.hp
	for i in 30:
		h.next_tick()
		status.call(h.ctx)
	assert_lt(a.hp, hp, "o veneno tira vida")
	h.run_summons(200)
	assert_eq(h.state.traps.size(), 0, "a nuvem some")


func test_lich_conta_abates_da_cripta_que_nao_sao_dele_e_atinge_o_mapa_inteiro() -> void:
	var h := _h("todas")
	var lich := h.tower_at("lich", 12.0, 1, 801)
	var morn := Tower.new(802, "morn", Vector2i(0, 0), 1)
	var other_lich := Tower.new(803, "lich", Vector2i(0, 1), 1)
	var lyra := Tower.new(804, "lyra", Vector2i(1, 0), 1)
	h.state.towers.append_array([morn, other_lich, lyra])
	var near := _tough(h.spawn("common", 12.0), 1000.0)
	var far := _tough(h.spawn("common", 30.0), 1000.0)
	for i in 19:
		h.kill_event(morn.id)
	for i in 10:
		h.kill_event(lyra.id)
		h.kill_event(other_lich.id)
	h.engine.run(h.ctx)
	assert_eq(h.events_of("lightningStruck").size(), 0, "19 da Cripta: ainda não")
	h.next_tick()
	h.kill_event(morn.id)
	h.engine.run(h.ctx)
	# Os dois Liches contam os abates do Morn (e não os um do outro): o 20º solta os dois raios.
	assert_eq(h.events_of("lightningStruck").size(), 2, "o 20º solta o raio de cada Lich")
	var beam: float = h.towers.get_type("lich").damage * 3.0
	assert_almost_eq(1000.0 - near.hp, beam * 2.0, 1e-9)
	assert_almost_eq(1000.0 - far.hp, beam * 2.0, 1e-9, "o caminho inteiro")


func test_regiao_cripta_almas_explosao_e_esqueleto() -> void:
	var h := _h("cripta")
	h.set_level("cripta", 1)
	var morn_type := h.towers.get_type("morn")
	var morn := h.tower_at("morn", 12.0)
	var level: ClassData.ClassLevel = h.classes.classes["cripta"].levels[0]
	h.state.souls = 40
	assert_almost_eq(ClassBonuses.damage_multiplier(h.classes, h.state, morn_type, morn),
			1.0 + 4.0 * level.soul_damage_percent / 100.0, 1e-12, "40 almas: 4 vezes o bônus")
	h.state.souls = 5000
	assert_almost_eq(ClassBonuses.damage_multiplier(h.classes, h.state, morn_type, morn),
			1.0 + level.soul_damage_max_percent / 100.0, 1e-12, "com o teto")
	# Nível 5: quem morre explode (10% da vida dele) e quem morre da explosão não explode de novo.
	h.set_level("cripta", 2)
	h.ctx.death_blast = ClassBonuses.death_blast(h.classes, h.state)
	var victim := _tough(h.spawn("common", 12.0), 100.0)
	var neighbor := _tough(h.spawn("common", 12.5), 1000.0)
	var weak := _tough(h.spawn("common", 11.5), 5.0)
	var chained := _tough(h.spawn("common", 10.75), 1000.0)
	Damage.damage_enemy(h.ctx, h.enemies, victim, 1000.0, morn.id)
	assert_eq(neighbor.hp, 990.0, "10 de dano (10% de 100)")
	assert_false(weak.active, "a explosão mata quem tem pouca vida")
	assert_eq(chained.hp, 1000.0, "a morte pela explosão não explode")
	var kills := h.events_of("enemyKilled")
	assert_eq(kills[1]["towerId"], null, "o abate da explosão é da região, não da torre")
	# Nível 8: esqueleto aliado (com chance; aqui forçada a 100%), com teto de vivos.
	h.ctx.skeleton_rise = {"chance": 100.0, "damage": 25.0}
	for i in 6:
		Damage.damage_enemy(h.ctx, h.enemies, _tough(h.spawn("common", 20.0), 40.0), 1000.0, morn.id)
	var skeletons := h.state.traps.filter(func(t: Trap) -> bool: return t.kind == "skeleton")
	assert_eq(skeletons.size(), 4, "no máximo 4 esqueletos da região vivos")
	assert_eq(skeletons[0].damage, 10.0, "25% da vida do morto")


# ------------------------------------------------------------------ Panteão

func test_falange_do_dorian_soma_por_guardiao_encostado() -> void:
	var h := _h("panteao")
	var dorian := h.tower_at("dorian", 12.0)
	var type := h.towers.get_type("dorian")
	assert_eq(TowerBuffs.damage_multiplier(h.state, h.towers, dorian, type), 1.0)
	h.state.towers.append(Tower.new(1, "dorian", Vector2i(dorian.x + 1, dorian.y), 1))
	h.state.towers.append(Tower.new(2, "dorian", Vector2i(dorian.x, dorian.y - 1), 1))
	h.state.towers.append(Tower.new(3, "dorian", Vector2i(dorian.x + 1, dorian.y + 1), 1))
	assert_almost_eq(TowerBuffs.damage_multiplier(h.state, h.towers, dorian, type), 1.2, 1e-12, "2 encostados: +20% (diagonal não)")
	dorian.star = 3
	assert_almost_eq(TowerBuffs.damage_multiplier(h.state, h.towers, dorian, type), 1.4, 1e-12, "★3: +20% cada")
	assert_eq(Stars.tower_damage(type, dorian), type.damage * 1.25, "★3 também dá +25% de dano")


func test_iliria_rajada_de_3_flechas_em_leque() -> void:
	var h := _h("panteao")
	for d in [12.0, 11.5, 11.0]:
		h.spawn("common", d)
	assert_true(h.fire(h.tower_at("iliria", 12.0)))
	var targets := h.events_of("towerFired").map(func(e: Dictionary) -> int: return e["targetId"])
	assert_eq(targets.size(), 3)
	var unique := {}
	for t in targets:
		unique[t] = true
	assert_eq(unique.size(), 3, "cada flecha num alvo")


func test_amunet_da_alcance_a_vizinha() -> void:
	var h := _h("panteao")
	var iliria := Tower.new(1, "iliria", Vector2i(10, 0), 1)
	h.state.towers.append(iliria)
	var type := h.towers.get_type("iliria")
	assert_eq(ClassBonuses.tower_range(h.classes, h.state, type, iliria), 4.0)
	h.state.towers.append(Tower.new(2, "amunet", Vector2i(9, 0), 1))
	assert_eq(ClassBonuses.tower_range(h.classes, h.state, type, iliria), 5.0, "+1 de alcance")
	h.spawn("common", 12.0).y = 4.6
	var scores := Targeting.create_target_scores(h.routes, h.enemies)
	assert_not_null(TowerSystems.find_tower_target(h.index, h.state, iliria, type, scores), "alvo a 4,6 casas")


func test_ciclope_cratera_deixa_lento_por_4_s() -> void:
	var h := _h("panteao")
	var e := _tough(h.spawn("common", 12.0))
	assert_true(h.fire(h.tower_at("ciclope", 12.0)))
	assert_almost_eq(10000.0 - e.hp, h.towers.get_type("ciclope").damage * 1.5, 1e-9)
	var crater: Trap = h.state.traps[0]
	assert_eq(crater.kind, "crater")
	h.run_summons(1)
	assert_eq(e.slow_percent, 30.0)
	h.run_summons(130)
	assert_eq(h.state.traps.size(), 0)


func test_pitia_atordoa_os_3_da_frente_por_1_5_s() -> void:
	var h := _h("panteao")
	var line: Array = []
	for d in [12.0, 11.5, 11.0, 10.5]:
		line.append(h.spawn("common", d))
	assert_true(h.fire(h.tower_at("pitia", 12.0)))
	assert_eq(line.map(func(e: Enemy) -> int: return e.stun_ticks), [45, 45, 45, 0])


func test_sigrun_julgamento_dobra_contra_marcado_e_chefao() -> void:
	var h := _h("panteao")
	var sigrun := h.tower_at("sigrun", 12.0)
	var type := h.towers.get_type("sigrun")
	var plain := _tough(h.spawn("common", 12.0))
	TowerSystems.fire_tower_shot(h.ctx, sigrun, type, plain, "normal", h.classes)
	h.fly_projectiles()
	assert_eq(10000.0 - plain.hp, type.damage, "sem marca: normal")
	TowerSystems.fire_tower_shot(h.ctx, sigrun, type, plain, "normal", h.classes)
	h.fly_projectiles()
	assert_eq(10000.0 - plain.hp, type.damage * 3.0, "o primeiro tiro marcou: o segundo dobra")
	var boss := h.spawn("boss", 11.0)
	var hp := boss.hp
	TowerSystems.fire_tower_shot(h.ctx, sigrun, type, boss, "normal", h.classes)
	h.fly_projectiles()
	assert_almost_eq(hp - boss.hp, Armor.apply_armor(type.damage * 2.0, h.enemies.get_type("boss").armor, 100.0), 1e-9,
			"chefão: dobra")


func test_tritao_raios_em_5_e_lento_leva_o_dobro() -> void:
	var h := _h("panteao")
	var line: Array = []
	for d in [12.5, 12.0, 11.5, 11.0, 10.5, 10.0]:
		line.append(_tough(h.spawn("common", d)))
	Status.apply_slow(line[1], 20.0, 50.0, 100)
	assert_true(h.fire(h.tower_at("tritao", 12.0)))
	var strike: float = h.towers.get_type("tritao").damage * 1.5
	assert_almost_eq(10000.0 - line[0].hp, strike, 1e-9)
	assert_almost_eq(10000.0 - line[1].hp, strike * 2.0, 1e-9, "Lento: o dobro")
	assert_eq(line[5].hp, 10000.0, "só 5")


func test_kallia_grifo_caca_voador_com_o_triplo() -> void:
	var h := _h("panteao")
	var kallia := h.tower_at("kallia", 12.0)
	var ground := _tough(h.spawn("common", 12.0))
	var flyer := _tough(h.spawn("flying", 0.0))
	flyer.x = float(kallia.x) + 1.0
	flyer.y = float(kallia.y)
	assert_true(h.fire(kallia))
	var griffin: Trap = h.state.traps[0]
	assert_eq([griffin.x, griffin.y], [float(kallia.x), float(kallia.y)], "em cima da Kallia")
	h.run_summons(2)
	h.fly_projectiles()
	assert_eq(ground.hp, 10000.0, "mira o voador primeiro")
	assert_almost_eq(10000.0 - flyer.hp, h.towers.get_type("kallia").damage * 3.0, 1e-9, "×3 no voador")


func test_regiao_panteao_fura_armadura_e_deus_salva_o_nucleo() -> void:
	GameSets.select("panteao")
	var sim := Simulation.create("panteao-regiao", GameSystems.create(_map))
	var cells := WaveBot.bot_cells(_map)
	for i in 8:
		sim.state.towers.append(Tower.new(500 + i, PANTEAO[i], cells[i], 1))
	sim.step()
	assert_eq((sim.state.classes["panteao"] as ClassState.ClassStatus).level, 3)
	# O deus: o primeiro que chega ao núcleo nesta onda é destruído; o segundo acerta.
	var routes := Route.build_routes(_map)
	var ctx := TickContext.new(sim.state, sim.rng, [], [], EventBus.new())
	var contact := NexusSystems.create_nexus_contact_system(routes, EnemyData.game_data(), ClassData.game_data())
	var hp: float = sim.state.nexus.hp
	var first := EnemySystems.spawn_enemy(ctx, routes, EnemyData.game_data(), "boss", routes["ground"].length)
	contact.call(ctx)
	assert_false(first.active)
	assert_eq(sim.state.nexus.hp, hp, "o chefão foi destruído antes de acertar")
	assert_eq(sim.state.status, "playing")
	EnemySystems.spawn_enemy(ctx, routes, EnemyData.game_data(), "common", routes["ground"].length)
	contact.call(ctx)
	assert_lt(sim.state.nexus.hp, hp, "só uma vez por onda")
	# Armadura: no nível 5 (e no 8), os heróis do Panteão ignoram toda.
	var h := HeroHarness.new(_map)
	h.set_level("panteao", 1)
	h.ctx.armor_pierce = {7: ClassBonuses.armor_pierce(h.classes, h.state, h.towers.get_type("dorian"))}
	var armored := _tough(h.spawn("armored", 12.0))
	Damage.damage_enemy(h.ctx, h.enemies, armored, 100.0, 7)
	assert_almost_eq(10000.0 - armored.hp, Armor.apply_armor(100.0, 25.0, 100.0), 1e-9, "50% da armadura")
	h.set_level("panteao", 2)
	h.ctx.armor_pierce = {7: ClassBonuses.armor_pierce(h.classes, h.state, h.towers.get_type("dorian"))}
	var before := armored.hp
	Damage.damage_enemy(h.ctx, h.enemies, armored, 100.0, 7)
	assert_almost_eq(before - armored.hp, 100.0, 1e-9, "toda a armadura")


# ------------------------------------------------------------------ runs completas e save no meio

func _full_run(set_id: String, seed_text: String) -> void:
	GameSets.select(set_id)
	var map := SimMap.load_map(DataLoader.load_json("map.json"))
	var types: Array = DataLoader.load_json("debug.json")["fullScenario"]["towerTypes"]
	var straight := Simulation.create(seed_text, GameSystems.create(map))
	var split := Simulation.create(seed_text, GameSystems.create(map))
	for sim in [straight, split]:
		for c in [
			{"type": "debugSetNexusInvulnerable", "value": true},
			{"type": "debugSpawnTowers", "count": types.size() * 2, "towerTypes": types, "layout": "clustered", "star": 2},
			{"type": "callWave"},
		]:
			sim.enqueue(c.duplicate(true))
	var kills := 0
	for i in 1200:
		straight.step()
		for e: Dictionary in straight.drain_events():
			if e["type"] == "enemyKilled":
				kills += 1
		if i < 600:
			split.step()
			split.drain_events()
	var restored := Simulation.restore(split.serialize(), GameSystems.create(map), map)
	assert_eq(restored.serialize(), split.serialize(), "%s: save no meio volta igual" % set_id)
	for i in 600:
		restored.step()
		restored.drain_events()
	assert_eq(restored.serialize(), straight.serialize(), "%s: e a run segue igual" % set_id)
	assert_gt(kills, 0, "%s: os heróis abatem" % set_id)
	assert_eq(straight.state.triggers.dropped_total, 0, "%s: nenhum gatilho descartado" % set_id)


func test_run_do_forjaferro_com_save_no_meio() -> void:
	_full_run("forjaferro", "forja-run")


func test_run_da_cripta_com_save_no_meio() -> void:
	_full_run("cripta", "cripta-run")


func test_run_do_panteao_com_save_no_meio() -> void:
	_full_run("panteao", "panteao-run")


func test_run_de_todas_as_regioes_com_save_no_meio() -> void:
	_full_run("todas", "todas-run")
