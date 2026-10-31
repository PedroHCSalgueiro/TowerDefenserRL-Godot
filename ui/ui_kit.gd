class_name UiKit
extends RefCounted
## Ajudantes de interface: painéis escuros, rótulos e botões com o visual do jogo no Phaser
## (fundo #141517 com transparência, borda #3a3d40, texto claro).

const BG := Color(0.0784, 0.0824, 0.0902, 0.92)
const BORDER := Color("#3a3d40")
const TEXT := Color("#dddddd")
const MUTED := Color("#9a9a9a")
const GOLD := Color("#ffd75e")
const GREEN := Color("#9be37a")
## Friso de bronze dos painéis de HUD.
const FRAME := Color("#7a6232")
const BUTTON_BG := Color("#33363a")
const BUTTON_BORDER := Color("#4a4d50")
const BUTTON_HOVER := Color("#44484d")
## Fonte base (px) dos textos pequenos; a UI escala com o tamanho da janela.
const FONT := 14


## Ocupa o espaço inteiro do pai (âncoras 0..1 e margens zero).
static func full_rect(c: Control) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = 0.0
	c.offset_top = 0.0
	c.offset_right = 0.0
	c.offset_bottom = 0.0


static func style(bg: Color = BG, border: Color = BORDER, radius: int = 8, border_width: int = 1,
		padding: Vector2 = Vector2(10, 8)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = padding.x
	s.content_margin_right = padding.x
	s.content_margin_top = padding.y
	s.content_margin_bottom = padding.y
	return s


## Painel de HUD com cara de jogo: fundo escuro, friso de bronze e sombra.
static func game_style(radius: int = 12, padding: Vector2 = Vector2(12, 8)) -> StyleBoxFlat:
	var s := style(Color(0.075, 0.08, 0.1, 0.94), FRAME, radius, 2, padding)
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0.0, 3.0)
	s.anti_aliasing = true
	return s


static func game_panel(radius: int = 12, padding: Vector2 = Vector2(12, 8)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", game_style(radius, padding))
	return p


## PanelContainer com o estilo padrão dos painéis.
static func panel(bg: Color = BG, border: Color = BORDER, radius: int = 8, padding: Vector2 = Vector2(10, 8)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(bg, border, radius, 1, padding))
	return p


static func label(text: String = "", size: int = FONT, color: Color = TEXT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bold:
		l.add_theme_font_override("font", bold_font())
	return l


static var _bold: FontVariation = null


## Fonte padrão engrossada (funciona também na exportação web, sem fontes do sistema).
static func bold_font() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = 0.55
	return _bold


## Botão sem foco (as teclas do jogo continuam chegando) no estilo dos botões da loja.
static func button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", FONT)
	b.add_theme_color_override("font_color", Color("#eeeeee"))
	b.add_theme_color_override("font_disabled_color", Color(0.93, 0.93, 0.93, 0.4))
	b.add_theme_stylebox_override("normal", _button_style(BUTTON_BG, BUTTON_BORDER))
	b.add_theme_stylebox_override("hover", _button_style(BUTTON_HOVER, FRAME.lightened(0.25)))
	b.add_theme_stylebox_override("pressed", _button_style(BUTTON_BG.darkened(0.2), FRAME, true))
	b.add_theme_stylebox_override("disabled", _button_style(Color(BUTTON_BG, 0.5), BUTTON_BORDER))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if on_pressed.is_valid():
		b.pressed.connect(on_pressed)
	return b


## Deixa o botão enxuto (fonte `font_size` e margens pequenas), para HUD e painéis compactos.
static func compact(b: Button, font_size: int = 12) -> Button:
	b.add_theme_font_size_override("font_size", font_size)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var s := (b.get_theme_stylebox(state) as StyleBoxFlat).duplicate() as StyleBoxFlat
		s.content_margin_left = 7.0
		s.content_margin_right = 7.0
		s.content_margin_top = 2.0
		s.content_margin_bottom = 3.0
		b.add_theme_stylebox_override(state, s)
	return b


## Botão de destaque (chamar onda): verde, com a mesma sombra de baixo dos demais.
static func primary_button(text: String, on_pressed: Callable) -> Button:
	var b := button(text, on_pressed)
	b.add_theme_font_override("font", bold_font())
	b.add_theme_stylebox_override("normal", _button_style(Color("#2f6a34"), Color("#7fd06b")))
	b.add_theme_stylebox_override("hover", _button_style(Color("#3b8040"), Color("#a6ec92")))
	b.add_theme_stylebox_override("pressed", _button_style(Color("#265a2a"), Color("#7fd06b"), true))
	b.add_theme_stylebox_override("disabled", _button_style(Color("#2f6a34", 0.35), Color("#7fd06b", 0.35)))
	return b


## Botão grande dourado (rerolar), no estilo do "Fim do turno" dos jogos de cartas.
static func accent_button(text: String, on_pressed: Callable) -> Button:
	var b := button(text, on_pressed)
	b.custom_minimum_size = Vector2(150, 44)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_font_override("font", bold_font())
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color("#3a2406"))
	b.add_theme_color_override("font_hover_color", Color("#2a1a04"))
	b.add_theme_color_override("font_disabled_color", Color("#3a2406", 0.45))
	b.add_theme_stylebox_override("normal", _button_style(Color("#f0b13c"), Color("#fff0a8")))
	b.add_theme_stylebox_override("hover", _button_style(Color("#ffc95a"), Color("#fff6c8")))
	b.add_theme_stylebox_override("pressed", _button_style(Color("#d99a2c"), Color("#fff0a8"), true))
	b.add_theme_stylebox_override("disabled", _button_style(Color("#f0b13c", 0.4), Color("#fff0a8", 0.4)))
	return b


## Botão com a borda de baixo mais grossa (relevo); apertado, afunda.
static func _button_style(bg: Color, border: Color, sunk: bool = false) -> StyleBoxFlat:
	var s := style(bg, border, 6, 1, Vector2(10, 5))
	s.border_width_bottom = 1 if sunk else 3
	s.content_margin_top = 6.0 if sunk else 5.0
	s.content_margin_bottom = 4.0 if sunk else 5.0
	s.anti_aliasing = true
	return s


static func hbox(separation: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


static func vbox(separation: int = 4) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


## Remove e libera todos os filhos de um nó.
static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
