class_name HintLabels
extends Control
## Avisos pequenos sobre o jogo, todos sem capturar o mouse:
## - `link_hint`: texto perto do mouse com a torre na mão ("ativa 2 · carga 1", "funde: ★2↑");
## - `locked_message`: "Torres travadas durante a onda" ao tentar mover com onda ativa;
## - `wave_announce`: aviso grande de onda de elite ou chefão;
## - `version_label`: versão da build no canto.
## (porte de `linkHint.ts`, `waveAnnounce.ts`, `versionLabel.ts` e da mensagem de `towerDragController.ts`)

var _link_panel: PanelContainer
var _link_box: VBoxContainer
var _link_key := ""
var _locked_panel: PanelContainer
var _locked_left_ms := 0.0
var _announce_panel: PanelContainer
var _announce_label: Label
var _announce_left_ms := 0.0
var _version: Label
var _link_offset: Vector2


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(self)
	var ui: Dictionary = DataLoader.load_json("ui.json")
	_link_offset = Vector2(float(ui["linkHint"]["offsetX"]), float(ui["linkHint"]["offsetY"]))
	_link_panel = UiKit.panel(Color(0.0784, 0.0824, 0.0902, 0.9), UiKit.BORDER, 6, Vector2(8, 3))
	_link_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_link_panel.z_index = 60
	_link_box = UiKit.vbox(0)
	_link_panel.add_child(_link_box)
	_link_panel.visible = false
	add_child(_link_panel)

	_locked_panel = UiKit.panel(Color(0.0784, 0.0824, 0.0902, 0.9), Color("#c05050"), 8, Vector2(16, 6))
	_locked_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_locked_panel.add_child(UiKit.label(ui["texts"]["towersLocked"], 15, Color("#ffd2d2"), true))
	_locked_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 56)
	_locked_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_locked_panel.visible = false
	add_child(_locked_panel)

	_announce_panel = PanelContainer.new()
	_announce_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_announce_label = UiKit.label("", 40, Color.WHITE, true)
	_announce_panel.add_child(_announce_label)
	_announce_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_announce_panel.position.y -= 160
	_announce_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_announce_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_announce_panel.visible = false
	add_child(_announce_panel)

	_version = UiKit.label("", 11, Color("#5d6166"))
	_version.anchor_top = 1.0
	_version.anchor_bottom = 1.0
	_version.offset_left = 4.0
	_version.offset_top = -20.0
	_version.offset_bottom = -2.0
	_version.offset_right = 200.0
	add_child(_version)


func set_version(text: String) -> void:
	_version.text = "v %s" % text


## Mostra a mensagem de torres travadas por `lockedMessageMs`.
func show_locked() -> void:
	_locked_left_ms = float(DataLoader.load_json("ui.json")["towerDrag"]["lockedMessageMs"])
	_locked_panel.visible = true


## Mostra o aviso de onda de elite/chefão: announcement = {"kind", "text"}.
func show_announcement(announcement: Dictionary) -> void:
	var elite: bool = announcement["kind"] == "elite"
	_announce_label.text = announcement["text"]
	_announce_label.add_theme_font_size_override("font_size", 40 if elite else 52)
	_announce_label.add_theme_color_override("font_color", Color("#e4c2ff") if elite else Color("#ffd6d0"))
	_announce_panel.add_theme_stylebox_override("panel", UiKit.style(
			Color(0.2745, 0.1176, 0.3922, 0.85) if elite else Color(0.4314, 0.0784, 0.0588, 0.88),
			Color("#c77dff") if elite else Color("#ff5a4a"), 10, 2, Vector2(36, 12)))
	_announce_panel.visible = true
	_announce_left_ms = WaveAnnounceModel.duration_ms()


## Linhas perto do mouse (vazio esconde).
func update_link_hint(lines: Array[String], mouse: Vector2) -> void:
	var key := "\n".join(lines)
	if key != _link_key:
		_link_key = key
		UiKit.clear(_link_box)
		for line in lines:
			_link_box.add_child(UiKit.label(line, 12))
		_link_panel.reset_size()
	_link_panel.visible = not lines.is_empty()
	if _link_panel.visible:
		_link_panel.position = mouse + _link_offset


## Chame a cada quadro com o tempo real (ms): apaga os avisos temporários.
func tick(delta_ms: float) -> void:
	if _locked_left_ms > 0.0:
		_locked_left_ms -= delta_ms
		if _locked_left_ms <= 0.0:
			_locked_panel.visible = false
	if _announce_left_ms > 0.0:
		_announce_left_ms -= delta_ms
		if _announce_left_ms <= 0.0:
			_announce_panel.visible = false
