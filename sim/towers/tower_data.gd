class_name TowerData
extends RefCounted
## Tipos de torre, lidos de `data/towers.json` (porte de `towerData.ts`).
##
## Alcance e raio são em casas, medidos do centro da casa da torre (ou do ponto de impacto)
## até a posição do inimigo. `projectile_speed` é em casas por segundo. `trigger` é o gatilho
## da torre (null = sem gatilho), no formato de `TriggerData`; `triggers` traz as regras de
## segurança do motor.

## Raridade para a loja (T10). Torres de teste não têm (null).
const RARITIES := ["common", "uncommon", "rare", "legendary"]
## Cada torre tem exatamente 2 classes (Mini-GDD, Sistema 1).
const CLASSES_PER_TOWER := 2

class TowerType:
	extends RefCounted
	var name: String
	## null = torre de teste: fora da loja e da contagem de classes.
	var rarity: Variant = null
	## Duas classes diferentes, a primeira é a principal (cor no greybox); ou nenhuma, nas
	## torres de teste.
	var classes: Array[String] = []
	## false = não atira (o Espelho): `damage` e `range` só servem aos efeitos copiados.
	var attacks := true
	var damage: float
	## 0 se a torre não atira.
	var shots_per_second: float
	var range: float
	var projectile_speed: float
	## Tiro único ({"kind": "single"}), em área ({"kind": "area", "radius": float}) ou armadilha
	## ({"kind": "trap", "radius", "damagePercent", "maxTraps"}: estrepes no caminho, sem projétil).
	var shot: Dictionary
	var target_mode: String
	## TriggerData.TriggerDef ou null.
	var trigger: TriggerData.TriggerDef = null
	## Efeitos de estado que os tiros da torre aplicam no acerto (vazio = nenhum):
	## {"slow": {"percent", "cap", "seconds", "bounces", "bounceRadius"}, "bleed": {"percentPerSecond", "seconds"}}.
	var on_hit: Dictionary = {}
	## Aura passiva nas vizinhas (vazio = nenhuma):
	## {"region": String, "stars": [{"attackSpeedPercent", "regionPercent"}, ...]} (índice 0 = ★1).
	var aura: Dictionary = {}
	## Todo acerto dos tiros da torre deixa o alvo Marcado (a torre é da classe que marca: o Caçador).
	var marks := false
	## Passiva com números por estrela (vazio = nenhuma): {"kind": "phalanx" | "judgment", "stars": [...]}.
	## "phalanx" (Hoplita Dorian): +`percent`% de dano por vizinha ortogonal da classe `class`.
	## "judgment" (Sigrun): +`percent`% de dano contra inimigo Marcado ou chefão.
	## Cada estrela pode trazer `attackDamagePercent`, como os gatilhos.
	var passive: Dictionary = {}
	## Área que cresce com as almas da onda (Golem de Ossos): {"percentPer10": float, "maxPercent": float}.
	var soul_radius: Dictionary = {}

## Raio, em casas, em que o projétil procura um alvo novo quando o dele some.
var projectile_retarget_radius: float
var triggers: TriggerData.TriggerRules
## Regras gerais dos efeitos de estado (bloco opcional `statuses` de `towers.json`):
## "mark": {"class": id, "seconds": float} — a classe cujos tiros marcam e a duração da marca ({} = sem marca);
## "push": {"eliteMaxCells": float, "bossImmune": bool} — o Empurrado no elite e no chefão.
var statuses: Dictionary = {"mark": {}, "push": {"eliteMaxCells": 1.0, "bossImmune": true}}
## Movimento das invocações que andam (bloco opcional `summons` de `towers.json`):
## "skeleton": {"speed", "seconds", "contactRadius", "blastRadius"}.
var summons: Dictionary = {}
## Alguma aura dá alcance (Sacerdotisa Amunet)? Sem isso, o alcance não olha as vizinhas.
var has_range_auras := false
## id -> TowerType, na ordem do JSON.
var types: Dictionary = {}

static var _default: TowerData = null


## Algum tipo aplica efeito de estado (Lento, Atordoado, Sangramento)? Sem isso, o sistema de estados
## nem entra na lista de sistemas (o conjunto Padrão não paga nada por ele).
func uses_statuses() -> bool:
	for id: String in types:
		var type: TowerType = types[id]
		if not type.on_hit.is_empty() or type.marks:
			return true
		if type.trigger != null:
			for star in type.trigger.stars:
				if TriggerData.STATUS_EFFECTS.has(star.effect["kind"]):
					return true
	return false


## Algum tipo põe armadilhas (tiro "trap", o efeito "trap" ou o tentáculo da Nerea, que vive no mesmo
## sistema)? Sem isso, o sistema de armadilhas não entra.
func uses_traps() -> bool:
	for id: String in types:
		var type: TowerType = types[id]
		if type.shot["kind"] == "trap":
			return true
		if type.trigger != null:
			for star in type.trigger.stars:
				if TriggerData.SUMMON_EFFECTS.has(star.effect["kind"]):
					return true
	return false


## Algum tipo tem aura?
func has_auras() -> bool:
	for id: String in types:
		if not (types[id] as TowerType).aura.is_empty():
			return true
	return false


## Esquece os dados carregados (troca de conjunto de torres; ver `GameSets`).
static func reset_cache() -> void:
	_default = null


static func game_data() -> TowerData:
	if _default == null:
		_default = load_data(DataLoader.load_json("towers.json"))
	return _default


static func _is_positive(v: Variant) -> bool:
	return (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) and is_finite(float(v)) and float(v) > 0.0


## Valida os dados das torres. Erro claro (push_error + null) em vez de NaN no meio da run.
static func load_data(raw: Variant, classes: ClassData = null) -> TowerData:
	if classes == null:
		classes = ClassData.game_data()
	if not (raw is Dictionary) or not (raw.get("types") is Dictionary):
		push_error('Dados de torres inválidos: falta "types"')
		return null
	if not _is_positive(raw.get("projectileRetargetRadius")):
		push_error('Dados de torres inválidos: "projectileRetargetRadius" precisa ser positivo')
		return null
	if raw["types"].is_empty():
		push_error("Dados de torres inválidos: nenhum tipo definido")
		return null
	var data := TowerData.new()
	data.projectile_retarget_radius = float(raw["projectileRetargetRadius"])
	if raw.has("statuses"):
		var statuses: Variant = _parse_statuses(raw["statuses"], classes)
		if statuses == null:
			return null
		data.statuses = statuses
	var mark_class: String = data.statuses["mark"].get("class", "")
	for id: String in raw["types"]:
		var type := _parse_type(id, raw["types"][id], classes)
		if type == null:
			return null
		type.marks = mark_class != "" and type.classes.has(mark_class)
		data.types[id] = type
		if not type.aura.is_empty():
			for star: Dictionary in type.aura["stars"]:
				data.has_range_auras = data.has_range_auras or star["rangeBonus"] > 0.0
	var summons: Variant = raw.get("summons", {})
	if not (summons is Dictionary):
		push_error('Dados de torres inválidos: "summons" não é um objeto')
		return null
	if summons.has("skeleton"):
		var s: Variant = summons["skeleton"]
		if not (s is Dictionary) or not _is_positive(s.get("speed")) or not _is_positive(s.get("seconds")) \
				or not _is_positive(s.get("contactRadius")) or not _is_positive(s.get("blastRadius")) \
				or not _is_positive(s.get("maxPerTower")) or not _is_positive(s.get("maxRegion")):
			push_error('Dados de torres inválidos: "summons.skeleton" precisa de speed, seconds, contactRadius, blastRadius, maxPerTower e maxRegion positivos')
			return null
		data.summons["skeleton"] = {"speed": float(s["speed"]), "seconds": float(s["seconds"]),
				"contactRadius": float(s["contactRadius"]), "blastRadius": float(s["blastRadius"]),
				"maxPerTower": int(s["maxPerTower"]), "maxRegion": int(s["maxRegion"])}
	data.triggers = TriggerData.parse_trigger_rules(raw.get("triggers"))
	if data.triggers == null:
		return null
	return data


## Bloco `statuses`: {"mark": {"class", "seconds"}?, "push": {"eliteMaxCells", "bossImmune"}?}. Devolve o
## Dictionary completo (com os padrões) ou null (push_error).
static func _parse_statuses(raw: Variant, classes: ClassData) -> Variant:
	var out := {"mark": {}, "push": {"eliteMaxCells": 1.0, "bossImmune": true}}
	if not (raw is Dictionary):
		push_error('Dados de torres inválidos: "statuses" não é um objeto')
		return null
	var mark: Variant = raw.get("mark")
	if mark != null:
		if not (mark is Dictionary) or typeof(mark.get("class")) != TYPE_STRING or not classes.classes.has(mark["class"]) \
				or not _is_positive(mark.get("seconds")):
			push_error('Dados de torres inválidos: "statuses.mark" precisa de "class" existente e "seconds" positivo')
			return null
		out["mark"] = {"class": mark["class"], "seconds": float(mark["seconds"])}
	var push: Variant = raw.get("push")
	if push != null:
		if not (push is Dictionary) or not _is_positive(push.get("eliteMaxCells")) or typeof(push.get("bossImmune")) != TYPE_BOOL:
			push_error('Dados de torres inválidos: "statuses.push" precisa de "eliteMaxCells" positivo e "bossImmune"')
			return null
		out["push"] = {"eliteMaxCells": float(push["eliteMaxCells"]), "bossImmune": push["bossImmune"]}
	return out


## `onHit` opcional: slow {percent, cap, seconds, bounces?, bounceRadius?}, bleed {percentPerSecond, seconds} e
## pierce {targets, radius}.
## Devolve o Dictionary normalizado ({} sem efeitos) ou null (push_error).
static func _parse_on_hit(id: String, raw: Variant) -> Variant:
	if raw == null:
		return {}
	var out := {}
	var bad := func(why: String) -> Variant:
		push_error('Torre inválida: "%s" tem "onHit" inválido (%s)' % [id, why])
		return null
	if not (raw is Dictionary) or raw.is_empty():
		return bad.call("precisa de slow e/ou bleed")
	for key: String in raw:
		var spec: Variant = raw[key]
		if not (spec is Dictionary):
			return bad.call("%s não é um objeto" % key)
		match key:
			"slow":
				if not (_is_positive(spec.get("percent")) and float(spec["percent"]) < 100.0 and _is_positive(spec.get("cap"))
						and float(spec["cap"]) < 100.0 and _is_positive(spec.get("seconds"))):
					return bad.call("slow precisa de percent e cap (0 a 100, exclusive) e seconds positivos")
				var bounces := int(spec.get("bounces", 0))
				if bounces < 0 or (bounces > 0 and not _is_positive(spec.get("bounceRadius"))):
					return bad.call("slow com bounces precisa de bounceRadius positivo")
				out["slow"] = {"percent": float(spec["percent"]), "cap": float(spec["cap"]),
						"seconds": float(spec["seconds"]), "bounces": bounces,
						"bounceRadius": float(spec.get("bounceRadius", 0.0))}
			"bleed":
				if not (_is_positive(spec.get("percentPerSecond")) and _is_positive(spec.get("seconds"))):
					return bad.call("bleed precisa de percentPerSecond e seconds positivos")
				out["bleed"] = {"percentPerSecond": float(spec["percentPerSecond"]), "seconds": float(spec["seconds"])}
			"pierce":
				# O tiro atravessa: depois do alvo, acerta até `targets` inimigos logo atrás dele (até `radius` casas).
				if not (_is_positive(spec.get("targets")) and _is_positive(spec.get("radius"))):
					return bad.call("pierce precisa de targets e radius positivos")
				out["pierce"] = {"targets": int(spec["targets"]), "radius": float(spec["radius"])}
			_:
				return bad.call("efeito desconhecido: %s" % key)
	return out


## `aura` opcional: {"region": id, "stars": [{"attackSpeedPercent"?, "regionPercent"?, "rangeBonus"?}, ...]}:
## cada estrela dá velocidade de ataque e/ou alcance (em casas) às vizinhas.
static func _parse_aura(id: String, raw: Variant) -> Variant:
	if raw == null:
		return {}
	if not (raw is Dictionary) or typeof(raw.get("region")) != TYPE_STRING or not (raw.get("stars") is Array) \
			or raw["stars"].is_empty() or raw["stars"].size() > TriggerData.MAX_STARS:
		push_error('Torre inválida: "%s" tem "aura" inválida (region e de 1 a %d stars)' % [id, TriggerData.MAX_STARS])
		return null
	var stars: Array = []
	for star in raw["stars"]:
		var valid: bool = star is Dictionary and (_is_positive(star.get("attackSpeedPercent")) or _is_positive(star.get("rangeBonus")))
		for key in ["attackSpeedPercent", "regionPercent", "rangeBonus"]:
			valid = valid and (not star.has(key) or _is_positive(star[key]))
		if not valid:
			push_error('Torre inválida: "%s" tem estrela de aura inválida' % id)
			return null
		stars.append({"attackSpeedPercent": float(star.get("attackSpeedPercent", 0.0)),
				"regionPercent": float(star.get("regionPercent", 0.0)), "rangeBonus": float(star.get("rangeBonus", 0.0))})
	return {"region": raw["region"], "stars": stars}


## `passive` opcional: {"kind": "phalanx" | "judgment", "stars": [{"percent", "class"?, "attackDamagePercent"?}]}.
static func _parse_passive(id: String, raw: Variant, classes: ClassData) -> Variant:
	if raw == null:
		return {}
	if not (raw is Dictionary) or not ["phalanx", "judgment"].has(raw.get("kind")) or not (raw.get("stars") is Array) \
			or raw["stars"].is_empty() or raw["stars"].size() > TriggerData.MAX_STARS:
		push_error('Torre inválida: "%s" tem "passive" inválida (kind phalanx ou judgment e de 1 a %d stars)' % [id, TriggerData.MAX_STARS])
		return null
	var stars: Array = []
	for star in raw["stars"]:
		if not (star is Dictionary) or not _is_positive(star.get("percent")) \
				or (star.has("attackDamagePercent") and not _is_positive(star["attackDamagePercent"])) \
				or (raw["kind"] == "phalanx" and (typeof(star.get("class")) != TYPE_STRING or not classes.classes.has(star["class"]))):
			push_error('Torre inválida: "%s" tem estrela de passiva inválida' % id)
			return null
		stars.append({"percent": float(star["percent"]), "class": star.get("class", ""),
				"attackDamagePercent": float(star.get("attackDamagePercent", 100.0))})
	return {"kind": raw["kind"], "stars": stars}


static func _parse_shot(id: String, raw: Variant) -> Dictionary:
	if raw is Dictionary and raw.get("kind") == "single":
		return {"kind": "single"}
	if raw is Dictionary and raw.get("kind") == "area" and _is_positive(raw.get("radius")):
		return {"kind": "area", "radius": float(raw["radius"])}
	if raw is Dictionary and raw.get("kind") == "trap" and _is_positive(raw.get("radius")) \
			and _is_positive(raw.get("damagePercent")) and _is_positive(raw.get("maxTraps")):
		return {"kind": "trap", "radius": float(raw["radius"]), "damagePercent": float(raw["damagePercent"]),
				"maxTraps": int(raw["maxTraps"])}
	push_error('Torre inválida: "%s" tem "shot" inválido (single, area com radius > 0, ou trap com radius, damagePercent e maxTraps)' % id)
	return {}


static func _parse_classes(id: String, raw: Variant, classes: ClassData) -> Variant:
	# Torre de teste (Básica, Canhão): sem classe.
	if raw is Array and raw.is_empty():
		return [] as Array[String]
	var valid: bool = raw is Array and raw.size() == CLASSES_PER_TOWER
	if valid:
		var seen := {}
		for c in raw:
			if typeof(c) != TYPE_STRING or not classes.classes.has(c) or seen.has(c):
				valid = false
			seen[c] = true
	if not valid:
		push_error('Torre inválida: "%s" precisa de %d classes diferentes e existentes (ou nenhuma, se for torre de teste)' % [id, CLASSES_PER_TOWER])
		return null
	var out: Array[String] = []
	for c in raw:
		out.append(c)
	return out


static func _parse_type(id: String, raw: Variant, classes: ClassData) -> TowerType:
	if not (raw is Dictionary):
		push_error('Torre inválida: "%s" não é um objeto' % id)
		return null
	var attacks: Variant = raw.get("attacks", true)
	if typeof(attacks) != TYPE_BOOL:
		push_error('Torre inválida: "%s" tem "attacks" que não é verdadeiro ou falso' % id)
		return null
	# Sem ataque não há cadência; a velocidade do projétil continua valendo para os efeitos copiados.
	var shots_per_second: Variant = raw.get("shotsPerSecond") if attacks else 0
	if typeof(raw.get("name")) != TYPE_STRING or raw["name"] == "" or not _is_positive(raw.get("damage")) \
			or not _is_positive(raw.get("range")) or not _is_positive(raw.get("projectileSpeed")) \
			or (attacks and not _is_positive(shots_per_second)):
		push_error('Torre inválida: "%s" tem campos ausentes ou não positivos' % id)
		return null
	if not Targeting.is_target_mode(raw.get("targetMode")):
		push_error('Torre inválida: "%s" tem modo de mira desconhecido (%s)' % [id, raw.get("targetMode")])
		return null
	if not raw.has("trigger"):
		push_error('Torre inválida: "%s" não tem "trigger" (use null para torre sem gatilho)' % id)
		return null
	var tower_classes: Variant = _parse_classes(id, raw.get("classes"), classes)
	if tower_classes == null:
		return null
	var rarity: Variant = raw.get("rarity")
	var rarity_ok: bool = (rarity == null) if tower_classes.is_empty() else RARITIES.has(rarity)
	if not rarity_ok:
		push_error('Torre inválida: "%s" precisa de raridade (%s); torre de teste, sem classes, usa null' % [id, ", ".join(RARITIES)])
		return null
	var shot := _parse_shot(id, raw.get("shot"))
	if shot.is_empty():
		return null
	var parsed := TriggerData.parse_trigger(id, raw["trigger"])
	if not parsed["ok"]:
		return null
	var on_hit: Variant = _parse_on_hit(id, raw.get("onHit"))
	if on_hit == null:
		return null
	var aura: Variant = _parse_aura(id, raw.get("aura"))
	if aura == null:
		return null
	var passive: Variant = _parse_passive(id, raw.get("passive"), classes)
	if passive == null:
		return null
	var soul: Variant = raw.get("soulRadius", {})
	if not (soul is Dictionary) or (not soul.is_empty() and not (_is_positive(soul.get("percentPer10")) and _is_positive(soul.get("maxPercent")))):
		push_error('Torre inválida: "%s" tem "soulRadius" inválido (percentPer10 e maxPercent positivos)' % id)
		return null
	var type := TowerType.new()
	type.name = raw["name"]
	type.rarity = rarity
	type.classes = tower_classes
	type.attacks = attacks
	type.damage = float(raw["damage"])
	type.shots_per_second = float(shots_per_second)
	type.range = float(raw["range"])
	type.projectile_speed = float(raw["projectileSpeed"])
	type.shot = shot
	type.target_mode = raw["targetMode"]
	type.trigger = parsed["def"]
	type.on_hit = on_hit
	type.aura = aura
	type.passive = passive
	if not soul.is_empty():
		type.soul_radius = {"percentPer10": float(soul["percentPer10"]), "maxPercent": float(soul["maxPercent"])}
	return type


## O tipo existe?
func has_type(id: String) -> bool:
	return types.has(id)


## Tipo pelo id; desconhecido: push_error + null.
func get_type(id: String) -> TowerType:
	if not types.has(id):
		push_error('Tipo de torre desconhecido: "%s"' % id)
		return null
	return types[id]
