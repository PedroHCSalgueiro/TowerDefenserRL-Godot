extends GutTest
## Testes de integração da cena do jogo: instancia `game.tscn`, manda eventos de teclado e mouse
## pelo pipeline normal de entrada (`Viewport.push_input`) e confere o estado da simulação. Roda
## headless (sem janela de verdade), então só valida a lógica; o visual é conferido em capturas.

var game: Game


func before_each() -> void:
	Input.use_accumulated_input = false
	Game.forced_seed = "integracao"
	game = load("res://scenes/game.tscn").instantiate()
	add_child_autofree(game)
	# Ouro de sobra: os testes de compra não dependem do preço do slot sorteado.
	game.runner.sim.enqueue({"type": "debugAddGold", "amount": 200})
	await _seconds(0.25)  # alguns ticks reais: o ouro entra no primeiro


func after_each() -> void:
	Game.forced_seed = ""


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


## Envia o evento como se viesse do sistema (atualiza o estado de `Input`, como num clique de verdade).
func _send(e: InputEvent) -> void:
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _key(keycode: Key, pressed: bool = true) -> void:
	var e := InputEventKey.new()
	e.keycode = keycode
	e.physical_keycode = keycode
	e.pressed = pressed
	_send(e)


func _tap_key(keycode: Key) -> void:
	_key(keycode, true)
	_key(keycode, false)


## O headless usa uma janela minúscula com escala: converte coordenadas da viewport em da janela.
func _to_window(pos: Vector2) -> Vector2:
	return game.get_window().get_final_transform() * pos


func _mouse_button(pos: Vector2, button: MouseButton, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = _to_window(pos)
	e.global_position = e.position
	e.button_index = button
	e.pressed = pressed
	e.button_mask = (1 << (button - 1)) if pressed else 0
	_send(e)


func _mouse_move(pos: Vector2, left_down: bool = false) -> void:
	var e := InputEventMouseMotion.new()
	e.position = _to_window(pos)
	e.global_position = e.position
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if left_down else 0
	_send(e)


func _click(pos: Vector2) -> void:
	_mouse_move(pos)
	_mouse_button(pos, MOUSE_BUTTON_LEFT, true)
	_mouse_button(pos, MOUSE_BUTTON_LEFT, false)


## Posição na tela do centro de uma casa.
func _screen_of(cell: Vector2i) -> Vector2:
	return game.camera.unproject_position(Vector3(cell.x, 0.0, cell.y))


## Uma casa livre (fora do caminho) um pouco abaixo e à direita do núcleo (no mapa que cresce, só o
## pedaço da base começa aberto; mais para cima, o painel do GUT cobre a tela e pega o clique).
func _free_cell() -> Vector2i:
	var nexus := game.map.nexus
	for y in range(nexus.y + 1, nexus.y + 4):
		for x in range(nexus.x + 2, nexus.x + 6):
			var cell := Vector2i(x, y)
			if game.map.can_place_tower(cell):
				return cell
	return Vector2i(-1, -1)


func test_cena_carrega_e_roda_alguns_quadros() -> void:
	await _seconds(0.3)
	assert_not_null(game.runner)
	assert_eq(game.seed_text, "integracao")
	assert_gt(game._state().tick, 0, "a simulação anda sozinha")
	assert_eq(game._state().status, "playing")


func test_tecla_1_e_clique_compram_e_posicionam_a_torre() -> void:
	var state := game._state()
	var slot0: String = state.shop.slots[0]
	var cell := _free_cell()
	_tap_key(KEY_1)
	await _frames(2)
	assert_eq(game.shop.carrying()["towerType"], slot0, "a torre ficou presa ao mouse")
	_click(_screen_of(cell))
	await _seconds(0.3)
	assert_eq(state.towers.size(), 1, "a torre foi posicionada")
	assert_eq(Vector2i(state.towers[0].x, state.towers[0].y), cell)
	assert_eq(state.towers[0].type, slot0)
	assert_lt(state.gold, 210)
	assert_true(game.shop.carrying().is_empty())


func test_arrastar_do_slot_ate_a_casa_compra() -> void:
	var state := game._state()
	var cell := _free_cell()
	# Aperta o botão sobre a barra da loja (o estado de Input precisa saber que está apertado).
	_mouse_button(Vector2(180, 650), MOUSE_BUTTON_LEFT, true)
	game.shop_panel.slot_pressed.emit(0, Vector2(180, 650))
	await _frames(1)
	assert_false(game.shop.carrying().is_empty(), "o slot foi pego")
	var target := _screen_of(cell)
	_mouse_move(Vector2(200, 600), true)
	_mouse_move(target, true)
	_mouse_button(target, MOUSE_BUTTON_LEFT, false)
	await _seconds(0.3)
	assert_eq(state.towers.size(), 1)


func test_esc_cancela_a_torre_na_mao() -> void:
	_tap_key(KEY_1)
	await _frames(2)
	assert_false(game.shop.carrying().is_empty())
	_tap_key(KEY_ESCAPE)
	await _frames(1)
	assert_true(game.shop.carrying().is_empty())
	assert_eq(game._state().towers.size(), 0)


func test_espaco_chama_a_onda_e_p_pausa() -> void:
	_tap_key(KEY_SPACE)
	await _seconds(0.3)
	assert_eq(game._state().waves.active.size(), 1, "a onda 1 foi chamada")
	_tap_key(KEY_P)
	await _frames(1)
	assert_true(game.runner.paused)
	var tick: int = game._state().tick
	await _seconds(0.2)
	assert_eq(game._state().tick, tick, "pausado: o tick não anda")
	_tap_key(KEY_P)
	await _frames(1)
	assert_false(game.runner.paused)


func test_q_alterna_a_velocidade() -> void:
	assert_eq(game.runner.clock.speed, 1.0)
	_tap_key(KEY_Q)
	assert_eq(game.runner.clock.speed, 2.0)
	_tap_key(KEY_Q)
	assert_eq(game.runner.clock.speed, 3.0)
	_tap_key(KEY_Q)
	assert_eq(game.runner.clock.speed, 1.0)


func test_ajuda_abre_com_h_pausa_e_fecha_com_esc() -> void:
	_tap_key(KEY_H)
	await _frames(1)
	assert_true(game.help.is_open())
	assert_true(game.runner.paused)
	_tap_key(KEY_ESCAPE)
	await _frames(1)
	assert_false(game.help.is_open())
	assert_false(game.runner.paused)


func test_tela_de_recompensa_escolhe_com_a_tecla_1() -> void:
	game.runner.sim.enqueue({"type": "debugOpenReward"})
	await _seconds(0.3)
	assert_true(game._state().rewards.screen_open(), "a tela abriu")
	assert_true(game.reward_screen.is_open())
	var tick: int = game._state().tick
	await _seconds(0.2)
	assert_eq(game._state().tick, tick, "congelado com a tela aberta")
	_tap_key(KEY_1)
	await _seconds(0.3)
	assert_false(game._state().rewards.screen_open(), "a carta foi escolhida")
	assert_eq(game._state().rewards.taken.size(), 1)


func test_rodinha_aproxima_e_afasta_a_camera() -> void:
	var before := game.camera_ctl.model.view().zoom
	_mouse_move(Vector2(640, 360))
	_mouse_button(Vector2(640, 360), MOUSE_BUTTON_WHEEL_UP, true)
	await _seconds(0.4)
	assert_gt(game.camera_ctl.model.view().zoom, before, "rodinha para cima aproxima")


func test_arrastar_torre_move_fora_da_onda() -> void:
	var state := game._state()
	var from := _free_cell()
	game.runner.sim.enqueue({"type": "placeTower", "towerType": "basic", "x": from.x, "y": from.y})
	await _seconds(0.2)
	assert_eq(state.towers.size(), 1)
	var to := Vector2i(from.x + 1, from.y)
	if not game.map.can_place_tower(to):
		to = Vector2i(from.x, from.y + 1)
	var start := _screen_of(from) + Vector2(0, -10)
	_mouse_move(start)
	_mouse_button(start, MOUSE_BUTTON_LEFT, true)
	var target := _screen_of(to)
	_mouse_move(start + Vector2(30, 0), true)
	_mouse_move(target, true)
	_mouse_button(target, MOUSE_BUTTON_LEFT, false)
	await _seconds(0.3)
	assert_eq(Vector2i(state.towers[0].x, state.towers[0].y), to, "a torre foi movida")


func test_debug_poe_campeao_de_graca_na_mao() -> void:
	var state := game._state()
	var gold: int = state.gold
	var towers := TowerData.game_data()
	var type: String = towers.types.keys().filter(func(id: String) -> bool: return not towers.types[id].classes.is_empty())[0]
	game.shop.carry_free(type, 2)
	await _frames(1)
	assert_true(game.shop.carrying()["free"])
	var cell := _free_cell()
	_click(_screen_of(cell))
	await _seconds(0.3)
	assert_eq(state.towers.size(), 1, "o campeão foi posicionado")
	assert_eq(state.towers[0].type, type)
	assert_eq(state.towers[0].star, 2, "na estrela escolhida")
	assert_eq(state.gold, gold, "de graça")
	assert_false(game.shop.carrying().is_empty(), "continua na mão para pôr outro")
	_tap_key(KEY_ESCAPE)
	await _frames(1)
	assert_true(game.shop.carrying().is_empty(), "Esc solta")


func test_run_perdida_mostra_a_tela_de_fim() -> void:
	game._state().status = "lost"
	await _frames(2)
	assert_true(game.end_screen.visible)
