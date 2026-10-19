class_name Armor
extends RefCounted
## Redução de dano pela armadura (decidido para o protótipo):
## dano = bruto × scale / (scale + armadura). Com scale 100, armadura 50 tira
## cerca de 33% e armadura 0 não tira nada. O dano nunca chega a zero.


static func apply_armor(raw_damage: float, armor: float, scale: float) -> float:
	return (raw_damage * scale) / (scale + armor)
