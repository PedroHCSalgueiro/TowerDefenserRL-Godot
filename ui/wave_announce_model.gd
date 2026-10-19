class_name WaveAnnounceModel
extends RefCounted
## Aviso grande na chamada de uma onda de elite (roxo) ou de chefão (vermelho) — T23. Some sozinho
## depois de `waveAnnounce.durationMs`. A onda com chefão e elites conta como chefão (porte da parte
## pura de `waveAnnounce.ts`).


## O aviso das ondas chamadas neste lote de eventos (o da última, se vierem várias):
## {"kind": "elite"|"boss", "text": String} ou {}.
static func announcement_for(events: Array, schedules: Array[WaveSchedule], enemies: EnemyData) -> Dictionary:
	var config: Dictionary = DataLoader.load_json("ui.json")["waveAnnounce"]
	var found := {}
	for event: Dictionary in events:
		if event["type"] != "waveStarted":
			continue
		var index: int = event["wave"] - 1
		if index < 0 or index >= schedules.size():
			continue
		var kind := WaveSystems.wave_kind_of(schedules[index], enemies)
		if kind != "normal":
			found = {"kind": kind, "text": config["texts"][kind]}
	return found


static func duration_ms() -> float:
	return float(DataLoader.load_json("ui.json")["waveAnnounce"]["durationMs"])
