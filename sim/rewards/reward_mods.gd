class_name RewardMods
extends RefCounted
## Efeito somado dos bônus escolhidos (T24), lido pelos sistemas: um objeto com os
## valores já combinados (somas, multiplicadores, tetos). Fica em cache por lista de
## escolhidos: só muda quando um bônus entra, e os leitores rodam a cada tiro e a cada
## abate (porte de `mods.ts`).
##
## Repetidos somam: +25% duas vezes = +50%; +1 de limite duas vezes = +2.

## Por classe: +% de dano da área (tiro em área e explosões).
var area_damage_percent: Dictionary = {}
## Por classe: quanto as contagens "a cada N" caem depois do bônus de classe.
var trigger_count_minus: Dictionary = {}
## Por classe: multiplicador das mortes de elite e chefão nos contadores e cargas.
var elite_kill_weight: Dictionary = {}
## Por classe: torres a mais na contagem do bônus de classe (coringa).
var wildcards: Dictionary = {}
## Trava de ativação de todas as torres (null = a dos dados das torres).
var activation_cooldown_seconds: Variant = null
## Teto dos juros (null = o da economia).
var interest_cap: Variant = null
var income_per_wave := 0
var free_rerolls_per_shop := 0
var tower_discount_percent := 0.0
## Devolução da venda (null = a da economia).
var sell_refund_percent: Variant = null
var tower_limit := 0
var nexus_max_hp := 0
var nexus_damage_multiplier := 1.0
var shop_rarity_levels := 0
## Ouro das cadeias (null = desligado): {"every": int, "gold": int}.
var chain_gold: Variant = null

## Sem nenhum bônus (compartilhado; não modifique).
static var NONE := RewardMods.new()


static func _add(record: Dictionary, key: String, amount: float) -> void:
	record[key] = record.get(key, 0) + amount


## Combina a lista de escolhidos (sem cache).
static func combine(taken: Array, data: RewardData) -> RewardMods:
	if taken.is_empty():
		return NONE
	var mods := RewardMods.new()
	for pick: RewardsState.TakenReward in taken:
		var reward := data.get_reward(pick.id)
		var class_id: String = reward.class_id if reward.class_id != null else ""
		var e: Dictionary = reward.effect
		match e["kind"]:
			"areaDamagePercent":
				_add(mods.area_damage_percent, class_id, e["percent"])
			"triggerCountMinus":
				_add(mods.trigger_count_minus, class_id, e["amount"])
			"eliteKillWeight":
				mods.elite_kill_weight[class_id] = mods.elite_kill_weight.get(class_id, 1.0) * e["multiplier"]
			"classWildcard":
				if pick.class_id != null:
					_add(mods.wildcards, pick.class_id, e["count"])
			"activationCooldownSeconds":
				mods.activation_cooldown_seconds = minf(
						mods.activation_cooldown_seconds if mods.activation_cooldown_seconds != null else INF,
						e["seconds"])
			"interestCap":
				mods.interest_cap = maxi(mods.interest_cap if mods.interest_cap != null else 0, e["cap"])
			"incomePerWave":
				mods.income_per_wave += e["gold"]
			"freeRerollsPerShop":
				mods.free_rerolls_per_shop += e["count"]
			"towerDiscountPercent":
				mods.tower_discount_percent = maxf(mods.tower_discount_percent, e["percent"])
			"sellRefundPercent":
				mods.sell_refund_percent = maxf(
						mods.sell_refund_percent if mods.sell_refund_percent != null else 0.0, e["percent"])
			"towerLimit":
				mods.tower_limit += e["amount"]
			"nexusMaxHp":
				mods.nexus_max_hp += e["amount"]
			"nexusDamageMultiplier":
				mods.nexus_damage_multiplier *= e["multiplier"]
			"shopRarityLevels":
				mods.shop_rarity_levels += e["levels"]
			"chainGold":
				mods.chain_gold = {"every": e["every"], "gold": e["gold"]}
	return mods


## Efeito dos bônus escolhidos na run. Aceita estados sem `rewards` ou sem `taken`
## (estados parciais de teste): sem recompensas, tudo neutro.
static func of(state: Object, data: RewardData = null) -> RewardMods:
	var rewards: Variant = state.get("rewards")
	if rewards == null:
		return NONE
	var taken: Variant = rewards.get("taken")
	if taken == null or taken.is_empty():
		return NONE
	if data == null:
		data = RewardData.game_data()
	if rewards._mods_cache != null and rewards._mods_count == taken.size() and rewards._mods_data == data:
		return rewards._mods_cache
	var mods := combine(taken, data)
	rewards._mods_cache = mods
	rewards._mods_count = taken.size()
	rewards._mods_data = data
	return mods
