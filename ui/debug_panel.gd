class_name DebugPanel
extends PanelContainer
## Painel de debug sobre o jogo (F2), simplificado em relação ao do Phaser: FPS, tempo de tick, os
## contadores do motor de gatilhos, inimigos, projéteis, torres e a semente; velocidades (inclusive
## 5x e 10x), trapaças (+ouro, ouro infinito, núcleo invulnerável), ondas (encerrar, pular,
## recompensa extra), posicionar torre na casa selecionada e spawn de inimigos (inclusive elite) e torres
## (inclusive o cenário "Cadeia"). Mostra também os efeitos de estado nos inimigos vivos (Lento,
## Atordoado, Marcado com 1 e com 2 marcas, Amaldiçoado) e os empurrões por normal, elite e chefão.
## Toda ação que muda o jogo passa pela fila de comandos da simulação.
##
## Em builds de depuração o painel já nasce liberado; na build de lançamento, só depois de
## Ctrl+Shift+D (a sessão) ou do argumento `--debug`.

const CHAIN_OPTION := "__chain__"
const FULL_OPTION := "__full__"

class Profiler:
	extends RefCounted
	var total_ms := 0.0
	var max_ms := 0.0
	var count := 0
	## Totais desde o começo (não zeram), para o resumo de desempenho.
	var grand_total_ms := 0.0
	var grand_max_ms := 0.0
	var grand_count := 0

	func now() -> float:
		return Time.get_ticks_usec() / 1000.0

	func record_tick(duration_ms: float) -> void:
		total_ms += duration_ms
		max_ms = maxf(max_ms, duration_ms)
		count += 1
		grand_total_ms += duration_ms
		grand_max_ms = maxf(grand_max_ms, duration_ms)
		grand_count += 1

	func average() -> float:
		return total_ms / float(count) if count > 0 else 0.0

	func reset() -> void:
		total_ms = 0.0
		max_ms = 0.0
		count = 0

var _runner: SimulationRunner
var _state: Callable
var _hovered_cell: Callable
var _selected_cell: Callable
var _profiler := Profiler.new()
var _unlocked := false
var _stats: Label
var _refresh_left := 0.0
var _invulnerable: CheckBox
var _infinite_gold: CheckBox
var _cfg: Dictionary
var _tower_option: OptionButton
var _star_option: OptionButton
var _enemy_option: OptionButton
var _enemy_count: SpinBox
var _tower_count: SpinBox
var _layout_option: OptionButton
var _skip_wave: SpinBox
var _tower_ids: Array[String] = []
var _enemy_ids: Array[String] = []
var _elite: CheckBox
## Empurrões vistos desde o começo (para conferir chefão imune e elite no máximo 1 casa):
## {"normal": [vezes, maior], "elite": [vezes, maior], "boss": [vezes, maior]}.
var _pushes := {"normal": [0, 0.0], "elite": [0, 0.0], "boss": [0, 0.0]}


func setup(runner: SimulationRunner, state: Callable, hovered_cell: Callable, selected_cell: Callable) -> void:
	_runner = runner
	_state = state
	_hovered_cell = hovered_cell
	_selected_cell = selected_cell
	_cfg = DataLoader.load_json("debug.json")
	_runner.profiler = _profiler
	_unlocked = OS.is_debug_build() or OS.get_cmdline_user_args().has("--debug")
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiKit.style(Color(0.0784, 0.0824, 0.0902, 0.94), UiKit.BORDER, 8, 1, Vector2(10, 8)))
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 8)
	position.y = 8
	_build()


func unlocked() -> bool:
	return _unlocked


## F2 mostra/esconde (se liberado); Ctrl+Shift+D libera na sessão (tratado em `handle_key`).
func handle_key(key: InputEventKey) -> bool:
	if key.keycode == KEY_F2 and _unlocked:
		visible = not visible
		return true
	return false


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.ctrl_pressed and key.shift_pressed and key.keycode == KEY_D:
		_unlocked = true
		visible = true
		get_viewport().set_input_as_handled()


func _send(command: Dictionary) -> void:
	_runner.sim.enqueue(command)


func _build() -> void:
	var towers := TowerData.game_data()
	var enemies := EnemyData.game_data()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(330, 560)
	add_child(scroll)
	var box := UiKit.vbox(4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_child(UiKit.label("Debug (F2)", 15, UiKit.TEXT, true))
	_stats = UiKit.label("", 11, Color("#9fd6a0"))
	box.add_child(_stats)

	box.add_child(_section("Velocidade"))
	var speeds := UiKit.hbox(4)
	for speed: float in [1.0, 2.0, 3.0, 5.0, 10.0]:
		speeds.add_child(_small_button("%sx" % int(speed), func() -> void: _runner.clock.set_speed(speed)))
	box.add_child(speeds)

	box.add_child(_section("Trapaças"))
	_invulnerable = CheckBox.new()
	_invulnerable.text = "núcleo invulnerável"
	_invulnerable.focus_mode = Control.FOCUS_NONE
	_invulnerable.toggled.connect(func(on: bool) -> void: _send({"type": "debugSetNexusInvulnerable", "value": on}))
	box.add_child(_invulnerable)
	_infinite_gold = CheckBox.new()
	_infinite_gold.text = "ouro infinito"
	_infinite_gold.focus_mode = Control.FOCUS_NONE
	_infinite_gold.toggled.connect(func(on: bool) -> void: _send({"type": "debugSetInfiniteGold", "value": on}))
	box.add_child(_infinite_gold)
	var gold_amount: int = int(_cfg["cheats"]["addGold"])
	box.add_child(_small_button("+%d ouro" % gold_amount, func() -> void: _send({"type": "debugAddGold", "amount": gold_amount})))

	box.add_child(_section("Ondas"))
	var wave_row := UiKit.hbox(4)
	wave_row.add_child(_small_button("Encerrar onda", func() -> void: _send({"type": "endWave"})))
	wave_row.add_child(_small_button("Abrir recompensa", func() -> void: _send({"type": "debugOpenReward"})))
	box.add_child(wave_row)
	var skip_row := UiKit.hbox(4)
	_skip_wave = _spin(1, 99, 10)
	skip_row.add_child(_small_button("Pular para onda", func() -> void: _send({"type": "debugSkipToWave", "wave": int(_skip_wave.value)})))
	skip_row.add_child(_skip_wave)
	box.add_child(skip_row)

	box.add_child(_section("Torres"))
	_tower_option = OptionButton.new()
	_tower_option.focus_mode = Control.FOCUS_NONE
	for id: String in towers.types:
		_tower_ids.append(id)
		_tower_option.add_item(towers.types[id].name)
	_tower_option.add_item(_cfg["chainScenario"]["name"])
	_tower_option.add_item(_cfg["fullScenario"]["name"])
	_star_option = OptionButton.new()
	_star_option.focus_mode = Control.FOCUS_NONE
	for s in [1, 2, 3]:
		_star_option.add_item("★%d" % s)
	box.add_child(_row("Tipo", _tower_option, _star_option))
	box.add_child(_small_button("Posicionar na casa selecionada", _place_tower))
	_tower_count = _spin(0, 5000, int(_cfg["defaults"]["towerCount"]))
	_layout_option = OptionButton.new()
	_layout_option.focus_mode = Control.FOCUS_NONE
	_layout_option.add_item("espalhados")
	_layout_option.add_item("agrupados")
	box.add_child(_row("Spawn", _tower_count, _layout_option))
	box.add_child(_small_button("Spawnar torres", _spawn_towers))

	box.add_child(_section("Inimigos"))
	_enemy_option = OptionButton.new()
	_enemy_option.focus_mode = Control.FOCUS_NONE
	_enemy_option.add_item("sorteados")
	for id: String in enemies.types:
		_enemy_ids.append(id)
		_enemy_option.add_item(id)
	_enemy_count = _spin(0, 5000, int(_cfg["defaults"]["spawnCount"]))
	box.add_child(_row("Tipo", _enemy_option, _enemy_count))
	_elite = CheckBox.new()
	_elite.text = "elite"
	_elite.focus_mode = Control.FOCUS_NONE
	box.add_child(_elite)
	var enemy_row := UiKit.hbox(4)
	enemy_row.add_child(_small_button("Spawnar", _spawn_enemies))
	enemy_row.add_child(_small_button("Estresse", func() -> void:
		_send({"type": "debugSetStress", "stress": {"count": int(_cfg["defaults"]["enemyCount"]), "layout": _layout()}})))
	enemy_row.add_child(_small_button("Parar estresse", func() -> void: _send({"type": "debugSetStress", "stress": null})))
	box.add_child(enemy_row)
	box.add_child(_small_button("Limpar tudo", func() -> void: _send({"type": "debugClear"})))


func _section(text: String) -> Label:
	return UiKit.label(text, 12, Color("#ffd24a"), true)


func _row(title: String, a: Control, b: Control) -> HBoxContainer:
	var r := UiKit.hbox(6)
	r.add_child(UiKit.label(title, 12, UiKit.MUTED))
	r.add_child(a)
	r.add_child(b)
	return r


func _spin(min_v: int, max_v: int, value: int) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.value = value
	s.step = 1
	return s


func _small_button(text: String, on_pressed: Callable) -> Button:
	var b := UiKit.button(text, on_pressed)
	b.add_theme_font_size_override("font_size", 12)
	return b


func _layout() -> String:
	return "clustered" if _layout_option.selected == 1 else "spread"


func _place_tower() -> void:
	var cell: Variant = _selected_cell.call()
	if cell == null:
		return
	var idx := _tower_option.selected
	if idx >= _tower_ids.size():
		return
	_send({"type": "placeTower", "towerType": _tower_ids[idx], "x": cell.x, "y": cell.y, "star": _star_option.selected + 1})


func _spawn_towers() -> void:
	var idx := _tower_option.selected
	var types: Array
	if idx < _tower_ids.size():
		types = [_tower_ids[idx]]
	elif idx == _tower_ids.size():
		types = _cfg["chainScenario"]["towerTypes"]
	else:
		types = _cfg["fullScenario"]["towerTypes"]
	_send({"type": "debugSpawnTowers", "count": int(_tower_count.value), "towerTypes": types,
			"layout": _layout(), "star": _star_option.selected + 1})


func _spawn_enemies() -> void:
	var idx := _enemy_option.selected
	_send({"type": "debugSpawnEnemies", "count": int(_enemy_count.value),
			"enemyType": null if idx == 0 else _enemy_ids[idx - 1], "layout": _layout(), "elite": _elite.button_pressed})


## Eventos do quadro: guarda os empurrões (Imediato Âncora) por tipo de inimigo.
func handle_events(events: Array) -> void:
	for event: Dictionary in events:
		if event["type"] != "enemiesPushed":
			continue
		for push: Dictionary in event["pushes"]:
			var kind := "boss" if push["boss"] else ("elite" if push["elite"] else "normal")
			var entry: Array = _pushes[kind]
			entry[0] += 1
			entry[1] = maxf(entry[1], float(push["cells"]))


## Contagem dos efeitos de estado nos inimigos vivos (Lento, Atordoado, Sangrando, Marcado com 1 e com 2+
## marcas, Amaldiçoado) e os empurrões vistos.
func _status_lines(state: RunState) -> Array[String]:
	var slow := 0
	var stun := 0
	var bleed := 0
	var marked := [0, 0]
	var cursed := 0
	var poisoned := 0
	var slow_stunned := 0
	for enemy: Enemy in state.enemies.slots:
		if not enemy.active:
			continue
		slow += 1 if enemy.slow_ticks > 0 else 0
		stun += 1 if enemy.stun_ticks > 0 else 0
		slow_stunned += 1 if enemy.slow_ticks > 0 and enemy.stun_ticks > 0 else 0
		bleed += 1 if enemy.bleed_ticks > 0 else 0
		if not enemy.marks.is_empty():
			marked[0 if enemy.marks.size() == 1 else 1] += 1
		cursed += 0 if enemy.curse.is_empty() else 1
		poisoned += 1 if enemy.poison_ticks > 0 else 0
	var hunter: ClassState.ClassStatus = state.classes.get("hunter")
	var push_text := "Empurrões: normal %dx (máx %s) · elite %dx (máx %s) · chefão %dx (máx %s)" % [
			_pushes["normal"][0], TowerInfo.fmt(_pushes["normal"][1]), _pushes["elite"][0], TowerInfo.fmt(_pushes["elite"][1]),
			_pushes["boss"][0], TowerInfo.fmt(_pushes["boss"][1])]
	return [
		"Lento %d  Atordoado %d (Lento e atordoado %d)  Sangrando %d" % [slow, stun, slow_stunned, bleed],
		"Marcado 1 marca %d · 2+ marcas %d · bônus Caçador %s  Amaldiçoado %d" % [marked[0], marked[1],
				"ativo" if hunter != null and hunter.level > 0 else "inativo", cursed],
		push_text,
		"Ouro guardado para o fim da onda %d · Envenenado %d · Almas da onda %d · Invocações %d" % [state.pending_loot,
				poisoned, state.souls, state.traps.size()],
	]


## Resumo de desempenho desde o começo da run (para medições por linha de comando).
func perf_summary() -> String:
	return "FPS %d | tick médio %.3f ms, máx %.3f ms (%d ticks) | ticks descartados %d" % [
			Engine.get_frames_per_second(), _profiler.grand_total_ms / maxf(1.0, float(_profiler.grand_count)),
			_profiler.grand_max_ms, _profiler.grand_count, _runner.clock.dropped_ticks]


## Chame a cada quadro.
func update_panel() -> void:
	if not visible:
		return
	_refresh_left -= get_process_delta_time()
	if _refresh_left > 0.0:
		return
	_refresh_left = float(_cfg["panel"]["refreshMs"]) / 1000.0
	var state: RunState = _state.call()
	var t := state.triggers.last_tick
	var lines: Array[String] = [
		"FPS %d" % Engine.get_frames_per_second(),
		"Tick %.2f / máx %.2f ms" % [_profiler.average(), _profiler.max_ms],
		"Ticks descartados %d" % _runner.clock.dropped_ticks,
		"Gatilhos %d/tick  prof. máx %d  adiados %d  descartados %d" % [t.fired, t.max_depth, t.deferred, state.triggers.dropped_total],
		"Inimigos %d  Projéteis %d  Torres %d" % [state.enemies.active_count, state.projectiles.active_count, state.towers.size()],
		"Casa sob o mouse %s  selecionada %s" % [_cell_text(_hovered_cell.call()), _cell_text(_selected_cell.call())],
		"Semente %s  tick %d%s" % [state.seed_text, state.tick, "  [trapaça]" if state.cheated else ""],
	]
	lines.append_array(_status_lines(state))
	_stats.text = "\n".join(lines)
	_profiler.reset()


static func _cell_text(cell: Variant) -> String:
	return "(%d, %d)" % [cell.x, cell.y] if cell != null else "—"
