class_name ChainMark
extends RefCounted
## Marcação de cadeia (T16) que um projétil ou uma morte carrega: a cadeia
## continua quando a morte vem de um tiro disparado por um gatilho.
## `chain_id` 0 = sem cadeia (tiro normal). `origin_tower_id` null = núcleo.

var chain_id := 0
var origin_tower_id: Variant = null


func _init(p_chain_id: int = 0, p_origin_tower_id: Variant = null) -> void:
	chain_id = p_chain_id
	origin_tower_id = p_origin_tower_id


## Sem cadeia (equivalente a NO_CHAIN do Phaser). Não modifique.
static var NO_CHAIN := ChainMark.new(0, null)
