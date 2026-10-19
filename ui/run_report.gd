class_name RunReport
extends RefCounted
## Resumo da run para as telas de vitória e derrota e o relatório copiável (T17), em texto simples,
## para os testadores colarem nos relatos (porte de `runReport.ts`).

var seed_text := ""
## Hash curto do commit da build.
var version := ""
var won := false
## Onda alcançada (a mais nova em andamento na derrota; a última na vitória).
var wave := 0
var total_waves := 0
var seconds := 0.0
var kills := 0
## Maior cadeia da run, em gatilhos (`stats.longest_chain`).
var longest_chain := 0
## Torres no mapa no fim, na ordem do mapa: [{"name": String, "star": int}].
var towers: Array = []
var nexus_level := 1
## Juros, bônus, bônus antecipado e ouro de abate (sem venda nem trapaça).
var gold_earned := 0
## Recompensas escolhidas (T24), na ordem: "Onda 5: Mais espaço".
var rewards: Array[String] = []
var cheated := false
## Link da run (no Godot não há URL; fica vazio ou a semente).
var link := ""


## Monta o resumo a partir do estado final da run. `ctx`: version, total_waves, ticks_per_second,
## link e os Callables tower_name(type) e reward_name(id, class_id).
static func summarize(state: Object, ctx: Dictionary) -> RunReport:
	var newest: int = state.wave
	if not state.waves.active.is_empty():
		newest = (state.waves.active[state.waves.active.size() - 1] as WaveState.ActiveWave).wave
	var r := RunReport.new()
	r.seed_text = state.seed_text
	r.version = ctx["version"]
	r.won = state.status == "won"
	r.wave = mini(newest, ctx["total_waves"])
	r.total_waves = ctx["total_waves"]
	r.seconds = float(state.tick) / float(ctx["ticks_per_second"])
	r.kills = state.stats.kills
	r.longest_chain = state.stats.longest_chain
	for t: Tower in state.towers:
		r.towers.append({"name": ctx["tower_name"].call(t.type), "star": t.star})
	r.nexus_level = state.nexus.level
	r.gold_earned = state.stats.gold_earned
	for t: RewardsState.TakenReward in state.rewards.taken:
		r.rewards.append("Onda %d: %s" % [t.wave, ctx["reward_name"].call(t.id, t.class_id)])
	r.cheated = state.cheated
	r.link = ctx.get("link", "")
	return r


## Tempo de jogo em "m:ss".
static func format_time(total_seconds: float) -> String:
	var minutes := int(floorf(total_seconds / 60.0))
	var secs := int(floorf(fmod(total_seconds, 60.0)))
	return "%d:%02d" % [minutes, secs]


## Relatório em texto simples, uma informação por linha.
func format() -> String:
	var tower_names: Array[String] = []
	for t: Dictionary in towers:
		tower_names.append("%s ★%d" % [t["name"], t["star"]])
	var towers_text := ", ".join(tower_names) if not towers.is_empty() else "nenhuma"
	return "\n".join([
		"Relatório da run",
		"Semente: %s" % seed_text,
		"Versão: %s" % version,
		"Resultado: %s" % ("vitória" if won else "derrota"),
		"Onda alcançada: %d/%d" % [wave, total_waves],
		"Tempo: %s" % format_time(seconds),
		"Abates: %d" % kills,
		"Maior cadeia: x%d" % longest_chain,
		"Torres finais (%d): %s" % [towers.size(), towers_text],
		"Núcleo: nível %d" % nexus_level,
		"Ouro ganho: %d" % gold_earned,
		"Recompensas (%d): %s" % [rewards.size(), ", ".join(rewards) if not rewards.is_empty() else "nenhuma"],
		"Trapaça: %s" % ("sim" if cheated else "não"),
		"Link: %s" % link,
	])
