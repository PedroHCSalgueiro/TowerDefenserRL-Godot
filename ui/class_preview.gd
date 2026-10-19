class_name ClassPreview
extends RefCounted
## Prévia da compra na janela do slot da loja (T16): o que a compra muda nas classes ("Arcana 1/2
## → 2/2 (ativa nível 2)") ou, se funde, a estrela nova ("★2↑", e as classes não mudam). Usa a mesma
## `Fusion.plan_fusion` da compra e a mesma contagem de classes da simulação (porte de
## `classPreview.ts`). Sem nós.

## "★2↑" quando a compra funde ("" = não funde).
var fusion := ""
## Uma linha por classe do tipo, só quando a compra traz um tipo novo ao mapa.
var classes: Array[String] = []


## Contagem com `count` torres: "1/2" ou "4 · máx.".
static func _count_text(count: int, next: int, has_levels: bool = true) -> String:
	if next < 0:
		return "%d · máx." % count if has_levels else str(count)
	return "%d/%d" % [count, next]


## Prévia da compra de uma cópia de `tower_type` com as torres de agora. null quando a compra não
## muda nada visível (o tipo já está no mapa e não funde). `wildcards`: coringas das recompensas
## (T24), que entram na contagem.
static func preview(towers: Array, tower_type: String, data: TowerData, classes: ClassData,
		wildcards: Dictionary = {}) -> ClassPreview:
	var plan := Fusion.plan_fusion(towers, data, tower_type)
	if plan != null:
		var p := ClassPreview.new()
		p.fusion = "★%d↑" % plan.star
		return p
	for t: Tower in towers:
		if t.type == tower_type:
			return null

	var types: Array = towers.map(func(t: Tower) -> String: return t.type)
	var before := ClassSystems.count_classes(types, data, classes, wildcards)
	var with_new := types.duplicate()
	with_new.append(tower_type)
	var after := ClassSystems.count_classes(with_new, data, classes, wildcards)
	var result := ClassPreview.new()
	for id in data.get_type(tower_type).classes:
		var info: ClassData.TowerClass = classes.classes[id]
		var was: Dictionary = before[id]
		var will: Dictionary = after[id]
		var extra := int(wildcards.get(id, 0))
		var was_count: int = (was["members"] as Array).size() + extra
		# O mesmo alvo dos dois lados ("1/2 → 2/2"): o próximo nível a partir de agora.
		var next := -1
		for l in info.levels:
			if l.count > was_count:
				next = l.count
				break
		var lights := ""
		if will["level"] > was["level"]:
			lights = " (ativa nível %d)" % info.levels[will["level"] - 1].count
		var has_levels := not info.levels.is_empty()
		result.classes.append("%s %s → %s%s" % [info.name, _count_text(was_count, next, has_levels),
				_count_text((will["members"] as Array).size() + extra, next, has_levels), lights])
	return result


## Assinatura da prévia (a janela só refaz o texto quando ela muda).
static func key(p: ClassPreview) -> String:
	return "-" if p == null else "%s|%s" % [p.fusion, "|".join(p.classes)]
