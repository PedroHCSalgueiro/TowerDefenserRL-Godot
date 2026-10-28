class_name Targeting
extends RefCounted
## Modos de mira das torres, escolhidos por dados (`targetMode` em `towers.json`) — porte
## de `targeting.ts`.
##
## Cada modo é só uma nota dada a cada inimigo dentro do alcance: vence a menor nota, com
## empate para o menor id (`SpatialIndex.find_best`). Um modo novo (T18) é uma nota nova
## aqui, sem mexer nas torres nem no índice.

const TARGET_MODES := ["first", "strongest"]


static func is_target_mode(value: Variant) -> bool:
	return TARGET_MODES.has(value)


## Monta as notas de cada modo: Dictionary modo -> Callable(enemy, from_x, from_y) -> float
## (menor é melhor).
## - `strongest`: o que tem mais vida no momento.
## - `first`: o mais avançado, ou seja, o que tem a menor distância que falta até o núcleo,
##   cada inimigo na sua própria rota (terrestre ou aérea).
static func create_target_scores(routes: Dictionary, enemies: EnemyData) -> Dictionary:
	var route_length := {}
	for id: String in enemies.types:
		route_length[id] = (routes[enemies.types[id].movement] as Route).length
	var remaining := func(enemy: Enemy, _from_x: float, _from_y: float) -> float:
		# Cada inimigo na rota da sua entrada (mapa que cresce); o comprimento vem do cache do spawn.
		if enemy.route != null:
			return enemy.route_length - enemy.distance
		if not route_length.has(enemy.type):
			push_error('Tipo de inimigo desconhecido: "%s"' % enemy.type)
			return INF
		return route_length[enemy.type] - enemy.distance
	# `strongest`: o inimigo com mais vida agora (a nota é a vida negativa; empate: menor id).
	var strongest := func(enemy: Enemy, _from_x: float, _from_y: float) -> float:
		return -enemy.hp
	return {"first": remaining, "strongest": strongest}
