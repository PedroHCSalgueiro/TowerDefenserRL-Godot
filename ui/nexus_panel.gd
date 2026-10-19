class_name NexusPanel
extends PanelContainer
## Painel do núcleo, sobre o jogo: nível, vida, "Torres 3/4", chances de raridade atuais e do
## próximo nível e o botão "Evoluir (custo)". O núcleo não tem teto (T22): o botão sempre mostra o
## custo do próximo nível. A tecla E é tratada pelo controle da loja (porte de `nexusPanel.ts`).

signal evolve_pressed

var _box: VBoxContainer
var _key := ""


func _init() -> void:
	add_theme_stylebox_override("panel", UiKit.style(UiKit.BG, UiKit.BORDER, 8, 1, Vector2(10, 8)))
	custom_minimum_size = Vector2(190, 0)
	_box = UiKit.vbox(2)
	add_child(_box)


static func _chances_text(chances: Dictionary) -> String:
	var parts: Array[String] = []
	for r: String in EconomyData.RARITIES:
		parts.append("%s %d%%" % [TowerInfo.RARITY_LABELS[r], chances[r]])
	return " · ".join(parts)


## Chame a cada quadro: só refaz os nós quando algo mudou.
func update(state: Object) -> void:
	var model := NexusPanelModel.build(state, EconomyData.game_data())
	var key := model.key()
	if key == _key:
		return
	_key = key
	_render(model)


func _render(model: NexusPanelModel) -> void:
	UiKit.clear(_box)
	_box.add_child(UiKit.label("Núcleo nível %d" % model.level, 14, UiKit.TEXT, true))
	_box.add_child(UiKit.label("Vida %d/%d" % [model.hp, model.max_hp], 13))
	var full := model.towers >= model.tower_limit
	var towers_text := "Torres %d/%d" % [model.towers, model.tower_limit]
	if model.next_tower_limit >= 0:
		towers_text += " (próx. %d)" % model.next_tower_limit
	_box.add_child(UiKit.label(towers_text, 13, Color("#ff7a6b") if full else UiKit.TEXT, full))
	var chances := UiKit.label("Loja agora: " + _chances_text(model.chances), 12)
	chances.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chances.custom_minimum_size = Vector2(170, 0)
	_box.add_child(chances)
	if not model.next_chances.is_empty():
		var next := UiKit.label("Próximo: " + _chances_text(model.next_chances), 12, Color("#a8c8ff"))
		next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		next.custom_minimum_size = Vector2(170, 0)
		_box.add_child(next)
	var button := UiKit.button("Evoluir (E)" if model.cost < 0 else "Evoluir (E) −%d" % model.cost, func() -> void: evolve_pressed.emit())
	button.disabled = not model.can_evolve
	_box.add_child(button)
