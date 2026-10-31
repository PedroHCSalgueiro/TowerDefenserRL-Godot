class_name ExpansionScreenUi
extends Control
## Escolha da parede (mapa que cresce): uma coluna à esquerda com os pedaços oferecidos e a barra do tempo,
## sem escurecer o mapa, para os pedaços acesos aparecerem (`GridView.show_candidates`). A câmera enquadra o
## mapa ao lado dela (`choiceInsetsPx` em render.json). Clique ou teclas 1, 2 e 3 escolhem; passar o mouse
## numa opção destaca o pedaço dela no mapa. A simulação é quem congela o jogo enquanto a escolha está
## aberta; com a pausa do relógio (P), nada é aceito.

const OPTION_COLORS_KEY := "optionColors"
## Largura do texto da coluna; com as margens, ela não passa de `choiceInsetsPx.left` (render.json).
const TEXT_WIDTH := 212
const SCREEN_MARGIN := 12

## Opção sob o mouse (-1 = nenhuma), para o mapa destacar o pedaço.
var hovered_option := -1
var _state: Callable      # () -> RunState
var _enqueue: Callable    # (command: Dictionary)
var _paused: Callable     # () -> bool
var _ticks_per_second: float
var _panel: PanelContainer
var _options_column: VBoxContainer
var _timer_fill: ColorRect
var _timer_text: Label
var _model: ExpansionScreenModel = null
var _key := ""


func setup(state: Callable, enqueue: Callable, paused: Callable, ticks_per_second: float) -> void:
	_state = state
	_enqueue = enqueue
	_paused = paused
	_ticks_per_second = ticks_per_second
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var texts: Dictionary = DataLoader.load_json("ui.json")["expansionScreen"]
	_panel = UiKit.game_panel(14, Vector2(12, 10))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := UiKit.vbox(8)
	box.add_child(UiKit.label(texts["title"], 20, UiKit.GOLD, true))
	var subtitle := UiKit.label(texts["subtitle"], 13, UiKit.MUTED)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	box.add_child(subtitle)
	_options_column = UiKit.vbox(8)
	box.add_child(_options_column)
	var timer_back := ColorRect.new()
	timer_back.color = Color("#2a2c2f")
	timer_back.custom_minimum_size = Vector2(0, 6)
	timer_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_fill = ColorRect.new()
	_timer_fill.color = Color("#e0b84a")
	_timer_fill.anchor_bottom = 1.0
	_timer_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_back.add_child(_timer_fill)
	box.add_child(timer_back)
	_timer_text = UiKit.label("", 12, UiKit.MUTED)
	_timer_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_timer_text)
	_panel.add_child(box)
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, SCREEN_MARGIN)


func is_open() -> bool:
	return _model != null


## Ids das aberturas oferecidas, na ordem das opções ([] fechada).
func option_ids() -> Array:
	if _model == null:
		return []
	return _model.options.map(func(o: ExpansionScreenModel.Option) -> String: return o.option_id)


## Cor de cada opção (a mesma do destaque do pedaço no mapa).
static func option_color(index: int) -> Color:
	var colors: Array = RenderConfig.data()["expansion"][OPTION_COLORS_KEY]
	return RenderConfig.color(colors[index % colors.size()])


func handle_key(event: InputEventKey) -> bool:
	if _model == null:
		return false
	if event.keycode >= KEY_1 and event.keycode <= KEY_9:
		var index := event.keycode - KEY_1
		if index < _model.options.size():
			_choose(index)
			return true
	return false


func _choose(index: int) -> void:
	if not _paused.call():
		_enqueue.call({"type": "chooseExpansion", "index": index})


func _render(model: ExpansionScreenModel) -> void:
	var texts: Dictionary = DataLoader.load_json("ui.json")["expansionScreen"]
	UiKit.clear(_options_column)
	hovered_option = -1
	for option in model.options:
		_options_column.add_child(_render_option(option, texts))


func _render_option(option: ExpansionScreenModel.Option, texts: Dictionary) -> Control:
	var color := option_color(option.index)
	var node := PanelContainer.new()
	var normal := UiKit.style(Color("#1d1f23"), color, 10, 2, Vector2(10, 8))
	var hover := UiKit.style(Color("#2a2c31"), color.lightened(0.3), 10, 3, Vector2(10, 8))
	node.add_theme_stylebox_override("panel", normal)
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var box := UiKit.vbox(2)
	var top := UiKit.hbox(6)
	var name_label := UiKit.label(option.name, 15, UiKit.TEXT, true)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	top.add_child(UiKit.label(option.key, 15, color, true))
	box.add_child(top)
	box.add_child(UiKit.label(option.cells, 13, Color("#9fd6a0")))
	if option.entrance:
		var entrance := UiKit.label(texts["entrance"], 13, Color("#ff7a6b"), true)
		entrance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(entrance)
	node.add_child(box)
	var index := option.index
	node.mouse_entered.connect(func() -> void:
		hovered_option = index
		node.add_theme_stylebox_override("panel", hover))
	node.mouse_exited.connect(func() -> void:
		if hovered_option == index:
			hovered_option = -1
		node.add_theme_stylebox_override("panel", normal))
	node.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_choose(index))
	return node


## Chame a cada quadro: opções só quando mudam; a barra do tempo sempre.
func update_screen() -> void:
	var texts: Dictionary = DataLoader.load_json("ui.json")["expansionScreen"]
	_model = ExpansionScreenModel.build(_state.call(), ExpansionData.game_data(), _ticks_per_second)
	visible = _model != null
	var key := ExpansionScreenModel.key(_model)
	if key != _key:
		_key = key
		if _model != null:
			_render(_model)
		else:
			hovered_option = -1
	if _model != null:
		_timer_fill.anchor_right = clampf(_model.time_left, 0.0, 1.0)
		_timer_text.text = String(texts["seconds"]).replace("{s}", str(_model.seconds))
