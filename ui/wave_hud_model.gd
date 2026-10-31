class_name WaveHudModel
extends RefCounted
## Modelo do HUD das ondas (sem nós, para testar): "Onda 3/40" ou "Ondas 5–7 de 40", o que falta,
## o bônus antecipado pendente, o botão de chamar (que vira "Antecipar +10" com a janela do bônus,
## ou "Chamar próxima" depois dela; textos em `ui.json`) e a faixa das próximas ondas com
## elite e chefão marcados (T23). Porte de `waveHudModel.ts`.

## "Onda 3/10" (a onda em andamento ou a próxima a chamar) ou "Ondas 5–7 de 10".
var label := ""
## Linha de baixo: inimigos restantes, aviso de mapa sujo ou vazio.
var detail := ""
## Bônus antecipado das ondas em andamento, pago quando cada uma fechar ("+15 ao limpar").
var pending_bonus := ""
## Texto do botão de chamar.
var call_label := ""
var can_call := false
## Janela do bônus antecipado ainda aberta: {"text": String, "spent": float} ou {} (fechada).
var bonus_window: Dictionary = {}
## As próximas ondas a chamar (depois das em andamento): [{"wave": int, "kind": "normal"|"elite"|"boss"}].
var upcoming: Array = []

static var _default_schedules: Array[WaveSchedule] = []


static func default_schedules() -> Array[WaveSchedule]:
	if _default_schedules.is_empty():
		_default_schedules = WaveSchedule.build_wave_schedules(WaveData.game_data(), float(EngineData.config()["ticksPerSecond"]))
	return _default_schedules


static func build(state: Object, paused: bool = false, schedules: Array[WaveSchedule] = [],
		economy: EconomyData = null, enemies: EnemyData = null) -> WaveHudModel:
	if schedules.is_empty():
		schedules = default_schedules()
	if economy == null:
		economy = EconomyData.game_data()
	if enemies == null:
		enemies = EnemyData.game_data()
	var texts: Dictionary = DataLoader.load_json("ui.json")["waveHud"]["texts"]
	var upcoming_count: int = int(DataLoader.load_json("ui.json")["waveHud"]["upcomingCount"])
	var total := schedules.size()
	var active: Array = state.waves.active
	var first: int = (active[0] as WaveState.ActiveWave).wave if not active.is_empty() else mini(state.wave + 1, total)
	var last: int = (active[active.size() - 1] as WaveState.ActiveWave).wave if not active.is_empty() else first
	var model := WaveHudModel.new()
	model.label = "Onda %d/%d" % [first, total] if first == last else "Ondas %d–%d de %d" % [first, last, total]

	var refusal := WaveSystems.call_wave_refusal(state, schedules, enemies)
	if not active.is_empty():
		model.detail = "Restam %d" % WaveSystems.wave_remaining(state, schedules)
	elif refusal == "enemies":
		model.detail = "Limpe o mapa (%d)" % state.enemies.active_count
	elif refusal == "":
		model.detail = "Pronta"

	var pending := 0
	for w: WaveState.ActiveWave in active:
		pending += w.early_bonus
	model.pending_bonus = "+%d ao limpar" % pending if pending > 0 else ""

	model.call_label = texts["call"]
	if refusal == "active":
		model.call_label = texts["callBoss"]
	elif refusal == "" and not active.is_empty():
		var window := WaveSystems.early_bonus_window(state, schedules, economy)
		if not window.is_empty() and window["open"]:
			model.call_label = String(texts["callEarly"]).replace("{bonus}", str(Economy.early_bonus_for(economy, active.size())))
			var remaining: int = window["remaining"]
			model.bonus_window = {
				"text": String(texts["bonusWindow"]).replace("{n}", str(remaining)).replace("{inimigos}", "inimigo" if remaining == 1 else "inimigos"),
				"spent": window["spent"],
			}
		else:
			model.call_label = texts["callNoBonus"]

	var next: int = state.wave + active.size() + 1
	var n := next
	while n < next + upcoming_count and n <= total:
		model.upcoming.append({"wave": n, "kind": WaveSystems.wave_kind_of(schedules[n - 1], enemies)})
		n += 1
	model.can_call = refusal == "" and not paused
	return model


func key() -> String:
	var up: Array[String] = []
	for u: Dictionary in upcoming:
		up.append("%d%s" % [u["wave"], String(u["kind"])[0]])
	return "|".join([label, detail, pending_bonus, call_label, str(can_call),
			bonus_window.get("text", ""), str(roundi(bonus_window["spent"] * 100.0)) if not bonus_window.is_empty() else "",
			",".join(up)])
