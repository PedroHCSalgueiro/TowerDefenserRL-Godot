class_name TestRunState
extends RngHolder
## Estado mínimo para testar o motor (Simulation/SimulationRunner) sem o RunState completo.
## Tem só os campos que o motor lê e escreve; espelha `createRunState` do Phaser
## (tick 0, rng_state = hash da semente, next_entity_id 1, status "playing").

class Rewards:
	extends RefCounted
	var screen: Variant = null

var seed_text: String
var tick := 0
var next_entity_id := 1
var status := "playing"
var command_queue: Array = []
var rewards := Rewards.new()


func _init(p_seed: String = "") -> void:
	super(Rng.hash_seed(p_seed))
	seed_text = p_seed
