class_name TowerTooltip
extends PanelContainer
## Janela de informações da torre: aparece ao parar o mouse numa torre do mapa ou num slot da loja e
## segue o mouse. Só nós; quem chama diz qual torre mostrar a cada quadro (porte de
## `towerTooltip.ts`).

var _box: VBoxContainer
var _key := ""
var _since_ms := 0.0
var _shown := false
var _delay_ms: float
var _offset: Vector2
var _edge_margin: float
var _progress: Label
var _progress_text := ""


func _init() -> void:
	var cfg: Dictionary = DataLoader.load_json("ui.json")["tooltip"]
	_delay_ms = float(cfg["delayMs"])
	_offset = Vector2(float(cfg["offsetX"]), float(cfg["offsetY"]))
	_edge_margin = float(cfg["edgeMarginPx"])
	add_theme_stylebox_override("panel", UiKit.style(Color(0.0784, 0.0824, 0.0902, 0.97), Color("#5a5f64"), 6, 1, Vector2(10, 8)))
	custom_minimum_size = Vector2(280, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	_box = UiKit.vbox(3)
	add_child(_box)
	visible = false


## A janela está aberta (passou a espera)?
func is_shown() -> bool:
	return _shown


## Chame a cada quadro. `info` é a torre a mostrar (null = nenhuma) e `key` identifica a torre e a
## estrela: a espera de `delayMs` recomeça quando ela muda. `purchase`: prévia da compra (só no slot
## da loja). `now_ms`: relógio em ms. `progress`: a carga da habilidade ("Carga: 2 de 5 ataques"),
## atualizada sem recomeçar a espera ("" = nenhuma).
func update_info(info: TowerInfo, key: String, now_ms: float, mouse: Vector2, purchase: ClassPreview = null,
		progress: String = "") -> void:
	if info == null or key == "":
		_key = ""
		_hide()
		return
	if key != _key:
		_key = key
		_since_ms = now_ms
		_hide()
		_fill(info, purchase)
		_progress_text = ""
	if progress != _progress_text:
		_progress_text = progress
		_progress.text = progress
		_progress.visible = progress != ""
		reset_size()
	if not _shown and now_ms - _since_ms >= _delay_ms:
		_shown = true
		visible = true
	if _shown:
		_place(mouse)


func _fill(info: TowerInfo, purchase: ClassPreview) -> void:
	UiKit.clear(_box)
	_box.add_child(UiKit.label(info.title, 15, Color("#ffe9a8"), true))
	if info.summary != "":
		_box.add_child(_wrapped(info.summary, 12, Color("#c8c8c8")))
	_box.add_child(UiKit.label(info.subtitle, 12, Color("#9fb3c8")))
	_box.add_child(_labelled("Ataque", info.attack))
	if info.trigger != "":
		_box.add_child(_labelled("Gatilho", info.trigger))
	_progress = UiKit.label("", 12, Color("#9fd6a0"))
	_progress.visible = false
	_box.add_child(_progress)
	if purchase != null and purchase.fusion != "":
		_box.add_child(_labelled("Compra", "funde: %s" % purchase.fusion))
	elif purchase != null and not purchase.classes.is_empty():
		_box.add_child(_labelled("Compra", "\n".join(purchase.classes)))
	reset_size()


func _wrapped(text: String, size: int, color: Color) -> Label:
	var l := UiKit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(260, 0)
	return l


func _labelled(title: String, text: String) -> Control:
	var row := UiKit.vbox(0)
	row.add_child(UiKit.label(title, 11, UiKit.MUTED, true))
	row.add_child(_wrapped(text, 12, UiKit.TEXT))
	return row


func _hide() -> void:
	_shown = false
	visible = false


func _place(mouse: Vector2) -> void:
	var area := get_viewport_rect().size
	var tip := size
	var pos := mouse + _offset
	if pos.x + tip.x > area.x - _edge_margin:
		pos.x = mouse.x - _offset.x - tip.x
	if pos.y + tip.y > area.y - _edge_margin:
		pos.y = mouse.y - _offset.y - tip.y
	pos.x = maxf(_edge_margin, pos.x)
	pos.y = maxf(_edge_margin, pos.y)
	position = pos
