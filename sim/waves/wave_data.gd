class_name WaveData
extends RefCounted
## Ondas da run, lidas de `data/waves.json` (porte de `waveData.ts`).
##
## Cada onda é uma fila única e contínua: um inimigo a cada `spawn_seconds`, na ordem da lista
## `enemies` (grupos em sequência, sem pausas e sem sorteio). Um grupo com `elite: true` traz a
## versão elite do tipo (ver `EnemyData.elite_*`). `hp_multiplier` multiplica a vida de todos os
## inimigos da onda, menos os chefões (que têm valores próprios).

class WaveGroup:
	extends RefCounted
	var type: String
	var count: int
	var elite: bool

class WaveDef:
	extends RefCounted
	var hp_multiplier: float
	## Segundos entre um inimigo e o próximo da fila.
	var spawn_seconds: float
	var enemies: Array[WaveGroup] = []

## Trava de segurança: com tantos inimigos ativos, os próximos esperam na entrada, na ordem, e
## nascem quando abrir espaço (fila invisível).
var max_active_enemies: int
var waves: Array[WaveDef] = []

static var _default: WaveData = null


static func game_data() -> WaveData:
	if _default == null:
		_default = load_data(DataLoader.load_json("waves.json"), EnemyData.game_data())
	return _default


static func _is_positive(v: Variant) -> bool:
	return (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) and is_finite(float(v)) and float(v) > 0.0


static func _fail(message: String) -> WaveData:
	push_error("Ondas inválidas: %s" % message)
	return null


static func _parse_groups(where: String, raw: Variant, enemies: EnemyData) -> Array[WaveGroup]:
	var out: Array[WaveGroup] = []
	if not (raw is Array) or raw.is_empty():
		push_error('Ondas inválidas: %s precisa de "enemies" com pelo menos um grupo' % where)
		return out
	for group in raw:
		if not (group is Dictionary):
			push_error("Ondas inválidas: grupo de %s não é um objeto" % where)
			return []
		var type: Variant = group.get("type")
		if typeof(type) != TYPE_STRING or not enemies.types.has(type):
			push_error('Ondas inválidas: %s usa o inimigo desconhecido "%s"' % [where, type])
			return []
		if not SimMap._is_integer(group.get("count")) or int(group["count"]) <= 0:
			push_error("Ondas inválidas: %s tem quantidade que não é inteiro positivo" % where)
			return []
		var elite: Variant = group.get("elite", false)
		if typeof(elite) != TYPE_BOOL:
			push_error('Ondas inválidas: %s tem "elite" que não é verdadeiro ou falso' % where)
			return []
		if elite and enemies.types[type].boss:
			push_error("Ondas inválidas: %s marca um chefão como elite" % where)
			return []
		var g := WaveGroup.new()
		g.type = type
		g.count = int(group["count"])
		g.elite = elite
		out.append(g)
	return out


## Valida as ondas contra os tipos de inimigo. Erro claro (push_error + null) em vez de onda vazia
## no meio da run.
static func load_data(raw: Variant, enemies: EnemyData) -> WaveData:
	if not (raw is Dictionary) or not (raw.get("waves") is Array):
		return _fail('falta "waves"')
	if raw.has("timing"):
		return _fail('formato antigo (pulsos e "timing"); use "spawnSeconds"')
	if not SimMap._is_integer(raw.get("maxActiveEnemies")) or int(raw["maxActiveEnemies"]) < 1:
		return _fail('"maxActiveEnemies" precisa ser inteiro >= 1')
	if raw["waves"].is_empty():
		return _fail("nenhuma onda definida")
	var data := WaveData.new()
	data.max_active_enemies = int(raw["maxActiveEnemies"])
	for i in raw["waves"].size():
		var wave: Variant = raw["waves"][i]
		var where := "a onda %d" % (i + 1)
		if not (wave is Dictionary) or not _is_positive(wave.get("hpMultiplier")) or not _is_positive(wave.get("spawnSeconds")):
			return _fail('%s precisa de "hpMultiplier" e "spawnSeconds"' % where)
		if wave.has("pulses"):
			return _fail("%s usa pulsos (formato antigo)" % where)
		var groups := _parse_groups(where, wave.get("enemies"), enemies)
		if groups.is_empty():
			return null
		var def := WaveDef.new()
		def.hp_multiplier = float(wave["hpMultiplier"])
		def.spawn_seconds = float(wave["spawnSeconds"])
		def.enemies = groups
		data.waves.append(def)
	return data
