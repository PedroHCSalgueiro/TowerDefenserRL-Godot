extends GutTest
## O Sir Aldric com modelo 3D no jogo (`towers.models` do conjunto Valcoroa): o modelo entra no lugar do
## bloco, vira e ataca quando a torre atira, e o raio de luz sai da ponta da espada.

var game: Game


func before_each() -> void:
	GameSets.select("valcoroa")
	Game.forced_seed = "heroi"
	game = load("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)


func after_each() -> void:
	Game.forced_seed = ""
	GameSets.select(GameSets.DEFAULT_ID)


func test_aldric_usa_o_modelo_e_ataca_com_raio() -> void:
	var cell: Vector2i = WaveBot.bot_cells(game.map)[0]
	game.runner.sim.enqueue({"type": "debugSetNexusInvulnerable", "value": true})
	game.runner.sim.enqueue({"type": "placeTower", "towerType": "aldric", "x": cell.x, "y": cell.y})
	game.runner.sim.enqueue({"type": "debugSetStress", "stress": {"count": 40, "layout": "spread"}})
	game.runner.clock.set_speed(3.0)
	var beams := 0
	var animated := false
	var model_found := false
	for i in 600:
		await get_tree().process_frame
		beams = maxi(beams, game.tower_view._beams.size())
		for node in game.tower_view._nodes.values():
			if node.model != null:
				model_found = true
				if node.model.has_method("atacando") and node.model.atacando():
					animated = true
		if beams > 0 and animated:
			break
	assert_true(model_found, "a torre tem o modelo do Sir Aldric")
	assert_true(animated, "a animação de ataque toca")
	assert_gt(beams, 0, "o raio de luz sai da ponta da espada")


func test_outros_herois_continuam_blocos() -> void:
	var cell: Vector2i = WaveBot.bot_cells(game.map)[0]
	game.runner.sim.enqueue({"type": "placeTower", "towerType": "lyra", "x": cell.x, "y": cell.y})
	await get_tree().create_timer(0.3).timeout
	for node in game.tower_view._nodes.values():
		assert_null(node.model, "sem modelo configurado, fica o bloco colorido")
