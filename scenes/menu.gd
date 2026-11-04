class_name MainMenu
extends Control
## Tela inicial, em três páginas: o título (Novo jogo, Opções, Sair), a escolha das torres da run (Padrão, uma das
## cinco regiões, Valcoroa + Costa Rubra ou todas as regiões; ver `GameSets`) com a semente opcional, e as opções
## (`OptionsPanel`). "Jogar" carrega a cena do jogo. Textos em `titleScreen` (ui.json).
##
## Linha de comando (depois de `--`): `--set=valcoroa` escolhe o conjunto, `--seed=abc` a semente, `--play` pula a
## tela e já abre o jogo e `--page=sets|options` abre direto numa página (para capturas de tela e testes manuais).

const GAME_SCENE := "res://scenes/game.tscn"
## Largura de cada cartão de conjunto e quantos por fileira (quatro lado a lado cabem em 1280 px).
const CARD_WIDTH := 290
const CARDS_PER_ROW := 4
const SETTINGS_PATH := "user://menu.cfg"

## Página visível: "title", "sets" ou "options".
var page := ""
var _sets: Array = []
var _selected := 0
var _cards: Array[PanelContainer] = []
var _seed_edit: LineEdit
var _play_button: Button
var _pages := {}
var _texts: Dictionary
## `--shot=arquivo.png`: salva uma captura da tela inicial depois de meio segundo e encerra.
var _shot_path := ""
var _elapsed := 0.0


func _ready() -> void:
	FontSetup.install()
	GameSettings.apply_window()
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
	_texts = DataLoader.load_json("ui.json")["titleScreen"]
	_build(args.get("seed", ""))
	show_page(String(args.get("page", "title")))


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
	_pages["title"] = _page(_build_title())
	_pages["sets"] = _page(_build_sets(seed_text))
	var options := OptionsPanel.new()
	options.closed.connect(show_page.bind("title"))
	var panel := UiKit.panel(Color("#1d1f21"), UiKit.BORDER, 10, Vector2(36, 26))
	panel.add_child(options)
	_pages["options"] = _page(panel)


## Cada página fica no centro da tela; só uma aparece por vez.
func _page(content: Control) -> CenterContainer:
	var center := CenterContainer.new()
	UiKit.full_rect(center)
	center.add_child(content)
	center.visible = false
	add_child(center)
	return center


func show_page(which: String) -> void:
	if not _pages.has(which):
		which = "title"
	page = which
	for key: String in _pages:
		_pages[key].visible = key == which


func _build_title() -> Control:
	var column := UiKit.vbox(14)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := UiKit.label(_texts["title"], 44, UiKit.GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	column.add_child(Control.new())  # respiro entre o nome e os botões
	column.add_child(_title_button(_texts["newGame"], show_page.bind("sets"), true))
	column.add_child(_title_button(_texts["options"], show_page.bind("options")))
	if not OS.has_feature("web"):
		column.add_child(_title_button(_texts["quit"], func() -> void: get_tree().quit()))
	var hint := UiKit.label(_texts["hint"], 12, Color("#777777"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)
	column.add_child(_version_label())
	return column


## Botão grande do título, centrado na coluna.
func _title_button(text: String, on_pressed: Callable, primary: bool = false) -> Control:
	var b := UiKit.primary_button(text, on_pressed) if primary else UiKit.button(text, on_pressed)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_font_size_override("font_size", 22)
	b.custom_minimum_size = Vector2(280, 52)
	return _centered(b)


func _centered(c: Control) -> Control:
	var row := CenterContainer.new()
	row.add_child(c)
	return row


func _version_label() -> Label:
	var version_label := UiKit.label("v %s" % ProjectSettings.get_setting("application/config/version", ""), 12, Color("#555555"))
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return version_label


func _build_sets(seed_text: String) -> Control:
	var column := UiKit.vbox(10)
	column.alignment = BoxContainer.ALIGNMENT_CENTER

	var title := UiKit.label("Tower Defense Roguelite", 40, UiKit.GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle := UiKit.label("Escolha as torres desta run", 18, UiKit.MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)

	# Os conjuntos em fileiras de `CARDS_PER_ROW` (oito cabem em duas fileiras na tela de 1280 × 720).
	var grid := GridContainer.new()
	grid.columns = mini(CARDS_PER_ROW, _sets.size())
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	column.add_child(_centered(grid))
	for i in _sets.size():
		var card := _make_card(i)
		_cards.append(card)
		grid.add_child(card)

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

	var buttons := UiKit.hbox(14)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var back := UiKit.button(_texts["back"], show_page.bind("title"))
	back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.add_theme_font_size_override("font_size", 18)
	back.custom_minimum_size = Vector2(140, 48)
	buttons.add_child(back)
	_play_button = UiKit.primary_button("Jogar", func() -> void: _start(_seed_edit.text))
	_play_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_play_button.add_theme_font_size_override("font_size", 22)
	_play_button.custom_minimum_size = Vector2(220, 48)
	buttons.add_child(_play_button)
	column.add_child(buttons)
	var hint := UiKit.label(String(_texts["setsHint"]).format({"n": _sets.size()}), 12, Color("#777777"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)
	column.add_child(_version_label())
	_refresh_cards()
	return column


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
	var box := UiKit.vbox(5)
	card.add_child(box)
	box.add_child(UiKit.label("%d. %s" % [index + 1, info["name"]], 19, UiKit.TEXT, true))
	var description := UiKit.label(str(info.get("description", "")), 12, UiKit.MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(CARD_WIDTH - 36, 0)
	box.add_child(description)
	# Os heróis numa linha só, quebrada no cartão (oito listas inteiras não caberiam na tela).
	var roster := UiKit.label(" · ".join(info.get("roster", []).map(func(n: Variant) -> String: return str(n))), 12, Color("#cfcfcf"))
	roster.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	roster.custom_minimum_size = Vector2(CARD_WIDTH - 36, 0)
	box.add_child(roster)
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
	match page:
		"title":
			if key == KEY_ENTER or key == KEY_KP_ENTER:
				show_page("sets")
		"options":
			if key == KEY_ESCAPE:
				show_page("title")
		"sets":
			if key >= KEY_1 and key < KEY_1 + _sets.size():
				_select(key - KEY_1)
			elif key == KEY_ENTER or key == KEY_KP_ENTER:
				_start(_seed_edit.text if _seed_edit != null else "")
			elif key == KEY_ESCAPE:
				show_page("title")


## Fixa o conjunto e a semente e abre o jogo.
func _start(seed_text: String) -> void:
	var id: String = _sets[_selected]["id"]
	if not GameSets.select(id):
		return
	_save_set(id)
	Game.pending_seed = seed_text.strip_edges()
	get_tree().change_scene_to_file(GAME_SCENE)
