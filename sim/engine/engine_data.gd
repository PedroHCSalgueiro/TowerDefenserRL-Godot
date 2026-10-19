class_name EngineData
extends RefCounted
## Configuração do motor (data/engine.json): ticks por segundo, velocidades etc.


static func config() -> Dictionary:
	return DataLoader.load_json("engine.json")
