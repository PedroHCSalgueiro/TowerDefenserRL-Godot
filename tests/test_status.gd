extends GutTest
## Efeitos de estado (Lento, Atordoado, Sangramento), a aura do Irmão Tomás e as habilidades dos heróis
## de Valcoroa que dependem deles (Sir Aldric, Wulf, Rainha Isolde, Mestre Brom, Lyra).

var _map: SimMap


func before_all() -> void:
	_map = SimMap.load_map(DataLoader.load_json("map.json"))


func before_each() -> void:
	GameSets.select("valcoroa")


func after_each() -> void:
	GameSets.select(GameSets.DEFAULT_ID)


func _sim(seed_text: String = "estado") -> Simulation:
	return Simulation.create(seed_text, GameSystems.create(_map))


func _first_enemy(sim: Simulation) -> Enemy:
	for e: Enemy in sim.state.enemies.slots:
		if e.active:
			return e
	return null


## Um inimigo "common" sozinho, depois do primeiro tick.
func _spawned(sim: Simulation) -> Enemy:
	sim.enqueue({"type": "spawnEnemy", "enemyType": "common"})
	sim.step()
	return _first_enemy(sim)


func _run(sim: Simulation, ticks: int) -> Array:
	var events: Array = []
	for i in ticks:
		sim.step()
		events.append_array(sim.drain_events())
	return events


# ------------------------------------------------------------------ estados

func test_lento_anda_mais_devagar_e_acaba() -> void:
	var free := _sim()
	var e_free := _spawned(free)
	var start := e_free.distance
	_run(free, 20)
	var moved_free := e_free.distance - start

	var slowed := _sim()
	var e_slow := _spawned(slowed)
	Status.apply_slow(e_slow, 50.0, 50.0, 1000)
	_run(slowed, 20)
	var moved_slow := e_slow.distance - start
	assert_almost_eq(moved_slow, moved_free * 0.5, 1e-9, "50% mais lento")

	var brief := _sim()
	var e_brief := _spawned(brief)
	Status.apply_slow(e_brief, 50.0, 50.0, 5)
	_run(brief, 20)
	assert_eq(e_brief.slow_ticks, 0)
	assert_eq(e_brief.slow_percent, 0.0, "a lentidão zera ao acabar")
	assert_gt(e_brief.distance - start, moved_slow, "depois de acabar, volta à velocidade normal")


func test_lento_empilha_ate_o_teto() -> void:
	var e := Enemy.new()
	Status.apply_slow(e, 10.0, 50.0, 30)
	assert_eq(e.slow_percent, 10.0)
	for i in 10:
		Status.apply_slow(e, 10.0, 50.0, 30)
	assert_eq(e.slow_percent, 50.0, "teto de 50%")


func test_atordoado_nao_anda() -> void:
	var sim := _sim()
	var e := _spawned(sim)
	Status.apply_stun(e, 10)
	var before := e.distance
	_run(sim, 10)
	assert_eq(e.distance, before, "parado durante o atordoamento")
	assert_eq(e.stun_ticks, 0)
	_run(sim, 5)
	assert_gt(e.distance, before, "anda de novo depois")


func test_sangramento_tira_vida_sem_armadura_e_credita_a_torre() -> void:
	var sim := _sim()
	sim.enqueue({"type": "spawnEnemy", "enemyType": "armored"})
	sim.step()
	var e := _first_enemy(sim)
	var hp := e.hp
	Status.apply_bleed(e, 2.0, 5, null)
	_run(sim, 5)
	assert_eq(e.hp, hp - 10.0, "5 ticks × 2, ignorando a armadura")
	assert_eq(e.bleed_ticks, 0)

	var killer := _sim("sangra")
	var victim := _spawned(killer)
	Status.apply_bleed(victim, 1000.0, 3, 7)
	var events := _run(killer, 2)
	var kills := events.filter(func(ev: Dictionary) -> bool: return ev["type"] == "enemyKilled")
	assert_eq(kills.size(), 1, "morreu de sangramento")
	assert_eq(kills[0]["towerId"], 7, "o abate vai para a torre de origem")


func test_slot_reaproveitado_nasce_sem_estado() -> void:
	var sim := _sim()
	var e := _spawned(sim)
	Status.apply_slow(e, 30.0, 50.0, 100)
	Status.apply_stun(e, 100)
	Status.apply_bleed(e, 1.0, 100, 3)
	sim.state.enemies.release(e)
	sim.enqueue({"type": "spawnEnemy", "enemyType": "common"})
	sim.step()
	var again := _first_enemy(sim)
	assert_eq(again.slot, e.slot, "mesmo slot")
	assert_eq([again.slow_ticks, again.stun_ticks, again.bleed_ticks], [0, 0, 0])


# ------------------------------------------------------------------ aura

func _adjacent_cells() -> Array:
	for cell in WaveBot.bot_cells(_map):
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			if _map.can_place_tower(cell + d):
				return [cell, cell + d]
	return []


func test_aura_do_tomas_da_30_para_o_reino_e_15_para_os_outros() -> void:
	var cells := _adjacent_cells()
	var sim := _sim()
	var data := TowerData.game_data()
	var tomas := Tower.new(9001, "tomas", cells[0], 1)
	var lyra := Tower.new(9002, "lyra", cells[1], 1)
	var basic := Tower.new(9003, "basic", cells[1], 1)
	sim.state.towers.append(tomas)
	sim.state.towers.append(lyra)
	sim.state.towers.append(basic)
	assert_eq(Auras.attack_speed_percent(sim.state, data, lyra), 30.0, "herói do Reino")
	assert_eq(Auras.attack_speed_percent(sim.state, data, basic), 15.0, "fora do Reino")
	assert_eq(Auras.attack_speed_percent(sim.state, data, tomas), 0.0, "a aura não vale para quem a dá")
	tomas.star = 3
	assert_eq(Auras.attack_speed_percent(sim.state, data, lyra), 50.0, "estrela maior, aura maior")
	lyra.x += 5
	assert_eq(Auras.attack_speed_percent(sim.state, data, lyra), 0.0, "só as vizinhas ortogonais")


func test_aura_acelera_o_ataque() -> void:
	var cells := _adjacent_cells()
	var shots: Array[int] = []
	for with_tomas in [false, true]:
		var sim := _sim("aura")
		sim.enqueue({"type": "debugSetNexusInvulnerable", "value": true})
		sim.enqueue({"type": "placeTower", "towerType": "lyra", "x": cells[0].x, "y": cells[0].y})
		if with_tomas:
			sim.enqueue({"type": "placeTower", "towerType": "tomas", "x": cells[1].x, "y": cells[1].y})
		sim.enqueue({"type": "debugSetStress", "stress": {"count": 60, "layout": "spread"}})
		var count := 0
		for e: Dictionary in _run(sim, 600):
			if e["type"] == "towerFired" and e["shot"] == "normal" and sim.state.towers[0].id == e["towerId"]:
				count += 1
		shots.append(count)
	assert_gt(shots[0], 0, "a Lyra atirou")
	assert_gt(shots[1], shots[0], "com o Tomás ao lado atira mais")


# ------------------------------------------------------------------ habilidades

func _with_heroes(seed_text: String, heroes: Array, ticks: int, star: int = 1) -> Array:
	var sim := _sim(seed_text)
	sim.enqueue({"type": "debugSetNexusInvulnerable", "value": true})
	sim.enqueue({"type": "debugSpawnTowers", "count": heroes.size() * 3, "towerTypes": heroes,
			"layout": "clustered", "star": star})
	sim.enqueue({"type": "debugSetStress", "stress": {"count": 60, "layout": "spread"}})
	var events := _run(sim, ticks)
	return [sim, events]


func test_sir_aldric_atordoa_os_da_frente() -> void:
	var result := _with_heroes("aldric", ["aldric"], 700)
	var stuns := (result[1] as Array).filter(func(e: Dictionary) -> bool:
		return e["type"] == "statusApplied" and e["status"] == "stun")
	assert_gt(stuns.size(), 0, "o raio atordoou inimigos")
	assert_lte(int(stuns[0]["count"]), 3, "até 3 inimigos")
	var fired := (result[1] as Array).filter(func(e: Dictionary) -> bool:
		return e["type"] == "triggerFired" and e["effect"] == "stunFront" and e["visible"])
	assert_gt(fired.size(), 0, "o gatilho aparece na cadeia quando atordoa")


func test_wulf_mira_o_mais_forte_e_faz_sangrar() -> void:
	var sim := _sim("wulf")
	sim.enqueue({"type": "debugSetNexusInvulnerable", "value": true})
	sim.enqueue({"type": "debugSpawnTowers", "count": 1, "towerTypes": ["wulf"], "layout": "clustered", "star": 1})
	sim.enqueue({"type": "debugSetStress", "stress": {"count": 60, "layout": "spread"}})
	var saw_bleed := false
	for i in 600:
		sim.step()
		sim.drain_events()
		for e: Enemy in sim.state.enemies.slots:
			if e.active and e.bleed_ticks > 0:
				saw_bleed = true
	assert_true(saw_bleed, "as flechas do Wulf causam Sangramento")
	var data := TowerData.game_data()
	assert_eq(data.get_type("wulf").target_mode, "strongest")


func test_mira_strongest_escolhe_o_de_mais_vida() -> void:
	var routes := Route.build_routes(_map)
	var scores := Targeting.create_target_scores(routes, EnemyData.game_data())
	var weak := Enemy.new()
	weak.hp = 10.0
	weak.id = 1
	var strong := Enemy.new()
	strong.hp = 50.0
	strong.id = 2
	var score: Callable = scores["strongest"]
	assert_lt(score.call(strong, 0.0, 0.0), score.call(weak, 0.0, 0.0), "menor nota = mais vida")


func test_isolde_deixa_lento_e_o_decreto_atordoa_os_lentos() -> void:
	var sim := _sim("isolde")
	sim.enqueue({"type": "debugSetNexusInvulnerable", "value": true})
	sim.enqueue({"type": "debugSpawnTowers", "count": 4, "towerTypes": ["isolde"], "layout": "clustered", "star": 1})
	sim.enqueue({"type": "debugSetStress", "stress": {"count": 60, "layout": "spread"}})
	var slowed := false
	var decree := false
	for i in 1000:
		sim.step()
		for ev: Dictionary in sim.drain_events():
			if ev["type"] == "statusApplied" and ev["status"] == "stun":
				decree = true
		for e: Enemy in sim.state.enemies.slots:
			if e.active and e.slow_ticks > 0:
				slowed = true
				assert_lte(e.slow_percent, 50.0, "teto de 50%")
	assert_true(slowed, "o raio de gelo deixa Lento")
	assert_true(decree, "o decreto atordoa os Lentos")


func test_brom_solta_bola_maior() -> void:
	var result := _with_heroes("brom", ["brom"], 600)
	var extra_areas := (result[1] as Array).filter(func(e: Dictionary) -> bool:
		return e["type"] == "areaExploded" and e["radius"] > 1.0 and not e["trigger"])
	assert_gt(extra_areas.size(), 0, "a bola carregada tem raio maior que o normal (1)")


func test_lyra_virote_perfurante_pega_no_maximo_3() -> void:
	var data := TowerData.game_data()
	var star: TriggerData.TriggerStar = data.get_type("lyra").trigger.stars[0]
	assert_eq(star.effect["kind"], "pierceLine")
	assert_eq(int(star.effect["maxTargets"]), 3)
	var result := _with_heroes("lyra", ["lyra"], 700)
	var lines := (result[1] as Array).filter(func(e: Dictionary) -> bool: return e["type"] == "lineFired")
	assert_gt(lines.size(), 0)


func test_run_toda_de_valcoroa_ida_e_volta_do_save() -> void:
	var result := _with_heroes("save-vc", ["aldric", "lyra", "tomas", "brom", "selene", "wulf", "mabel", "isolde"], 700, 2)
	var sim: Simulation = result[0]
	assert_gt(sim.state.enemies.active_count, 0)
	var restored := Simulation.restore(sim.serialize(), GameSystems.create(_map), _map)
	assert_eq(restored.serialize(), sim.serialize(), "estados de Lento/Atordoado/Sangramento voltam iguais")
	var a := _run(sim, 200)
	var b := _run(restored, 200)
	assert_eq(a.size(), b.size())
	assert_eq(restored.serialize(), sim.serialize(), "e a run segue igual")


# ------------------------------------------------------------------ Mabel

func test_mabel_poe_estrepes_e_armadilha_de_urso_e_os_inimigos_pisam() -> void:
	var sim := _sim("mabel")
	sim.enqueue({"type": "debugSetNexusInvulnerable", "value": true})
	var cell: Vector2i = WaveBot.bot_cells(_map)[0]
	sim.enqueue({"type": "placeTower", "towerType": "mabel", "x": cell.x, "y": cell.y})
	sim.enqueue({"type": "debugSetStress", "stress": {"count": 40, "layout": "spread"}})
	var placed := {"caltrop": 0, "bear": 0}
	var sprung := {"caltrop": 0, "bear": 0}
	var max_alive := 0
	for i in 1500:
		sim.step()
		for e: Dictionary in sim.drain_events():
			if e["type"] == "trapPlaced":
				placed[e["kind"]] += 1
				var dx: float = e["x"] - float(cell.x)
				var dy: float = e["y"] - float(cell.y)
				assert_lte(sqrt(dx * dx + dy * dy), 3.0 + 1e-9, "a armadilha fica dentro do alcance")
			elif e["type"] == "trapSprung":
				sprung[e["kind"]] += 1
		max_alive = maxi(max_alive, sim.state.traps.size())
	assert_gt(placed["caltrop"], 0, "estrepes")
	assert_gt(placed["bear"], 0, "armadilha de urso")
	assert_gt(sprung["caltrop"], 0, "um inimigo pisou nos estrepes")
	assert_lte(max_alive, 4 + 2, "o teto de armadilhas vivas vale")


func test_armadilha_de_urso_prende_e_faz_sangrar() -> void:
	var sim := _sim("urso")
	var victim := _spawned(sim)
	var trap := Trap.new()
	trap.id = 5000
	trap.owner_id = 9
	trap.kind = "bear"
	trap.x = victim.x
	trap.y = victim.y
	trap.damage = 0.5
	trap.hold_ticks = 30
	trap.radius = 0.5
	sim.state.traps.append(trap)
	var hp := victim.hp
	_run(sim, 1)
	assert_eq(sim.state.traps.size(), 0, "a armadilha some depois de pisada")
	var where := victim.distance
	_run(sim, 9)
	assert_eq(victim.distance, where, "preso")
	assert_lt(victim.hp, hp, "sangrando")


func test_estrepes_dao_dano_uma_vez() -> void:
	var sim := _sim("estrepes")
	var victim := _spawned(sim)
	var trap := Trap.new()
	trap.id = 5001
	trap.owner_id = 9
	trap.kind = "caltrop"
	trap.x = victim.x
	trap.y = victim.y
	trap.damage = 7.0
	trap.radius = 0.5
	sim.state.traps.append(trap)
	var hp := victim.hp
	_run(sim, 1)
	assert_eq(victim.hp, hp - 7.0)
	assert_eq(sim.state.traps.size(), 0)


# ------------------------------------------------------------------ região

func test_bonus_do_reino_de_valcoroa_3_5_8() -> void:
	var cells := WaveBot.bot_cells(_map)
	var ids := ["aldric", "lyra", "tomas", "brom", "selene", "wulf", "mabel", "isolde"]
	var data := TowerData.game_data()
	var classes := ClassData.game_data()
	var sim := _sim("regiao")
	var spots := _spread_cells(cells, 8)
	for i in 8:
		sim.state.towers.append(Tower.new(8000 + i, ids[i], spots[i], 1))
	# Com 3 tipos: +15% de velocidade; com 5: +30% e +10% de dano; com 8: o mesmo (sem vizinhas, sem dobrar).
	var expected := [[3, 15.0, 1.0], [5, 30.0, 1.1], [8, 30.0, 1.1]]
	var all: Array[Tower] = sim.state.towers.duplicate()
	for row in expected:
		sim.state.towers.assign(all.slice(0, row[0]))
		sim.step()
		var member: Tower = sim.state.towers[0]
		var type := data.get_type(member.type)
		assert_eq(ClassBonuses.attack_speed_percent(classes, sim.state, type, member), row[1], "%d tipos: velocidade" % row[0])
		assert_almost_eq(ClassBonuses.damage_multiplier(classes, sim.state, type, member), row[2], 1e-12, "%d tipos: dano" % row[0])
	# Com 8, uma vizinha do Reino ao lado dobra o bônus.
	var pair := _adjacent_cells()
	all[0].x = pair[0].x
	all[0].y = pair[0].y
	all[1].x = pair[1].x
	all[1].y = pair[1].y
	sim.state.towers.assign(all)
	sim.step()
	var type0 := data.get_type(all[0].type)
	assert_eq(ClassBonuses.attack_speed_percent(classes, sim.state, type0, all[0]), 60.0, "vizinhos do Reino dobram o bônus")
	assert_almost_eq(ClassBonuses.damage_multiplier(classes, sim.state, type0, all[0]), 1.2, 1e-12)


##  casas de torre bem separadas (nenhuma vizinha ortogonal de outra).
func _spread_cells(cells: Array, count: int) -> Array:
	var out: Array = []
	for cell: Vector2i in cells:
		var clear := true
		for other: Vector2i in out:
			if absi(other.x - cell.x) + absi(other.y - cell.y) <= 1:
				clear = false
				break
		if clear:
			out.append(cell)
			if out.size() == count:
				break
	return out
