class_name DebugPanel
extends PanelContainer
## Painel de debug sobre o jogo (F2), para testar a run de ponta a ponta. Abas:
## - Jogo: velocidades (inclusive 5x e 10x) e trapaças (+ouro, ouro infinito, núcleo invulnerável, limpar).
## - Ondas: chamar, encerrar, abrir recompensa e pular para qualquer onda (atalhos 5..40); as recompensas
##   e paredes das ondas puladas abrem depois, uma de cada vez.
## - Mapa: derrubar a próxima parede, todas as que faltam ou dividir a linha principal (entrada nova).
## - Campeões: qualquer campeão, na estrela escolhida, de graça na mão (clique no mapa para colocar, quantas
##   vezes quiser; Esc ou botão direito soltam); spawn em massa (inclusive os cenários "Cadeia").
## - Inimigos: spawn (inclusive elite) e estresse.
## - Info: FPS, tempo de tick, os contadores do motor de gatilhos, inimigos, projéteis, torres, a semente, os
##   efeitos de estado nos inimigos vivos e os empurrões por normal, elite e chefão.
## Toda ação que muda o jogo passa pela fila de comandos da simulação.
##
## Em builds de depuração o painel já nasce liberado; na build de lançamento, só depois de
## Ctrl+Shift+D (a sessão) ou do argumento `--debug`.

const TABS: Array[String] = ["Jogo", "Ondas", "Mapa", "Campeões", "Inimigos", "Info"]
const SPEEDS: Array[float] = [1.0, 2.0, 3.0, 5.0, 10.0]
const ON_COLOR := Color("#e0b84a")

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
var _carry: Callable          # (tower_type: String, star: int)
var _carrying: Callable       # () -> Dictionary
var _profiler := Profiler.new()
var _unlocked := false
var _cfg: Dictionary
var _refresh_left := 0.0
var _total_waves := 0

var _summary: Label
var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []
var _tab := 0
var _stats: Label
var _speed_buttons: Array[Button] = []
var _invulnerable: CheckBox
var _infinite_gold: CheckBox
var _wave_label: Label
var _skip_wave: SpinBox
var _map_label: Label
var _star := 1
var _star_buttons: Array[Button] = []
var _search: LineEdit
var _champion_grid: GridContainer
var _hand_label: Label
var _mass_option: OptionButton
var _tower_count: SpinBox
var _layout_option: OptionButton
var _tower_ids: Array[String] = []
var _enemy_option: OptionButton
var _enemy_count: SpinBox
var _enemy_ids: Array[String] = []
var _elite: CheckBox
## Empurrões vistos desde o começo (para conferir chefão imune e elite no máximo 1 casa):
## {"normal": [vezes, maior], "elite": [vezes, maior], "boss": [vezes, maior]}.
var _pushes := {"normal": [0, 0.0], "elite": [0, 0.0], "boss": [0, 0.0]}


func setup(runner: SimulationRunner, state: Callable, hovered_cell: Callable, selected_cell: Callable,
		carry: Callable = Callable(), carrying: Callable = Callable()) -> void:
	_runner = runner
	_state = state
	_hovered_cell = hovered_cell
	_selected_cell = selected_cell
	_carry = carry
	_carrying = carrying
	_cfg = DataLoader.load_json("debug.json")
	_total_waves = WaveHudModel.default_schedules().size()
	_runner.profiler = _profiler
	_unlocked = OS.is_debug_build() or OS.get_cmdline_user_args().has("--debug")
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiKit.game_style(8, Vector2(8, 6)))
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 8)
	position = Vector2(8, 8)
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


# --- Montagem -----------------------------------------------------------------------------------

func _build() -> void:
	var width := float(_cfg["panel"]["width"])
	var box := UiKit.vbox(5)
	box.custom_minimum_size = Vector2(width, 0)
	add_child(box)
	var head := UiKit.hbox(6)
	head.add_child(UiKit.label("Debug", 13, UiKit.GOLD, true))
	head.add_child(UiKit.label("F2 fecha", 10, UiKit.MUTED))
	box.add_child(head)
	_summary = UiKit.label("", 10, Color("#9fd6a0"))
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_summary)

	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 3)
	tabs.add_theme_constant_override("v_separation", 3)
	box.add_child(tabs)
	var pages := [_page_game(), _page_waves(), _page_map(), _page_champions(), _page_enemies(), _page_info()]
	for i in TABS.size():
		var index := i
		var b := _chip(TABS[i], func() -> void: _show_tab(index))
		tabs.add_child(b)
		_tab_buttons.append(b)
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(width, float(_cfg["panel"]["pageHeight"]))
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var page: Control = pages[i]
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(page)
		box.add_child(scroll)
		_pages.append(scroll)
	_show_tab(0)


func _show_tab(index: int) -> void:
	_tab = index
	for i in _pages.size():
		_pages[i].visible = i == index
		_set_on(_tab_buttons[i], i == index)
	_refresh_left = 0.0


func _page_game() -> Control:
	var page := UiKit.vbox(4)
	page.add_child(_section("Velocidade"))
	var speeds := UiKit.hbox(3)
	for speed in SPEEDS:
		var b := _chip("%dx" % int(speed), func() -> void: _runner.clock.set_speed(speed))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		speeds.add_child(b)
		_speed_buttons.append(b)
	page.add_child(speeds)

	page.add_child(_section("Trapaças"))
	_invulnerable = _check("Núcleo invulnerável", func(on: bool) -> void:
		_send({"type": "debugSetNexusInvulnerable", "value": on}))
	page.add_child(_invulnerable)
	_infinite_gold = _check("Ouro infinito", func(on: bool) -> void:
		_send({"type": "debugSetInfiniteGold", "value": on}))
	page.add_child(_infinite_gold)
	var gold := UiKit.hbox(4)
	for key in ["addGold", "addGoldBig"]:
		var amount: int = int(_cfg["cheats"][key])
		gold.add_child(_grow(_button("+%d ouro" % amount, func() -> void: _send({"type": "debugAddGold", "amount": amount}))))
	page.add_child(gold)

	page.add_child(_section("Mapa e torres"))
	page.add_child(_button("Limpar tudo (torres, inimigos, tiros)", func() -> void: _send({"type": "debugClear"})))
	page.add_child(_hint("O que muda o jogo marca a run como \"com trapaça\" no relatório."))
	return page


func _page_waves() -> Control:
	var page := UiKit.vbox(4)
	_wave_label = UiKit.label("", 12, UiKit.TEXT, true)
	page.add_child(_wave_label)
	var row := UiKit.hbox(4)
	row.add_child(_grow(_button("Chamar onda", func() -> void: _send({"type": "callWave"}))))
	row.add_child(_grow(_button("Encerrar onda", func() -> void: _send({"type": "endWave"}))))
	page.add_child(row)
	page.add_child(_button("Abrir recompensa", func() -> void: _send({"type": "debugOpenReward"})))

	page.add_child(_section("Pular para a onda"))
	var shortcuts := GridContainer.new()
	shortcuts.columns = 4
	shortcuts.add_theme_constant_override("h_separation", 3)
	shortcuts.add_theme_constant_override("v_separation", 3)
	for wave in _cfg["waveShortcuts"]:
		var target := int(wave)
		var b := _button(str(target), func() -> void: _skip_to(target))
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shortcuts.add_child(b)
	page.add_child(shortcuts)
	var custom := UiKit.hbox(4)
	_skip_wave = _spin(1, maxi(1, _total_waves), 10)
	_skip_wave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom.add_child(_skip_wave)
	custom.add_child(_button("Ir", func() -> void: _skip_to(int(_skip_wave.value))))
	page.add_child(custom)
	page.add_child(_hint("Pular encerra a onda em andamento e fecha as do meio (ouro, juros e loja de cada " +
			"uma). As recompensas e as paredes delas abrem depois, uma de cada vez."))
	return page


## Encerra o que estiver em andamento e pula: a próxima onda a chamar passa a ser `wave`.
func _skip_to(wave: int) -> void:
	if not _state.call().waves.active.is_empty():
		_send({"type": "endWave"})
	_send({"type": "debugSkipToWave", "wave": wave})


func _page_map() -> Control:
	var page := UiKit.vbox(4)
	_map_label = UiKit.label("", 11, UiKit.TEXT)
	_map_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_map_label)
	page.add_child(_section("Paredes"))
	page.add_child(_button("Derrubar a próxima parede", func() -> void: _send({"type": "debugOpenExpansion"})))
	page.add_child(_button("Derrubar todas as que faltam", _open_all_walls))
	page.add_child(_hint("A direção é escolhida na tela que abre (1, 2, 3); o caminho já vem sorteado."))
	page.add_child(_section("Dividir"))
	page.add_child(_button("Dividir na próxima parede", func() -> void:
		_send({"type": "debugOpenExpansion", "split": true})))
	page.add_child(_hint("Abre duas direções de uma vez: a segunda vira uma linha nova, com entrada própria, " +
			"e a horda se divide entre as entradas. Depois, cada parede pergunta qual linha cresce."))
	return page


func _open_all_walls() -> void:
	var data := ExpansionData.game_data()
	var state: RunState = _state.call()
	if not data.enabled or state.expansion == null:
		return
	for i in maxi(0, data.max_walls() - state.expansion.opened.size() - state.expansion.pending):
		_send({"type": "debugOpenExpansion"})


func _page_champions() -> Control:
	var page := UiKit.vbox(4)
	var stars := UiKit.hbox(3)
	stars.add_child(UiKit.label("Estrela", 11, UiKit.MUTED))
	for s in [1, 2, 3]:
		var star: int = s
		var b := _chip("★%d" % star, func() -> void: _set_star(star))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stars.add_child(b)
		_star_buttons.append(b)
	page.add_child(stars)
	_set_star(1)
	_search = LineEdit.new()
	_search.placeholder_text = "Buscar campeão ou classe..."
	_search.clear_button_enabled = true
	_search.add_theme_font_size_override("font_size", 11)
	_search.text_changed.connect(func(_text: String) -> void: _fill_champions())
	page.add_child(_search)
	_hand_label = UiKit.label("", 10, Color("#9fd6a0"))
	_hand_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_hand_label)
	_champion_grid = GridContainer.new()
	_champion_grid.columns = 2
	_champion_grid.add_theme_constant_override("h_separation", 3)
	_champion_grid.add_theme_constant_override("v_separation", 3)
	page.add_child(_champion_grid)
	_fill_champions()

	page.add_child(_section("Em massa"))
	var towers := TowerData.game_data()
	_mass_option = _option()
	for id: String in towers.types:
		_tower_ids.append(id)
		_mass_option.add_item(towers.types[id].name)
	_mass_option.add_item(_cfg["chainScenario"]["name"])
	_mass_option.add_item(_cfg["fullScenario"]["name"])
	_mass_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(_mass_option)
	var row := UiKit.hbox(4)
	_tower_count = _spin(0, 5000, int(_cfg["defaults"]["towerCount"]))
	row.add_child(_tower_count)
	_layout_option = _option()
	_layout_option.add_item("espalhados")
	_layout_option.add_item("agrupados")
	_layout_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_layout_option)
	page.add_child(row)
	page.add_child(_button("Spawnar torres", _spawn_towers))
	return page


func _set_star(star: int) -> void:
	_star = star
	for i in _star_buttons.size():
		_set_on(_star_buttons[i], i + 1 == star)


## Botões dos campeões (filtrados pela busca), por raridade e nome.
func _fill_champions() -> void:
	UiKit.clear(_champion_grid)
	var towers := TowerData.game_data()
	var classes := ClassData.game_data()
	var query := _search.text.strip_edges().to_lower()
	var ids: Array = towers.types.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ra := _rarity_rank(towers.types[a])
		var rb := _rarity_rank(towers.types[b])
		return ra < rb if ra != rb else String(towers.types[a].name) < String(towers.types[b].name))
	for id: String in ids:
		var type: TowerData.TowerType = towers.types[id]
		var class_names: Array[String] = []
		for class_id in type.classes:
			var c: Variant = classes.classes.get(class_id)
			class_names.append(c.name if c != null else class_id)
		var text := "%s %s" % [type.name, " ".join(class_names)]
		if query != "" and not text.to_lower().contains(query):
			continue
		_champion_grid.add_child(_champion_button(id, type, " · ".join(class_names)))


static func _rarity_rank(type: TowerData.TowerType) -> int:
	return TowerData.RARITIES.find(type.rarity) if type.rarity != null else TowerData.RARITIES.size()


func _champion_button(id: String, type: TowerData.TowerType, class_text: String) -> Control:
	var rarity_color := Color(ShopCard.RARITY_COLORS.get(type.rarity if type.rarity != null else "", ShopCard.RARITY_COLORS["common"]))
	var accent := RenderConfig.tower_color(TowerData.game_data(), id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 34)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := UiKit.style(Color("#1d1f23"), rarity_color.darkened(0.25), 6, 1, Vector2(8, 4))
	normal.border_width_left = 4
	normal.border_color = rarity_color
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#2c2f35")
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	var box := UiKit.vbox(0)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0)
	box.offset_left = 8
	box.offset_top = 3
	var name_row := UiKit.hbox(6)
	var dot := ColorRect.new()
	dot.color = accent
	dot.custom_minimum_size = Vector2(6, 6)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(dot)
	name_row.add_child(UiKit.label(type.name, 11, UiKit.TEXT, true))
	box.add_child(name_row)
	box.add_child(UiKit.label(class_text if class_text != "" else "teste", 9, UiKit.MUTED))
	b.add_child(box)
	b.pressed.connect(func() -> void:
		if _carry.is_valid():
			_carry.call(id, _star))
	return b


func _page_enemies() -> Control:
	var page := UiKit.vbox(4)
	var enemies := EnemyData.game_data()
	_enemy_option = _option()
	_enemy_option.add_item("sorteados")
	for id: String in enemies.types:
		_enemy_ids.append(id)
		_enemy_option.add_item(id)
	_enemy_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UiKit.hbox(4)
	row.add_child(_enemy_option)
	_enemy_count = _spin(0, 5000, int(_cfg["defaults"]["spawnCount"]))
	row.add_child(_enemy_count)
	page.add_child(row)
	_elite = _check("Elite", Callable())
	page.add_child(_elite)
	page.add_child(_button("Spawnar inimigos", _spawn_enemies))
	page.add_child(_section("Estresse"))
	var stress := UiKit.hbox(4)
	stress.add_child(_grow(_button("Ligar (%d)" % int(_cfg["defaults"]["enemyCount"]), func() -> void:
		_send({"type": "debugSetStress", "stress": {"count": int(_cfg["defaults"]["enemyCount"]), "layout": _layout()}}))))
	stress.add_child(_grow(_button("Desligar", func() -> void: _send({"type": "debugSetStress", "stress": null}))))
	page.add_child(stress)
	page.add_child(_hint("O estresse mantém essa quantidade de inimigos vivos o tempo todo, para medir desempenho."))
	return page


func _page_info() -> Control:
	var page := UiKit.vbox(4)
	_stats = UiKit.label("", 10, Color("#9fd6a0"))
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_stats)
	return page


# --- Peças --------------------------------------------------------------------------------------

func _section(text: String) -> Control:
	var box := UiKit.vbox(1)
	box.add_child(UiKit.label(text, 11, UiKit.GOLD, true))
	var line := ColorRect.new()
	line.color = Color(UiKit.FRAME, 0.6)
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line)
	return box


func _hint(text: String) -> Label:
	var l := UiKit.label(text, 10, UiKit.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _button(text: String, on_pressed: Callable) -> Button:
	return UiKit.compact(UiKit.button(text, on_pressed), 11)


## Botão que fica aceso (aba, velocidade, estrela).
func _chip(text: String, on_pressed: Callable) -> Button:
	var b := _button(text, on_pressed)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return b


func _set_on(b: Button, on: bool) -> void:
	if on:
		var s := UiKit.style(Color("#4a3c18"), ON_COLOR, 6, 1, Vector2(7, 2))
		s.border_width_bottom = 2
		s.content_margin_bottom = 3.0
		b.add_theme_stylebox_override("normal", s)
		b.add_theme_color_override("font_color", Color("#ffe9a8"))
	else:
		var off := UiKit._button_style(UiKit.BUTTON_BG, UiKit.BUTTON_BORDER)
		off.content_margin_left = 7.0
		off.content_margin_right = 7.0
		off.content_margin_top = 2.0
		off.content_margin_bottom = 3.0
		b.add_theme_stylebox_override("normal", off)
		b.add_theme_color_override("font_color", Color("#eeeeee"))


func _grow(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


func _check(text: String, on_toggled: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", 11)
	if on_toggled.is_valid():
		c.toggled.connect(on_toggled)
	return c


func _option() -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.add_theme_font_size_override("font_size", 11)
	return o


func _spin(min_v: int, max_v: int, value: int) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.value = value
	s.step = 1
	s.get_line_edit().add_theme_font_size_override("font_size", 11)
	return s


func _layout() -> String:
	return "clustered" if _layout_option.selected == 1 else "spread"


func _spawn_towers() -> void:
	var idx := _mass_option.selected
	var types: Array
	if idx < _tower_ids.size():
		types = [_tower_ids[idx]]
	elif idx == _tower_ids.size():
		types = _cfg["chainScenario"]["towerTypes"]
	else:
		types = _cfg["fullScenario"]["towerTypes"]
	_send({"type": "debugSpawnTowers", "count": int(_tower_count.value), "towerTypes": types,
			"layout": _layout(), "star": _star})


func _spawn_enemies() -> void:
	var idx := _enemy_option.selected
	_send({"type": "debugSpawnEnemies", "count": int(_enemy_count.value),
			"enemyType": null if idx == 0 else _enemy_ids[idx - 1], "layout": _layout(), "elite": _elite.button_pressed})


# --- Atualização --------------------------------------------------------------------------------

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
	var data := ExpansionData.game_data()
	var walls := "" if state.expansion == null or not data.enabled else \
			" · paredes %d/%d" % [state.expansion.opened.size(), data.max_walls()]
	_summary.text = "Onda %d/%d · ouro %d · torres %d%s%s" % [_current_wave(state), _total_waves, state.gold,
			state.towers.size(), walls, " · [trapaça]" if state.cheated else ""]
	for i in SPEEDS.size():
		_set_on(_speed_buttons[i], is_equal_approx(_runner.clock.speed, SPEEDS[i]))
	match _tab:
		1:
			var running := not state.waves.active.is_empty()
			_wave_label.text = "Onda %d de %d · %s" % [_current_wave(state), _total_waves,
					"em andamento" if running else "esperando chamar"]
		2:
			_map_label.text = _map_text(state, data)
		3:
			var hand: Dictionary = _carrying.call() if _carrying.is_valid() else {}
			if hand.get("free", false):
				_hand_label.text = "Na mão: %s ★%d. Clique no mapa para colocar (quantas quiser); Esc ou botão direito soltam." % [
						TowerData.game_data().get_type(hand["towerType"]).name, int(hand["star"])]
			else:
				_hand_label.text = "Clique num campeão para pegar de graça, na estrela escolhida."
		5:
			_stats.text = "\n".join(_info_lines(state))
	_profiler.reset()


## Onda que o HUD mostra: a maior em andamento ou, sem nenhuma, a próxima a chamar.
static func _current_wave(state: RunState) -> int:
	var wave := 0
	for active: WaveState.ActiveWave in state.waves.active:
		wave = maxi(wave, active.wave)
	return wave if wave > 0 else WaveState.next_wave_number(state)


func _map_text(state: RunState, data: ExpansionData) -> String:
	if state.expansion == null or not data.enabled:
		return "Este mapa não cresce."
	var lay := data.layout(state.expansion.opened)
	var lines := "%d linha" % lay.lines.size() if lay.lines.size() == 1 else "%d linhas (horda dividida)" % lay.lines.size()
	var waiting := ""
	if state.expansion.pending > 0:
		waiting = " · %d esperando" % state.expansion.pending
	if state.expansion.split_next:
		waiting += " · a próxima divide"
	return "Paredes derrubadas: %d de %d · %s%s" % [state.expansion.opened.size(), data.max_walls(), lines, waiting]


func _info_lines(state: RunState) -> Array[String]:
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
	return lines


static func _cell_text(cell: Variant) -> String:
	return "(%d, %d)" % [cell.x, cell.y] if cell != null else "—"
