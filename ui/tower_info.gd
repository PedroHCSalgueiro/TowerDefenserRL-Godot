class_name TowerInfo
extends RefCounted
## Texto da janela de uma torre ("o que ela faz"), montado a partir dos números de
## `towers.json` na estrela pedida: o texto nunca fica diferente do jogo (porte de `towerInfo.ts`).
## Sem nós, para testar direto.

const RARITY_LABELS := {"common": "Comum", "uncommon": "Incomum", "rare": "Rara"}

## "Relé ★2"
var title := ""
## Frase simples do que a torre faz (T23), acima da descrição técnica ("" = sem frase).
var summary := ""
## "Arcana · Mecânica · Comum"
var subtitle := ""
## Ataque normal.
var attack := ""
## O que o gatilho faz ("" = torre sem gatilho).
var trigger := ""


## Número no formato brasileiro, sem casas sobrando (0,8 · 1,3 · 8 · 1.000).
static func fmt(n: float) -> String:
	var rounded := snappedf(n, 0.01)
	var text := str(rounded)
	if text.contains("."):
		text = text.rstrip("0").rstrip(".")
	var negative := text.begins_with("-")
	if negative:
		text = text.substr(1)
	var parts := text.split(".")
	var integer: String = parts[0]
	var grouped := ""
	for i in integer.length():
		if i > 0 and (integer.length() - i) % 3 == 0:
			grouped += "."
		grouped += integer[i]
	var out := grouped
	if parts.size() > 1:
		out += "," + parts[1]
	return ("-" if negative else "") + out


static func _plural(n: float, one: String, many: String) -> String:
	return "%s %s" % [fmt(n), one if n == 1.0 else many]


static func _when_text(when: Dictionary) -> String:
	match when["kind"]:
		"everyNShots":
			return "A cada %s tiros" % fmt(when["shots"])
		"enemyDiesInRange":
			return "Quando um inimigo morre no alcance"
		"onFire":
			return "Sempre que atira"
		"onActivated":
			return "Quando uma vizinha a ativa"
		"neighborKills":
			return "Quando uma vizinha abate um inimigo"
		"everyNKillsInRange":
			return "A cada %s abates no alcance" % fmt(when["kills"])
	return ""


static func _effect_text(effect: Dictionary) -> String:
	match effect["kind"]:
		"multiShot":
			return "dispara %s%s" % [_plural(effect["extraShots"], "tiro extra", "tiros extras"),
					", cada um em um alvo diferente" if effect["spread"] else ""]
		"explosion":
			var weight := ""
			if effect["killWeight"] > 1:
				weight = "; as mortes da explosão contam como %s" % _plural(effect["killWeight"], "abate", "abates")
			return "explode (raio %s, %s%% do dano)%s" % [fmt(effect["radius"]), fmt(effect["damagePercent"]), weight]
		"activateNeighbors":
			var who := "até %s" % _plural(effect["maxTargets"], "vizinha", "vizinhas") if effect["maxTargets"] > 0 else "todas as vizinhas"
			var reach := " (alcance ampliado em %s)" % fmt(effect["reach"]) if effect["reach"] > 0 else ""
			var self_too := " e a si mesma" if effect["selfToo"] else ""
			var shot := "" if effect["activatedDamagePercent"] == 100.0 else ", com %s%% do dano" % fmt(effect["activatedDamagePercent"])
			return "ativa %s%s%s; cada uma dá um tiro extra%s" % [who, reach, self_too, shot]
		"chargeLightning":
			return "carrega o raio. Com %s, solta um raio em %s (salto de %s casas, %s%% do dano)%s" % [
					_plural(effect["charges"], "carga", "cargas"), _plural(effect["targets"], "inimigo", "inimigos"),
					fmt(effect["jumpRadius"]), fmt(effect["damagePercent"]),
					" e ativa as vizinhas" if effect["activateOnDischarge"] else ""]
		"pierceLine":
			return "dispara uma linha%s (largura %s, %s%% do dano)" % [
					" que atravessa todo o mapa" if effect["unlimited"] else "",
					fmt(effect["halfWidth"] * 2.0), fmt(effect["damagePercent"])]
		"execute":
			var boss := "; no chefão, dá um golpe de %s%% da vida máxima" % fmt(effect["bossMaxHpPercent"]) \
					if effect["bossMaxHpPercent"] > 0.0 else "; o chefão é poupado"
			var blast := "; cada execução explode (raio %s, %s%% do dano)" % [fmt(effect["explodeRadius"]), fmt(effect["explodeDamagePercent"])] \
					if effect["explodeRadius"] > 0.0 else ""
			return "executa o inimigo com menos de %s%% da vida (a morte conta como %s)%s%s" % [
					fmt(effect["hpPercent"]), _plural(effect["killWeight"], "abate", "abates"), boss, blast]
		"copyLast":
			var from := "os últimos efeitos de %s vizinhas diferentes" % fmt(effect["copies"]) if effect["copies"] > 1 \
					else "o último efeito de uma vizinha"
			var power := "" if effect["powerPercent"] == 100.0 else ", com %s%% do dano" % fmt(effect["powerPercent"])
			return "copia %s%s" % [from, power]
	return ""


## Frase simples da torre em `ui.json` ("" = sem frase, como as torres do debug).
static func tower_summary(type_id: String) -> String:
	var summaries: Dictionary = DataLoader.load_json("ui.json")["texts"]["towerSummaries"]
	return summaries.get(type_id, "")


## Informações da torre `type` na estrela `star` (presa entre ★1 e a última do tipo).
static func describe_tower(type: TowerData.TowerType, star: int, classes: ClassData, type_id: String = "") -> TowerInfo:
	var s := Stars.clamp_star(type, star)
	var def: TriggerData.TriggerStar = TriggerData.trigger_at(type.trigger, s) if type.trigger != null else null
	var info := TowerInfo.new()
	info.title = "%s ★%d" % [type.name, s] if Stars.max_stars(type) > 1 else type.name
	var parts: Array[String] = []
	for id in type.classes:
		parts.append(classes.classes[id].name if classes.classes.has(id) else id)
	if type.rarity != null:
		parts.append(RARITY_LABELS[type.rarity])
	info.subtitle = " · ".join(parts)
	var damage := (type.damage * (def.attack_damage_percent if def != null else 100.0)) / 100.0
	var area := ", área de raio %s" % fmt(type.shot["radius"]) if type.shot["kind"] == "area" else ""
	if type.attacks:
		info.attack = "Dano %s · %s/s · alcance %s%s" % [fmt(damage), _plural(type.shots_per_second, "tiro", "tiros"), fmt(type.range), area]
	else:
		info.attack = "Não ataca por conta própria"
	info.summary = tower_summary(type_id) if type_id != "" else ""
	if def != null:
		info.trigger = "%s: %s." % [_when_text(def.when), _effect_text(def.effect)]
	return info
