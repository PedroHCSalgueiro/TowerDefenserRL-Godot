class_name TriggerData
extends RefCounted
## Formato dos gatilhos em dados (`trigger` de cada torre em `towers.json`) e as
## regras de segurança do motor (bloco `triggers` do mesmo arquivo) — porte de
## `triggerData.ts`.
##
## Um gatilho é **quando** (`when`) + **o quê** (`do`) + **parâmetros por estrela**
## (`stars`, índice 0 = ★1). Cada entrada de `stars` traz, num objeto só, os
## parâmetros do "quando" e os do "o quê"; os nomes nunca se repetem entre os dois.
## O carregador expande isso em um Dictionary por estrela, com `"kind"` e os
## parâmetros já tipados (contagem = int, número = float, flag = bool).
##
## Para criar um "quando" ou um "o quê" novo: uma linha nas tabelas abaixo mais o
## código no motor (`TriggerEngine` ou `TriggerEffects`). Torre nova com gatilho
## existente é só dado.

## Estrelas possíveis (Mini-GDD, Sistema 4): de ★1 a ★5.
const MAX_STARS := 5

# Parâmetro: nome, tipo ("count" = inteiro ≥ 1, "positive" = número > 0, "flag" = bool),
# teto inclusivo opcional (porcentagens de vida) e valor padrão (sem ele, é obrigatório).
static func _count(p_name: String, fallback: Variant = null) -> Dictionary:
	return {"name": p_name, "kind": "count", "fallback": fallback}


static func _positive(p_name: String, max_value: Variant = null, fallback: Variant = null) -> Dictionary:
	return {"name": p_name, "kind": "positive", "max": max_value, "fallback": fallback}


static func _flag(p_name: String) -> Dictionary:
	return {"name": p_name, "kind": "flag", "fallback": false}


static var WHEN_PARAMS := {
	## Completa N tiros (normais ou de ativação).
	"everyNShots": [_count("shots")],
	## Um inimigo morre dentro do alcance (qualquer autor).
	"enemyDiesInRange": [],
	## A torre dispara (tiro normal ou de ativação).
	"onFire": [],
	## A torre é ativada por uma vizinha.
	"onActivated": [],
	## Uma vizinha abate (abate duplo conta 2).
	"neighborKills": [],
	## Completa N abates dentro do alcance (qualquer autor; abate duplo conta 2).
	"everyNKillsInRange": [_count("kills")],
	## A cada N segundos (o relógio da torre anda a cada tick; pausa com a tela de recompensa).
	"everyNSeconds": [_positive("seconds")],
	## A própria torre abate um inimigo (abate duplo conta 1). `markedOnly`: só se ele estava Marcado.
	"ownKill": [_flag("markedOnly")],
}

## Parâmetros de cada "o quê". Porcentagens de dano são do dano da torre.
## Os que têm valor padrão são opcionais nos dados (0 e false = desligado).
static var DO_PARAMS := {
	## `spread`: cada tiro extra vai para um alvo diferente, na ordem de mira (dando a volta).
	"multiShot": [_count("extraShots"), _flag("spread")],
	## `killWeight`: quanto as mortes da explosão valem nos contadores de abate.
	"explosion": [_positive("radius"), _positive("damagePercent"), _count("killWeight", 1)],
	## Sem `maxTargets` (0), ativa todas as vizinhas da vizinhança atual.
	## `activatedDamagePercent`: dano do tiro ativado. `reach`: soma a cruz de alcance N
	## à vizinhança. `selfToo`: a torre também ativa a si mesma.
	"activateNeighbors": [_count("maxTargets", 0), _positive("activatedDamagePercent", null, 100),
			_count("reach", 0), _flag("selfToo")],
	## `activateOnDischarge`: ao soltar o raio, ativa as vizinhas.
	"chargeLightning": [_count("charges"), _count("targets"), _positive("jumpRadius"),
			_positive("damagePercent"), _flag("activateOnDischarge")],
	## `unlimited`: a linha atravessa o mapa (comprimento `unlimitedLineLength`). `maxTargets`: só os N
	## primeiros da fila levam o dano (0 = todos).
	"pierceLine": [_positive("halfWidth"), _positive("damagePercent"), _flag("unlimited"), _count("maxTargets", 0)],
	## `bossMaxHpPercent`: o chefão nunca é executado; abaixo do limite de vida, leva um
	## golpe de tantos % da vida máxima por disparo (0 = sem golpe). `explodeRadius` e
	## `explodeDamagePercent` (juntos): cada execução explode.
	"execute": [_positive("hpPercent", 100), _count("killWeight"), _positive("bossMaxHpPercent", 100, 0),
			_positive("explodeRadius", null, 0), _positive("explodeDamagePercent", null, 0)],
	## `powerPercent`: escala o dano do efeito copiado. `copies`: quantos efeitos copia.
	"copyLast": [_positive("powerPercent", null, 100), _count("copies", 1)],
	## Atordoa os `count` inimigos mais à frente da fila, no alcance, por `seconds`.
	"stunFront": [_count("count"), _positive("seconds")],
	## Tiro em área do alvo normal, com o raio ×`radiusMultiplier` e `damagePercent`% do dano.
	"empoweredShot": [_positive("radiusMultiplier"), _positive("damagePercent")],
	## Atordoa por `stunSeconds` os inimigos no alcance que já estão Lentos.
	"stunSlowed": [_positive("stunSeconds")],
	## Raio de luz nos `count` inimigos mais à frente (pelo modo "first") dentro do alcance, cada um com
	## `damagePercent`% do dano da torre. Com `slowPercent`, deixa cada um Lento (o Lento da Rainha Isolde:
	## soma até `slowCap`, por `slowSeconds`).
	"frontBeam": [_count("count"), _positive("damagePercent"), _positive("slowPercent", 100, 0),
			_positive("slowCap", 100, 0), _positive("slowSeconds", null, 0)],
	## Põe uma armadilha de urso no caminho: o inimigo que pisa fica preso `holdSeconds` e sangra
	## `damagePercent`% do dano da torre por segundo. No máximo `maxTraps` dessas por torre.
	"trap": [_positive("holdSeconds"), _positive("damagePercent"), _count("maxTraps")],
	## Bala que quica (Bart): `impacts` impactos, o primeiro no alvo normal e cada quique no inimigo mais
	## perto do impacto anterior (até `jumpRadius`) que a bala ainda não atingiu. Cada impacto é uma área de
	## raio `radius` com `damagePercent`% do dano; a cada quique, raio e dano ficam em `falloffPercent`%.
	"bounceShot": [_count("impacts"), _positive("radius"), _positive("damagePercent"), _positive("falloffPercent", 100),
			_positive("jumpRadius")],
	## Âncora: prende o primeiro da fila no alcance e o empurra `cells` casas para trás; o inimigo colado
	## atrás dele (até `gap` casas no caminho) vai junto.
	"anchorPush": [_count("cells"), _positive("gap")],
	## Maré (Morgana): uma onda da torre até o limite do alcance; cada inimigo terrestre no caminho leva
	## `damagePercent`% do dano e fica Lento (`slowPercent`, até `slowCap`, por `slowSeconds`).
	"tide": [_positive("damagePercent"), _positive("slowPercent", 100), _positive("slowCap", 100), _positive("slowSeconds")],
	## Tentáculo (Nerea): numa casa do caminho no alcance (onde houver mais inimigos; empate, o mais à
	## frente) agarra os terrestres no raio `radius`: Atordoa por `stunSeconds` (chefão imune, elite
	## `eliteStunPercent`% do tempo) e causa `damagePercent`% do dano por segundo por `damageSeconds`.
	"tentacle": [_positive("radius"), _positive("stunSeconds"), _positive("eliteStunPercent", 100),
			_positive("damagePercent"), _positive("damageSeconds")],
	## Guarda `gold` de ouro para o fim da onda. `maxPerWave`: teto por torre a cada onda (0 = sem teto).
	"loot": [_count("gold"), _count("maxPerWave", 0)],
	## O próximo ataque normal sai com dois tiros: o segundo `delaySeconds` depois, no alvo da hora.
	"doubleShot": [_positive("delaySeconds")],
	## O próximo ataque amaldiçoa o alvo por `seconds`: ele divide `sharePercent`% do dano que recebe com os
	## `spread` inimigos mais próximos (até `radius` casas) e, ao morrer, a Maldição pula para eles (no
	## máximo `jumps` saltos).
	"curseNext": [_positive("seconds"), _positive("sharePercent", 100), _count("spread"), _positive("radius"),
			_count("jumps")],
}

## "O quê" que aplicam efeitos de estado: precisam do sistema de estados.
const STATUS_EFFECTS := ["stunFront", "stunSlowed", "trap", "tide", "tentacle", "curseNext"]
## "O quê" que só contam como visíveis na cadeia quando fazem alguma coisa (acertam alguém, guardam ouro):
## sem ninguém para atordoar, o gatilho não aparece na cadeia. Armar o próximo tiro não é visível.
const LAZY_EFFECTS := ["stunFront", "stunSlowed", "trap", "tide", "tentacle", "curseNext", "bounceShot",
		"anchorPush", "loot", "doubleShot"]

## Parâmetro de estrela que vale para qualquer gatilho: multiplica o dano do ataque
## normal da torre (e, com ele, tudo que é % do dano dela).
static var STAR_PARAMS := [_positive("attackDamagePercent", null, 100)]

## Um gatilho numa estrela: "quando" e "o quê" já com os números.
class TriggerStar:
	extends RefCounted
	## {"kind": "everyNShots", "shots": 5, ...}
	var when: Dictionary
	## {"kind": "multiShot", "extraShots": 2, "spread": false, ...}
	var effect: Dictionary
	## % do dano do ataque normal da torre nesta estrela (100 = sem mudança).
	var attack_damage_percent: float = 100.0

class TriggerDef:
	extends RefCounted
	## Índice 0 = ★1. De 1 a 5 entradas.
	var stars: Array[TriggerStar] = []

## Regras de segurança do motor, iguais para todas as torres.
class TriggerRules:
	extends RefCounted
	## Vizinhas de uma torre: 4 (lados) ou 8 (com diagonais).
	var neighborhood: int
	## Cada torre só pode ser ativada por gatilho uma vez a cada tantos segundos.
	var activation_cooldown_seconds: float
	## Comprimento, em casas, das linhas "sem limite" (maior que qualquer mapa).
	var unlimited_line_length: float
	## Profundidade de cadeia processada por tick; o resto continua no tick seguinte.
	var max_chain_depth_per_tick: int
	## Entradas da fila processadas por tick; o resto continua no tick seguinte.
	var max_activations_per_tick: int
	## Teto da fila: entradas novas acima dele são descartadas (e contadas).
	var max_queue_size: int

static var WHEN_KINDS: Array = WHEN_PARAMS.keys()
static var EFFECT_KINDS: Array = DO_PARAMS.keys()


static func _valid_param(spec: Dictionary, value: Variant) -> bool:
	if spec["kind"] == "flag":
		return typeof(value) == TYPE_BOOL
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var f := float(value)
	if not is_finite(f) or f <= 0.0:
		return false
	if spec["kind"] == "count" and floorf(f) != f:
		return false
	return spec.get("max") == null or f <= float(spec["max"])


## Valor tipado de um parâmetro (count = int, positive = float, flag = bool).
static func _typed(spec: Dictionary, value: Variant) -> Variant:
	match spec["kind"]:
		"count":
			return int(value)
		"positive":
			return float(value)
	return value


## Lê os parâmetros de `specs` de uma entrada de estrela, em {"kind": kind, ...params}.
## Parâmetro inválido: push_error e devolve {} (vazio).
static func _pick(where: String, kind: String, specs: Array, raw: Dictionary) -> Dictionary:
	var out := {"kind": kind}
	for spec: Dictionary in specs:
		var p_name: String = spec["name"]
		if not raw.has(p_name) and spec.get("fallback") != null:
			out[p_name] = _typed(spec, spec["fallback"])
			continue
		var value: Variant = raw.get(p_name)
		if not _valid_param(spec, value):
			var rule := "verdadeiro ou falso"
			if spec["kind"] == "count":
				rule = "inteiro ≥ 1"
			elif spec["kind"] == "positive":
				rule = "> 0 e ≤ %s" % spec["max"] if spec.get("max") != null else "> 0"
			push_error('%s: "%s" precisa ser %s (%s)' % [where, p_name, rule, value])
			return {}
		out[p_name] = _typed(spec, value)
	return out


## Valida o `trigger` de uma torre. Devolve {"ok": bool, "def": TriggerDef|null}:
## `raw == null` = torre sem gatilho (ok, def null); erro: push_error e ok = false.
static func parse_trigger(tower_id: String, raw: Variant) -> Dictionary:
	if raw == null:
		return {"ok": true, "def": null}
	var where := 'Gatilho inválido na torre "%s"' % tower_id
	var bad := {"ok": false, "def": null}
	if not (raw is Dictionary):
		push_error("%s: não é um objeto" % where)
		return bad
	var when: Variant = raw.get("when")
	var effect: Variant = raw.get("do")
	var stars: Variant = raw.get("stars")
	if typeof(when) != TYPE_STRING or not WHEN_PARAMS.has(when):
		push_error('%s: "when" desconhecido (%s)' % [where, when])
		return bad
	if typeof(effect) != TYPE_STRING or not DO_PARAMS.has(effect):
		push_error('%s: "do" desconhecido (%s)' % [where, effect])
		return bad
	if not (stars is Array) or stars.size() < 1 or stars.size() > MAX_STARS:
		push_error('%s: "stars" precisa ter de 1 a %d entradas' % [where, MAX_STARS])
		return bad
	var when_specs: Array = WHEN_PARAMS[when]
	var do_specs: Array = DO_PARAMS[effect]
	var allowed := {}
	for spec: Dictionary in when_specs + do_specs + STAR_PARAMS:
		allowed[spec["name"]] = true
	var def := TriggerDef.new()
	for i in stars.size():
		var entry: Variant = stars[i]
		var at := "%s, ★%d" % [where, i + 1]
		if not (entry is Dictionary):
			push_error("%s: não é um objeto" % at)
			return bad
		var extra: Array = entry.keys().filter(func(k: String) -> bool: return not allowed.has(k))
		if not extra.is_empty():
			push_error('%s: parâmetros que "%s" e "%s" não usam: %s' % [at, when, effect, ", ".join(extra)])
			return bad
		var params := _pick(at, effect, do_specs, entry)
		if params.is_empty():
			return bad
		if (params.get("explodeRadius", 1.0) == 0.0) != (params.get("explodeDamagePercent", 1.0) == 0.0):
			push_error('%s: "explodeRadius" e "explodeDamagePercent" vêm juntos' % at)
			return bad
		var when_params := _pick(at, when, when_specs, entry)
		var star_params := _pick(at, "", STAR_PARAMS, entry)
		if when_params.is_empty() or star_params.is_empty():
			return bad
		var star := TriggerStar.new()
		star.when = when_params
		star.effect = params
		star.attack_damage_percent = star_params["attackDamagePercent"]
		def.stars.append(star)
	return {"ok": true, "def": def}


## Gatilho na estrela pedida (a primeira é ★1). Estrela inexistente: push_error + null.
static func trigger_at(def: TriggerDef, stars: int = 1) -> TriggerStar:
	if stars < 1 or stars > def.stars.size():
		push_error("Gatilho sem parâmetros para ★%d" % stars)
		return null
	return def.stars[stars - 1]


## Valida o bloco `triggers` de `towers.json`. Inválido: push_error + null.
static func parse_trigger_rules(raw: Variant) -> TriggerRules:
	if not (raw is Dictionary):
		push_error('Dados de torres inválidos: falta o bloco "triggers"')
		return null
	var neighborhood: Variant = raw.get("neighborhood")
	if not SimMap._is_integer(neighborhood) or (int(neighborhood) != 4 and int(neighborhood) != 8):
		push_error('Regras de gatilho inválidas: "neighborhood" precisa ser 4 ou 8')
		return null
	for key: String in ["activationCooldownSeconds", "unlimitedLineLength"]:
		var v: Variant = raw.get(key)
		if (typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT) or not is_finite(float(v)) or float(v) <= 0.0:
			push_error('Regras de gatilho inválidas: "%s" precisa ser > 0' % key)
			return null
	for key: String in ["maxChainDepthPerTick", "maxActivationsPerTick", "maxQueueSize"]:
		var v: Variant = raw.get(key)
		if not SimMap._is_integer(v) or int(v) <= 0:
			push_error('Regras de gatilho inválidas: "%s" precisa ser inteiro ≥ 1' % key)
			return null
	var rules := TriggerRules.new()
	rules.neighborhood = int(neighborhood)
	rules.activation_cooldown_seconds = float(raw["activationCooldownSeconds"])
	rules.unlimited_line_length = float(raw["unlimitedLineLength"])
	rules.max_chain_depth_per_tick = int(raw["maxChainDepthPerTick"])
	rules.max_activations_per_tick = int(raw["maxActivationsPerTick"])
	rules.max_queue_size = int(raw["maxQueueSize"])
	return rules
