class_name Auras
extends RefCounted
## Auras passivas das torres sobre as vizinhas (`aura` em `towers.json`; ex.: a Bênção do Irmão Tomás).
## Vizinha = as 4 casas ortogonais (a regra padrão do Notion); com o bônus do Suporte, a vizinhança da fonte
## ganha as diagonais (`ClassBonuses.neighborhood_radius`) e a aura fica mais forte. Várias auras somam.


## Bônus de velocidade de ataque, em %, que `tower` recebe das auras vizinhas. Cada fonte dá o seu
## `attackSpeedPercent` na estrela dela, ou `regionPercent` (se maior que 0) quando a torre que recebe
## é da região da aura (a classe `region` está entre as classes dela).
static func attack_speed_percent(state: Object, data: TowerData, tower: Tower) -> float:
	var total := 0.0
	var tower_type := data.get_type(tower.type)
	var classes := ClassData.game_data()
	for source: Tower in state.towers:
		if source == tower:
			continue
		var source_type: TowerData.TowerType = data.types[source.type]
		if source_type.aura.is_empty():
			continue
		var radius := ClassBonuses.neighborhood_radius(classes, state, source_type)
		if not TriggerNeighborhood.is_neighbor(source, tower, 4, radius):
			continue
		var stars: Array = source_type.aura["stars"]
		var level: Dictionary = stars[mini(maxi(source.star, 1), stars.size()) - 1]
		var percent: float = level["attackSpeedPercent"]
		if level["regionPercent"] > 0.0 and tower_type.classes.has(source_type.aura["region"]):
			percent = level["regionPercent"]
		total += percent * ClassBonuses.aura_multiplier(classes, state, source_type)
	return total
