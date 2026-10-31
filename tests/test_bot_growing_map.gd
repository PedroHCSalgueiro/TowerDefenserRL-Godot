extends GutTest
## Os bots no mapa que cresce (`WaveBot.use_growing_map`): cada run tem o seu mapa, a parede é escolhida
## pela política do bot e as casas de torre acompanham o que abriu. Sem ligar, seguem no mapa fixo
## (é nele que rodam os golden files).


func after_each() -> void:
	WaveBot.use_growing_map(false)


## Joga até `waves` ondas com o nexo invulnerável, para a parede cair mesmo com um bot simples.
func _play(seed_text: String, waves: int) -> Simulation:
	var sim := WaveBot.bot_sim(seed_text, true)
	for i in waves:
		WaveBot.resolve_rewards(sim, WaveBot.first_reward)
		WaveBot.bot_break(sim)
		WaveBot.drain(sim)
		WaveBot.play_wave(sim)
	WaveBot.resolve_rewards(sim, WaveBot.first_reward)
	return sim


func test_sem_ligar_o_bot_fica_no_mapa_fixo() -> void:
	WaveBot.use_growing_map(false)
	assert_eq(WaveBot.bot_map().id, "greybox-01")
	assert_eq(WaveBot.new_run_map(), WaveBot.bot_map(), "o mapa fixo não muda: as runs dividem o mesmo")


func test_ligado_cada_run_tem_um_mapa_novo() -> void:
	WaveBot.use_growing_map(true)
	var first := WaveBot.new_run_map()
	assert_eq(first.id, ExpansionData.game_data().map_id)
	assert_ne(WaveBot.new_run_map(), first)


func test_a_parede_cai_e_o_caminho_cresce_durante_a_run() -> void:
	WaveBot.use_growing_map(true)
	var data := ExpansionData.game_data()
	var sim := WaveBot.bot_sim("bot-cresce", true)
	var base_path: int = WaveBot.bot_map().path_cells.size()
	sim = _play("bot-cresce", data.after_waves[0])
	assert_eq(sim.state.expansion.opened.size(), 1, "a primeira parede abriu")
	assert_null(sim.state.expansion.screen, "nenhuma escolha ficou aberta")
	assert_gt(WaveBot.bot_map().path_cells.size(), base_path)


func test_as_casas_acompanham_a_parede() -> void:
	WaveBot.use_growing_map(true)
	var data := ExpansionData.game_data()
	var sim := _play("bot-casas", data.after_waves[0])
	var map := WaveBot.bot_map()
	assert_eq(WaveBot._cells, WaveBot.bot_cells(map), "as casas do bot são as do mapa com a parede aberta")
	var cell: Variant = WaveBot._free_cell(sim)
	assert_not_null(cell)
	assert_true(map.can_place_tower(cell))


func test_longest_e_shortest_pegam_os_extremos() -> void:
	var data := ExpansionData.game_data()
	var cases := {"longest": true, "shortest": false}
	for policy: String in cases:
		WaveBot.use_growing_map(true, policy)
		var sim := WaveBot.bot_sim("bot-parede")
		sim.state.expansion.opened.assign(["0:direita:reto", "0:direita:reto"])
		for id: String in sim.state.expansion.opened:
			Expansion.apply(WaveBot.bot_map(), null, data, id)
		var screen := ExpansionState.ExpansionScreen.new()
		screen.options = ["0:direita:reto", "0:cima:zigue", "0:baixo:reto"]
		screen.wave = 15
		screen.ticks_left = 100
		sim.state.expansion.screen = screen
		WaveBot.choose_wall(sim)
		var sizes: Array = screen.options.map(func(id: String) -> int:
			return data.opening(sim.state.expansion.opened, id).path_cells.size())
		var chosen: int = sim.state.command_queue[-1]["index"]
		assert_eq(sizes[chosen], sizes.max() if cases[policy] else sizes.min(), policy)


func test_auto_deixa_a_simulacao_escolher() -> void:
	WaveBot.use_growing_map(true, "auto")
	var sim := _play("bot-auto", ExpansionData.game_data().after_waves[0])
	assert_eq(sim.state.expansion.opened.size(), 1, "o tempo acabou e a simulação escolheu")
