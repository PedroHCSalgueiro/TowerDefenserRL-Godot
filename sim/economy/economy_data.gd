class_name EconomyData
extends RefCounted
## Economia da run e regras da loja, lidas de `data/economy.json` (porte de `economyData.ts`).
## Chances em porcentagem (cada nível soma 100); `rarity_chances[n - 1]` é o nível `n` do núcleo.

## Raridades em ordem. "legendary" é opcional nos dados (o conjunto Padrão não usa): sem ele, preço e chance valem 0.
const RARITIES := ["common", "uncommon", "rare", "legendary"]

var starting_gold: int
var nexus_start_level: int
var interest_percent: int
var interest_cap: int
var wave_bonus_base: int
var wave_bonus_per_wave: int
## Ouro por abate: `base + perWave × onda` do inimigo (0 para inimigo sem onda, como os do debug),
## somado ao `gold` do tipo (`enemies.json`).
var kill_gold_base: int
var kill_gold_per_wave: int
## O ouro sobe `perWave` a cada `waveStep` ondas: `base + perWave × ceil(onda / waveStep)`.
var kill_gold_wave_step: int = 1
## Chamada antecipada: `early_per_active_wave` × ondas já ativas (chamadas e não fechadas) no
## momento da chamada, pago quando a onda chamada fecha.
var early_per_active_wave: int
## Janela do bônus (T23): só há bônus enquanto menos desta porcentagem dos inimigos da onda
## mais recente já nasceu. Depois, a chamada sai sem bônus.
var early_window_percent: int
var shop_slots: int
## Nas primeiras N ondas (enquanto menos de N ondas fecharam) a loja só traz torres comuns.
var shop_common_only_waves: int
var shop_reroll_cost: int
var shop_sell_refund_percent: int
## Raridade que a primeira loja da run precisa ter em pelo menos um slot.
var shop_first_guarantee: String
## rarity -> int
var shop_prices: Dictionary = {}
## Array de Dictionary rarity -> int, índice 0 = nível 1 do núcleo.
var shop_rarity_chances: Array = []
## Como a loja escolhe a raridade: "nexusLevel" (tabela por nível do núcleo, a regra do Phaser) ou "wave" (tabela
## por onda: `rarity_by_wave`, cada faixa vale da onda `fromWave` até a seguinte).
var rarity_mode := "nexusLevel"
## Modo "wave": [{"fromWave": int, "chances": Dictionary rarity -> %}], `fromWave` crescente e a primeira = 1.
var rarity_by_wave: Array = []

static var _default: EconomyData = null


## Esquece os dados carregados (troca de conjunto de torres; ver `GameSets`).
static func reset_cache() -> void:
	_default = null


static func game_data() -> EconomyData:
	if _default == null:
		_default = load_data(DataLoader.load_json("economy.json"))
	return _default


static func _is_int(v: Variant, min_value: int) -> bool:
	return SimMap._is_integer(v) and int(v) >= min_value


static func _fail(message: String) -> void:
	push_error("Dados de economia inválidos: %s" % message)


static func _by_rarity(p_name: String, raw: Variant, min_value: int) -> Dictionary:
	if not (raw is Dictionary):
		_fail('"%s" precisa ter %s válidos' % [p_name, ", ".join(RARITIES)])
		return {}
	var out := {}
	for r: String in RARITIES:
		if r == "legendary" and not raw.has(r):
			out[r] = 0
			continue
		if not _is_int(raw.get(r), min_value):
			_fail('"%s" precisa ter %s válidos' % [p_name, ", ".join(RARITIES)])
			return {}
		out[r] = int(raw[r])
	return out


static func load_data(raw: Variant) -> EconomyData:
	if not (raw is Dictionary):
		_fail("não é um objeto")
		return null
	if not _is_int(raw.get("startingGold"), 0):
		_fail('"startingGold" precisa ser inteiro >= 0')
		return null
	if not _is_int(raw.get("nexusStartLevel"), 1):
		_fail('"nexusStartLevel" precisa ser inteiro >= 1')
		return null
	var interest: Variant = raw.get("interest")
	if not (interest is Dictionary) or not _is_int(interest.get("percent"), 0) or not _is_int(interest.get("cap"), 0):
		_fail('"interest" precisa de percent e cap inteiros >= 0')
		return null
	var wave_bonus: Variant = raw.get("waveBonus")
	if not (wave_bonus is Dictionary) or not _is_int(wave_bonus.get("base"), 0) or not _is_int(wave_bonus.get("perWave"), 0):
		_fail('"waveBonus" precisa de base e perWave inteiros >= 0')
		return null
	var kill_gold: Variant = raw.get("killGold")
	if not (kill_gold is Dictionary) or not _is_int(kill_gold.get("base"), 0) or not _is_int(kill_gold.get("perWave"), 0):
		_fail('"killGold" precisa de base e perWave inteiros >= 0')
		return null
	if kill_gold.has("waveStep") and not _is_int(kill_gold["waveStep"], 1):
		_fail('"killGold.waveStep" precisa ser inteiro >= 1')
		return null
	var early: Variant = raw.get("earlyCall")
	if not (early is Dictionary) or not _is_int(early.get("perActiveWave"), 0) \
			or not _is_int(early.get("windowPercent"), 1) or int(early["windowPercent"]) > 100:
		_fail('"earlyCall" precisa de perActiveWave inteiro >= 0 e windowPercent inteiro de 1 a 100')
		return null
	var shop: Variant = raw.get("shop")
	if not (shop is Dictionary) or not _is_int(shop.get("slots"), 1) or not _is_int(shop.get("rerollCost"), 0) or not _is_int(shop.get("commonOnlyWaves"), 0) \
			or not _is_int(shop.get("sellRefundPercent"), 0) or int(shop["sellRefundPercent"]) > 100 \
			or not RARITIES.has(shop.get("firstShopGuarantee")):
		_fail('"shop" com campos ausentes ou fora do intervalo')
		return null
	var prices := _by_rarity("shop.prices", shop.get("prices"), 1)
	if prices.is_empty():
		return null
	var chances_raw: Variant = shop.get("rarityChances")
	if not (chances_raw is Array) or chances_raw.is_empty():
		_fail('"shop.rarityChances" precisa de pelo menos um nível')
		return null
	var chances: Array = []
	for i in chances_raw.size():
		var level := _by_rarity("shop.rarityChances[%d]" % i, chances_raw[i], 0)
		if level.is_empty():
			return null
		var total := 0
		for r: String in RARITIES:
			total += level[r]
		if total != 100:
			_fail('"shop.rarityChances[%d]" precisa somar 100' % i)
			return null
		chances.append(level)
	if int(raw["nexusStartLevel"]) > chances.size():
		_fail('"nexusStartLevel" passa do último nível da tabela de chances')
		return null

	var mode: Variant = shop.get("rarityMode", "nexusLevel")
	if mode != "nexusLevel" and mode != "wave":
		_fail('"shop.rarityMode" precisa ser "nexusLevel" ou "wave"')
		return null
	var by_wave: Array = []
	if mode == "wave":
		var rows_raw: Variant = shop.get("rarityByWave")
		if not (rows_raw is Array) or rows_raw.is_empty():
			_fail('"shop.rarityByWave" precisa de pelo menos uma faixa')
			return null
		var last_from := 0
		for i in rows_raw.size():
			var row: Variant = rows_raw[i]
			if not (row is Dictionary) or not _is_int(row.get("fromWave"), 1) or int(row["fromWave"]) <= last_from \
					or (i == 0 and int(row["fromWave"]) != 1):
				_fail('"shop.rarityByWave[%d]" precisa de fromWave inteiro crescente (a primeira faixa começa na onda 1)' % i)
				return null
			var row_chances := _by_rarity("shop.rarityByWave[%d]" % i, row, 0)
			if row_chances.is_empty():
				return null
			var row_total := 0
			for r: String in RARITIES:
				row_total += row_chances[r]
			if row_total != 100:
				_fail('"shop.rarityByWave[%d]" precisa somar 100' % i)
				return null
			last_from = int(row["fromWave"])
			by_wave.append({"fromWave": last_from, "chances": row_chances})

	var data := EconomyData.new()
	data.starting_gold = int(raw["startingGold"])
	data.nexus_start_level = int(raw["nexusStartLevel"])
	data.interest_percent = int(interest["percent"])
	data.interest_cap = int(interest["cap"])
	data.wave_bonus_base = int(wave_bonus["base"])
	data.wave_bonus_per_wave = int(wave_bonus["perWave"])
	data.kill_gold_base = int(kill_gold["base"])
	data.kill_gold_per_wave = int(kill_gold["perWave"])
	data.kill_gold_wave_step = int(kill_gold.get("waveStep", 1))
	data.early_per_active_wave = int(early["perActiveWave"])
	data.early_window_percent = int(early["windowPercent"])
	data.shop_slots = int(shop["slots"])
	data.shop_common_only_waves = int(shop["commonOnlyWaves"])
	data.shop_reroll_cost = int(shop["rerollCost"])
	data.shop_sell_refund_percent = int(shop["sellRefundPercent"])
	data.shop_first_guarantee = shop["firstShopGuarantee"]
	data.shop_prices = prices
	data.shop_rarity_chances = chances
	data.rarity_mode = mode
	data.rarity_by_wave = by_wave
	return data
