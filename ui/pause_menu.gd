class_name PauseMenu
extends Control
## Menu de pausa: Esc (sem torre na mão) ou o botão "Menu" do HUD abrem por cima do jogo. Abrir pausa; fechar volta
## como estava, como na ajuda. Continuar, Reiniciar run, Ajuda, Opções, Voltar ao menu inicial e Sair do jogo
## (que não aparece no navegador). Reiniciar, voltar e sair perguntam antes, porque a run se perde (ainda não há
## save em disco). Embaixo, o conjunto e a semente da run. Textos em `pauseMenu` (ui.json).

signal restart_pressed
signal menu_pressed
signal help_pressed
signal damage_numbers_changed(on: bool)

## O botão do HUD ("Menu").
var toggle_button: Button
var _paused: Callable      # () -> bool
var _set_paused: Callable  # (bool)
var _paused_before := false
var _texts: Dictionary
var _run_info := ""
## O que o painel mostra: "list" (os botões), "confirm" ou "options".
var page := ""
var _box: VBoxContainer


func setup(paused: Callable, set_paused: Callable, run_info: String) -> void:
	_paused = paused
	_set_paused = set_paused
	_run_info = run_info
	_texts = DataLoader.load_json("ui.json")["pauseMenu"]
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.04, 0.05, 0.72)
	UiKit.full_rect(dim)
	add_child(dim)
	var center := CenterContainer.new()
	UiKit.full_rect(center)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := UiKit.panel(Color("#1d1f21"), Color("#55595e"), 8, Vector2(36, 26))
	center.add_child(panel)
	_box = UiKit.vbox(8)
	_box.custom_minimum_size = Vector2(300, 0)
	panel.add_child(_box)
	toggle_button = UiKit.button(_texts["buttonLabel"], func() -> void:
		if is_open():
			close()
		else:
			open())
	toggle_button.tooltip_text = _texts["buttonTooltip"]


func is_open() -> bool:
	return visible


func open() -> void:
	if is_open():
		return
	show_list()
	_paused_before = _paused.call()
	_set_paused.call(true)
	visible = true


func close() -> void:
	if not is_open():
		return
	visible = false
	_set_paused.call(_paused_before)


## Os botões do menu.
func show_list() -> void:
	_page("list")
	var title := UiKit.label(_texts["title"], 26, UiKit.TEXT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	_add_button(_texts["resume"], close, true)
	_add_button(_texts["restart"], func() -> void: _confirm(restart_pressed.emit))
	_add_button(_texts["help"], func() -> void:
		close()
		help_pressed.emit())
	_add_button(_texts["options"], _show_options)
	_add_button(_texts["toMenu"], func() -> void: _confirm(menu_pressed.emit))
	if not OS.has_feature("web"):
		_add_button(_texts["quit"], func() -> void: _confirm(func() -> void: get_tree().quit()))
	_add_note(_run_info)
	_add_note(_texts["escHint"])


## Pergunta antes de perder a run: "Sim" faz `action`, "Não" volta aos botões.
func _confirm(action: Callable) -> void:
	_page("confirm")
	var question := UiKit.label(_texts["confirm"], 16, UiKit.TEXT, true)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(question)
	var row := UiKit.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var yes := UiKit.button(_texts["confirmYes"], action)
	yes.custom_minimum_size = Vector2(110, 36)
	yes.alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(yes)
	var no := UiKit.button(_texts["confirmNo"], show_list)
	no.custom_minimum_size = Vector2(110, 36)
	no.alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(no)
	_box.add_child(row)


func _show_options() -> void:
	_page("options")
	var options := OptionsPanel.new()
	options.closed.connect(show_list)
	options.damage_numbers_changed.connect(func(on: bool) -> void: damage_numbers_changed.emit(on))
	_box.add_child(options)


func _page(which: String) -> void:
	page = which
	UiKit.clear(_box)


func _add_button(text: String, on_pressed: Callable, primary: bool = false) -> void:
	var b := UiKit.primary_button(text, on_pressed) if primary else UiKit.button(text, on_pressed)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(300, 38)
	b.add_theme_font_size_override("font_size", 16)
	_box.add_child(b)


func _add_note(text: String) -> void:
	var note := UiKit.label(text, 12, UiKit.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(note)


## Tecla do jogo. Com o menu aberto, consome tudo: Esc volta da pergunta ou das opções para os botões, ou fecha.
func handle_key(event: InputEventKey) -> bool:
	if not is_open():
		return false
	if event.keycode == KEY_ESCAPE:
		if page == "list":
			close()
		else:
			show_list()
	return true
