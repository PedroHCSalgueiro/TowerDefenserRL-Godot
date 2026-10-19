class_name RngHolder
extends RefCounted
## Dono do estado do RNG. O RunState terá a mesma propriedade `rng_state`.

var rng_state: int = 0


func _init(p_rng_state: int = 0) -> void:
	rng_state = p_rng_state
