class_name ExpansionState
extends RefCounted
## Parte do `RunState` do mapa que cresce: salas abertas, a escolha da parede aberta, escolhas
## esperando e o RNG próprio do sorteio das paredes (fluxo separado do RNG da simulação, como o das
## recompensas: sortear paredes não muda a loja).

class ExpansionScreen:
	extends RefCounted
	## Onda (chefão) que deu a escolha; no botão do debug, a última onda fechada.
	var wave: int
	## Ids das salas oferecidas, na ordem das opções.
	var options: Array = []
	## Ticks congelados até a simulação escolher sozinha.
	var ticks_left := 0

## Sufixo da semente do fluxo do RNG das paredes.
const RNG_STREAM := "/salas"

var rng_state := 0
## Salas abertas, na ordem em que abriram.
var opened: Array[String] = []
## Onda que deu a escolha de cada sala aberta (mesma ordem de `opened`), para o relatório da run.
var opened_waves: Array[int] = []
## Escolha aberta; com ela, a simulação fica congelada (null = fechada).
var screen: ExpansionScreen = null
## Escolhas esperando para abrir (chefões fechados), depois das telas de recompensa.
var pending := 0


static func create(seed_text: String) -> ExpansionState:
	var state := ExpansionState.new()
	state.rng_state = Rng.hash_seed(seed_text + RNG_STREAM)
	return state


func screen_open() -> bool:
	return screen != null


## Nada aconteceu ainda (o save não precisa guardar).
func is_untouched(seed_text: String) -> bool:
	return opened.is_empty() and screen == null and pending == 0 \
			and rng_state == Rng.hash_seed(seed_text + RNG_STREAM)
