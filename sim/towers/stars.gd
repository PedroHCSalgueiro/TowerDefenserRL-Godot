class_name Stars
extends RefCounted
## Estrela da torre. Até a T11 (fusão) a estrela só vem do spawn do debug; cada estrela traz
## o gatilho com os seus números (`stars` do gatilho). Torre sem gatilho só tem ★1
## (porte de `stars.ts`).


## Estrelas que o tipo tem em dados (1 se não tem gatilho, aura nem passiva).
static func max_stars(type: TowerData.TowerType) -> int:
	var from_trigger := type.trigger.stars.size() if type.trigger != null else 1
	var from_passive: int = type.passive["stars"].size() if not type.passive.is_empty() else 1
	return maxi(maxi(from_trigger, from_passive), type.aura["stars"].size() if not type.aura.is_empty() else 1)


## Os números da passiva na estrela da torre ({} = sem passiva).
static func passive_star(type: TowerData.TowerType, tower: Tower) -> Dictionary:
	if type.passive.is_empty():
		return {}
	var stars: Array = type.passive["stars"]
	return stars[mini(clamp_star(type, tower.star), stars.size()) - 1]


## Estrela pedida, presa entre ★1 e a última que o tipo tem.
static func clamp_star(type: TowerData.TowerType, star: float) -> int:
	var wanted := int(floorf(star)) if is_finite(star) else 1
	return mini(maxi(1, wanted), max_stars(type))


## Gatilho da torre na estrela dela (null = tipo sem gatilho).
static func tower_star(type: TowerData.TowerType, tower: Tower) -> TriggerData.TriggerStar:
	if type.trigger == null:
		return null
	return TriggerData.trigger_at(type.trigger, clamp_star(type, tower.star))


## Dano do ataque normal da torre: o dano dos dados com o bônus da estrela.
static func tower_damage(type: TowerData.TowerType, tower: Tower) -> float:
	var star := tower_star(type, tower) if type.trigger != null else null
	if star != null and star.attack_damage_percent != 100.0:
		return (type.damage * star.attack_damage_percent) / 100.0
	if star == null and not type.passive.is_empty():
		var percent: float = passive_star(type, tower)["attackDamagePercent"]
		if percent != 100.0:
			return (type.damage * percent) / 100.0
	return type.damage
