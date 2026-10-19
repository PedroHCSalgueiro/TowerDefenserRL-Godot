class_name TestRunState
extends RngHolder
## Estado mínimo para testar o motor e os sistemas isolados sem o RunState completo.
## Tem só os campos que os módulos testados leem e escrevem; espelha `createRunState`
## do Phaser no que importa (tick 0, rng_state = hash da semente, next_entity_id 1,
## status "playing"). Campos novos entram aqui conforme os módulos são portados.

class Rewards:
	extends RefCounted
	var screen: Variant = null

var seed_text: String
var tick := 0
var next_entity_id := 1
var status := "playing"
var command_queue: Array = []
var rewards := Rewards.new()
var enemies := EnemyPool.create(8)


func _init(p_seed: String = "") -> void:
	super(Rng.hash_seed(p_seed))
	seed_text = p_seed
