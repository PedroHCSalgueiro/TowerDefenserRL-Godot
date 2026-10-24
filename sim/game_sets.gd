class_name GameSets
extends RefCounted
## Conjuntos de torres que o jogador escolhe antes da run: o "Padrão" (as torres do protótipo,
## que usam só data/) e as regiões (Reino de Valcoroa, Costa Rubra e as duas juntas), que complementam
## os dados com as camadas de data/sets/ listadas em `layers` (ver `DataLoader`; sem `layers`, a pasta
## com o id do conjunto). A lista e os textos da tela inicial vêm de data/sets/sets.json.

const DEFAULT_ID := "default"


## Todos os conjuntos, na ordem do arquivo: Array de {"id", "name", "description", "roster", "layers"?}.
static func list() -> Array:
	var raw: Variant = _manifest()
	var out: Array = []
	if raw is Dictionary and raw.get("sets") is Array:
		for entry in raw["sets"]:
			if entry is Dictionary and typeof(entry.get("id")) == TYPE_STRING:
				out.append(entry)
	return out


static func has_set(id: String) -> bool:
	return not _entry(id).is_empty()


static func _entry(id: String) -> Dictionary:
	for entry: Dictionary in list():
		if entry["id"] == id:
			return entry
	return {}


## Conjunto em uso.
static func current() -> String:
	return DataLoader.set_id()


## Escolhe o conjunto da próxima run. Desconhecido: push_error e fica como está (false).
static func select(id: String) -> bool:
	var entry := _entry(id)
	if entry.is_empty():
		push_error('Conjunto de torres desconhecido: "%s"' % id)
		return false
	if id == DataLoader.set_id():
		return true
	DataLoader.use_set(id, entry.get("layers"))
	TowerData.reset_cache()
	ClassData.reset_cache()
	RewardData.reset_cache()
	SimDebugData.reset_cache()
	EconomyData.reset_cache()
	EnemyData.reset_cache()
	NexusData.reset_cache()
	WaveData.reset_cache()
	return true


static func _manifest() -> Variant:
	# O manifesto não depende do conjunto: lê direto, fora do cache por conjunto.
	var path := DataLoader.SETS_DIR + "sets.json"
	if not FileAccess.file_exists(path):
		push_error("arquivo de dados ausente: %s" % path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_error("JSON inválido em %s: %s" % [path, json.get_error_message()])
		return null
	return json.data
