class_name GameSettings
extends RefCounted
## Opções do jogador (a tela de opções do menu inicial e do menu de pausa), gravadas em `user://settings.cfg`:
## tela cheia, números de dano no começo da run e a velocidade no começo da run. Não mudam a simulação.

const DEFAULT_PATH := "user://settings.cfg"
## Arquivo das opções (os testes das opções trocam por outro).
static var path := DEFAULT_PATH
static var _file: ConfigFile = null
static var _file_path := ""


## Sem tela (testes e bots), o arquivo de quem joga não é lido nem gravado: tudo fica no padrão e a velocidade
## gravada não muda o ritmo dos testes.
static func _uses_file() -> bool:
	return path != DEFAULT_PATH or DisplayServer.get_name() != "headless"


static func _cfg() -> ConfigFile:
	if _file == null or _file_path != path:
		_file = ConfigFile.new()
		if _uses_file():
			_file.load(path)  # sem arquivo, tudo fica no padrão
		_file_path = path
	return _file


static func _store(key: String, value: Variant) -> void:
	_cfg().set_value("options", key, value)
	if _uses_file():
		_cfg().save(path)


static func fullscreen() -> bool:
	return bool(_cfg().get_value("options", "fullscreen", false))


static func set_fullscreen(on: bool) -> void:
	_store("fullscreen", on)
	apply_window()


static func damage_numbers() -> bool:
	return bool(_cfg().get_value("options", "damageNumbers", true))


static func set_damage_numbers(on: bool) -> void:
	_store("damageNumbers", on)


## Velocidade no começo da run: uma das `speeds` de engine.json (a primeira se a gravada não existir mais).
static func start_speed() -> float:
	var speeds: Array = EngineData.config()["speeds"]
	var saved := float(_cfg().get_value("options", "startSpeed", speeds[0]))
	for s: Variant in speeds:
		if is_equal_approx(float(s), saved):
			return float(s)
	return float(speeds[0])


static func set_start_speed(speed: float) -> void:
	_store("startSpeed", speed)


## Leva a janela para a opção de tela cheia (no navegador e sem tela, não mexe).
static func apply_window() -> void:
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.window_get_mode()
	var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if is_full != fullscreen():
		# janela maximizada continua maximizada: só troca quando a tela cheia muda
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen() else DisplayServer.WINDOW_MODE_WINDOWED)
