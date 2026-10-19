class_name NexusPanelModel
extends RefCounted
## Modelo do painel do núcleo: nível, torres no mapa contra o limite, chances de raridade atuais e
## do próximo nível e o custo de evoluir (porte de `nexusPanelModel.ts`). Sem nós.

var level := 1
var towers := 0
var tower_limit := 0
## Limite do próximo nível (-1 só com dados sem `beyondLevels`).
var next_tower_limit := -1
var hp := 0
var max_hp := 0
## rarity -> %.
var chances: Dictionary = {}
## Chances do próximo nível ({} só com dados sem `beyondLevels`).
var next_chances: Dictionary = {}
## Custo de evoluir (-1 só com dados sem `beyondLevels`).
var cost := -1
var can_evolve := false


static func build(state: Object, economy: EconomyData, nexus: NexusData = null) -> NexusPanelModel:
	if nexus == null:
		nexus = NexusData.game_data()
	var level: int = state.nexus.level
	var cost := NexusEvolve.next_level_cost(nexus, level)
	# Bônus das recompensas (T24): limite a mais e raridade de um nível acima.
	var extra_limit := RewardMods.of(state).tower_limit
	var rarity_level := Shop.shop_rarity_level(state)
	var model := NexusPanelModel.new()
	model.level = level
	model.towers = TowerLimit.tower_count(state)
	model.tower_limit = TowerLimit.current_tower_limit(state, nexus)
	model.next_tower_limit = -1 if cost < 0 else nexus.tower_limit_at(level + 1) + extra_limit
	model.hp = int(ceilf(state.nexus.hp))
	model.max_hp = state.nexus.max_hp
	model.chances = Shop.chances_for(economy, rarity_level)
	model.next_chances = {} if cost < 0 else Shop.chances_for(economy, rarity_level + 1)
	model.cost = cost
	model.can_evolve = cost >= 0 and state.status == "playing" and state.gold >= cost
	return model


func key() -> String:
	var fmt_chances := func(c: Dictionary) -> String:
		if c.is_empty():
			return "-"
		return "/".join(EconomyData.RARITIES.map(func(r: String) -> String: return str(c[r])))
	return "|".join([str(level), str(towers), str(tower_limit), str(hp), str(max_hp), fmt_chances.call(chances),
			fmt_chances.call(next_chances), str(cost) if cost >= 0 else "-", "1" if can_evolve else "0"])
