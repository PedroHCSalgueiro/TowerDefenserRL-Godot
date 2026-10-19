class_name EnemyData
extends RefCounted
## Tipos de inimigo, lidos de `data/enemies.json` (porte de `enemyData.ts`).
##
## `speed` é em casas por segundo. Inimigos `ground` seguem o caminho; `air`
## vão em linha reta da entrada até o núcleo.
##
## `elite` vale para qualquer tipo marcado como elite numa onda: o inimigo
## mantém o tipo (armadura, movimento), com a vida multiplicada, a velocidade
## multiplicada e um dano próprio no núcleo.

class EnemyType:
	extends RefCounted
	var hp: float
	var speed: float
	var armor: float
	var nexus_damage: float
	var gold: float
	## "ground" ou "air".
	var movement: String
	## Chefão: imune à execução do Carrasco (que lhe dá um golpe crítico).
	var boss: bool = false

const MOVEMENTS := ["ground", "air"]

var armor_scale: float
## Multiplica a vida (por cima do multiplicador da onda).
var elite_hp_multiplier: float
var elite_speed_multiplier: float
## Dano no núcleo do elite, no lugar do `nexus_damage` do tipo.
var elite_nexus_damage: float
## id -> EnemyType, na ordem do JSON.
var types: Dictionary = {}

static var _default: EnemyData = null


## Dados do jogo (data/enemies.json), carregados uma vez.
static func game_data() -> EnemyData:
	if _default == null:
		_default = load_data(DataLoader.load_json("enemies.json"))
	return _default


static func _is_number(v: Variant, min_value: float, allow_min: bool = true) -> bool:
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
		return false
	var f := float(v)
	return is_finite(f) and (f >= min_value if allow_min else f > min_value)


## Valida os dados de inimigos. Erro claro (push_error + null) em vez de NaN no meio da run.
static func load_data(raw: Variant) -> EnemyData:
	if not (raw is Dictionary) or not (raw.get("armor") is Dictionary) \
			or not (raw.get("elite") is Dictionary) or not (raw.get("types") is Dictionary):
		push_error('Dados de inimigos inválidos: faltam "armor", "elite" ou "types"')
		return null
	var elite: Dictionary = raw["elite"]
	if not _is_number(elite.get("hpMultiplier"), 0, false) \
			or not _is_number(elite.get("speedMultiplier"), 0, false) \
			or not _is_number(elite.get("nexusDamage"), 0):
		push_error('Dados de inimigos inválidos: "elite" tem campos ausentes ou fora do intervalo')
		return null
	if not _is_number(raw["armor"].get("scale"), 0, false):
		push_error('Dados de inimigos inválidos: "armor.scale" precisa ser positivo')
		return null
	var raw_types: Dictionary = raw["types"]
	if raw_types.is_empty():
		push_error("Dados de inimigos inválidos: nenhum tipo definido")
		return null

	var data := EnemyData.new()
	data.armor_scale = float(raw["armor"]["scale"])
	data.elite_hp_multiplier = float(elite["hpMultiplier"])
	data.elite_speed_multiplier = float(elite["speedMultiplier"])
	data.elite_nexus_damage = float(elite["nexusDamage"])
	for id: String in raw_types:
		var type := _parse_type(id, raw_types[id])
		if type == null:
			return null
		data.types[id] = type
	return data


static func _parse_type(id: String, raw: Variant) -> EnemyType:
	if not (raw is Dictionary):
		push_error('Inimigo inválido: "%s" não é um objeto' % id)
		return null
	if not _is_number(raw.get("hp"), 0, false) or not _is_number(raw.get("speed"), 0, false) \
			or not _is_number(raw.get("armor"), 0) or not _is_number(raw.get("nexusDamage"), 0) \
			or not _is_number(raw.get("gold"), 0) \
			or typeof(raw.get("movement")) != TYPE_STRING or not MOVEMENTS.has(raw["movement"]):
		push_error('Inimigo inválido: "%s" tem campos ausentes ou fora do intervalo' % id)
		return null
	var boss: Variant = raw.get("boss", false)
	if typeof(boss) != TYPE_BOOL:
		push_error('Inimigo inválido: "%s" tem "boss" que não é verdadeiro ou falso' % id)
		return null
	var type := EnemyType.new()
	type.hp = float(raw["hp"])
	type.speed = float(raw["speed"])
	type.armor = float(raw["armor"])
	type.nexus_damage = float(raw["nexusDamage"])
	type.gold = float(raw["gold"])
	type.movement = raw["movement"]
	type.boss = boss
	return type


## Tipo pelo id; id desconhecido: push_error + null.
func get_type(id: String) -> EnemyType:
	if not types.has(id):
		push_error('Tipo de inimigo desconhecido: "%s"' % id)
		return null
	return types[id]


## Velocidade do inimigo em casas por segundo (a do tipo, ou reduzida no elite).
func enemy_speed(type: EnemyType, elite: bool) -> float:
	return type.speed * elite_speed_multiplier if elite else type.speed


## Dano no núcleo de quem chega (o do tipo, ou o do elite).
func enemy_nexus_damage(type: EnemyType, elite: bool) -> float:
	return elite_nexus_damage if elite else type.nexus_damage
