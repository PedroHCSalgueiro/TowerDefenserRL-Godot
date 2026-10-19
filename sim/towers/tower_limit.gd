class_name TowerLimit
extends RefCounted
## Limite de torres no mapa (T12). Contam todas as torres, inclusive as de debug; uma torre
## fundida conta como 1. O limite só barra a compra que precisa de casa nova: fusão e o
## posicionamento cru do debug passam. O bônus "Mais espaço" das recompensas (T24) soma ao
## limite do nível (porte de `limit.ts`). Estados sem `rewards` valem sem recompensas.


## Torres no mapa agora.
static func tower_count(state: Object) -> int:
	return state.towers.size()


## Limite de torres do nível atual do núcleo.
static func current_tower_limit(state: Object, nexus: NexusData = null) -> int:
	if nexus == null:
		nexus = NexusData.game_data()
	return nexus.tower_limit_at(state.nexus.level) + RewardMods.of(state).tower_limit


## Cabe mais uma torre no mapa (que não seja fusão)?
static func has_room_for_tower(state: Object, nexus: NexusData = null) -> bool:
	return tower_count(state) < current_tower_limit(state, nexus)
