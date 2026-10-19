class_name ClassPanelModel
extends RefCounted
## Modelo do painel de classes: transforma o estado (`state.classes`) e os dados em linhas prontas
## para mostrar (porte de `classPanelModel.ts`). O coringa das recompensas (T24) entra na contagem
## e aparece como "Coringa" na lista de torres. Sem nós.

class Row:
	extends RefCounted
	var id := ""
	var name := ""
	## Torres diferentes com a classe no mapa, mais o coringa.
	var count := 0
	## Torres para o próximo nível; -1 se já está no último.
	var next := -1
	## Nível ativo (0 = nenhum).
	var level := 0
	## "Arcana 3/4" ou "Arcana 5 · máx."
	var label := ""
	## [{"count": int, "text": String, "active": bool}]
	var levels: Array = []
	## Nomes das torres que estão contando.
	var members: Array[String] = []


static func build_rows(class_state: Dictionary, classes: ClassData, towers: TowerData, wildcards: Dictionary = {}) -> Array[Row]:
	var wildcard_name: String = DataLoader.load_json("ui.json")["rewardScreen"]["wildcardMember"]
	var rows: Array[Row] = []
	for id in classes.ids:
		var data: ClassData.TowerClass = classes.classes[id]
		var status: ClassState.ClassStatus = class_state.get(id)
		var member_types: Array = status.members if status != null else []
		var extra := int(wildcards.get(id, 0))
		var row := Row.new()
		row.id = id
		row.name = data.name
		row.count = member_types.size() + extra
		row.level = status.level if status != null else 0
		for l in data.levels:
			if l.count > row.count:
				row.next = l.count
				break
		row.label = "%s %d · máx." % [data.name, row.count] if row.next < 0 else "%s %d/%d" % [data.name, row.count, row.next]
		for i in data.levels.size():
			row.levels.append({"count": data.levels[i].count, "text": data.levels[i].text, "active": row.level == i + 1})
		for type: String in member_types:
			row.members.append(towers.types[type].name if towers.types.has(type) else type)
		for i in extra:
			row.members.append(wildcard_name)
		rows.append(row)
	return rows


## Assinatura das linhas: a interface só mexe nos nós quando ela muda.
static func rows_key(rows: Array[Row]) -> String:
	var parts: Array[String] = []
	for r in rows:
		parts.append("%s:%d:%d:%s" % [r.id, r.level, r.count, ",".join(r.members)])
	return "|".join(parts)
