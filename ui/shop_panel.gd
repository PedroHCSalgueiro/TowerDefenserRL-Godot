class_name ShopPanel
extends PanelContainer
## Barra da loja, sobre o jogo: ouro, juros previstos, os 5 slots (nome, classes, raridade e preço;
## esmaecido sem ouro), rerolar e vender (porte de `shopPanel.ts`). Ancorada embaixo no centro.

signal slot_pressed(slot: int, global_pos: Vector2)
signal reroll_pressed
signal sell_pressed

const RARITY_COLORS := {"common": "#8a8f94", "uncommon": "#4fa86a", "rare": "#b06adf"}

var hovered_slot := -1
var _row: HBoxContainer


func _init() -> void:
	add_theme_stylebox_override("panel", UiKit.style(UiKit.BG, UiKit.BORDER, 8, 1, Vector2(10, 8)))
	_row = UiKit.hbox(10)
	add_child(_row)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 8)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN


func render(model: ShopModel, carry_slot: int) -> void:
	UiKit.clear(_row)
	var texts: Dictionary = DataLoader.load_json("ui.json")["shop"]
	var status := UiKit.vbox(2)
	status.custom_minimum_size = Vector2(130, 0)
	status.alignment = BoxContainer.ALIGNMENT_CENTER
	status.add_child(UiKit.label("Ouro %d" % model.gold, 20, UiKit.GOLD, true))
	status.add_child(UiKit.label("Juros previstos +%d" % model.interest, 13, Color("#9fd6a0")))
	status.add_child(UiKit.label("Fim da onda %d" % model.next_wave, 12, UiKit.MUTED))
	_row.add_child(status)

	var slots := UiKit.hbox(6)
	for slot in model.slots:
		slots.add_child(_render_slot(slot, carry_slot == slot.index))
	_row.add_child(slots)

	var actions := UiKit.vbox(6)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	var reroll_text: String = texts["freeRerollLabel"] if model.reroll_cost == 0 \
			else String(texts["rerollLabel"]).replace("{cost}", str(model.reroll_cost))
	var reroll := UiKit.button(reroll_text, func() -> void: reroll_pressed.emit())
	reroll.disabled = not model.can_reroll
	var sell_text := "Vender %s (S) +%d" % [model.sell["name"], model.sell["refund"]] if not model.sell.is_empty() else "Vender (S)"
	var sell := UiKit.button(sell_text, func() -> void: sell_pressed.emit())
	sell.disabled = model.sell.is_empty()
	actions.add_child(reroll)
	actions.add_child(sell)
	_row.add_child(actions)
	# Os slots foram refeitos: o slot sob o mouse continua valendo.
	hovered_slot = -1
	for node in slots.get_children():
		if node is Control and (node as Control).get_global_rect().has_point(get_global_mouse_position()):
			hovered_slot = int(node.get_meta("slot"))


func _render_slot(slot: ShopModel.SlotModel, carried: bool) -> PanelContainer:
	var empty := slot.is_empty()
	var border := Color("#4a4d50")
	if not empty:
		border = Color(RARITY_COLORS.get(slot.rarity, "#8a8f94"))
	var bg := Color("#26282b")
	var border_width := 2
	if carried:
		bg = Color("#3a3520")
		border = Color("#ffd75e")
	elif not empty and slot.fuse_star > 0:
		border = border.lerp(Color("#ffd75e"), 0.5)
	var node := PanelContainer.new()
	node.custom_minimum_size = Vector2(150, 0)
	node.add_theme_stylebox_override("panel", UiKit.style(bg, border, 6, border_width, Vector2(8, 6)))
	node.set_meta("slot", slot.index)
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	if empty:
		node.modulate.a = 0.35
	elif not slot.affordable or slot.blocked_by_limit:
		node.modulate.a = 0.5
	var box := UiKit.vbox(1)
	var head := UiKit.hbox(4)
	var name_label := UiKit.label("Comprada" if empty else slot.name, 14, UiKit.TEXT, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	head.add_child(UiKit.label(str(slot.index + 1), 11, Color("#8a8a8a")))
	box.add_child(head)
	if not empty:
		var summary := UiKit.label(slot.summary, 11, Color("#c8c8c8"))
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.custom_minimum_size = Vector2(134, 42)
		summary.max_lines_visible = 3
		summary.clip_text = true
		box.add_child(summary)
		box.add_child(UiKit.label(" · ".join(slot.classes), 11, Color("#9fb3c8")))
		var foot := UiKit.hbox(4)
		foot.add_child(UiKit.label(slot.rarity_label, 11, Color("#aaaaaa")))
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		foot.add_child(spacer)
		if slot.fuse_star > 0:
			foot.add_child(UiKit.label("★%d↑" % slot.fuse_star, 12, UiKit.GOLD, true))
		elif slot.blocked_by_limit:
			foot.add_child(UiKit.label(DataLoader.load_json("ui.json")["texts"]["limitWarning"], 12, Color("#ff7a6b"), true))
		box.add_child(foot)
		box.add_child(UiKit.label("● %d" % slot.price, 14, UiKit.GOLD, true))
	node.add_child(box)
	node.mouse_entered.connect(func() -> void: hovered_slot = slot.index)
	node.mouse_exited.connect(func() -> void:
		if hovered_slot == slot.index:
			hovered_slot = -1)
	if not empty:
		node.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				slot_pressed.emit(slot.index, (event as InputEventMouseButton).global_position))
	return node
