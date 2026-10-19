class_name TutorialCard
extends PanelContainer
## Cartão do mini tutorial (T23), sobre o jogo. Não pausa o jogo: só mostra o cartão que o
## `TutorialModel` mandar, com "Ok" nos que fecham com clique e "Avançar" e "Pular tutorial" em
## todos (porte de `tutorial.ts`).

var model: TutorialModel
var _text: Label
var _ok: Button
var _shown_id := ""


func _init(mark_path: String = "user://tutorial_done.mark") -> void:
	model = TutorialModel.new(mark_path)
	var cfg: Dictionary = DataLoader.load_json("ui.json")["tutorial"]
	add_theme_stylebox_override("panel", UiKit.style(Color(0.1176, 0.102, 0.0706, 0.94), Color("#c08a30"), 8, 1, Vector2(14, 10)))
	custom_minimum_size = Vector2(320, 0)
	var box := UiKit.vbox(8)
	_text = UiKit.label("", 14, Color("#f0e6b8"))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(290, 0)
	box.add_child(_text)
	var buttons := UiKit.hbox(6)
	_ok = UiKit.button(cfg["closeLabel"], func() -> void: model.close())
	buttons.add_child(_ok)
	buttons.add_child(UiKit.button(cfg["advanceLabel"], func() -> void: model.advance()))
	buttons.add_child(UiKit.button(cfg["skipLabel"], func() -> void: model.skip()))
	box.add_child(buttons)
	add_child(box)
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	position.y -= 150
	visible = false


## Chame a cada quadro (`now_ms`: relógio em ms).
func update_card(state: Object, now_ms: float) -> void:
	var card := model.update(state, now_ms)
	visible = not card.is_empty()
	if card.is_empty() or card["id"] == _shown_id:
		return
	_shown_id = card["id"]
	_text.text = card["text"]
	_ok.visible = card["closable"]
	reset_size()
