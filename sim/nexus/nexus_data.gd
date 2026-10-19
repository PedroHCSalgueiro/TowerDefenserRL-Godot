class_name NexusData
extends RefCounted
## Números do núcleo, lidos de `data/nexus.json` (porte de `nexusData.ts`). O alcance é em
## casas, medido do centro do núcleo até a posição do inimigo.

## Um nível do núcleo. `cost` é o ouro para chegar nele (o nível 1 é o início).
class NexusLevel:
	extends RefCounted
	var cost: int
	var tower_limit: int
	var max_hp: int

	func _init(p_cost: int = 0, p_tower_limit: int = 0, p_max_hp: int = 0) -> void:
		cost = p_cost
		tower_limit = p_tower_limit
		max_hp = p_max_hp

## Níveis depois da tabela (T22, núcleo sem teto): cada nível custa o custo do anterior ×
## `cost_multiplier` (arredondado) e soma `tower_limit_per_level` ao limite de torres e
## `max_hp_per_level` à vida máxima. Sem teto.
class NexusGrowth:
	extends RefCounted
	var cost_multiplier: float
	var tower_limit_per_level: int
	var max_hp_per_level: int

## `levels[n - 1]` é o nível `n`. Sem `beyond_levels`, o último é o máximo.
var levels: Array[NexusLevel] = []
## Níveis depois da tabela, sem teto (null = a tabela é o máximo).
var beyond_levels: NexusGrowth = null
var attack_damage: float
var attack_cooldown_seconds: float
var attack_range: float

static var _default: NexusData = null


## Esquece os dados carregados (troca de conjunto de torres; ver `GameSets`).
static func reset_cache() -> void:
	_default = null


static func game_data() -> NexusData:
	if _default == null:
		_default = load_data(DataLoader.load_json("nexus.json"))
	return _default


static func _is_positive(v: Variant) -> bool:
	return (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) and is_finite(float(v)) and float(v) > 0.0


static func _is_level(v: Variant) -> bool:
	return v is Dictionary and SimMap._is_integer(v.get("cost")) and float(v["cost"]) >= 0.0 \
			and SimMap._is_integer(v.get("towerLimit")) and _is_positive(v["towerLimit"]) \
			and SimMap._is_integer(v.get("maxHp")) and _is_positive(v["maxHp"])


## Valida os dados do núcleo. Inválido: push_error + null.
static func load_data(raw: Variant) -> NexusData:
	var attack: Variant = raw.get("attack") if raw is Dictionary else null
	if not (raw is Dictionary) or not (raw.get("levels") is Array) or raw["levels"].is_empty() \
			or not raw["levels"].all(func(l: Variant) -> bool: return _is_level(l)) \
			or not (attack is Dictionary) or not _is_positive(attack.get("damage")) \
			or not _is_positive(attack.get("cooldownSeconds")) or not _is_positive(attack.get("range")):
		push_error("Dados do núcleo inválidos: campos ausentes ou não positivos")
		return null
	var growth: Variant = raw.get("beyondLevels")
	if growth != null and (not (growth is Dictionary) or not _is_positive(growth.get("costMultiplier")) \
			or not SimMap._is_integer(growth.get("towerLimitPerLevel")) or float(growth["towerLimitPerLevel"]) < 0.0 \
			or not SimMap._is_integer(growth.get("maxHpPerLevel")) or float(growth["maxHpPerLevel"]) < 0.0):
		push_error('Dados do núcleo inválidos: "beyondLevels" com campos ausentes ou negativos')
		return null
	var data := NexusData.new()
	for l in raw["levels"]:
		data.levels.append(NexusLevel.new(int(l["cost"]), int(l["towerLimit"]), int(l["maxHp"])))
	if growth != null:
		data.beyond_levels = NexusGrowth.new()
		data.beyond_levels.cost_multiplier = float(growth["costMultiplier"])
		data.beyond_levels.tower_limit_per_level = int(growth["towerLimitPerLevel"])
		data.beyond_levels.max_hp_per_level = int(growth["maxHpPerLevel"])
	data.attack_damage = float(attack["damage"])
	data.attack_cooldown_seconds = float(attack["cooldownSeconds"])
	data.attack_range = float(attack["range"])
	return data


## Nível máximo: o último da tabela, ou INF com `beyond_levels`.
func max_level() -> float:
	return INF if beyond_levels != null else float(levels.size())


## Dados do nível `level` (preso em 1 e no máximo). Depois da tabela, com `beyond_levels`,
## cada nível sai do anterior pela fórmula.
func level_data(level: int) -> NexusLevel:
	var wanted := int(minf(float(maxi(1, level)), max_level()))
	if wanted <= levels.size():
		return levels[wanted - 1]
	var last := levels[levels.size() - 1]
	var cost := last.cost
	var tower_limit := last.tower_limit
	var max_hp := last.max_hp
	for n in range(levels.size() + 1, wanted + 1):
		cost = SimMath.js_round(float(cost) * beyond_levels.cost_multiplier)
		tower_limit += beyond_levels.tower_limit_per_level
		max_hp += beyond_levels.max_hp_per_level
	return NexusLevel.new(cost, tower_limit, max_hp)


## Limite de torres no mapa no nível `level`.
func tower_limit_at(level: int) -> int:
	return level_data(level).tower_limit
