class_name ExpansionState
extends RefCounted
## Parte do `RunState` do mapa que cresce: aberturas feitas, a escolha da parede aberta, paredes
## esperando e o RNG próprio da escolha automática (fluxo separado do RNG da simulação, como o das
## recompensas: escolher parede não muda a loja).

class ExpansionScreen:
	extends RefCounted
	## Onda que derrubou a parede; no botão do debug, a última onda fechada.
	var wave: int
	## Ids das aberturas oferecidas (`ExpansionData`), na ordem das opções.
	var options: Array = []
	## Ticks congelados até a simulação escolher sozinha.
	var ticks_left := 0

## Sufixo da semente do fluxo do RNG das paredes.
const RNG_STREAM := "/salas"

var rng_state := 0
## Aberturas feitas (ids de `ExpansionData`, "0:cima:gancho~:u-largo"...), na ordem.
var opened: Array[String] = []
## Onda de cada abertura (mesma ordem de `opened`), para o relatório da run.
var opened_waves: Array[int] = []
## Escolha aberta; com ela, a simulação fica congelada (null = fechada).
var screen: ExpansionScreen = null
## Paredes esperando para cair, depois das telas de recompensa.
var pending := 0
## Debug: a próxima parede divide a linha principal.
var split_next := false


static func create(seed_text: String) -> ExpansionState:
	var state := ExpansionState.new()
	state.rng_state = Rng.hash_seed(seed_text + RNG_STREAM)
	return state


func screen_open() -> bool:
	return screen != null


## Nada aconteceu ainda (o save não precisa guardar).
func is_untouched(seed_text: String) -> bool:
	return opened.is_empty() and screen == null and pending == 0 and not split_next \
			and rng_state == Rng.hash_seed(seed_text + RNG_STREAM)
