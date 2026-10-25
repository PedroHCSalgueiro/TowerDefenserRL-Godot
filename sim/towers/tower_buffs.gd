class_name TowerBuffs
extends RefCounted
## Bônus de dano da própria torre, fora das classes: a Falange (passiva do Hoplita Dorian: +% por vizinha
## ortogonal de uma classe) e o bônus do Acólito Sombrio até o fim da onda (`Tower.wave_buff_percent`).
## Valem no ataque normal (`TowerSystems.fire_tower_shot`) e nos efeitos de gatilho (`TriggerEffects`).


## Multiplicador do dano da torre agora (1 = sem bônus).
static func damage_multiplier(state: Object, towers: TowerData, tower: Tower, type: TowerData.TowerType) -> float:
	var mult := 1.0
	if tower.wave_buff_percent > 0.0:
		mult *= 1.0 + tower.wave_buff_percent / 100.0
	if not type.passive.is_empty() and type.passive["kind"] == "phalanx":
		var star := Stars.passive_star(type, tower)
		var allies := 0
		for other: Tower in state.towers:
			if other != tower and absi(other.x - tower.x) + absi(other.y - tower.y) == 1 \
					and towers.has_type(other.type) and towers.types[other.type].classes.has(star["class"]):
				allies += 1
		if allies > 0:
			mult *= 1.0 + float(star["percent"]) * float(allies) / 100.0
	return mult
