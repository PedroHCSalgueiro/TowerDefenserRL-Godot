class_name Shop
extends RefCounted
## Loja: 5 slots (6 com o bônus da Costa Rubra) sorteados com reposição pelo RNG da simulação, compra, reroll e venda. Só
## torres com raridade entram (Básica e Canhão ficam de fora). Slot comprado fica null até o
## próximo reroll ou loja nova (porte de `shop.ts`).

## Estado da loja (vai no RunState).
class ShopState:
	extends RefCounted
	## Id da torre em cada slot; null = comprado.
	var slots: Array = []
	## Rerolls grátis que ainda restam nesta loja (bônus "Reroll grátis", T24).
	var free_rerolls := 0


## Ids das torres de loja de cada raridade, na ordem dos dados: {"common": [...], ...}.
static func shop_pools(towers: TowerData) -> Dictionary:
	var pools := {"common": [], "uncommon": [], "rare": [], "legendary": []}
	for id: String in towers.types:
		var rarity: Variant = towers.types[id].rarity
		if rarity != null:
			pools[rarity].append(id)
	return pools


## Chances (em %) do nível do núcleo, preso ao último da tabela: {"common": int, ...}.
static func chances_for(economy: EconomyData, nexus_level: int) -> Dictionary:
	var table := economy.shop_rarity_chances
	return table[mini(maxi(1, nexus_level), table.size()) - 1]


## Chances da loja agora (rarity -> %). Modo "nexusLevel": a linha do nível do núcleo (com a carta "Loja melhor").
## Modo "wave": a faixa da onda que vai ser jogada (`state.wave + 1`), deslocada pela carta "Loja melhor".
static func chances_for_state(economy: EconomyData, state: Object) -> Dictionary:
	if economy.rarity_mode != "wave":
		return chances_for(economy, shop_rarity_level(state))
	var rows := economy.rarity_by_wave
	return rows[_wave_row(economy, state)]["chances"]


## Chances da primeira loja da run (onda 1, núcleo no nível inicial).
static func initial_chances(economy: EconomyData) -> Dictionary:
	if economy.rarity_mode != "wave":
		return chances_for(economy, economy.nexus_start_level)
	return economy.rarity_by_wave[0]["chances"]


## Modo "wave": índice da faixa em uso (a da onda atual, deslocada pelas cartas, presa na última).
static func _wave_row(economy: EconomyData, state: Object) -> int:
	var rows := economy.rarity_by_wave
	var index := 0
	for i in rows.size():
		if state.wave + 1 >= int(rows[i]["fromWave"]):
			index = i
	return mini(rows.size() - 1, index + RewardMods.of(state).shop_rarity_levels)


## A próxima faixa da loja: {"fromWave": int, "chances": Dictionary} (modo "wave"), ou {} no último
## ou no modo "nexusLevel". Serve ao painel ("Incomum a partir da onda 9").
static func next_rarity_row(economy: EconomyData, state: Object) -> Dictionary:
	if economy.rarity_mode != "wave":
		return {}
	var next := _wave_row(economy, state) + 1
	if next >= economy.rarity_by_wave.size():
		return {}
	return economy.rarity_by_wave[next]


## A carta "Loja melhor" ainda tem o que melhorar? (Senão ela nem é oferecida.)
static func can_improve_rarity(economy: EconomyData, state: Object) -> bool:
	if economy.rarity_mode == "wave":
		return _wave_row(economy, state) < economy.rarity_by_wave.size() - 1
	return state.nexus.level < economy.shop_rarity_chances.size()


## Preço da torre (-1 = não é de loja). Com desconto (bônus "Desconto", T24), o preço é
## arredondado para o inteiro mais próximo (,5 para cima).
static func price_of(economy: EconomyData, towers: TowerData, tower_type: String, discount_percent: float = 0.0) -> int:
	if not towers.has_type(tower_type):
		return -1
	var rarity: Variant = towers.get_type(tower_type).rarity
	if rarity == null:
		return -1
	var price: int = economy.shop_prices[rarity]
	if discount_percent > 0.0:
		return SimMath.js_round((float(price) * (100.0 - discount_percent)) / 100.0)
	return price


## Preço da torre na run, com o desconto das recompensas (-1 = não é de loja).
static func shop_price(economy: EconomyData, towers: TowerData, state: Object, tower_type: String) -> int:
	return price_of(economy, towers, tower_type, RewardMods.of(state).tower_discount_percent)


## Nível usado na tabela de raridade da loja: o do núcleo mais o bônus "Loja melhor" (T24).
static func shop_rarity_level(state: Object) -> int:
	return state.nexus.level + RewardMods.of(state).shop_rarity_levels


## Custo do próximo reroll da loja: 0 com reroll grátis sobrando.
static func shop_reroll_cost(economy: EconomyData, state: Object) -> int:
	return 0 if state.shop.free_rerolls > 0 else economy.shop_reroll_cost


## A loja só traz comuns enquanto menos de `commonOnlyWaves` ondas fecharam (`waves_closed` = `state.wave`).
static func common_only(economy: EconomyData, waves_closed: int) -> bool:
	return waves_closed < economy.shop_common_only_waves


static func _draw_rarity(rng: Rng, chances: Dictionary) -> String:
	var roll := rng.next_float() * 100.0
	for rarity: String in EconomyData.RARITIES:
		roll -= float(chances[rarity])
		if roll < 0.0:
			return rarity
	# Sobra de arredondamento: a última raridade que tem chance.
	for i in range(EconomyData.RARITIES.size() - 1, -1, -1):
		if float(chances[EconomyData.RARITIES[i]]) > 0.0:
			return EconomyData.RARITIES[i]
	return EconomyData.RARITIES[0]


## Chances sem as raridades que não têm torre no conjunto (a Costa Rubra não tem lendária): a fatia delas
## cai na sobra do sorteio, que vai para a última raridade com chance. Sem pool vazio, as chances ficam
## como estão.
static func _without_empty(chances: Dictionary, pools: Dictionary) -> Dictionary:
	var out := chances
	for rarity: String in EconomyData.RARITIES:
		if float(chances.get(rarity, 0)) > 0.0 and pools[rarity].is_empty():
			if out == chances:
				out = chances.duplicate()
			out[rarity] = 0
	return out


## Vagas da loja na run: as da economia mais o bônus de região da Costa Rubra (nível 8).
static func slot_count(economy: EconomyData, state: Object) -> int:
	return economy.shop_slots + ClassBonuses.shop_extra_slots(ClassData.game_data(), state)


## Loja nova: por slot, a raridade sai da tabela do nível e depois uma torre da raridade com
## chance igual. Na primeira loja da run, se nenhum slot trouxer a raridade garantida, um slot
## sorteado vira uma torre dela. `free_rerolls`: rerolls grátis da loja (bônus das recompensas).
## `only_common`: todos os slots saem do pool de comuns (primeira rodada; ver `common_only`).
## `extra_slots`: vagas a mais (bônus da Costa Rubra).
static func new_shop(rng: Rng, economy: EconomyData, towers: TowerData, chances: Dictionary,
		is_first_shop: bool, free_rerolls: int = 0, only_common: bool = false, extra_slots: int = 0) -> ShopState:
	var pools := shop_pools(towers)
	chances = _without_empty(chances, pools)
	var slots: Array = []
	for i in economy.shop_slots + extra_slots:
		var drawn := _draw_rarity(rng, chances)
		var pool: Array = pools["common" if only_common else drawn]
		if pool.is_empty():
			push_error("Loja: raridade sorteada sem nenhuma torre nos dados")
			return null
		slots.append(rng.pick(pool))
	if is_first_shop:
		var guaranteed := economy.shop_first_guarantee
		var has := slots.any(func(id: String) -> bool: return towers.get_type(id).rarity == guaranteed)
		if not has:
			var pool: Array = pools[guaranteed]
			if pool.is_empty():
				push_error("Loja: raridade garantida sem nenhuma torre nos dados")
				return null
			slots[rng.next_int(0, slots.size() - 1)] = rng.pick(pool)
	var shop := ShopState.new()
	shop.slots = slots
	shop.free_rerolls = free_rerolls
	return shop


## Compra o slot. Se a cópia funde com uma torre do mapa, funde na hora e a casa é ignorada;
## senão posiciona a torre na casa. Nada muda (nem ouro, nem slot) se o slot estiver vazio,
## faltar ouro, ou, sem fusão, o mapa estiver no limite de torres do núcleo (emite `buyRefused`),
## a casa faltar ou for inválida ou ocupada. A fusão não ocupa casa nova e passa com o limite
## cheio. `cell`: Vector2i, ou null para "sem casa".
static func buy_tower(ctx: TickContext, map: SimMap, towers: TowerData, economy: EconomyData,
		nexus: NexusData, slot: int, cell: Variant = null) -> bool:
	var state := ctx.state
	if slot < 0 or slot >= state.shop.slots.size():
		return false
	var tower_type: Variant = state.shop.slots[slot]
	if typeof(tower_type) != TYPE_STRING:
		return false
	var price := shop_price(economy, towers, state, tower_type)
	if price < 0 or state.gold < price:
		return false
	var plan := Fusion.plan_fusion(state.towers, towers, tower_type)
	if plan == null and not TowerLimit.has_room_for_tower(state, nexus):
		ctx.emit({"type": "buyRefused", "tick": state.tick, "slot": slot, "reason": "limit"})
		return false
	var tower: Tower
	if plan != null:
		tower = Fusion.apply_fusion(ctx, towers, plan, price)
	else:
		tower = TowerPlacement.place_tower(ctx, map, towers, tower_type, cell) if cell != null else null
		if tower == null:
			return false
		tower.invested = price
	Gold.spend_gold(state, price)
	state.shop.slots[slot] = null
	ctx.emit({
		"type": "towerBought",
		"tick": state.tick,
		"towerId": tower.id,
		"towerType": tower_type,
		"slot": slot,
		"price": price,
		"fused": plan != null,
	})
	ctx.emit({"type": "shopChanged", "tick": state.tick, "reason": "bought"})
	return true


## Troca os 5 slots por sorteio novo, pagando o reroll. Com reroll grátis sobrando, não paga e
## gasta um deles (a loja nova não ganha outro).
static func reroll_shop(ctx: TickContext, towers: TowerData, economy: EconomyData) -> bool:
	var state := ctx.state
	var free: bool = state.shop.free_rerolls > 0
	var cost := shop_reroll_cost(economy, state)
	if state.gold < cost:
		return false
	var free_left: int = state.shop.free_rerolls - 1 if free else state.shop.free_rerolls
	Gold.spend_gold(state, cost)
	state.shop = new_shop(ctx.rng, economy, towers, chances_for_state(economy, state), false, free_left,
			common_only(economy, state.wave), slot_count(economy, state) - economy.shop_slots)
	ctx.emit({"type": "shopChanged", "tick": state.tick, "reason": "reroll"})
	return true


## Porcentagem devolvida na venda: a da economia ou a do bônus "Revenda cheia" (T24).
static func sell_refund_percent(economy: EconomyData, state: Object) -> float:
	var percent: Variant = RewardMods.of(state).sell_refund_percent
	return float(percent) if percent != null else float(economy.shop_sell_refund_percent)


## Devolução da venda: a porcentagem do valor investido, arredondada para baixo.
static func refund_for(invested: int, percent: float) -> int:
	return int(floorf((float(invested) * percent) / 100.0))


## Vende a torre: sai do mapa e devolve parte do valor investido.
static func sell_tower(ctx: TickContext, economy: EconomyData, tower_id: int) -> bool:
	var state := ctx.state
	var index := -1
	for i in state.towers.size():
		if state.towers[i].id == tower_id:
			index = i
			break
	if index < 0:
		return false
	var tower: Tower = state.towers[index]
	state.towers.remove_at(index)
	var refund := refund_for(tower.invested, sell_refund_percent(economy, state))
	state.gold += refund
	ctx.emit({
		"type": "towerSold",
		"tick": state.tick,
		"towerId": tower_id,
		"towerType": tower.type,
		"x": tower.x,
		"y": tower.y,
		"refund": refund,
	})
	return true
