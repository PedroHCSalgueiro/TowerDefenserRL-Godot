class_name TutorialModel
extends RefCounted
## Mini tutorial da primeira partida (T23), sem nós: cartões que não pausam o jogo e avançam com as
## ações do jogador (porte de `tutorialModel.ts`). Textos e tempos em `ui.json`.
##
## - `buy`: aparece logo; some quando a primeira torre entra no mapa.
## - `call`: depois do `buy`; some quando a primeira onda é chamada.
## - `income`: quando a primeira onda fecha.
## - `nexus`: quando o limite de torres enche.
## - `positions`: quando há 2 torres no mapa.
## Os três últimos fecham com clique ou sozinhos depois de `autoCloseMs`. "Avançar" passa qualquer
## cartão, inclusive os de ação. Só um cartão por vez: o primeiro da lista que pode aparecer.
## Terminar (ou "Pular tutorial") grava a marca no armazenamento; sem a marca, recomeça.

const CLOSABLE := ["income", "nexus", "positions"]

var _done := {}
var _shown_at := -1.0
var _current := ""
var _finished: bool
## Arquivo onde a marca de "já viu" é gravada ("" = não grava; usado nos testes).
var _mark_path: String
var _config: Dictionary


func _init(mark_path: String = "user://tutorial_done.mark") -> void:
	_mark_path = mark_path
	_config = DataLoader.load_json("ui.json")["tutorial"]
	_finished = tutorial_seen(mark_path)


## Já viu o tutorial? Se ler falhar, responde que não (pode aparecer de novo).
static func tutorial_seen(path: String) -> bool:
	return path != "" and FileAccess.file_exists(path)


## Acabou (visto antes, pulado ou todos os passos feitos).
func is_over() -> bool:
	return _finished


func _text_of(id: String) -> String:
	for step: Dictionary in _config["steps"]:
		if step["id"] == id:
			return step["text"]
	return ""


## Chame a cada quadro: o cartão a mostrar agora ({"id", "text", "closable"}) ou {} (nenhum).
func update(state: Object, now_ms: float) -> Dictionary:
	if _finished:
		return {}
	var called: bool = state.wave > 0 or not state.waves.active.is_empty()
	# Os de ação terminam quando a ação acontece, mesmo sem ter aparecido.
	if not state.towers.is_empty():
		_done["buy"] = true
	if called:
		_done["call"] = true
	if _current != "" and CLOSABLE.has(_current) and _shown_at >= 0.0 and now_ms - _shown_at >= float(_config["autoCloseMs"]):
		_done[_current] = true
	var ready := {
		"buy": true,
		"call": _done.has("buy"),
		"income": state.wave >= 1,
		"nexus": called and state.towers.size() >= TowerLimit.current_tower_limit(state),
		"positions": called and state.towers.size() >= 2,
	}
	var next := ""
	for step: Dictionary in _config["steps"]:
		var id: String = step["id"]
		if not _done.has(id) and ready.get(id, false):
			next = id
			break
	if next != _current:
		_current = next
		_shown_at = now_ms if next != "" else -1.0
	var all_done := true
	for step: Dictionary in _config["steps"]:
		if not _done.has(step["id"]):
			all_done = false
	if all_done:
		_finish()
	if next == "":
		return {}
	return {"id": next, "text": _text_of(next), "closable": CLOSABLE.has(next)}


## Clique no cartão: fecha o passo atual, se ele fecha com clique.
func close() -> void:
	if _current != "" and CLOSABLE.has(_current):
		_done[_current] = true


## "Avançar": dá o cartão atual por visto, seja qual for, e segue para o próximo.
func advance() -> void:
	if _current != "":
		_done[_current] = true


## "Pular tutorial".
func skip() -> void:
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_current = ""
	if _mark_path != "":
		var f := FileAccess.open(_mark_path, FileAccess.WRITE)
		if f != null:
			f.store_string("1")
