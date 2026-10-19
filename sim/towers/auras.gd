class_name Auras
extends RefCounted
## Auras passivas das torres sobre as vizinhas (`aura` em `towers.json`; ex.: a Bênção do Irmão Tomás).
## Vizinha = as 4 casas ortogonais (a regra padrão do Notion). Várias auras somam.


## Bônus de velocidade de ataque, em %, que `tower` recebe das auras vizinhas. Cada fonte dá o seu
## `attackSpeedPercent` na estrela dela, ou `regionPercent` (se maior que 0) quando a torre que recebe
## é da região da aura (a classe `region` está entre as classes dela).
static func attack_speed_percent(state: Object, data: TowerData, tower: Tower) -> float:
	var total := 0.0
	var tower_type := data.get_type(tower.type)
	for source: Tower in state.towers:
		if source == tower or absi(source.x - tower.x) + absi(source.y - tower.y) != 1:
			continue
		var source_type: TowerData.TowerType = data.types[source.type]
		if source_type.aura.is_empty():
			continue
		var stars: Array = source_type.aura["stars"]
		var level: Dictionary = stars[mini(maxi(source.star, 1), stars.size()) - 1]
		if level["regionPercent"] > 0.0 and tower_type.classes.has(source_type.aura["region"]):
			total += level["regionPercent"]
		else:
			total += level["attackSpeedPercent"]
	return total
