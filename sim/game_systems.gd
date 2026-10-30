class_name GameSystems
extends RefCounted
## Lista dos sistemas da partida, na ordem em que rodam a cada tick (porte de `systems.ts`):
## relógio da recompensa → ações → tempo esgotado da recompensa → nascimentos das ondas → reposição
## do estresse → movimento → chegada ao núcleo → ataque do núcleo → projéteis → torres → gatilhos →
## ouro → fim da onda → abertura da recompensa → classes.
##
## Com a tela de recompensa aberta (T24), o tick é congelado: só rodam os sistemas da recompensa, as
## ações, o ouro e as classes (`Simulation.runs_while_frozen`).
##
## Todo spawn acontece antes do movimento e toda busca por alvo depois dele: é o que permite montar
## o índice espacial uma única vez por tick. O índice é compartilhado pelo núcleo, pelos projéteis
## (troca de alvo e área), pelas torres e pelos gatilhos.
##
## O sistema de estados (Lento, Atordoado, Sangramento) e o de armadilhas rodam depois das torres e só entram
## se algum tipo de torre aplica estado (`TowerData.uses_statuses`) ou põe armadilha (`uses_traps`).
##
## Os gatilhos enxergam todos os tiros e abates do tick; o ouro dos abates é somado depois deles, e
## só então a onda pode fechar (os juros já contam o ouro do último abate). As classes rodam por
## último: o bônus muda no tick seguinte a posicionar, vender ou fundir.


## `options` (Dictionary, todas opcionais; o padrão são os dados do jogo): enemies, nexus, towers,
## classes, debug, economy, waves, rewards, expansion (os objetos *Data) e ticksPerSecond (float).
## O mapa que cresce (`Expansion`) só entra se `map` for o mapa dele (`ExpansionData.build_map`).
static func create(map: SimMap, options: Dictionary = {}) -> Array:
	var enemies: EnemyData = options.get("enemies", EnemyData.game_data())
	var nexus: NexusData = options.get("nexus", NexusData.game_data())
	var towers: TowerData = options.get("towers", TowerData.game_data())
	var classes: ClassData = options.get("classes", ClassData.game_data())
	var debug: SimDebugData = options.get("debug", SimDebugData.game_data())
	var economy: EconomyData = options.get("economy", EconomyData.game_data())
	var waves: WaveData = options.get("waves", WaveData.game_data())
	var rewards: RewardData = options.get("rewards", RewardData.game_data())
	var expansion := ExpansionData.for_map(map, options.get("expansion", ExpansionData.game_data()))
	var engine := EngineData.config()
	var ticks_per_second: float = options.get("ticksPerSecond", float(engine["ticksPerSecond"]))
	var routes := Route.build_routes(map)
	var index := SpatialIndex.new(float(engine["spatialCellSize"]))
	var scores := Targeting.create_target_scores(routes, enemies)
	var schedules := WaveSchedule.build_wave_schedules(waves, ticks_per_second)
	var systems: Array = [
		# O índice espacial e as classes no contexto do tick (o dano da Maldição procura os vizinhos pelo índice;
		# o bônus do Controlador e as durações dos estados leem as classes).
		Simulation.runs_while_frozen(func(ctx: TickContext) -> void:
			ctx.index = index
			ctx.classes = classes
			ctx.routes = routes
			ctx.towers = towers
			ctx.ticks_per_second = ticks_per_second
			ctx.afflicted_damage_percent = ClassBonuses.afflicted_damage_percent(classes, ctx.state)
			ctx.death_blast = ClassBonuses.death_blast(classes, ctx.state)
			ctx.skeleton_rise = ClassBonuses.skeleton_rise(classes, ctx.state)
			if classes.has_armor_pierce:
				for tower: Tower in ctx.state.towers:
					var pierce := ClassBonuses.armor_pierce(classes, ctx.state, towers.get_type(tower.type))
					if pierce > 0.0:
						ctx.armor_pierce[tower.id] = pierce),
		Rewards.create_reward_clock_system(),
		Expansion.create_clock_system() if expansion != null else Callable(),
		Commands.create_command_system(map, routes, enemies, towers, debug, schedules, economy, nexus,
				rewards, classes, ticks_per_second),
		Expansion.create_command_system(map, routes, expansion) if expansion != null else Callable(),
		Rewards.create_reward_timeout_system(rewards),
		Expansion.create_timeout_system(map, routes, expansion) if expansion != null else Callable(),
		WaveSystems.create_wave_spawn_system(routes, enemies, schedules, waves.max_active_enemies, map),
		Stress.create_stress_system(routes, enemies),
		EnemySystems.create_movement_system(routes, enemies, ticks_per_second),
		NexusSystems.create_nexus_contact_system(routes, enemies, classes),
		NexusSystems.create_nexus_attack_system(map.nexus, enemies, nexus, ticks_per_second, index),
		ProjectileSystems.create_projectile_system(enemies, index, towers.projectile_retarget_radius, ticks_per_second, towers,
				classes),
		TowerSystems.create_tower_system(index, towers, scores, ticks_per_second, classes, routes),
		Status.create_status_system(enemies) if towers.uses_statuses() else Callable(),
		TrapSystems.create_trap_system(enemies, index, routes, ticks_per_second) if towers.uses_traps() else Callable(),
		TriggerEngine.create_trigger_system({
			"index": index, "enemies": enemies, "towers": towers, "classes": classes,
			"scores": scores, "ticksPerSecond": ticks_per_second, "routes": routes, "map": map,
		}),
		Economy.create_gold_system(enemies, economy),
		WaveSystems.create_wave_progress_system(enemies, schedules, economy, towers),
		Rewards.create_reward_open_system(rewards, economy, classes, ticks_per_second),
		Expansion.create_open_system(map, routes, expansion, ticks_per_second) if expansion != null else Callable(),
		ClassSystems.create_class_system(towers, classes),
	]
	return systems.filter(func(system: Callable) -> bool: return system.is_valid())
