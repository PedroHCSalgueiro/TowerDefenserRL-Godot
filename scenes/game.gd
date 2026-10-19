class_name Game
extends Node3D
## A cena do jogo (porte de `Game.ts`): liga a simulação (SimulationRunner), a renderização 3D
## (grade, torres, inimigos, projéteis, efeitos), a câmera e a interface. A cada quadro: roda os
## ticks devidos, repassa os eventos às views e atualiza os painéis.
##
## Linha de comando (depois de `--`): `--seed=abc` fixa a semente; `--demo` compra torres e chama
## ondas sozinho (para capturas de tela); `--shot=arquivo.png` salva uma captura depois de
## `--shot-seconds=N` segundos (padrão 8) e encerra.

## Semente fixa para testes (vazio = sorteia ou usa --seed).
static var forced_seed := ""

var runner: SimulationRunner
var map: SimMap
var seed_text := ""

var camera: Camera3D
var camera_ctl: CameraController
var grid: GridView
var tower_view: TowerView
var nexus_view: NexusView
var enemy_view: EnemyView
var projectile_view: ProjectileView
var trigger_fx: TriggerFxView
var overlay: OverlayView

var ui: CanvasLayer
var shop_panel: ShopPanel
var shop: ShopController
var nexus_panel: NexusPanel
var class_panel: ClassPanel
var wave_hud: WaveHud
var tooltip: TowerTooltip
var hints: HintLabels
var tutorial: TutorialCard
var reward_screen: RewardScreenUi
var help: HelpScreen
var end_screen: EndScreen
var tower_drag: TowerDragController
var debug_panel: DebugPanel

var _end_shown := false
var _hovered_tower_id := -1
var _args := {}
var _elapsed := 0.0
var _demo_step := 0.0


func _ready() -> void:
	FontSetup.install()
	_parse_args()
	map = SimMap.load_map(DataLoader.load_json("map.json"))
	seed_text = _args.get("seed", forced_seed if forced_seed != "" else _random_seed())
	runner = SimulationRunner.new(Simulation.create(seed_text, GameSystems.create(map)))
	_build_world()
	_build_ui()
	if _args.has("demo"):
		_demo_setup()
	_open_for_dev()


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var clean := arg.trim_prefix("--")
		if clean.contains("="):
			var parts := clean.split("=", true, 1)
			_args[parts[0]] = parts[1]
		else:
			_args[clean] = true


func _random_seed() -> String:
	# Sem semente fixa, sorteia (como o Phaser com Date.now()).
	return String.num_int64(Time.get_ticks_usec() ^ int(Time.get_unix_time_from_system()), 36)


# ---------------------------------------------------------------- construção

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#1d1f21")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.65, 0.7)
	environment.ambient_light_energy = 0.7
	env.environment = environment
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)

	camera = Camera3D.new()
	camera.current = true
	add_child(camera)

	grid = GridView.new()
	add_child(grid)
	grid.setup(map)
	tower_view = TowerView.new()
	add_child(tower_view)
	tower_view.setup(TowerData.game_data())
	nexus_view = NexusView.new()
	add_child(nexus_view)
	nexus_view.setup(map)
	enemy_view = EnemyView.new()
	add_child(enemy_view)
	enemy_view.setup(EnemyData.game_data())
	projectile_view = ProjectileView.new()
	add_child(projectile_view)
	projectile_view.setup()
	trigger_fx = TriggerFxView.new()
	add_child(trigger_fx)
	trigger_fx.setup(map, TowerData.game_data(), tower_view)
	overlay = OverlayView.new()
	add_child(overlay)
	overlay.setup(TowerData.game_data())

	camera_ctl = CameraController.new()
	add_child(camera_ctl)
	camera_ctl.setup(camera, map, _camera_blocked, _holding_tower, _cancel_hand)
	camera_ctl.right_clicked.connect(func() -> void: shop.cancel())


func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	UiKit.full_rect(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	# Coluna da direita: classes e núcleo.
	var right := UiKit.vbox(6)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	class_panel = ClassPanel.new()
	right.add_child(class_panel)
	nexus_panel = NexusPanel.new()
	right.add_child(nexus_panel)
	root.add_child(right)
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 8)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	shop_panel = ShopPanel.new()
	root.add_child(shop_panel)
	wave_hud = WaveHud.new()
	root.add_child(wave_hud)
	hints = HintLabels.new()
	root.add_child(hints)
	hints.set_version(_version())
	tutorial = TutorialCard.new()
	root.add_child(tutorial)
	tooltip = TowerTooltip.new()
	root.add_child(tooltip)

	reward_screen = RewardScreenUi.new()
	root.add_child(reward_screen)
	reward_screen.setup(_state, _enqueue_checked, func() -> bool: return runner.paused,
			float(EngineData.config()["ticksPerSecond"]))
	help = HelpScreen.new()
	root.add_child(help)
	help.setup(func() -> bool: return runner.paused, func(v: bool) -> void: runner.paused = v,
			func() -> bool: return debug_panel.unlocked())
	wave_hud.append_control(help.toggle_button)
	end_screen = EndScreen.new()
	root.add_child(end_screen)
	end_screen.visible = false
	end_screen.restart_pressed.connect(_restart)

	debug_panel = DebugPanel.new()
	root.add_child(debug_panel)
	debug_panel.setup(runner, _state, func() -> Variant: return grid.hovered_cell, func() -> Variant: return grid.selected_cell)

	nexus_panel.evolve_pressed.connect(_evolve_nexus)
	wave_hud.call_pressed.connect(_call_wave)
	wave_hud.speed_pressed.connect(func() -> void: runner.clock.cycle_speed())
	wave_hud.pause_pressed.connect(func() -> void: runner.paused = not runner.paused)

	shop = ShopController.new()
	add_child(shop)
	shop.setup(shop_panel, map, _state, _enqueue_checked, _evolve_nexus, _blocked, _selected_cell, _cell_at_screen)
	tower_drag = TowerDragController.new()
	add_child(tower_drag)
	tower_drag.setup(map, _state, _blocked, _enqueue_checked, _cell_at_screen)
	tower_drag.started.connect(func(id: int) -> void: grid.select(_cell_of(id)))
	tower_drag.locked.connect(_show_locked)


func _version() -> String:
	var v := str(ProjectSettings.get_setting("application/config/version", ""))
	return v if v != "" else "dev"


# ---------------------------------------------------------------- ajudantes de estado

func _state() -> RunState:
	return runner.sim.state


## Jogo pausado (P) ou tela de recompensa aberta: as ações do jogador são ignoradas.
func _blocked() -> bool:
	return runner.paused or _state().rewards.screen_open()


func _camera_blocked() -> bool:
	return help.is_open() or _state().rewards.screen_open() or _state().status != "playing"


func _holding_tower() -> bool:
	return not shop.carrying().is_empty() or not tower_drag.dragging().is_empty()


func _cancel_hand() -> void:
	shop.cancel()
	tower_drag.cancel()


func _enqueue_checked(command: Dictionary) -> void:
	if not runner.paused:
		runner.sim.enqueue(command)


func _evolve_nexus() -> void:
	if not _blocked():
		runner.sim.enqueue({"type": "evolveNexus"})


func _call_wave() -> void:
	if not _blocked():
		runner.sim.enqueue({"type": "callWave"})


func _selected_cell() -> Variant:
	return grid.selected_cell


func _cell_at_screen(pos: Vector2) -> Variant:
	return GroundProjection.cell_at_screen(camera, pos, map)


func _cell_of(tower_id: int) -> Variant:
	for t: Tower in _state().towers:
		if t.id == tower_id:
			return Vector2i(t.x, t.y)
	return null


func _tower_at(id: int) -> Tower:
	for t: Tower in _state().towers:
		if t.id == id:
			return t
	return null


func _show_locked(tower_id: int) -> void:
	tower_view.show_locked(tower_id)
	hints.show_locked()


func _restart() -> void:
	get_tree().reload_current_scene()


# ---------------------------------------------------------------- entrada

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
			return
		if debug_panel.handle_key(key):
			get_viewport().set_input_as_handled()
			return
		# A ajuda aberta consome todas as teclas do jogo.
		if help.handle_key(key):
			get_viewport().set_input_as_handled()
			return
		if reward_screen.handle_key(key):
			get_viewport().set_input_as_handled()
			return
		if _handle_game_key(key):
			get_viewport().set_input_as_handled()


func _handle_game_key(key: InputEventKey) -> bool:
	if _state().status != "playing":
		return false
	match key.keycode:
		KEY_SPACE:
			_call_wave()
			return true
		KEY_Q:
			runner.clock.cycle_speed()
			return true
		KEY_P:
			runner.paused = not runner.paused
			return true
		KEY_N:
			trigger_fx.toggle_numbers()
			return true
		KEY_ESCAPE:
			_cancel_hand()
			return true
	if _blocked() and key.keycode != KEY_R and key.keycode != KEY_S and key.keycode != KEY_E \
			and not (key.keycode >= KEY_1 and key.keycode <= KEY_5):
		return false
	return shop.handle_key(key)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if camera_ctl.panning() or _camera_blocked():
			return
		var pos := (event as InputEventMouseButton).position
		var cell: Variant = _cell_at_screen(pos)
		grid.select(cell)
		if not shop.carrying().is_empty():
			shop.click_cell(cell)
			return
		var tower := _tower_under_pointer(pos, cell)
		if tower != null:
			tower_drag.press(tower, pos)


## Torre sob o mouse: a que tem o bloco desenhado sob o ponteiro (a da frente, se houver duas) ou,
## se não houver, a da casa sob o mouse.
func _tower_under_pointer(pos: Vector2, cell: Variant) -> Tower:
	var origin := camera.project_ray_origin(pos)
	var normal := camera.project_ray_normal(pos)
	var id := tower_view.tower_at_ray(origin, normal)
	if id >= 0:
		return _tower_at(id)
	if cell != null:
		for t: Tower in _state().towers:
			if t.x == cell.x and t.y == cell.y:
				return t
	return null


# ---------------------------------------------------------------- quadro

func _process(delta: float) -> void:
	var delta_ms := delta * 1000.0
	_elapsed += delta
	var events := runner.update(delta_ms)
	var state := _state()
	var frozen := runner.paused or state.rewards.screen_open()
	var frame_delta := 0.0 if frozen else delta_ms
	var alpha := 1.0 if state.rewards.screen_open() else runner.alpha

	var mouse := get_viewport().get_mouse_position()
	var over_ui := get_viewport().gui_get_hovered_control() != null and not _dragging_from_ui()
	grid.update_hover(camera, null if over_ui else mouse)

	nexus_view.handle_events(events)
	projectile_view.handle_events(events)
	tower_view.handle_events(events)
	_handle_move_events(events)
	tower_view.draw(state, grid.selected_cell, frame_delta)
	nexus_view.draw(state, frame_delta)
	enemy_view.draw(state, alpha)
	projectile_view.draw(state, alpha, frame_delta)
	trigger_fx.handle_events(state, events)
	trigger_fx.draw(state, frame_delta)

	class_panel.update(state.classes, RewardMods.of(state).wildcards)
	nexus_panel.update(state)
	wave_hud.update(state, runner.clock.speed, runner.paused)
	var announcement := WaveAnnounceModel.announcement_for(events, WaveHudModel.default_schedules(), EnemyData.game_data())
	if not announcement.is_empty():
		hints.show_announcement(announcement)
	hints.tick(delta_ms)
	var now_ms := float(Time.get_ticks_msec())
	tutorial.update_card(state, now_ms)
	reward_screen.update_screen()
	shop.update()
	tower_drag.update()
	_update_overlays(state, mouse, over_ui, now_ms)
	debug_panel.update_panel()

	if state.status != "playing" and not _end_shown:
		_end_shown = true
		help.close()
		end_screen.show_report(RunReport.summarize(state, {
			"version": _version(),
			"total_waves": WaveHudModel.default_schedules().size(),
			"ticks_per_second": float(EngineData.config()["ticksPerSecond"]),
			"tower_name": func(type: String) -> String: return TowerData.game_data().get_type(type).name,
			"reward_name": func(id: String, class_id: Variant) -> String:
				return RewardScreenModel.reward_card({"id": id, "classId": class_id}, 0, RewardData.game_data(), ClassData.game_data()).name,
			"link": "semente %s" % state.seed_text,
		}))
	_run_dev_tools(delta)


## Arrastando a partir da interface (slot da loja): a casa sob o mouse vale mesmo fora do painel.
func _dragging_from_ui() -> bool:
	return not shop.carrying().is_empty() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


## Mover (T15): a seleção acompanha a torre que estava selecionada, também na troca; uma recusa por
## trava da simulação mostra o mesmo aviso da tentativa.
func _handle_move_events(events: Array) -> void:
	for event: Dictionary in events:
		if event["type"] == "towerMoved":
			var selected: Variant = grid.selected_cell
			if selected == null:
				continue
			if selected.x == event["fromX"] and selected.y == event["fromY"]:
				grid.select(Vector2i(event["x"], event["y"]))
			elif event["swappedWithId"] != null and selected.x == event["x"] and selected.y == event["y"]:
				grid.select(Vector2i(event["fromX"], event["fromY"]))
		elif event["type"] == "moveRefused" and event["reason"] == "locked":
			_show_locked(event["towerId"])


func _update_overlays(state: RunState, mouse: Vector2, over_ui: bool, now_ms: float) -> void:
	var carrying := shop.carrying()
	var dragging := tower_drag.dragging()
	var hovered: Variant = grid.hovered_cell
	var towers := TowerData.game_data()
	var classes := ClassData.game_data()
	var holding := not carrying.is_empty() or not dragging.is_empty()
	var links: TriggerLinks = null
	var purchase: ClassPreview = null
	var ghost_type := ""
	var ghost_valid := false
	if not dragging.is_empty():
		ghost_type = dragging["towerType"]
		# Mover: verde se a casa está livre ou tem outra torre (troca), vermelho se não.
		ghost_valid = TowerDragModel.can_drop_at(map, hovered)
		var moving := _tower_at(dragging["towerId"])
		if ghost_valid and hovered != null and moving != null:
			var cand := TriggerLinks.Candidate.new()
			cand.type = moving.type
			cand.star = moving.star
			cand.x = hovered.x
			cand.y = hovered.y
			cand.moving_id = moving.id
			# Na troca, a outra torre vai para a casa de onde esta saiu.
			var swapped := _TowersView.new(state, moving, hovered)
			links = TriggerLinks.preview_links(swapped, cand, towers, classes, map)
	elif not carrying.is_empty():
		ghost_type = carrying["towerType"]
		ghost_valid = hovered != null and ShopModel.can_place_at(state, map, hovered)
		purchase = ClassPreview.preview(state.towers, ghost_type, towers, classes, RewardMods.of(state).wildcards)
		if ghost_valid and hovered != null and (purchase == null or purchase.fusion == ""):
			var cand2 := TriggerLinks.Candidate.new()
			cand2.type = ghost_type
			cand2.star = 1
			cand2.x = hovered.x
			cand2.y = hovered.y
			cand2.moving_id = -1
			links = TriggerLinks.preview_links(state, cand2, towers, classes, map)
	overlay.draw_ghost(ghost_type, hovered if holding else null, ghost_valid)
	grid.show_hover(hovered if (holding or hovered != null) else null, ghost_valid if holding else (hovered != null and ShopModel.can_place_at(state, map, hovered)))

	# Janela de informações: slot da loja sob o mouse ou torre do mapa (sem torre na mão).
	var info: TowerInfo = null
	var key := ""
	var preview: ClassPreview = null
	var tower_hover: Tower = null
	var shop_type := shop.hovered_tower_type()
	if shop_type != "":
		info = TowerInfo.describe_tower(towers.get_type(shop_type), 1, classes, shop_type)
		preview = ClassPreview.preview(state.towers, shop_type, towers, classes, RewardMods.of(state).wildcards)
		key = "loja:%s:%s" % [shop_type, ClassPreview.key(preview)]
	elif not holding and hovered != null and not over_ui:
		tower_hover = _tower_under_pointer(mouse, hovered)
		if tower_hover != null:
			info = TowerInfo.describe_tower(towers.get_type(tower_hover.type), tower_hover.star, classes, tower_hover.type)
			key = "torre:%d:%d" % [tower_hover.id, tower_hover.star]
	tooltip.update_info(info, key, now_ms, mouse, preview)
	var shown: Tower = tower_hover if (tower_hover != null and tooltip.is_shown()) else null
	var neighbors: Array = TriggerNeighborhood.affected_neighbors(state, shown, towers, classes) if shown != null else []
	overlay.draw_info(shown, neighbors, links)
	var hint_lines: Array[String] = []
	if holding:
		hint_lines = LinkHint.lines(links, purchase)
	hints.update_link_hint(hint_lines, mouse)


## Estado com as torres trocadas (a outra torre vai para a casa de onde a movida saiu), só para a
## prévia das ligações.
class _TowersView:
	extends RefCounted
	var towers: Array = []
	var rewards: Object

	func _init(state: Object, moving: Tower, target: Vector2i) -> void:
		rewards = state.rewards
		for t: Tower in state.towers:
			if t != moving and t.x == target.x and t.y == target.y:
				var copy := Tower.new(t.id, t.type, Vector2i(moving.x, moving.y), t.star)
				towers.append(copy)
			else:
				towers.append(t)


# ---------------------------------------------------------------- ferramentas de desenvolvimento

func _demo_setup() -> void:
	runner.sim.enqueue({"type": "debugSetNexusInvulnerable", "value": true})
	runner.sim.enqueue({"type": "debugAddGold", "amount": 400})
	runner.clock.set_speed(3.0)


## `--open=reward|help|end|debug`: abre uma tela logo no começo (para capturas de tela).
func _open_for_dev() -> void:
	match String(_args.get("open", "")):
		"reward":
			runner.sim.enqueue({"type": "debugAddGold", "amount": 100})
			runner.sim.enqueue({"type": "debugOpenReward"})
		"help":
			help.open()
		"end":
			_state().status = "lost"
		"debug":
			debug_panel.visible = true
		"stress":
			# Medição de desempenho: núcleo invulnerável, 30 torres dos 8 tipos em ★2 e 1.000 inimigos.
			var cfg: Dictionary = DataLoader.load_json("debug.json")
			runner.sim.enqueue({"type": "debugSetNexusInvulnerable", "value": true})
			runner.sim.enqueue({"type": "debugSpawnTowers", "count": 30, "towerTypes": cfg["fullScenario"]["towerTypes"],
					"layout": "clustered", "star": 2})
			runner.sim.enqueue({"type": "debugSetStress", "stress": {"count": 1000, "layout": "spread"}})


func _run_dev_tools(delta: float) -> void:
	if _args.has("demo"):
		_demo_step += delta
		if _demo_step > 0.8:
			_demo_step = 0.0
			# O bot fica em dev/ (fora da exportação): carrega só se existir.
			if ResourceLoader.exists("res://dev/wave_bot.gd"):
				load("res://dev/wave_bot.gd").drive_for_demo(runner.sim)
	if _args.has("shot") and _elapsed >= float(_args.get("shot-seconds", "8")):
		print("[PERF] ", debug_panel.perf_summary())
		var image := get_viewport().get_texture().get_image()
		image.save_png(String(_args["shot"]))
		get_tree().quit()
