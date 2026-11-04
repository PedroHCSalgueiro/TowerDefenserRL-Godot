extends GutTest
## Menus: o de pausa dentro da run (Esc e o botão "Menu"), a tela de título do menu inicial e as opções gravadas.
## O "Sim" de voltar ao menu e de reiniciar só é conferido pelo sinal: trocar de cena aqui derrubaria o GUT.

const TEST_SETTINGS := "user://settings_teste.cfg"

var game: Game


func before_each() -> void:
	Input.use_accumulated_input = false
	GameSettings.path = TEST_SETTINGS
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	GameSettings.path = GameSettings.DEFAULT_PATH
	Game.forced_seed = ""


func _start_game() -> void:
	GameSets.select(GameSets.DEFAULT_ID)
	Game.forced_seed = "menus"
	game = load("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)
	await get_tree().create_timer(0.2).timeout


func _tap(keycode: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = keycode
		e.physical_keycode = keycode
		e.pressed = pressed
		Input.parse_input_event(e)
		Input.flush_buffered_events()
	await get_tree().process_frame


## O botão de um painel pelo texto.
func _button(root: Node, text: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node
	return null


func _pause_menu() -> PauseMenu:
	var menu := PauseMenu.new()
	add_child_autofree(menu)
	var state := {"paused": false}
	menu.setup(func() -> bool: return state["paused"], func(v: bool) -> void: state["paused"] = v, "Conjunto · semente x")
	return menu


func test_esc_abre_o_menu_pausa_e_esc_fecha() -> void:
	await _start_game()
	await _tap(KEY_ESCAPE)
	assert_true(game.pause_menu.is_open(), "Esc sem torre na mão abre o menu")
	assert_true(game.runner.paused, "o jogo fica pausado")
	await _tap(KEY_ESCAPE)
	assert_false(game.pause_menu.is_open(), "Esc de novo fecha")
	assert_false(game.runner.paused, "e o jogo volta a andar")


func test_esc_com_torre_na_mao_so_solta_a_torre() -> void:
	await _start_game()
	game.shop.carry_free("basic", 1)
	assert_false(game.shop.carrying().is_empty(), "uma torre na mão")
	await _tap(KEY_ESCAPE)
	assert_true(game.shop.carrying().is_empty(), "o Esc solta a torre")
	assert_false(game.pause_menu.is_open(), "e não abre o menu")


func test_fechar_volta_como_estava() -> void:
	await _start_game()
	game.runner.paused = true
	game.pause_menu.open()
	game.pause_menu.close()
	assert_true(game.runner.paused, "pausado antes (P), continua pausado depois")


func test_botao_menu_do_hud_abre_e_fecha() -> void:
	await _start_game()
	game.pause_menu.toggle_button.pressed.emit()
	assert_true(game.pause_menu.is_open())
	game.pause_menu.toggle_button.pressed.emit()
	assert_false(game.pause_menu.is_open())


func test_com_o_menu_aberto_as_teclas_nao_chegam_ao_jogo() -> void:
	await _start_game()
	game.pause_menu.open()
	await _tap(KEY_P)
	assert_true(game.runner.paused, "o P não despausa por baixo do menu")
	assert_true(game.pause_menu.is_open())


func test_reiniciar_pergunta_antes() -> void:
	var menu := _pause_menu()
	watch_signals(menu)
	menu.open()
	_button(menu, "Reiniciar run").pressed.emit()
	assert_eq(menu.page, "confirm", "pergunta antes de perder a run")
	_button(menu, "Não").pressed.emit()
	assert_eq(menu.page, "list", "Não volta aos botões")
	assert_signal_not_emitted(menu, "restart_pressed")
	_button(menu, "Reiniciar run").pressed.emit()
	_button(menu, "Sim").pressed.emit()
	assert_signal_emitted(menu, "restart_pressed")


func test_voltar_ao_menu_inicial_pergunta_e_avisa() -> void:
	var menu := _pause_menu()
	watch_signals(menu)
	menu.open()
	_button(menu, "Voltar ao menu inicial").pressed.emit()
	_button(menu, "Sim").pressed.emit()
	assert_signal_emitted(menu, "menu_pressed")


func test_esc_na_pergunta_volta_aos_botoes() -> void:
	var menu := _pause_menu()
	menu.open()
	_button(menu, "Opções").pressed.emit()
	assert_eq(menu.page, "options")
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	assert_true(menu.handle_key(key))
	assert_eq(menu.page, "list", "Esc nas opções volta aos botões")
	assert_true(menu.is_open(), "sem fechar o menu")


func test_opcoes_gravam_e_valem_na_proxima_run() -> void:
	var options := OptionsPanel.new()
	add_child_autofree(options)
	assert_true(GameSettings.damage_numbers(), "números de dano ligados por padrão")
	options.numbers_box.button_pressed = false
	options.speed_button.select(1)
	options.speed_button.item_selected.emit(1)
	assert_false(GameSettings.damage_numbers())
	var speeds: Array = EngineData.config()["speeds"]
	assert_eq(GameSettings.start_speed(), float(speeds[1]))
	# relê do arquivo, como numa abertura nova do jogo (trocar de arquivo e voltar descarta o que estava lido)
	GameSettings.path = GameSettings.DEFAULT_PATH
	assert_true(GameSettings.damage_numbers(), "sem tela, o arquivo de quem joga não é lido: padrão")
	GameSettings.path = TEST_SETTINGS
	assert_false(GameSettings.damage_numbers(), "gravado em disco")
	await _start_game()
	assert_eq(game.runner.clock.speed, float(speeds[1]), "a run começa na velocidade escolhida")


func test_titulo_leva_a_escolha_das_torres_e_volta() -> void:
	var menu: MainMenu = load("res://scenes/menu.tscn").instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame
	assert_eq(menu.page, "title", "o jogo abre no título")
	await _tap(KEY_ENTER)
	assert_eq(menu.page, "sets", "Enter (Novo jogo) leva à escolha das torres")
	await _tap(KEY_ESCAPE)
	assert_eq(menu.page, "title", "Esc volta ao título")
	_button(menu, "Opções").pressed.emit()
	assert_eq(menu.page, "options")
	_button(menu, "Voltar").pressed.emit()
	assert_eq(menu.page, "title")
