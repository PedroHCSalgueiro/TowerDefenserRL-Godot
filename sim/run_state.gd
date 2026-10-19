class_name RunState
extends RngHolder
## Estado completo da run (porte de `state.ts`). Tudo aqui precisa caber em JSON: é a base do save
## no meio da run. O estado do RNG da simulação é `rng_state` (herdado de RngHolder).
##
## Convenções: propriedades em snake_case; comandos e eventos são Dictionaries com as chaves do
## Phaser (camelCase). `status`: "playing" | "lost" | "won".

const VERSION := 16

## Estado do núcleo.
class NexusState:
	extends RefCounted
	var hp: float
	var max_hp: int
	## Ticks até o próximo ataque; 0 = pronto.
	var attack_cooldown_ticks := 0
	## Nível do núcleo (limite de torres, vida máxima e chances de raridade da loja). Sobe ao evoluir.
	var level: int

class DebugState:
	extends RefCounted
	## O núcleo não perde vida (e a run não termina).
	var nexus_invulnerable := false
	## Trapaça "ouro infinito" (T17): a compra continua exigindo o preço, mas o ouro não diminui.
	var infinite_gold := false
	## Modo estresse: null ou {"count": int, "layout": "spread"|"clustered"}.
	var stress: Variant = null

var version := VERSION
var seed_text: String
var tick := 0
var next_entity_id := 1
var status := "playing"
## Alguma trapaça (comando de debug) chegou nesta run; nunca volta a false.
var cheated := false
var nexus := NexusState.new()
var enemies: EnemyPool
var projectiles: ProjectilePool
## Torres no mapa, na ordem em que foram posicionadas (é a ordem de disparo).
var towers: Array[Tower] = []
## Motor de gatilhos: fila pendente, ordem de disparo e contadores.
var triggers := TriggerState.new()
## Contagem e nível de bônus de cada classe (atualizado no fim de cada tick): id -> ClassStatus.
var classes: Dictionary
## Ouro guardado.
var gold: int
## Último saldo informado em `goldChanged` (para emitir no máximo um por tick).
var reported_gold: int
## Ondas encerradas até agora (a primeira a fechar é a 1).
var wave := 0
## Ondas em andamento (a mais antiga é a de número `wave + 1`).
var waves := WaveState.new()
var stats := WaveState.RunStats.new()
var shop: Shop.ShopState
## Recompensas de escolha (T24): bônus escolhidos, tela aberta, fila e RNG das cartas.
var rewards: RewardsState
var debug := DebugState.new()
## Armadilhas no chão do caminho (Engenheira Mabel).
var traps: Array[Trap] = []
## Ações enfileiradas que ainda não foram aplicadas.
var command_queue: Array = []


## Estado inicial de uma run com a semente dada (porte de `createRunState`). A primeira loja da run
## sai do RNG da própria semente e garante uma comum.
static func create(seed_text_value: String, economy_data: EconomyData = null) -> RunState:
	var economy := economy_data if economy_data != null else EconomyData.game_data()
	var nexus_data := NexusData.game_data()
	var engine := EngineData.config()
	var state := RunState.new()
	state.seed_text = seed_text_value
	state.rng_state = Rng.hash_seed(seed_text_value)
	var start := nexus_data.level_data(economy.nexus_start_level)
	state.nexus.hp = float(start.max_hp)
	state.nexus.max_hp = start.max_hp
	state.nexus.level = economy.nexus_start_level
	state.enemies = EnemyPool.create(int(engine["enemyPoolInitialCapacity"]))
	state.projectiles = ProjectilePool.create(int(engine["projectilePoolInitialCapacity"]))
	state.classes = ClassState.create(ClassData.game_data())
	state.gold = economy.starting_gold
	state.reported_gold = economy.starting_gold
	state.rewards = RewardsState.create(seed_text_value)
	state.shop = Shop.new_shop(Rng.new(state), economy, TowerData.game_data(), Shop.initial_chances(economy), true, 0,
			Shop.common_only(economy, 0))
	return state
