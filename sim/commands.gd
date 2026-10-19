class_name Commands
extends RefCounted
## Aplica as ações da fila, na ordem em que foram enfileiradas, no início do tick. É o único lugar
## em que ações do jogador e do debug mudam o estado. Qualquer comando de debug liga `cheated`
## (T17), mesmo se for recusado (porte de `commands.ts`).
##
## Com a tela de recompensa aberta (T24), roda também nos ticks congelados, mas só aceita as ações
## de `REWARD_SCREEN_COMMAND_TYPES`; as outras são ignoradas (a interface também as bloqueia).
##
## Um comando é um Dictionary com "type" e os campos do Phaser (camelCase):
##   spawnEnemy{enemyType}  placeTower{towerType,x,y,star?}  buyTower{slot,x?,y?}  rerollShop
##   sellTower{towerId}  moveTower{towerId,x,y}  endWave  callWave  evolveNexus
##   chooseReward{index}  rerollRewards  debugSpawnEnemies{count,enemyType,layout}
##   debugSpawnTowers{count,towerTypes,layout,star?}  debugClear  debugSetStress{stress}
##   debugSetNexusInvulnerable{value}  debugSkipToWave{wave}  debugAddGold{amount}
##   debugSetInfiniteGold{value}  debugOpenReward

## Comandos de debug (trapaças): qualquer um que chegue à fila liga `cheated`, mesmo se a simulação
## o recusar (T17).
const CHEAT_COMMAND_TYPES := [
	"spawnEnemy", "placeTower", "endWave", "debugSpawnEnemies", "debugSpawnTowers", "debugClear",
	"debugSetStress", "debugSetNexusInvulnerable", "debugSkipToWave", "debugAddGold",
	"debugSetInfiniteGold", "debugOpenReward",
]

## Ações aceitas com a tela de recompensa aberta (T24): escolher, rerolar as cartas e as trapaças
## que não mexem no mapa. As outras são ignoradas.
const REWARD_SCREEN_COMMAND_TYPES := [
	"chooseReward", "rerollRewards", "debugOpenReward", "debugAddGold", "debugSetInfiniteGold",
	"debugSetNexusInvulnerable",
]


## Devolve o sistema (Callable) de comandos. Roda também congelado.
static func create_command_system(map: SimMap, routes: Dictionary, enemies: EnemyData, towers: TowerData,
		debug: SimDebugData, schedules: Array[WaveSchedule], economy: EconomyData, nexus: NexusData,
		rewards: RewardData, classes: ClassData, ticks_per_second: float) -> Callable:
	# Quantidade pedida, presa em [0, max_spawn_per_command].
	var clamp_count := func(count: Variant) -> int:
		return mini(maxi(0, int(floorf(float(count)))), debug.max_spawn_per_command) if is_finite(float(count)) else 0
	# Ouro da trapaça: inteiro, entre 0 e `max_gold_per_command`.
	var clamp_gold := func(amount: Variant) -> int:
		return mini(maxi(0, int(floorf(float(amount)))), debug.max_gold_per_command) if is_finite(float(amount)) else 0

	var system := func(ctx: TickContext) -> void:
		var state := ctx.state
		for command: Dictionary in ctx.commands:
			var type: String = command["type"]
			if CHEAT_COMMAND_TYPES.has(type):
				state.cheated = true
			if state.rewards.screen != null and not REWARD_SCREEN_COMMAND_TYPES.has(type):
				continue
			match type:
				"spawnEnemy":
					EnemySystems.spawn_enemy(ctx, routes, enemies, command["enemyType"])
				"placeTower":
					TowerPlacement.place_tower(ctx, map, towers, command["towerType"],
							Vector2i(int(command["x"]), int(command["y"])), int(command.get("star", 1)))
				"buyTower":
					var cell: Variant = null
					if command.has("x") and command.has("y"):
						cell = Vector2i(int(command["x"]), int(command["y"]))
					Shop.buy_tower(ctx, map, towers, economy, nexus, int(command["slot"]), cell)
				"rerollShop":
					Shop.reroll_shop(ctx, towers, economy)
				"sellTower":
					Shop.sell_tower(ctx, economy, int(command["towerId"]))
				"moveTower":
					TowerMove.move_tower(ctx, map, int(command["towerId"]), Vector2i(int(command["x"]), int(command["y"])))
				"evolveNexus":
					NexusEvolve.evolve_nexus(ctx, nexus)
				"chooseReward":
					Rewards.choose_reward(ctx, rewards, int(command["index"]))
				"rerollRewards":
					Rewards.reroll_rewards(ctx, rewards, economy, classes, ticks_per_second)
				"debugOpenReward":
					# A tela abre no fim do tick (`create_reward_open_system`), ou depois da que estiver aberta.
					state.rewards.queue.append(state.wave)
				"callWave":
					WaveSystems.call_wave(ctx, schedules, enemies, economy)
				"endWave":
					WaveSystems.force_end_wave(ctx, schedules, economy, towers)
				"debugSkipToWave":
					WaveSystems.skip_to_wave(ctx, schedules, economy, towers, float(command["wave"]))
				"debugSpawnEnemies":
					var count: int = clamp_count.call(command["count"])
					for i in count:
						Stress.spawn_debug_enemy(ctx, routes, enemies, command["enemyType"], command["layout"])
				"debugSpawnTowers":
					var occupied := {}
					for t: Tower in state.towers:
						occupied[map.index_of(Vector2i(t.x, t.y))] = true
					var cells := TowerCells.pick_tower_cells(map, occupied, clamp_count.call(command["count"]), command["layout"])
					for tower_cell in cells:
						var tower_type := TowerCells.pattern_tower_type(command["towerTypes"], tower_cell)
						if tower_type != "":
							TowerPlacement.place_tower(ctx, map, towers, tower_type, tower_cell, int(command.get("star", 1)))
				"debugClear":
					state.enemies.release_all()
					state.projectiles.release_all()
					state.towers.clear()
					state.traps.clear()
					state.triggers.queue.clear()
					state.debug.stress = null
				"debugSetStress":
					var stress: Variant = command["stress"]
					state.debug.stress = null if stress == null else {
						"count": clamp_count.call(stress["count"]),
						"layout": stress["layout"],
					}
				"debugSetNexusInvulnerable":
					state.debug.nexus_invulnerable = command["value"]
				"debugAddGold":
					# Fora do ouro ganho da run (`stats.gold_earned`).
					state.gold += clamp_gold.call(command["amount"])
				"debugSetInfiniteGold":
					state.debug.infinite_gold = command["value"]
	return Simulation.runs_while_frozen(system)
