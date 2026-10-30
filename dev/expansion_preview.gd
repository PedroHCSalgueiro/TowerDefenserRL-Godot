extends SceneTree
## Capturas do mapa que cresce com moldes e do painel de debug rodando no jogo de verdade. Precisa de
## janela (não roda com --headless):
##   godot --path . --resolution 1280x720 -s dev/expansion_preview.gd -- <pasta de saída>
## Gera, em ordem: começo, duas paredes para a frente, escolha da 3ª (para cima em destaque), linha que
## subiu, divisão pelo debug com a horda nas duas entradas, mapa no fim das 6 paredes e as abas Campeões,
## Ondas e Mapa do painel de debug.


var _out := "."
var _game: Game


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "."
	Game.forced_seed = "moldes-preview"
	_game = load("res://scenes/game.tscn").instantiate()
	root.add_child(_game)
	for i in 3:
		await process_frame
	var sim := _game.runner.sim
	sim.enqueue({"type": "debugSetNexusInvulnerable", "value": true})
	sim.enqueue({"type": "debugAddGold", "amount": 300})
	await create_timer(1.0).timeout
	_save("moldes_1_inicio.png")

	# As 2 primeiras paredes seguem para a frente (abrem na hora).
	for i in 2:
		sim.enqueue({"type": "debugOpenExpansion"})
		await create_timer(0.3).timeout
	await create_timer(1.5).timeout
	_save("moldes_2_frente.png")

	# 3ª parede: direita, cima ou baixo, com o molde já sorteado.
	sim.enqueue({"type": "debugOpenExpansion"})
	await create_timer(0.8).timeout
	var screen: ExpansionState.ExpansionScreen = sim.state.expansion.screen
	var up := _find(screen, ExpansionData.UP)
	_game.expansion_screen.hovered_option = up
	await create_timer(0.4).timeout
	_save("moldes_3_escolha.png")
	sim.enqueue({"type": "chooseExpansion", "index": up})
	await create_timer(1.5).timeout
	_save("moldes_4_subiu.png")

	# Debug: divide a linha principal; torres e uma onda mostram a horda nas duas entradas.
	sim.enqueue({"type": "debugOpenExpansion", "split": true})
	await create_timer(0.8).timeout
	_game.expansion_screen.hovered_option = 0
	await create_timer(0.4).timeout
	_save("moldes_5_dividir.png")
	sim.enqueue({"type": "chooseExpansion", "index": 0})
	await create_timer(1.0).timeout
	var cfg: Dictionary = DataLoader.load_json("debug.json")
	sim.enqueue({"type": "debugSpawnTowers", "count": 10, "towerTypes": cfg["fullScenario"]["towerTypes"],
			"layout": "spread", "star": 1})
	sim.enqueue({"type": "callWave"})
	_game.runner.clock.set_speed(2.0)
	await create_timer(4.0).timeout
	_save("moldes_6_horda_dividida.png")

	# O resto das paredes, sempre a primeira opção.
	for i in 2:
		sim.enqueue({"type": "debugOpenExpansion"})
		await create_timer(0.4).timeout
		if sim.state.expansion.screen != null:
			sim.enqueue({"type": "chooseExpansion", "index": 0})
		await create_timer(1.2).timeout
	_save("moldes_7_fim.png")

	# Painel de debug.
	_game.runner.clock.set_speed(1.0)
	_game.debug_panel.visible = true
	for tab in [3, 1, 2]:
		_game.debug_panel._show_tab(tab)
		await create_timer(0.5).timeout
		_save("debug_%s.png" % DebugPanel.TABS[tab].to_lower())
	quit()


func _find(screen: ExpansionState.ExpansionScreen, dir: String) -> int:
	for i in screen.options.size():
		if String(screen.options[i]).begins_with("0:%s:" % dir):
			return i
	return 0


func _save(file: String) -> void:
	var path := _out.path_join(file)
	var err := root.get_texture().get_image().save_png(path)
	print("[preview] %s -> %s" % [path, "ok" if err == OK else "erro %d" % err])
