class_name MainMenu
extends Control
## Tela inicial: o jogador escolhe o conjunto de torres da run (Padrão, uma região — Reino de Valcoroa,
## Costa Rubra — ou as duas juntas; ver `GameSets`) e, se quiser, a semente. "Jogar" carrega a cena do jogo.
##
## Linha de comando (depois de `--`): `--set=valcoroa` escolhe o conjunto, `--seed=abc` a semente e
## `--play` pula a tela e já abre o jogo (para capturas de tela e testes manuais).

const GAME_SCENE := "res://scenes/game.tscn"
## Largura de cada cartão de conjunto (quatro lado a lado cabem em 1280 px).
const CARD_WIDTH := 290
const SETTINGS_PATH := "user://menu.cfg"

var _sets: Array = []
var _selected := 0
var _cards: Array[PanelContainer] = []
var _seed_edit: LineEdit
var _play_button: Button
## `--shot=arquivo.png`: salva uma captura da tela inicial depois de meio segundo e encerra.
var _shot_path := ""
var _elapsed := 0.0


func _ready() -> void:
	FontSetup.install()
	_sets = GameSets.list()
	if _sets.is_empty():
		push_error("Nenhum conjunto de torres em data/sets/sets.json")
		return
	var args := _parse_args()
	_shot_path = String(args.get("shot", ""))
	_selected = _index_of(args.get("set", _saved_set()))
	if args.has("play"):
		_start(args.get("seed", ""))
		return
	_build(args.get("seed", ""))


func _parse_args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		var clean := arg.trim_prefix("--")
		if clean.contains("="):
			var parts := clean.split("=", true, 1)
			out[parts[0]] = parts[1]
		else:
			out[clean] = true
	return out


func _index_of(id: String) -> int:
	for i in _sets.size():
		if _sets[i]["id"] == id:
			return i
	return 0


func _saved_set() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		return str(cfg.get_value("menu", "set", GameSets.DEFAULT_ID))
	return GameSets.DEFAULT_ID


func _save_set(id: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("menu", "set", id)
	cfg.save(SETTINGS_PATH)


func _build(seed_text: String) -> void:
	var bg := ColorRect.new()
	bg.color = Color("#141517")
	UiKit.full_rect(bg)
	add_child(bg)
	var center := CenterContainer.new()
	UiKit.full_rect(center)
	add_child(center)
	var column := UiKit.vbox(18)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(column)

	var title := UiKit.label("Tower Defense Roguelite", 40, UiKit.GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle := UiKit.label("Escolha as torres desta run", 18, UiKit.MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)

	var row := UiKit.hbox(18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	for i in _sets.size():
		var card := _make_card(i)
		_cards.append(card)
		row.add_child(card)

	var seed_row := UiKit.hbox(8)
	seed_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(seed_row)
	seed_row.add_child(UiKit.label("Semente (opcional):", 14, UiKit.MUTED))
	_seed_edit = LineEdit.new()
	_seed_edit.text = seed_text
	_seed_edit.placeholder_text = "aleatória"
	_seed_edit.custom_minimum_size = Vector2(180, 0)
	_seed_edit.text_submitted.connect(func(_t: String) -> void: _start(_seed_edit.text))
	seed_row.add_child(_seed_edit)

	_play_button = UiKit.button("Jogar", func() -> void: _start(_seed_edit.text))
	_play_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_play_button.add_theme_font_size_override("font_size", 22)
	_play_button.custom_minimum_size = Vector2(220, 48)
	var play_row := CenterContainer.new()
	play_row.add_child(_play_button)
	column.add_child(play_row)
	var hint := UiKit.label("Teclas 1 a %d escolhem o conjunto · Enter joga" % _sets.size(), 12, Color("#777777"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)
	var version_label := UiKit.label("v %s" % ProjectSettings.get_setting("application/config/version", ""), 12, Color("#555555"))
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(version_label)
	_refresh_cards()


func _make_card(index: int) -> PanelContainer:
	var info: Dictionary = _sets[index]
	var card := UiKit.panel(Color("#1d1f21"), UiKit.BORDER, 10, Vector2(18, 16))
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select(index)
			if event.double_click:
				_start(_seed_edit.text))
	var box := UiKit.vbox(8)
	card.add_child(box)
	box.add_child(UiKit.label(str(info["name"]), 24, UiKit.TEXT, true))
	var description := UiKit.label(str(info.get("description", "")), 14, UiKit.MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(CARD_WIDTH - 36, 0)
	box.add_child(description)
	box.add_child(UiKit.label("Torres", 13, UiKit.GOLD, true))
	for tower_name in info.get("roster", []):
		box.add_child(UiKit.label("• " + str(tower_name), 14, Color("#cfcfcf")))
	return card


func _select(index: int) -> void:
	_selected = clampi(index, 0, _sets.size() - 1)
	_refresh_cards()


func _refresh_cards() -> void:
	for i in _cards.size():
		var chosen := i == _selected
		_cards[i].add_theme_stylebox_override("panel", UiKit.style(
				Color("#26292d") if chosen else Color("#1d1f21"),
				UiKit.GOLD if chosen else UiKit.BORDER, 10, 3 if chosen else 1, Vector2(22, 18)))


func _process(delta: float) -> void:
	if _shot_path == "":
		return
	_elapsed += delta
	if _elapsed >= 0.5:
		get_viewport().get_texture().get_image().save_png(_shot_path)
		get_tree().quit()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if _seed_edit != null and _seed_edit.has_focus():
		return
	var key := (event as InputEventKey).keycode
	if key >= KEY_1 and key < KEY_1 + _sets.size():
		_select(key - KEY_1)
	elif key == KEY_ENTER or key == KEY_KP_ENTER:
		_start(_seed_edit.text if _seed_edit != null else "")


## Fixa o conjunto e a semente e abre o jogo.
func _start(seed_text: String) -> void:
	var id: String = _sets[_selected]["id"]
	if not GameSets.select(id):
		return
	_save_set(id)
	Game.pending_seed = seed_text.strip_edges()
	get_tree().change_scene_to_file(GAME_SCENE)
