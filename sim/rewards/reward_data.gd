class_name RewardData
extends RefCounted
## Recompensas de escolha (T24), lidas de `data/rewards.json`: em que ondas a tela
## aparece, quantas cartas, o tempo para escolher, o custo do reroll das cartas e
## a lista de bônus (porte de `rewardData.ts`).
##
## Cada bônus tem um efeito (`effect["kind"]`) com os números dele (Dictionary com as
## chaves do JSON). Os efeitos de classe (areaDamagePercent, triggerCountMinus,
## eliteKillWeight) valem para as torres da classe da carta (`class_id`). O coringa
## não tem classe nos dados: ela é sorteada quando a carta aparece.

class RewardDef:
	extends RefCounted
	var id: String
	var name: String
	## Frase da carta. No coringa, `{classe}` vira o nome da classe sorteada.
	var text: String
	## "class" | "economy" | "nexus" | "chain"
	var category: String
	## Classe da carta (cor e alvo dos efeitos de classe); null = sem classe fixa.
	var class_id: Variant = null
	## Pode sair de novo depois de escolhido.
	var repeatable: bool
	## {"kind": ..., + parâmetros}; números como float, contagens como int.
	var effect: Dictionary

## Ondas que dão a tela ao fechar, em ordem.
var waves: Array[int] = []
## Cartas por tela.
var choices: int
## Tempo para escolher; depois disso a simulação escolhe pelo RNG.
var choose_seconds: float
## Reroll das cartas: `reroll_base_cost` + `reroll_cost_step` × rerolls já feitos na tela.
var reroll_base_cost: int
var reroll_cost_step: int
## Na ordem do arquivo.
var rewards: Array[RewardDef] = []
var by_id: Dictionary = {}  # id -> RewardDef

const CATEGORIES := ["class", "economy", "nexus", "chain"]

## Parâmetros numéricos de cada efeito: inteiro ≥ 1 ("int") ou número > 0 ("positive").
const EFFECT_PARAMS := {
	"areaDamagePercent": {"percent": "positive"},
	"triggerCountMinus": {"amount": "int"},
	"activationCooldownSeconds": {"seconds": "positive"},
	"eliteKillWeight": {"multiplier": "positive"},
	"classWildcard": {"count": "int"},
	"interestCap": {"cap": "int"},
	"incomePerWave": {"gold": "int"},
	"freeRerollsPerShop": {"count": "int"},
	"towerDiscountPercent": {"percent": "positive"},
	"sellRefundPercent": {"percent": "positive"},
	"towerLimit": {"amount": "int"},
	"nexusMaxHp": {"amount": "int"},
	"nexusDamageMultiplier": {"multiplier": "positive"},
	"shopRarityLevels": {"levels": "int"},
	"chainGold": {"every": "int", "gold": "int"},
}

## Efeitos que valem só para as torres da classe da carta (precisam de `classId`).
const CLASS_SCOPED := ["areaDamagePercent", "triggerCountMinus", "eliteKillWeight"]

static var _default: RewardData = null


## Esquece os dados carregados (troca de conjunto de torres; ver `GameSets`).
static func reset_cache() -> void:
	_default = null


static func game_data() -> RewardData:
	if _default == null:
		_default = load_data(DataLoader.load_json("rewards.json"))
	return _default


static func _fail(message: String) -> void:
	push_error("Dados de recompensas inválidos: %s" % message)


static func _is_int(v: Variant, min_value: int) -> bool:
	return SimMap._is_integer(v) and int(v) >= min_value


static func _is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


static func load_data(raw: Variant, classes: ClassData = null) -> RewardData:
	if classes == null:
		classes = ClassData.game_data()
	if not (raw is Dictionary):
		_fail("não é um objeto")
		return null
	var waves_raw: Variant = raw.get("waves")
	if not (waves_raw is Array) or not waves_raw.all(func(w: Variant) -> bool: return _is_int(w, 1)):
		_fail('"waves" precisa ser uma lista de ondas (inteiros ≥ 1)')
		return null
	for i in range(1, waves_raw.size()):
		if int(waves_raw[i]) <= int(waves_raw[i - 1]):
			_fail('"waves" fora de ordem')
			return null
	if not _is_int(raw.get("choices"), 1):
		_fail('"choices" precisa ser inteiro ≥ 1')
		return null
	var choose_seconds: Variant = raw.get("chooseSeconds")
	if not _is_num(choose_seconds) or not is_finite(float(choose_seconds)) or float(choose_seconds) <= 0.0:
		_fail('"chooseSeconds" precisa ser > 0')
		return null
	var reroll: Variant = raw.get("reroll")
	if not (reroll is Dictionary) or not _is_int(reroll.get("baseCost"), 0) or not _is_int(reroll.get("costStep"), 0):
		_fail('"reroll" precisa de baseCost e costStep inteiros ≥ 0')
		return null
	var rewards_raw: Variant = raw.get("rewards")
	if not (rewards_raw is Dictionary) or rewards_raw.is_empty():
		_fail('"rewards" precisa ter pelo menos um bônus')
		return null

	var data := RewardData.new()
	for w in waves_raw:
		data.waves.append(int(w))
	data.choices = int(raw["choices"])
	data.choose_seconds = float(choose_seconds)
	data.reroll_base_cost = int(reroll["baseCost"])
	data.reroll_cost_step = int(reroll["costStep"])
	for id: String in rewards_raw:
		var reward := _parse_reward(id, rewards_raw[id], classes)
		if reward == null:
			return null
		data.rewards.append(reward)
		data.by_id[id] = reward
	return data


static func _parse_effect(where: String, raw: Variant) -> Dictionary:
	if not (raw is Dictionary) or typeof(raw.get("kind")) != TYPE_STRING or not EFFECT_PARAMS.has(raw["kind"]):
		_fail('%s: "effect.kind" desconhecido' % where)
		return {}
	var params: Dictionary = EFFECT_PARAMS[raw["kind"]]
	var extra: Array = raw.keys().filter(func(k: String) -> bool: return k != "kind" and not params.has(k))
	if not extra.is_empty():
		_fail("%s: campos desconhecidos no efeito: %s" % [where, ", ".join(extra)])
		return {}
	var effect := {"kind": raw["kind"]}
	for name: String in params:
		var rule: String = params[name]
		var value: Variant = raw.get(name)
		var ok := _is_int(value, 1) if rule == "int" else (_is_num(value) and is_finite(float(value)) and float(value) > 0.0)
		if not ok:
			_fail('%s: "%s" precisa ser %s' % [where, name, "inteiro ≥ 1" if rule == "int" else "> 0"])
			return {}
		effect[name] = int(value) if rule == "int" else float(value)
	if raw["kind"] == "towerDiscountPercent" and effect["percent"] >= 100.0:
		_fail("%s: o desconto precisa ser menor que 100%%" % where)
		return {}
	return effect


static func _parse_reward(id: String, raw: Variant, classes: ClassData) -> RewardDef:
	var where := '"%s"' % id
	if not (raw is Dictionary):
		_fail("%s não é um objeto" % where)
		return null
	if typeof(raw.get("name")) != TYPE_STRING or raw["name"] == "":
		_fail('%s precisa de "name"' % where)
		return null
	if typeof(raw.get("text")) != TYPE_STRING or raw["text"] == "":
		_fail('%s precisa de "text"' % where)
		return null
	if not CATEGORIES.has(raw.get("category")):
		_fail('%s: "category" precisa ser %s' % [where, ", ".join(CATEGORIES)])
		return null
	if typeof(raw.get("repeatable")) != TYPE_BOOL:
		_fail('%s: "repeatable" precisa ser verdadeiro ou falso' % where)
		return null
	var class_id: Variant = raw.get("classId", null)
	if class_id != null and (typeof(class_id) != TYPE_STRING or not classes.ids.has(class_id)):
		_fail('%s: "classId" não é uma classe dos dados' % where)
		return null
	var effect := _parse_effect(where, raw.get("effect"))
	if effect.is_empty():
		return null
	if CLASS_SCOPED.has(effect["kind"]) and class_id == null:
		_fail('%s: o efeito "%s" precisa de "classId"' % [where, effect["kind"]])
		return null
	if effect["kind"] == "classWildcard" and (class_id != null or raw["category"] != "class"):
		_fail('%s: o coringa é da categoria "class" e não tem "classId" (a classe é sorteada)' % where)
		return null
	var reward := RewardDef.new()
	reward.id = id
	reward.name = raw["name"]
	reward.text = raw["text"]
	reward.category = raw["category"]
	reward.class_id = class_id
	reward.repeatable = raw["repeatable"]
	reward.effect = effect
	return reward


## Bônus pelo id; desconhecido: push_error + null.
func get_reward(id: String) -> RewardDef:
	if not by_id.has(id):
		push_error('Recompensa desconhecida: "%s"' % id)
		return null
	return by_id[id]
