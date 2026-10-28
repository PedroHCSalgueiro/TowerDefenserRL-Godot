extends SceneTree
## Captura da interface do jogo em PNG, para conferir o visual sem abrir o editor. Precisa de janela
## (não roda com --headless):
##   godot --path . --resolution 1280x720 -s dev/ui_preview.gd -- <pasta de saída>
## Gera `loja.png` (estado normal) e `loja_hover.png` (primeira carta com o mouse em cima).


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else "."
	Game.forced_seed = "preview"
	var game: Game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	for i in 3:
		await process_frame
	game.runner.sim.enqueue({"type": "debugAddGold", "amount": 25})
	await create_timer(1.0).timeout
	_save(out_dir.path_join("loja.png"))
	for card in _cards(game):
		if card.slot_index == 2:
			card.snap_hover(true)
	await create_timer(0.3).timeout
	_save(out_dir.path_join("loja_hover.png"))
	game.shop_panel.visible = false
	_show_rarities()
	await create_timer(0.5).timeout
	_save(out_dir.path_join("raridades.png"))
	quit()


## Loja de mentira, no lugar da do jogo, com uma carta de cada tipo: as quatro raridades, fusão (★),
## limite do mapa, sem ouro, nome longo e slot já comprado.
func _show_rarities() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	root.add_child(layer)
	var panel := ShopPanel.new()
	layer.add_child(panel)
	var model := ShopModel.new()
	model.gold = 35
	model.interest = 3
	model.next_wave = 1
	model.reroll_cost = 4
	model.can_reroll = true
	model.slots.append(_slot(0, "Morteiro", "common", "Comum", ["Artilharia", "Mecânica"], 10))
	model.slots.append(_slot(1, "Irmão Tomás", "uncommon", "Incomum", ["Suporte", "Reino de Valcoroa"], 18))
	model.slots.append(_slot(2, "Ruby, Duas-Pistolas", "rare", "Rara", ["Atirador", "Costa Rubra"], 30, 2))
	model.slots.append(_slot(3, "Nerea, Domadora Abissal", "legendary", "Lendária", ["Invocador", "Costa Rubra"], 55, 0, false, true))
	model.slots.append(_slot(4, "Rainha Isolde", "legendary", "Lendária", ["Controle", "Reino de Valcoroa"], 55, 0, false))
	model.slots.append(ShopModel.SlotModel.new())
	model.slots[5].index = 5
	panel.render(model, 2)


func _slot(index: int, slot_name: String, rarity: String, label: String, classes: Array[String], price: int,
		fuse: int = 0, affordable: bool = true, blocked: bool = false) -> ShopModel.SlotModel:
	var slot := ShopModel.SlotModel.new()
	slot.index = index
	slot.tower_type = slot_name.to_lower()
	slot.name = slot_name
	slot.rarity = rarity
	slot.rarity_label = label
	slot.classes = classes
	slot.price = price
	slot.fuse_star = fuse
	slot.affordable = affordable
	slot.blocked_by_limit = blocked
	return slot


func _cards(node: Node) -> Array[ShopCard]:
	var found: Array[ShopCard] = []
	if node is ShopCard:
		found.append(node)
	for child in node.get_children():
		found.append_array(_cards(child))
	return found


func _save(path: String) -> void:
	var err := root.get_texture().get_image().save_png(path)
	print("[preview] %s -> %s" % [path, "ok" if err == OK else "erro %d" % err])
