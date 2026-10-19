class_name GoodBot
extends RefCounted
## Bot bom (T21; porte de tests/support/goodBot.ts): joga como alguém que conhece o jogo, para
## provar a curva de dificuldade. Entre as ondas:
## - abre com 2 torres diferentes; depois funde primeiro (compra a cópia que vira ★2 ou ★3),
##   mesmo mexendo na reserva;
## - guarda para os juros: a partir da onda 3 só gasta o que passar da reserva
##   `min(100, 10 × (onda − 2))` (100 guardados = teto de juros);
## - escolhe a torre pelo preço, pelas classes que já tem (bônus de classe) e pelas cópias que já
##   tem (fusão futura);
## - posiciona por vizinhança: a primeira na casa que mais vê o caminho, as outras coladas nas que
##   já estão (4 vizinhas), e o Relé onde tem mais vizinhas;
## - evolui o núcleo quando o limite enche;
## - rerola com o que sobra acima da reserva, procurando cópias.
## Chama a próxima onda só com o mapa limpo (não empilha).
##
## Recompensas (T24): pega a carta mais alta de uma ordem fixa (`REWARD_PRIORITY`). Rerola as
## cartas só se nenhuma estiver entre as `REWARD_TOP` primeiras e o ouro depois do reroll
## continuar acima da reserva de juros; no máximo `MAX_REWARD_REROLLS` por tela.

## Torres diferentes no mapa antes da primeira fusão.
const OPENING_TOWERS := 2
## Teto de rerolls por pausa.
const MAX_REROLLS := 4

## Ordem fixa das cartas de recompensa, da preferida para a última.
const REWARD_PRIORITY := [
	"towerLimit", "classWildcard", "income", "artilleryArea", "mechanicalCount", "arcaneLock",
	"interestCap", "discount", "shadowElite", "shopRarity", "chainGold", "nexusHp", "freeReroll",
	"nexusDamage", "fullRefund",
]
## Rerola as cartas só se nenhuma estiver entre as primeiras `REWARD_TOP` da ordem.
const REWARD_TOP := 6
## Teto de rerolls de cartas por tela (custos 5 e 10).
const MAX_REWARD_REROLLS := 2

static var _coverage: Dictionary = {}
static var _cells: Array[Vector2i] = []


static func _init_cells() -> void:
	if _cells.is_empty():
		var map := WaveBot.bot_map()
		_cells = WaveBot.bot_cells(map)
		for i in _cells.size():
			_coverage[map.index_of(_cells[i])] = _cells.size() - i


## Ouro guardado na onda `wave` (a próxima a chamar): sobe 10 por onda a partir da 3, até o ouro
## que rende o teto dos juros (100; 150 com o "Cofre maior").
static func reserve(wave: int, state: Object = null) -> float:
	var economy := EconomyData.game_data()
	var cap := Economy.interest_cap_for(economy, state) if state != null else economy.interest_cap
	var full := float(cap * 100) / float(economy.interest_percent)
	return 0.0 if wave < 3 else minf(full, float(10 * (wave - 2)))


static func _rank(priority: Array, id: String) -> int:
	var r := priority.find(id)
	return priority.size() if r < 0 else r


## Política de recompensa com uma ordem própria: a carta mais alta da ordem, ou reroll (ver acima).
## Devolve um Callable(sim).
static func reward_policy(priority: Array) -> Callable:
	return func(sim: Simulation) -> void:
		var state = sim.state
		var screen: RewardsState.RewardScreen = state.rewards.screen
		if screen == null:
			return
		var best := 0
		for i in range(1, screen.options.size()):
			if _rank(priority, screen.options[i]["id"]) < _rank(priority, screen.options[best]["id"]):
				best = i
		var cost := Rewards.reward_reroll_cost(RewardData.game_data(), screen)
		var reserve_now := reserve(state.wave + 1, state)
		if _rank(priority, screen.options[best]["id"]) >= REWARD_TOP and screen.rerolls < MAX_REWARD_REROLLS \
				and float(state.gold - cost) >= reserve_now:
			sim.enqueue({"type": "rerollRewards"})
			return
		sim.enqueue({"type": "chooseReward", "index": best})


## Tela de recompensa do bot bom: a carta mais alta de `REWARD_PRIORITY`, ou reroll (ver acima).
static func reward(sim: Simulation) -> void:
	reward_policy(REWARD_PRIORITY).call(sim)


## Casa livre para `type`: colada nas torres que já estão, a que mais vê o caminho.
static func _choose_cell(sim: Simulation, type: String) -> Variant:
	_init_cells()
	var map := WaveBot.bot_map()
	var used := {}
	for t: Tower in sim.state.towers:
		used[map.index_of(Vector2i(t.x, t.y))] = true
	var free: Array[Vector2i] = []
	for c in _cells:
		if not used.has(map.index_of(c)):
			free.append(c)
	if used.is_empty():
		return free[0] if not free.is_empty() else null
	var relay := type == "relay"
	var best: Variant = null
	var best_score := -INF
	for cell in free:
		var touching := 0
		for n in [Vector2i(cell.x + 1, cell.y), Vector2i(cell.x - 1, cell.y), Vector2i(cell.x, cell.y + 1), Vector2i(cell.x, cell.y - 1)]:
			if map.is_inside(n) and used.has(map.index_of(n)):
				touching += 1
		if touching == 0:
			continue
		var score := float((100 * touching) if relay else (10 * touching)) + float(_coverage.get(map.index_of(cell), 0))
		if score > best_score:
			best_score = score
			best = cell
	if best != null:
		return best
	return free[0] if not free.is_empty() else null


static func _classes_owned(sim: Simulation) -> Dictionary:
	var owned := {}
	var types := {}
	for t: Tower in sim.state.towers:
		types[t.type] = true
	var towers := TowerData.game_data()
	for type: String in types:
		var data := towers.types.get(type) as TowerData.TowerType
		for c in (data.classes if data != null else []):
			owned[c] = owned.get(c, 0) + 1
	return owned


static func _tower_score(sim: Simulation, type: String, price: float) -> float:
	var owned := _classes_owned(sim)
	var data: TowerData.TowerType = TowerData.game_data().types[type]
	var synergy := 0
	for c in data.classes:
		synergy += 8 if owned.get(c, 0) == 1 else (3 if owned.has(c) else 0)
	var is_new := 4
	for t: Tower in sim.state.towers:
		if t.type == type:
			is_new = 0
			break
	return price + float(synergy) + float(is_new)


static func _action(sim: Simulation, rerolls: Dictionary) -> bool:
	var state = sim.state
	var economy := EconomyData.game_data()
	var towers := TowerData.game_data()
	var nexus := NexusData.game_data()
	var reserve_now := reserve(state.wave + 1, state)
	var spendable := float(state.gold) - reserve_now
	var slots: Array = []
	for slot in state.shop.slots.size():
		var type: Variant = state.shop.slots[slot]
		if type == null:
			continue
		var p := Shop.shop_price(economy, towers, state, type)
		slots.append({"type": type, "slot": slot, "price": INF if p < 0 else float(p)})

	var fuses := func(type: String) -> bool: return Fusion.plan_fusion(state.towers, towers, type) != null
	var fusing: Variant = null
	for s: Dictionary in slots:
		if s["price"] <= float(state.gold) and fuses.call(s["type"]):
			fusing = s
			break
	# Abertura: antes de fundir, tem pelo menos OPENING_TOWERS torres diferentes no mapa.
	var opening: bool = state.towers.size() < OPENING_TOWERS and TowerLimit.has_room_for_tower(state)
	if opening:
		var any := false
		for s: Dictionary in slots:
			if s["price"] <= float(state.gold) and not fuses.call(s["type"]):
				any = true
				break
		opening = any
	if fusing != null and not opening:
		sim.enqueue({"type": "buyTower", "slot": fusing["slot"]})
		return true
	if TowerLimit.has_room_for_tower(state):
		var usable: Array = []
		for s: Dictionary in slots:
			if (s["price"] <= spendable or state.towers.is_empty()) and s["price"] <= float(state.gold) and not fuses.call(s["type"]):
				usable.append(s)
		if not usable.is_empty():
			var best: Dictionary = usable[0]
			for b: Dictionary in usable:
				if _tower_score(sim, b["type"], b["price"]) > _tower_score(sim, best["type"], best["price"]):
					best = b
			var cell: Variant = _choose_cell(sim, best["type"])
			if cell != null:
				sim.enqueue({"type": "buyTower", "slot": best["slot"], "x": cell.x, "y": cell.y})
				return true
	else:
		var level: int = state.nexus.level
		if float(level) < nexus.max_level() and float(nexus.level_data(level + 1).cost) <= spendable:
			sim.enqueue({"type": "evolveNexus"})
			return true
	if rerolls["left"] > 0 and spendable >= float(Shop.shop_reroll_cost(economy, state) + 10):
		rerolls["left"] -= 1
		sim.enqueue({"type": "rerollShop"})
		return true
	return false


## A pausa entre ondas do bot bom: age até não ter mais o que fazer (um tick por ação).
static func bot_break(sim: Simulation) -> void:
	var rerolls := {"left": MAX_REROLLS}
	var guard := 0
	while guard < 100 and _action(sim, rerolls):
		sim.step()
		guard += 1
