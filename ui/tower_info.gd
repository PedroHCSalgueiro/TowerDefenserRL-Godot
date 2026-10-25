class_name TowerInfo
extends RefCounted
## Texto da janela de uma torre ("o que ela faz"), montado a partir dos números de
## `towers.json` na estrela pedida: o texto nunca fica diferente do jogo (porte de `towerInfo.ts`).
## Sem nós, para testar direto.

const RARITY_LABELS := {"common": "Comum", "uncommon": "Incomum", "rare": "Rara", "legendary": "Lendária"}

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
		"everyNSeconds":
			return "A cada %s s" % fmt(when["seconds"])
		"ownKill":
			return "Quando abate um inimigo Marcado" if when["markedOnly"] else "Quando abate um inimigo"
		"everyNRegionKills":
			return "A cada %s abates de heróis da região (os dele não contam)" % fmt(when["kills"])
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
		"empoweredShot":
			return "dispara um tiro em área extra, com raio ×%s e %s%% do dano" % [fmt(effect["radiusMultiplier"]), fmt(effect["damagePercent"])]
		"frontBeam":
			var slow := ""
			if effect["slowPercent"] > 0.0:
				slow = " e os deixa Lentos (%s%%, por %s s)" % [fmt(effect["slowPercent"]), fmt(effect["slowSeconds"])]
			return "solta um raio de luz nos %s mais à frente da fila (%s%% do dano em cada)%s" % [
					_plural(effect["count"], "inimigo", "inimigos"), fmt(effect["damagePercent"]), slow]
		"bounceShot":
			return "dispara uma bala que quica em %s (área de raio %s e %s%% do dano no primeiro; a cada quique, área e dano caem para %s%%)" % [
					_plural(effect["impacts"], "alvo", "alvos"), fmt(effect["radius"]), fmt(effect["damagePercent"]),
					fmt(effect["falloffPercent"])]
		"anchorPush":
			return "prende o primeiro da fila e o empurra %s para trás, junto com quem estiver colado atrás dele (chefão imune, elite no máximo 1 casa)" % \
					_plural(effect["cells"], "casa", "casas")
		"tide":
			return "solta uma maré até o fim do alcance: %s%% do dano e Lento (%s%%, por %s s) em quem ela atravessar" % [
					fmt(effect["damagePercent"]), fmt(effect["slowPercent"]), fmt(effect["slowSeconds"])]
		"tentacle":
			return "um tentáculo agarra o grupo maior no alcance: Atordoa por %s s (chefão imune, elite pela metade) e causa %s%% do dano por segundo por %s s" % [
					fmt(effect["stunSeconds"]), fmt(effect["damagePercent"]), fmt(effect["damageSeconds"])]
		"loot":
			var cap := " (até %s por onda)" % fmt(effect["maxPerWave"]) if effect["maxPerWave"] > 0 else ""
			return "guarda +%s de ouro para o fim da onda%s" % [fmt(effect["gold"]), cap]
		"doubleShot":
			return "o próximo ataque sai com dois tiros, um logo depois do outro"
		"curseNext":
			return "o próximo ataque amaldiçoa o alvo por %s s: ele divide %s%% do dano que recebe com os %s mais próximos e, se morrer, a maldição pula para eles (até %s)" % [
					fmt(effect["seconds"]), fmt(effect["sharePercent"]), fmt(effect["spread"]),
					_plural(effect["jumps"], "salto", "saltos")]
		"stunFront":
			return "atordoa %s mais à frente da fila por %s s" % [_plural(effect["count"], "inimigo", "inimigos"), fmt(effect["stunSeconds"])]
		"sentinel":
			var where := "invoca um grifo sobre ela" if effect["onTower"] else "monta uma torreta numa casa vizinha livre"
			var air := " (×%s em voadores, que ele mira primeiro)" % fmt(effect["airMultiplier"]) if effect["airMultiplier"] > 1.0 else ""
			return "%s por %s s: %s tiros/s com %s%% do dano, alcance %s%s" % [where, fmt(effect["lifeSeconds"]),
					fmt(effect["shotsPerSecond"]), fmt(effect["damagePercent"]), fmt(effect["range"]), air]
		"magnetPull":
			return "puxa os inimigos no alcance para o meio do caminho e os atordoa por %s s (chefão não é puxado, elite anda no máximo 1 casa)" % fmt(effect["stunSeconds"])
		"markNext":
			return "o próximo ataque deixa o alvo Marcado"
		"empowerKiller":
			return "a vizinha que abateu ganha +%s%% de dano até o fim da onda (até +%s%%)" % [fmt(effect["percent"]), fmt(effect["maxPercent"])]
		"skeleton":
			return "ergue um esqueleto aliado que anda contra a horda e explode no primeiro inimigo (%s%% do dano)" % fmt(effect["damagePercent"])
		"plagueCloud":
			return "solta uma nuvem de peste por %s s onde há mais inimigos: Lento (%s%%) e Envenenado (%s%% do dano por segundo)" % [
					fmt(effect["cloudSeconds"]), fmt(effect["slowPercent"]), fmt(effect["poisonPercent"])]
		"pathBeam":
			return "solta um raio no caminho inteiro: todo inimigo do mapa leva %s%% do dano" % fmt(effect["damagePercent"])
		"crater":
			return "lança uma rocha (área de raio %s, %s%% do dano) que deixa uma cratera: Lento (%s%%) por %s s" % [
					fmt(effect["radius"]), fmt(effect["damagePercent"]), fmt(effect["slowPercent"]), fmt(effect["seconds"])]
		"strikes":
			return "raios caem nos %s mais à frente (%s%% do dano; os Lentos levam ×%s)" % [
					_plural(effect["count"], "inimigo", "inimigos"), fmt(effect["damagePercent"]), fmt(effect["slowedMultiplier"])]
		"trap":
			return "põe uma armadilha de urso no caminho (até %s; prende por %s s e causa %s%% do dano por segundo)" % [
					fmt(effect["maxTraps"]), fmt(effect["holdSeconds"]), fmt(effect["damagePercent"])]
		"stunSlowed":
			return "atordoa por %s s os inimigos Lentos no alcance" % fmt(effect["stunSeconds"])
		"copyLast":
			var from := "os últimos efeitos de %s vizinhas diferentes" % fmt(effect["copies"]) if effect["copies"] > 1 \
					else "o último efeito de uma vizinha"
			var power := "" if effect["powerPercent"] == 100.0 else ", com %s%% do dano" % fmt(effect["powerPercent"])
			return "copia %s%s" % [from, power]
	return ""


## Progresso da carga de uma torre do mapa, só para o tooltip (nunca na tela): "Carga: 2 de 5 ataques"
## nos gatilhos "a cada N tiros" e "a cada N abates" (com o desconto de classe da contagem). "" = nada a
## mostrar.
static func charge_progress(type: TowerData.TowerType, tower: Tower, classes: ClassData, state: Object) -> String:
	var star := Stars.tower_star(type, tower)
	if star == null:
		return ""
	var when := star.when
	var unit := ""
	var base := 0
	match when["kind"]:
		"everyNShots":
			base = int(when["shots"])
			unit = "ataques"
		"everyNKillsInRange":
			base = int(when["kills"])
			unit = "abates"
		_:
			return ""
	var count := ClassBonuses.reduced_trigger_count(classes, state, type, base)
	return "Carga: %s de %d %s" % [fmt(minf(tower.trigger_counter, float(count))), count, unit]


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
	if def == null and not type.passive.is_empty():
		damage = (type.damage * float(type.passive["stars"][mini(s, type.passive["stars"].size()) - 1]["attackDamagePercent"])) / 100.0
	var area := ", área de raio %s" % fmt(type.shot["radius"]) if type.shot["kind"] == "area" else ""
	if type.attacks and type.shot["kind"] == "trap":
		info.attack = "Estrepes no caminho: dano %s · %s/s · alcance %s · até %s no chão" % [
				fmt(damage * type.shot["damagePercent"] / 100.0), _plural(type.shots_per_second, "tiro", "tiros"), fmt(type.range),
				_plural(type.shot["maxTraps"], "estrepe", "estrepes")]
	elif type.attacks:
		info.attack = "Dano %s · %s/s · alcance %s%s" % [fmt(damage), _plural(type.shots_per_second, "tiro", "tiros"), fmt(type.range), area]
	else:
		info.attack = "Não ataca por conta própria"
	if type.on_hit.has("pierce"):
		info.attack += " · atravessa %s" % _plural(type.on_hit["pierce"]["targets"], "inimigo", "inimigos")
	info.summary = tower_summary(type_id) if type_id != "" else ""
	if def != null:
		info.trigger = "%s: %s." % [_when_text(def.when), _effect_text(def.effect)]
	elif not type.passive.is_empty():
		var p: Dictionary = type.passive["stars"][mini(s, type.passive["stars"].size()) - 1]
		if type.passive["kind"] == "phalanx":
			var class_name_text: String = classes.classes[p["class"]].name if classes.classes.has(p["class"]) else p["class"]
			info.trigger = "Passiva (Falange): +%s%% de dano para cada %s encostado." % [fmt(p["percent"]), class_name_text]
		else:
			info.trigger = "Passiva (Julgamento): +%s%% de dano contra inimigos Marcados e chefões." % fmt(p["percent"])
	elif not type.aura.is_empty():
		var a: Dictionary = type.aura["stars"][mini(s, type.aura["stars"].size()) - 1]
		var parts_aura: Array[String] = []
		if a["rangeBonus"] > 0.0:
			parts_aura.append("+%s de alcance" % fmt(a["rangeBonus"]))
		if a["attackSpeedPercent"] > 0.0:
			var region := " (+%s%% nos heróis da região)" % fmt(a["regionPercent"]) if a["regionPercent"] > 0.0 else ""
			parts_aura.append("+%s%% de velocidade de ataque%s" % [fmt(a["attackSpeedPercent"]), region])
		info.trigger = "Aura: as torres encostadas ganham %s." % " e ".join(parts_aura)
	return info
