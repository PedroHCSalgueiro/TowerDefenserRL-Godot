class_name RewardScreenUi
extends Control
## Tela de recompensa (T24): três cartas no centro, a barra do tempo para escolher e o botão de
## reroll das cartas. Clique ou teclas 1, 2 e 3 escolhem; R (ou o botão) rerola. Tudo vira comando
## da simulação, que é quem pausa o jogo enquanto a tela está aberta. Com a pausa do relógio (P ou a
## ajuda), a tela não aceita nada (porte de `rewardScreen.ts`).

var _state: Callable      # () -> RunState
var _enqueue: Callable    # (command: Dictionary)
var _paused: Callable     # () -> bool
var _ticks_per_second: float
var _panel_box: VBoxContainer
var _timer_fill: ColorRect
var _timer_text: Label
var _model: RewardScreenModel = null
var _key := ""


func setup(state: Callable, enqueue: Callable, paused: Callable, ticks_per_second: float) -> void:
	_state = state
	_enqueue = enqueue
	_paused = paused
	_ticks_per_second = ticks_per_second
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.04, 0.05, 0.72)
	UiKit.full_rect(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	UiKit.full_rect(center)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var box := UiKit.vbox(10)
	box.custom_minimum_size = Vector2(760, 0)
	center.add_child(box)
	_panel_box = UiKit.vbox(10)
	box.add_child(_panel_box)
	var timer_back := ColorRect.new()
	timer_back.color = Color("#2a2c2f")
	timer_back.custom_minimum_size = Vector2(0, 8)
	timer_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_fill = ColorRect.new()
	_timer_fill.color = Color("#e0b84a")
	_timer_fill.anchor_bottom = 1.0
	_timer_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_back.add_child(_timer_fill)
	box.add_child(timer_back)
	_timer_text = UiKit.label("", 14, UiKit.MUTED)
	_timer_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_timer_text)


## A tela está aberta (a simulação está congelada).
func is_open() -> bool:
	return _model != null


func handle_key(event: InputEventKey) -> bool:
	if _model == null:
		return false
	var texts: Dictionary = DataLoader.load_json("ui.json")["rewardScreen"]
	if event.keycode >= KEY_1 and event.keycode <= KEY_9:
		var card := event.keycode - KEY_1
		if card < _model.cards.size():
			_choose(card)
			return true
	elif OS.get_keycode_string(event.keycode).to_lower() == texts["rerollKey"]:
		_reroll()
		return true
	return false


func _choose(index: int) -> void:
	if not _paused.call():
		_enqueue.call({"type": "chooseReward", "index": index})


func _reroll() -> void:
	if not _paused.call() and _model != null and _model.can_reroll:
		_enqueue.call({"type": "rerollRewards"})


func _render(model: RewardScreenModel) -> void:
	var texts: Dictionary = DataLoader.load_json("ui.json")["rewardScreen"]
	UiKit.clear(_panel_box)
	var header := UiKit.hbox(12)
	header.add_child(UiKit.label(model.title, 26, UiKit.TEXT, true))
	if model.queued != "":
		header.add_child(UiKit.label(model.queued, 14, UiKit.MUTED))
	_panel_box.add_child(header)
	var subtitle := UiKit.label(texts["subtitle"], 14, UiKit.MUTED)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_box.add_child(subtitle)
	var cards := UiKit.hbox(14)
	for card in model.cards:
		cards.add_child(_render_card(card, texts))
	_panel_box.add_child(cards)
	var reroll := UiKit.button(RewardScreenModel.fill_text(texts["rerollLabel"], {"cost": model.reroll_cost}), _reroll)
	reroll.disabled = not model.can_reroll
	_panel_box.add_child(reroll)


func _render_card(card: RewardScreenModel.Card, texts: Dictionary) -> Control:
	var color := Color(card.color)
	var node := PanelContainer.new()
	node.custom_minimum_size = Vector2(228, 228)
	node.add_theme_stylebox_override("panel", UiKit.style(Color("#1d1f21"), color, 10, 3, Vector2(14, 12)))
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var box := UiKit.vbox(6)
	var top := UiKit.hbox(4)
	var category := UiKit.label(card.category, 12, color, true)
	category.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(category)
	top.add_child(UiKit.label(card.key, 16, UiKit.MUTED, true))
	box.add_child(top)
	var name_label := UiKit.label(card.name, 18, UiKit.TEXT, true)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(196, 0)
	box.add_child(name_label)
	var text := UiKit.label(card.text, 13, Color("#c8c8c8"))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(196, 0)
	box.add_child(text)
	if card.repeatable:
		box.add_child(UiKit.label(texts["repeatable"], 11, UiKit.MUTED))
	node.add_child(box)
	var index := card.index
	node.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_choose(index))
	return node


## Chame a cada quadro: cartas só quando mudam; a barra do tempo sempre.
func update_screen() -> void:
	var texts: Dictionary = DataLoader.load_json("ui.json")["rewardScreen"]
	_model = RewardScreenModel.build(_state.call(), RewardData.game_data(), ClassData.game_data(), _ticks_per_second)
	visible = _model != null
	var key := RewardScreenModel.key(_model)
	if key != _key:
		_key = key
		if _model != null:
			_render(_model)
	if _model != null:
		_timer_fill.anchor_right = clampf(_model.time_left, 0.0, 1.0)
		_timer_text.text = RewardScreenModel.fill_text(texts["seconds"], {"s": _model.seconds})
