class_name ShopModel
extends RefCounted
## Modelo da loja e do ouro: transforma o estado da run em dados prontos para mostrar (porte de
## `shopModel.ts`). Sem nós, para testar direto.

class SlotModel:
	extends RefCounted
	var index: int
	## "" = slot comprado (vazio).
	var tower_type := ""
	var name := ""
	## Frase simples da torre (T23); vazio no slot comprado.
	var summary := ""
	var classes: Array[String] = []
	var rarity := ""
	var rarity_label := ""
	var price := 0
	## Tem ouro para comprar (slot vazio nunca tem).
	var affordable := false
	## Estrela que a compra daria ao fundir com uma torre do mapa (0 = não funde).
	var fuse_star := 0
	## A compra precisaria de casa nova e o mapa está no limite do núcleo (aviso "limite").
	var blocked_by_limit := false

	func is_empty() -> bool:
		return tower_type == ""

	## Etiqueta de raridade da carta: a comum é cinza e não leva texto ("").
	func rarity_tag() -> String:
		return "" if rarity == "common" else rarity_label

	## Primeira letra do nome (medalhão da carta sem retrato).
	func initial() -> String:
		return name.substr(0, 1).to_upper()

var gold := 0
## Juros que entram no fim da próxima onda, com o ouro de agora.
var interest := 0
## Número da próxima onda a fechar.
var next_wave := 1
## Custo do próximo reroll (0 = grátis, bônus das recompensas).
var reroll_cost := 0
var can_reroll := false
var slots: Array[SlotModel] = []
## Torre da casa selecionada, se houver: {"towerId": int, "name": String, "refund": int} ou {}.
var sell: Dictionary = {}


static func build(state: Object, selected: Variant, economy: EconomyData, towers: TowerData,
		classes: ClassData, nexus: NexusData = null) -> ShopModel:
	var room := TowerLimit.has_room_for_tower(state, nexus)
	var model := ShopModel.new()
	for index in state.shop.slots.size():
		var tower_type: Variant = state.shop.slots[index]
		var slot := SlotModel.new()
		slot.index = index
		if tower_type != null:
			var type := towers.get_type(tower_type)
			var price := Shop.shop_price(economy, towers, state, tower_type)
			slot.tower_type = tower_type
			slot.name = type.name
			slot.summary = TowerInfo.tower_summary(tower_type)
			for id in type.classes:
				slot.classes.append(classes.classes[id].name if classes.classes.has(id) else id)
			slot.rarity = type.rarity if type.rarity != null else ""
			slot.rarity_label = TowerInfo.RARITY_LABELS[type.rarity] if type.rarity != null else ""
			slot.price = maxi(price, 0)
			slot.affordable = state.gold >= slot.price
			slot.fuse_star = Fusion.fusion_star(state.towers, towers, tower_type)
			slot.blocked_by_limit = slot.fuse_star == 0 and not room
		model.slots.append(slot)
	var tower: Tower = null
	if selected != null:
		for t: Tower in state.towers:
			if t.x == selected.x and t.y == selected.y:
				tower = t
				break
	model.gold = state.gold
	model.interest = Economy.interest_for(economy, state.gold, Economy.interest_cap_for(economy, state))
	# Depois da última onda, o rótulo fica na última.
	model.next_wave = mini(state.wave + 1, WaveData.game_data().waves.size())
	model.reroll_cost = Shop.shop_reroll_cost(economy, state)
	model.can_reroll = state.gold >= model.reroll_cost
	if tower != null:
		model.sell = {
			"towerId": tower.id,
			"name": towers.types[tower.type].name if towers.types.has(tower.type) else tower.type,
			"refund": Shop.refund_for(tower.invested, Shop.sell_refund_percent(economy, state)),
		}
	return model


## Assinatura do modelo: a interface só mexe nos nós quando ela muda.
func key(carry_slot: int) -> String:
	var parts: Array[String] = []
	for s in slots:
		parts.append("%s:%d:%d:%d:%d" % [s.tower_type if s.tower_type != "" else "-", s.price,
				1 if s.affordable else 0, s.fuse_star, 1 if s.blocked_by_limit else 0])
	var sell_key := "%d:%d" % [sell["towerId"], sell["refund"]] if not sell.is_empty() else "-"
	return "|".join([str(gold), str(interest), str(next_wave), str(reroll_cost), "1" if can_reroll else "0",
			",".join(parts), sell_key, str(carry_slot) if carry_slot >= 0 else "-"])


## Dá para posicionar uma torre nesta casa (dentro do mapa, fora do caminho e sem torre)?
static func can_place_at(state: Object, map: SimMap, cell: Vector2i) -> bool:
	if not map.can_place_tower(cell):
		return false
	for t: Tower in state.towers:
		if t.x == cell.x and t.y == cell.y:
			return false
	return true
