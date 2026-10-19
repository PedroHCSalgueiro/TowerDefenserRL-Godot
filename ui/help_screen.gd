class_name HelpScreen
extends Control
## Tela de ajuda (T17): a tecla H e o botão "?" abrem a lista de controles por cima do jogo. Abrir
## pausa; fechar (H, Esc ou o botão) volta como estava. Com a ajuda aberta, as outras teclas não
## chegam ao jogo (porte de `helpScreen.ts`).

var _paused: Callable        # () -> bool
var _set_paused: Callable    # (bool)
var _debug_unlocked: Callable  # () -> bool
var _table: GridContainer
var _paused_before := false
var toggle_button: Button


func setup(paused: Callable, set_paused: Callable, debug_unlocked: Callable) -> void:
	_paused = paused
	_set_paused = set_paused
	_debug_unlocked = debug_unlocked
	var help: Dictionary = DataLoader.load_json("ui.json")["help"]
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.04, 0.05, 0.72)
	UiKit.full_rect(dim)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close())
	add_child(dim)
	var center := CenterContainer.new()
	UiKit.full_rect(center)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := UiKit.panel(Color("#1d1f21"), Color("#55595e"), 8, Vector2(26, 20))
	center.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 560)
	panel.add_child(scroll)
	var box := UiKit.vbox(8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_child(UiKit.label(help["title"], 24, UiKit.TEXT, true))
	_table = GridContainer.new()
	_table.columns = 2
	_table.add_theme_constant_override("h_separation", 18)
	_table.add_theme_constant_override("v_separation", 4)
	box.add_child(_table)
	box.add_child(UiKit.label(help["chains"]["title"], 18, UiKit.TEXT, true))
	for paragraph: String in help["chains"]["paragraphs"]:
		var p := UiKit.label(paragraph, 13, Color("#c8c8c8"))
		p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.custom_minimum_size = Vector2(700, 0)
		box.add_child(p)
	box.add_child(UiKit.label(help["pausedNote"], 13, UiKit.MUTED))
	box.add_child(UiKit.button(help["closeLabel"], close))
	toggle_button = UiKit.button(help["buttonLabel"], func() -> void:
		if is_open():
			close()
		else:
			open())


func is_open() -> bool:
	return visible


func open() -> void:
	if is_open():
		return
	UiKit.clear(_table)
	for line: Dictionary in HelpModel.help_lines(_debug_unlocked.call()):
		var keys := UiKit.label(line["keys"], 13, Color("#ffd24a") if line["debug"] else Color("#ffe9a8"), true)
		keys.custom_minimum_size = Vector2(150, 0)
		_table.add_child(keys)
		var action := UiKit.label(line["action"], 13, UiKit.TEXT)
		action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		action.custom_minimum_size = Vector2(540, 0)
		_table.add_child(action)
	_paused_before = _paused.call()
	_set_paused.call(true)
	visible = true


func close() -> void:
	if not is_open():
		return
	visible = false
	_set_paused.call(_paused_before)


## Tecla do jogo. Com a ajuda aberta, consome tudo (H e Esc fecham). Devolve true se consumiu.
func handle_key(event: InputEventKey) -> bool:
	var help_key: String = DataLoader.load_json("ui.json")["help"]["key"]
	var is_help_key := OS.get_keycode_string(event.keycode).to_lower() == help_key
	if is_open():
		if is_help_key or event.keycode == KEY_ESCAPE:
			close()
		return true
	if is_help_key:
		open()
		return true
	return false
