class_name ClassSystems
extends RefCounted
## Sistema de classes, o último do tick: conta as torres diferentes de cada classe no mapa
## e atualiza o nível de bônus em `state.classes` (porte de `classes/systems.ts`).
##
## Conta tipos de torre, não torres: cópias não somam, e fundir (que mantém o tipo) nunca
## reduz o bônus. As duas classes de cada torre contam, mais o coringa das recompensas (T24).
## Como roda depois de tudo, o bônus muda no tick seguinte à mudança das torres.


## Torres diferentes de cada classe e o nível ativo, para um conjunto de tipos no mapa. É a
## contagem do sistema e da prévia de classes da loja (T16). `wildcards`: torres a mais por
## classe (coringa das recompensas, T24); elas contam para o nível, mas não entram em
## `members`. Devolve id -> {"members": Array[String], "level": int}.
static func count_classes(types: Array, towers: TowerData, classes: ClassData, wildcards: Dictionary = {}) -> Dictionary:
	var unique := {}
	for t in types:
		unique[t] = true
	var sorted_types: Array = unique.keys()
	sorted_types.sort()
	var result := {}
	for id in classes.ids:
		var members: Array[String] = []
		for t: String in sorted_types:
			if towers.get_type(t).classes.has(id):
				members.append(t)
		var count := members.size() + int(wildcards.get(id, 0))
		var level := 0
		for l: ClassData.ClassLevel in classes.classes[id].levels:
			if count >= l.count:
				level += 1
		result[id] = {"members": members, "level": level}
	return result


## Devolve o sistema (Callable). Roda também congelado (T24): o coringa escolhido na tela
## já muda o nível.
static func create_class_system(towers: TowerData, classes: ClassData) -> Callable:
	return Simulation.runs_while_frozen(func(ctx: TickContext) -> void:
		var state := ctx.state
		var wildcards := RewardMods.of(state).wildcards
		var types: Array = state.towers.map(func(t: Tower) -> String: return t.type)
		var counted := count_classes(types, towers, classes, wildcards)
		for id in classes.ids:
			var status: ClassState.ClassStatus = state.classes[id]
			var members: Array[String] = counted[id]["members"]
			var level: int = counted[id]["level"]
			status.members = members
			if level != status.level:
				var previous_level := status.level
				status.level = level
				ctx.emit({
					"type": "classLevelChanged",
					"tick": state.tick,
					"classId": id,
					"level": level,
					"previousLevel": previous_level,
					"count": members.size() + int(wildcards.get(id, 0)),
				}))
