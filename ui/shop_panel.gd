class_name ShopPanel
extends Control
## Loja como uma mão de cartas na parte de baixo da tela (porte de `shopPanel.ts`, com outro visual):
## as cartas (`ShopCard`) ficam em leque, inclinadas e com o pé abaixo da borda da tela; a carta sob o
## mouse sobe e endireita. À esquerda, o ouro e os juros previstos; à direita, rerolar e vender.
## A descrição de cada torre aparece na janela de informações ao passar o mouse.

signal slot_pressed(slot: int, global_pos: Vector2)
signal reroll_pressed
signal sell_pressed

## Altura da faixa da loja (de baixo da tela para cima).
const PANEL_HEIGHT := 230.0
## Raio do leque: quanto maior, mais reta a mão.
const FAN_RADIUS := 1100.0
## Distância entre os pés de duas cartas vizinhas.
const CARD_SPACING := 104.0
## Quanto do pé da carta do meio fica abaixo da borda da tela (negativo = acima): as das pontas
## descem com o arco e ficam um pouco cortadas.
const FOOT_BELOW := -6.0

var hovered_slot := -1
var _hand: Control
var _left: VBoxContainer
var _right: VBoxContainer
var _cards: Array[ShopCard] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_right = 0.0
	offset_top = -PANEL_HEIGHT
	offset_bottom = 0.0
	_hand = Control.new()
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(_hand)
	add_child(_hand)
	_left = UiKit.vbox(6)
	add_child(_left)
	_left.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 18)
	_left.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_right = UiKit.vbox(8)
	add_child(_right)
	_right.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 18)
	_right.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	resized.connect(_layout)


func render(model: ShopModel, carry_slot: int) -> void:
	var texts: Dictionary = DataLoader.load_json("ui.json")["shop"]
	UiKit.clear(_left)
	_left.add_child(_gold(model))

	UiKit.clear(_right)
	var reroll_text: String = texts["freeRerollLabel"] if model.reroll_cost == 0 \
			else String(texts["rerollLabel"]).replace("{cost}", str(model.reroll_cost))
	var reroll := UiKit.accent_button(reroll_text, func() -> void: reroll_pressed.emit())
	reroll.disabled = not model.can_reroll
	var sell_text := "Vender %s (S) +%d" % [model.sell["name"], model.sell["refund"]] if not model.sell.is_empty() else "Vender (S)"
	var sell := UiKit.button(sell_text, func() -> void: sell_pressed.emit())
	sell.alignment = HORIZONTAL_ALIGNMENT_CENTER
	sell.disabled = model.sell.is_empty()
	_right.add_child(sell)
	_right.add_child(reroll)

	UiKit.clear(_hand)
	_cards.clear()
	for slot in model.slots:
		var card := _render_slot(slot, carry_slot == slot.index)
		_hand.add_child(card)
		_cards.append(card)
	_layout()
	# As cartas foram refeitas: a carta sob o mouse continua valendo (a de cima ganha).
	hovered_slot = -1
	for i in range(_cards.size() - 1, -1, -1):
		var card := _cards[i]
		if Rect2(Vector2.ZERO, card.size).has_point(card.get_local_mouse_position()):
			hovered_slot = card.slot_index
			card.snap_hover(not model.slots[card.slot_index].is_empty())
			break


## Põe as cartas em leque: cada uma gira em torno do próprio pé, que fica num arco abaixo da tela.
func _layout() -> void:
	var count := _cards.size()
	var step := CARD_SPACING / FAN_RADIUS
	for i in count:
		var card := _cards[i]
		var angle := (float(i) - float(count - 1) * 0.5) * step
		var foot := Vector2(size.x * 0.5 + FAN_RADIUS * sin(angle),
				size.y + FOOT_BELOW + FAN_RADIUS * (1.0 - cos(angle)))
		card.position = foot - card.pivot_offset
		card.rest_rotation = angle
		card.hover = card.hover


## Ouro: moeda grande com o valor, juros previstos e a onda em que a loja fecha.
func _gold(model: ShopModel) -> Control:
	var panel := UiKit.game_panel(14, Vector2(14, 8))
	var box := UiKit.vbox(2)
	var row := UiKit.hbox(8)
	var coin := CoinIcon.new(38.0)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	row.add_child(UiKit.label(str(model.gold), 32, UiKit.GOLD, true))
	box.add_child(row)
	box.add_child(UiKit.label("+%d de juros" % model.interest, 13, Color("#9fd6a0"), true))
	box.add_child(UiKit.label("Fim da onda %d" % model.next_wave, 12, UiKit.MUTED))
	panel.add_child(box)
	return panel


func _render_slot(slot: ShopModel.SlotModel, carried: bool) -> ShopCard:
	var card := ShopCard.new()
	card.setup(slot, carried)
	card.set_meta("slot", slot.index)
	card.mouse_entered.connect(func() -> void:
		hovered_slot = slot.index
		# Só uma carta levantada por vez.
		for other in _cards:
			if other != card:
				other.lower())
	card.mouse_exited.connect(func() -> void:
		if hovered_slot == slot.index:
			hovered_slot = -1)
	card.pressed.connect(func(pos: Vector2) -> void: slot_pressed.emit(slot.index, pos))
	return card
