class_name OptionsPanel
extends VBoxContainer
## Lista de opções (`GameSettings`): tela cheia, números de dano e velocidade no começo da run. A mesma lista
## aparece no menu inicial e no menu de pausa; cada mudança grava na hora. "Voltar" emite `closed`.

signal closed
## A opção dos números de dano mudou (com a run aberta, o jogo liga ou desliga na hora).
signal damage_numbers_changed(on: bool)

var fullscreen_box: CheckButton
var numbers_box: CheckButton
var speed_button: OptionButton


func _init() -> void:
	var texts: Dictionary = DataLoader.load_json("ui.json")["options"]
	add_theme_constant_override("separation", 10)
	var title := UiKit.label(texts["title"], 24, UiKit.TEXT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	fullscreen_box = _check(texts["fullscreen"], GameSettings.fullscreen())
	fullscreen_box.toggled.connect(func(on: bool) -> void: GameSettings.set_fullscreen(on))
	# no navegador a tela cheia é do próprio navegador
	fullscreen_box.visible = not OS.has_feature("web")

	numbers_box = _check(texts["damageNumbers"], GameSettings.damage_numbers())
	numbers_box.toggled.connect(func(on: bool) -> void:
		GameSettings.set_damage_numbers(on)
		damage_numbers_changed.emit(on))

	var row := UiKit.hbox(10)
	row.add_child(UiKit.label(texts["startSpeed"], 15, UiKit.TEXT))
	speed_button = OptionButton.new()
	speed_button.add_theme_font_size_override("font_size", 15)
	var speeds: Array = EngineData.config()["speeds"]
	for s: Variant in speeds:
		speed_button.add_item("%dx" % int(s))
		if is_equal_approx(float(s), GameSettings.start_speed()):
			speed_button.select(speed_button.item_count - 1)
	speed_button.item_selected.connect(func(i: int) -> void: GameSettings.set_start_speed(float(speeds[i])))
	row.add_child(speed_button)
	add_child(row)

	var back := UiKit.button(texts["back"], func() -> void: closed.emit())
	back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(back)


## Interruptor (a caixinha de marcar do tema padrão quase some no painel escuro).
func _check(text: String, on: bool) -> CheckButton:
	var box := CheckButton.new()
	box.text = text
	box.button_pressed = on
	box.add_theme_font_size_override("font_size", 15)
	add_child(box)
	return box
