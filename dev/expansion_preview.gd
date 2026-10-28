extends SceneTree
## Capturas do mapa que cresce rodando no jogo de verdade. Precisa de janela (não roda com --headless):
##   godot --path . --resolution 1280x720 -s dev/expansion_preview.gd -- <pasta de saída>
## Gera, em ordem: começo, escolha da parede, destaque de uma opção, sala abrindo, sala aberta, ondas
## pelas duas entradas e uma segunda sala.


var _out := "."
var _game: Game


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "."
	Game.forced_seed = "salas-preview"
	_game = load("res://scenes/game.tscn").instantiate()
	root.add_child(_game)
	for i in 3:
		await process_frame
	var sim := _game.runner.sim
	sim.enqueue({"type": "debugSetNexusInvulnerable", "value": true})
	sim.enqueue({"type": "debugAddGold", "amount": 300})
	await create_timer(1.0).timeout
	_save("salas_1_inicio.png")

	# Escolha com uma sala de entrada nova entre as opções.
	sim.enqueue({"type": "debugOpenExpansion"})
	await create_timer(0.4).timeout
	var screen: ExpansionState.ExpansionScreen = sim.state.expansion.screen
	if not screen.options.has("ala_oeste"):
		screen.options[0] = "ala_oeste"
	await create_timer(0.6).timeout
	_save("salas_2_escolha.png")
	_game.expansion_screen.hovered_option = screen.options.find("ala_oeste")
	await create_timer(0.4).timeout
	_save("salas_3_destaque.png")

	sim.enqueue({"type": "chooseExpansion", "index": screen.options.find("ala_oeste")})
	await create_timer(0.3).timeout
	_save("salas_4_abrindo.png")
	await create_timer(1.4).timeout
	_save("salas_5_aberta.png")

	# Algumas torres e uma onda: os inimigos vêm pelas duas entradas.
	var cfg: Dictionary = DataLoader.load_json("debug.json")
	sim.enqueue({"type": "debugSpawnTowers", "count": 6, "towerTypes": cfg["fullScenario"]["towerTypes"],
			"layout": "spread", "star": 1})
	sim.enqueue({"type": "callWave"})
	_game.runner.clock.set_speed(2.0)
	await create_timer(3.5).timeout
	_save("salas_6_duas_entradas.png")

	# Segunda parede: uma sala sem entrada.
	sim.enqueue({"type": "debugOpenExpansion"})
	await create_timer(0.4).timeout
	screen = sim.state.expansion.screen
	if screen != null:
		var plain := 0
		for i in screen.options.size():
			if not ExpansionData.game_data().get_room(screen.options[i]).has_entrance():
				plain = i
				break
		sim.enqueue({"type": "chooseExpansion", "index": plain})
	await create_timer(2.0).timeout
	_save("salas_7_segunda_sala.png")
	quit()


func _save(file: String) -> void:
	var path := _out.path_join(file)
	var err := root.get_texture().get_image().save_png(path)
	print("[preview] %s -> %s" % [path, "ok" if err == OK else "erro %d" % err])
