class_name WaveHud
extends Control
## HUD das ondas, sobre o jogo: "Onda 3/40" ou "Ondas 5–7 de 40", os inimigos restantes, o bônus
## antecipado pendente, o botão de chamar, a janela do bônus, a velocidade e a pausa, a faixa das
## próximas ondas e o aviso de pausa (porte de `waveHud.ts`). Atalhos (Espaço, Q, P) ficam no
## controle de teclas da cena.

signal call_pressed
signal speed_pressed
signal pause_pressed

var _panel: PanelContainer
var _label: Label
var _detail: Label
var _pending: Label
var _call: Button
var _window_box: VBoxContainer
var _window_text: Label
var _window_fill: ColorRect
var _window_bar: Control
var _upcoming_panel: PanelContainer
var _upcoming_row: HBoxContainer
var _speed: Button
var _pause: Button
var _banner: PanelContainer
var _controls: HBoxContainer
var _key := ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(self)
	_panel = UiKit.game_panel(12, Vector2(16, 8))
	var row := UiKit.hbox(14)
	_label = UiKit.label("", 22, UiKit.GOLD, true)
	_detail = UiKit.label("", 13, Color("#b4b8bc"))
	_detail.custom_minimum_size = Vector2(120, 0)
	_detail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pending = UiKit.label("", 13, UiKit.GREEN, true)
	_pending.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var call_group := UiKit.vbox(3)
	_call = UiKit.primary_button("Chamar onda (Espaço)", func() -> void: call_pressed.emit())
	call_group.add_child(_call)
	_window_box = UiKit.vbox(2)
	_window_text = UiKit.label("", 11, UiKit.GREEN)
	_window_bar = Control.new()
	_window_bar.custom_minimum_size = Vector2(0, 3)
	_window_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := ColorRect.new()
	back.color = Color("#2c3a26")
	UiKit.full_rect(back)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window_bar.add_child(back)
	_window_fill = ColorRect.new()
	_window_fill.color = UiKit.GREEN
	_window_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window_fill.anchor_bottom = 1.0
	_window_bar.add_child(_window_fill)
	_window_box.add_child(_window_text)
	_window_box.add_child(_window_bar)
	_window_box.visible = false
	call_group.add_child(_window_box)
	_speed = UiKit.button("1x (Q)", func() -> void: speed_pressed.emit())
	_speed.custom_minimum_size = Vector2(60, 0)
	_pause = UiKit.button("Pausar (P)", func() -> void: pause_pressed.emit())
	_controls = UiKit.hbox(6)
	_controls.add_child(_speed)
	_controls.add_child(_pause)
	row.add_child(_label)
	row.add_child(_detail)
	row.add_child(_pending)
	row.add_child(call_group)
	row.add_child(_controls)
	_panel.add_child(row)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 8)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_panel)

	_upcoming_panel = UiKit.panel(Color(0.075, 0.08, 0.1, 0.85), UiKit.FRAME.darkened(0.3), 8, Vector2(12, 3))
	_upcoming_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upcoming_row = UiKit.hbox(8)
	_upcoming_panel.add_child(_upcoming_row)
	_upcoming_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 8)
	_upcoming_panel.position.y = 84
	_upcoming_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_upcoming_panel)

	_banner = UiKit.panel(Color(0.0784, 0.0824, 0.0902, 0.85), Color("#c08a30"), 8, Vector2(24, 10))
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(UiKit.label("Pausado (P)", 28, Color("#ffd84a"), true))
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.visible = false
	add_child(_banner)


## Põe mais um controle no fim do HUD (o botão "?" da ajuda).
func append_control(control: Control) -> void:
	_controls.add_child(control)


## Chame a cada quadro: só refaz os nós quando algo mudou.
func update(state: Object, speed: float, paused: bool) -> void:
	var model := WaveHudModel.build(state, paused)
	var key := "%s|%s|%s" % [model.key(), speed, paused]
	if key == _key:
		return
	_key = key
	_label.text = model.label
	_detail.text = model.detail
	_pending.text = model.pending_bonus
	_pending.visible = model.pending_bonus != ""
	_call.text = model.call_label
	_call.disabled = not model.can_call
	_window_box.visible = not model.bonus_window.is_empty()
	if not model.bonus_window.is_empty():
		_window_text.text = model.bonus_window["text"]
		# A barra mostra o que ainda resta da janela.
		_window_fill.anchor_right = clampf(1.0 - float(model.bonus_window["spent"]), 0.0, 1.0)
	_render_upcoming(model.upcoming)
	_speed.text = "%sx (Q)" % TowerInfo.fmt(speed)
	_pause.text = "Continuar (P)" if paused else "Pausar (P)"
	_banner.visible = paused


func _render_upcoming(upcoming: Array) -> void:
	UiKit.clear(_upcoming_row)
	_upcoming_panel.visible = not upcoming.is_empty()
	if upcoming.is_empty():
		return
	var texts: Dictionary = DataLoader.load_json("ui.json")["waveHud"]["texts"]
	_upcoming_row.add_child(UiKit.label(texts["upcoming"], 12, Color("#8a8f94")))
	for item: Dictionary in upcoming:
		var color := Color("#dddddd")
		var text := str(item["wave"])
		if item["kind"] == "elite":
			color = Color("#c77dff")
			text += texts["eliteMark"]
		elif item["kind"] == "boss":
			color = Color("#ff5a4a")
			text += texts["bossMark"]
		_upcoming_row.add_child(UiKit.label(text, 12, color, true))
