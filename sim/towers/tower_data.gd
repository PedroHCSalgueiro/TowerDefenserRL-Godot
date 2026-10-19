class_name TowerData
extends RefCounted
## Tipos de torre, lidos de `data/towers.json` (porte de `towerData.ts`).
##
## Alcance e raio são em casas, medidos do centro da casa da torre (ou do ponto de impacto)
## até a posição do inimigo. `projectile_speed` é em casas por segundo. `trigger` é o gatilho
## da torre (null = sem gatilho), no formato de `TriggerData`; `triggers` traz as regras de
## segurança do motor.

## Raridade para a loja (T10). Torres de teste não têm (null).
const RARITIES := ["common", "uncommon", "rare"]
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
	## Tiro único ({"kind": "single"}) ou em área ({"kind": "area", "radius": float}).
	var shot: Dictionary
	var target_mode: String
	## TriggerData.TriggerDef ou null.
	var trigger: TriggerData.TriggerDef = null

## Raio, em casas, em que o projétil procura um alvo novo quando o dele some.
var projectile_retarget_radius: float
var triggers: TriggerData.TriggerRules
## id -> TowerType, na ordem do JSON.
var types: Dictionary = {}

static var _default: TowerData = null


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
	for id: String in raw["types"]:
		var type := _parse_type(id, raw["types"][id], classes)
		if type == null:
			return null
		data.types[id] = type
	data.triggers = TriggerData.parse_trigger_rules(raw.get("triggers"))
	if data.triggers == null:
		return null
	return data


static func _parse_shot(id: String, raw: Variant) -> Dictionary:
	if raw is Dictionary and raw.get("kind") == "single":
		return {"kind": "single"}
	if raw is Dictionary and raw.get("kind") == "area" and _is_positive(raw.get("radius")):
		return {"kind": "area", "radius": float(raw["radius"])}
	push_error('Torre inválida: "%s" tem "shot" inválido (single, ou area com radius > 0)' % id)
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
