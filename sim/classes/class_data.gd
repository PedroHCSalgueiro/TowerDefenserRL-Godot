class_name ClassData
extends RefCounted
## Classes das torres e seus bônus, lidos de `data/classes.json` (porte de `classData.ts`).
##
## Cada classe tem uma lista de níveis, do menor para o maior. Um nível vale
## quando o mapa tem `count` torres diferentes com a classe (ver `ClassBonuses`).
## Os campos de efeito que um nível não cita ficam neutros (multiplicador 1,
## redução 0, raio 0), para o código multiplicar sem checar null.

class ClassLevel:
	extends RefCounted
	## Torres diferentes com a classe para o nível valer.
	var count: int
	## Texto do nível, mostrado na interface.
	var text: String
	## Artilharia: multiplica o raio da área do ataque normal e das explosões de gatilho.
	var area_radius_multiplier := 1.0
	## Artilharia: multiplica o dano da área do ataque normal e das explosões de gatilho.
	var area_damage_multiplier := 1.0
	## Mecânica: reduz, em %, a contagem dos gatilhos "a cada N".
	var trigger_count_reduction_percent := 0.0
	## Arcana: raio, em casas, da vizinhança quadrada (0 = vizinhança dos dados).
	var neighborhood_radius := 0
	## Sombria: multiplica o peso das mortes nos gatilhos das torres da classe.
	var kill_weight_multiplier := 1.0
	## Sombria: quais mortes o multiplicador atinge: "sameClass" ou "any".
	var kill_weight_from := "sameClass"
	## Região (Reino de Valcoroa): % de velocidade de ataque e % de dano das torres da classe.
	var attack_speed_percent := 0.0
	var damage_percent := 0.0
	## Região: a torre com uma vizinha ortogonal da mesma classe recebe esses bônus em dobro.
	var double_with_neighbors := false
	## Guardião: % a mais na intensidade do Lento dos Guardiões (30% com +20% = 36%).
	var slow_bonus_percent := 0.0
	## Guardião: casas a mais no Empurrado dos Guardiões (o teto do elite e a imunidade do chefão continuam).
	var push_bonus_cells := 0.0
	## Guardião: % a menos no dano que o núcleo recebe dos inimigos que chegam nele (vale para todos).
	var nexus_damage_reduction_percent := 0.0
	## Caçador: % de dano a mais por marca no alvo, nos tiros dos Caçadores.
	var mark_damage_percent := 0.0
	## Região (Costa Rubra): ouro a mais no teto dos juros; baú de ouro no fim de cada onda; vagas a mais na loja.
	var interest_cap_bonus := 0
	var wave_end_gold := 0
	var shop_extra_slots := 0

class TowerClass:
	extends RefCounted
	var name: String
	## Do menor para o maior `count`.
	var levels: Array[ClassLevel] = []

const LEVEL_KEYS := ["count", "text", "areaRadiusMultiplier", "areaDamageMultiplier",
		"triggerCountReductionPercent", "neighborhoodRadius", "killWeightMultiplier", "killWeightFrom",
		"attackSpeedPercent", "damagePercent", "doubleWithNeighbors", "slowBonusPercent", "pushBonusCells",
		"nexusDamageReductionPercent", "markDamagePercent", "interestCapBonus", "waveEndGold", "shopExtraSlots"]

## Mecânica: a contagem de um "a cada N" nunca cai abaixo disto.
var min_trigger_count: int
## Teto do peso de uma morte depois do bônus da Sombria.
var max_kill_weight: int
var classes: Dictionary = {}  # id -> TowerClass
## Algum nível de alguma classe dá velocidade de ataque / dano (senão os cálculos são pulados).
var has_attack_speed_bonus := false
var has_damage_bonus := false
## Ids das classes, na ordem do arquivo.
var ids: Array[String] = []

static var _default: ClassData = null


## Esquece os dados carregados (troca de conjunto de torres; ver `GameSets`).
static func reset_cache() -> void:
	_default = null


## Dados do jogo (data/classes.json), carregados uma vez.
static func game_data() -> ClassData:
	if _default == null:
		_default = load_data(DataLoader.load_json("classes.json"))
	return _default


static func _is_integer(v: Variant) -> bool:
	return SimMap._is_integer(v)


static func _is_positive_integer(v: Variant) -> bool:
	return _is_integer(v) and v > 0


static func _fail(message: String) -> Variant:
	push_error(message)
	return null


## Valida os dados de classes. Dado inválido: push_error + null.
static func load_data(raw: Variant) -> ClassData:
	if not (raw is Dictionary) or not (raw.get("classes") is Dictionary):
		_fail('Dados de classes inválidos: falta "classes"')
		return null
	if not _is_positive_integer(raw.get("minTriggerCount")) or raw["minTriggerCount"] < 2:
		_fail('Dados de classes inválidos: "minTriggerCount" precisa ser inteiro ≥ 2')
		return null
	if not _is_positive_integer(raw.get("maxKillWeight")) or raw["maxKillWeight"] < 2:
		_fail('Dados de classes inválidos: "maxKillWeight" precisa ser inteiro ≥ 2')
		return null
	var entries: Dictionary = raw["classes"]
	if entries.is_empty():
		_fail("Dados de classes inválidos: nenhuma classe definida")
		return null
	var data := ClassData.new()
	data.min_trigger_count = int(raw["minTriggerCount"])
	data.max_kill_weight = int(raw["maxKillWeight"])
	for id: String in entries:
		var tower_class := _parse_class(id, entries[id])
		if tower_class == null:
			return null
		data.classes[id] = tower_class
		data.ids.append(id)
		for level: ClassLevel in tower_class.levels:
			data.has_attack_speed_bonus = data.has_attack_speed_bonus or level.attack_speed_percent > 0.0
			data.has_damage_bonus = data.has_damage_bonus or level.damage_percent > 0.0
	return data


static func _parse_class(id: String, raw: Variant) -> TowerClass:
	if not (raw is Dictionary) or typeof(raw.get("name")) != TYPE_STRING or raw["name"] == "":
		_fail('Classe inválida: "%s" precisa de um nome' % id)
		return null
	if not (raw.get("levels") is Array):
		_fail('Classe inválida: "%s" precisa de "levels" (pode ser vazio)' % id)
		return null
	var tower_class := TowerClass.new()
	tower_class.name = raw["name"]
	var index := 0
	for level_raw in raw["levels"]:
		var level := _parse_level(id, index, level_raw)
		if level == null:
			return null
		tower_class.levels.append(level)
		index += 1
	for i in range(1, tower_class.levels.size()):
		if tower_class.levels[i].count <= tower_class.levels[i - 1].count:
			_fail('Classe inválida: "%s" tem níveis fora de ordem (count crescente)' % id)
			return null
	return tower_class


## Campo numérico opcional: neutro se ausente. Inválido: push_error e devolve NAN.
static func _optional(where: String, raw: Dictionary, key: String, neutral: float,
		valid: Callable, rule: String) -> float:
	if not raw.has(key):
		return neutral
	var value: Variant = raw[key]
	if (typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT) or not is_finite(float(value)) \
			or not valid.call(float(value)):
		push_error('%s: "%s" precisa ser %s (%s)' % [where, key, rule, value])
		return NAN
	return float(value)


static func _parse_level(class_id: String, index: int, raw: Variant) -> ClassLevel:
	var where := 'Classe inválida: "%s", nível %d' % [class_id, index + 1]
	if not (raw is Dictionary):
		_fail("%s: não é um objeto" % where)
		return null
	var extra: Array = raw.keys().filter(func(k: String) -> bool: return not LEVEL_KEYS.has(k))
	if not extra.is_empty():
		_fail("%s: campos desconhecidos: %s" % [where, ", ".join(extra)])
		return null
	if not _is_positive_integer(raw.get("count")):
		_fail('%s: "count" precisa ser inteiro ≥ 1' % where)
		return null
	if typeof(raw.get("text")) != TYPE_STRING or raw["text"] == "":
		_fail('%s: "text" precisa ser um texto' % where)
		return null
	if raw.has("doubleWithNeighbors") and typeof(raw["doubleWithNeighbors"]) != TYPE_BOOL:
		_fail('%s: "doubleWithNeighbors" precisa ser verdadeiro ou falso' % where)
		return null
	var from: Variant = raw.get("killWeightFrom", "sameClass")
	if from != "sameClass" and from != "any":
		_fail('%s: "killWeightFrom" precisa ser "sameClass" ou "any"' % where)
		return null
	var level := ClassLevel.new()
	level.count = int(raw["count"])
	level.text = raw["text"]
	level.area_radius_multiplier = _optional(where, raw, "areaRadiusMultiplier", 1.0,
			func(v: float) -> bool: return v > 0.0, "> 0")
	level.area_damage_multiplier = _optional(where, raw, "areaDamageMultiplier", 1.0,
			func(v: float) -> bool: return v > 0.0, "> 0")
	level.trigger_count_reduction_percent = _optional(where, raw, "triggerCountReductionPercent", 0.0,
			func(v: float) -> bool: return v >= 0.0 and v < 100.0, "de 0 a menos de 100")
	var speed := _optional(where, raw, "attackSpeedPercent", 0.0, func(v: float) -> bool: return v >= 0.0, "≥ 0")
	var damage_bonus := _optional(where, raw, "damagePercent", 0.0, func(v: float) -> bool: return v >= 0.0, "≥ 0")
	var radius := _optional(where, raw, "neighborhoodRadius", 0.0,
			func(v: float) -> bool: return floorf(v) == v and v >= 1.0, "inteiro ≥ 1")
	level.kill_weight_multiplier = _optional(where, raw, "killWeightMultiplier", 1.0,
			func(v: float) -> bool: return v >= 1.0, "≥ 1")
	var non_negative := func(v: float) -> bool: return v >= 0.0
	var whole := func(v: float) -> bool: return v >= 0.0 and floorf(v) == v
	level.slow_bonus_percent = _optional(where, raw, "slowBonusPercent", 0.0, non_negative, "≥ 0")
	level.push_bonus_cells = _optional(where, raw, "pushBonusCells", 0.0, non_negative, "≥ 0")
	level.nexus_damage_reduction_percent = _optional(where, raw, "nexusDamageReductionPercent", 0.0,
			func(v: float) -> bool: return v >= 0.0 and v < 100.0, "de 0 a menos de 100")
	level.mark_damage_percent = _optional(where, raw, "markDamagePercent", 0.0, non_negative, "≥ 0")
	var interest_cap := _optional(where, raw, "interestCapBonus", 0.0, whole, "inteiro ≥ 0")
	var wave_end_gold := _optional(where, raw, "waveEndGold", 0.0, whole, "inteiro ≥ 0")
	var shop_slots := _optional(where, raw, "shopExtraSlots", 0.0, whole, "inteiro ≥ 0")
	if is_nan(level.area_radius_multiplier) or is_nan(level.area_damage_multiplier) \
			or is_nan(level.trigger_count_reduction_percent) or is_nan(radius) \
			or is_nan(level.kill_weight_multiplier) or is_nan(speed) or is_nan(damage_bonus) \
			or is_nan(level.slow_bonus_percent) or is_nan(level.push_bonus_cells) \
			or is_nan(level.nexus_damage_reduction_percent) or is_nan(level.mark_damage_percent) \
			or is_nan(interest_cap) or is_nan(wave_end_gold) or is_nan(shop_slots):
		return null
	level.interest_cap_bonus = int(interest_cap)
	level.wave_end_gold = int(wave_end_gold)
	level.shop_extra_slots = int(shop_slots)
	level.attack_speed_percent = speed
	level.damage_percent = damage_bonus
	level.double_with_neighbors = raw.get("doubleWithNeighbors", false)
	level.neighborhood_radius = int(radius)
	level.kill_weight_from = from
	return level
