class_name RewardsState
extends RefCounted
## Parte do `RunState` das recompensas de escolha (T24): os bônus escolhidos, a tela
## aberta, a fila de telas e o RNG próprio do sorteio das cartas (porte de `rewardState.ts`).
##
## O RNG das cartas é um fluxo separado do RNG da simulação, derivado da semente da
## run: sortear e rerolar cartas não muda a sequência da loja.

## Um bônus escolhido, na ordem da run.
class TakenReward:
	extends RefCounted
	var id: String
	## Classe do coringa (null nos outros).
	var class_id: Variant = null
	## Onda da tela em que foi escolhido.
	var wave: int

	func _init(p_id: String = "", p_class_id: Variant = null, p_wave: int = 0) -> void:
		id = p_id
		class_id = p_class_id
		wave = p_wave

class RewardScreen:
	extends RefCounted
	## Onda que deu a tela (no botão do debug, a última onda fechada).
	var wave: int
	## Cartas: [{"id": String, "classId": String|null}, ...] (`classId` só no coringa).
	var options: Array = []
	## Rerolls já feitos nesta tela (o custo do próximo depende disto).
	var rerolls := 0
	## Ticks congelados até a simulação escolher sozinha.
	var ticks_left := 0

## Sufixo da semente que separa o fluxo das cartas do RNG da simulação.
const RNG_STREAM := "/recompensas"

## Estado do RNG das cartas (fluxo próprio, ver acima). RewardsState é o holder desse RNG.
var rng_state := 0
var taken: Array[TakenReward] = []
## Tela aberta; com ela, a simulação fica congelada (null = fechada).
var screen: RewardScreen = null
## Ondas esperando a tela, na ordem em que fecharam.
var queue: Array[int] = []

# Cache do efeito somado (ver RewardMods.of): refeito só quando um bônus entra.
var _mods_cache: RewardMods = null
var _mods_count := -1
var _mods_data: RewardData = null


static func create(seed_text: String) -> RewardsState:
	var state := RewardsState.new()
	state.rng_state = Rng.hash_seed(seed_text + RNG_STREAM)
	return state


## Há uma tela de recompensa aberta (a simulação está congelada)?
func screen_open() -> bool:
	return screen != null
