class_name ShopCard
extends Control
## Carta da loja, desenhada por código, no estilo de carta de jogo: moldura grossa na cor da raridade,
## círculo dourado de custo no canto, nome numa faixa no topo, ilustração grande no meio e as classes
## numa placa embaixo. Brilho verde quando dá para comprar (dourado se a compra funde ou a carta está
## na mão). A descrição não fica na carta: aparece na janela de informações ao passar o mouse
## (`TowerTooltip`). Comum é cinza e não leva etiqueta.
##
## A carta fica numa mão em leque (`ShopPanel`): `rest_rotation` é a inclinação dela na mão. Com o mouse
## em cima ela sobe, endireita e cresce. A área do mouse inclui o espaço da subida, então a carta não
## "pisca" quando sobe.
##
## Arte final: se existir `assets/cards/<id da torre>.png`, ela entra na janela da ilustração no lugar
## do medalhão com a inicial.

signal pressed(global_pos: Vector2)

const CARD_W := 112.0
const CARD_H := 160.0
## Quanto a carta sobe com o mouse em cima (a área do mouse cobre essa altura a mais).
const POP := 34.0
const RARITY_COLORS := {"common": "#8f98a3", "uncommon": "#4fa86a", "rare": "#a066dc", "legendary": "#f0a830"}
const PORTRAIT_DIR := "res://assets/cards/"
const HOVER_SCALE := 0.1
const BANNER := Rect2(7.0, 7.0, CARD_W - 14.0, 26.0)
const ART := Rect2(7.0, 37.0, CARD_W - 14.0, 82.0)
const PLATE := Rect2(7.0, 123.0, CARD_W - 14.0, 30.0)
const COST_CENTER := Vector2(14.0, 14.0)
const COST_RADIUS := 14.0
const INK := Color("#16110c")

var slot_index := 0
## Inclinação da carta na mão (radianos).
var rest_rotation := 0.0
var _slot: ShopModel.SlotModel
var _carried := false
var _accent := Color(RARITY_COLORS["common"])
var _portrait: Texture2D = null
## 0 = parada, 1 = com o mouse em cima (anima a subida, o giro e o brilho).
var hover := 0.0:
	set(value):
		hover = value
		rotation = rest_rotation * (1.0 - 0.85 * hover)
		scale = Vector2.ONE * (1.0 + HOVER_SCALE * hover)
		z_index = 20 if hover > 0.01 else 0
		queue_redraw()
var _tween: Tween = null


func setup(slot: ShopModel.SlotModel, carried: bool) -> void:
	_slot = slot
	_carried = carried
	slot_index = slot.index
	if not slot.is_empty():
		_accent = Color(RARITY_COLORS.get(slot.rarity, RARITY_COLORS["common"]))
		var path := PORTRAIT_DIR + slot.tower_type + ".png"
		if ResourceLoader.exists(path):
			_portrait = load(path) as Texture2D
	custom_minimum_size = Vector2(CARD_W, CARD_H + POP)
	size = custom_minimum_size
	# O pé da carta é o eixo do giro e da escala (a carta cresce para cima).
	pivot_offset = Vector2(CARD_W * 0.5, CARD_H + POP)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not slot.is_empty() and slot.affordable and not slot.blocked_by_limit:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if slot.is_empty():
		modulate.a = 0.35
	elif not slot.affordable or slot.blocked_by_limit:
		modulate.a = 0.6
	mouse_entered.connect(func() -> void: _hover_to(1.0))
	mouse_exited.connect(func() -> void: _hover_to(0.0))
	queue_redraw()


## O mouse já estava em cima quando a carta foi refeita: mostra o estado sem animar.
func snap_hover(on: bool) -> void:
	hover = 1.0 if on else 0.0


## Baixa a carta (outra carta ganhou o mouse).
func lower() -> void:
	if hover > 0.0:
		_hover_to(0.0)


func _hover_to(target: float) -> void:
	if _slot == null or _slot.is_empty():
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "hover", target, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Parada, só a carta recebe o mouse (a folga de cima deixa o clique passar para o mapa); levantada,
## a folga também conta, para ela não descer enquanto o mouse a segue.
func _has_point(point: Vector2) -> bool:
	var top := 0.0 if hover > 0.01 else POP
	return Rect2(0.0, top, CARD_W, CARD_H + POP - top).has_point(point)


func _gui_input(event: InputEvent) -> void:
	if _slot == null or _slot.is_empty():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit((event as InputEventMouseButton).global_position)


func _draw() -> void:
	if _slot == null:
		return
	# A carta é desenhada na parte de baixo do controle; a de cima é a folga da subida.
	draw_set_transform(Vector2(0.0, POP * (1.0 - hover)))
	var rect := Rect2(0.0, 0.0, CARD_W, CARD_H)
	if _slot.is_empty():
		_box(rect, Color(0.1, 0.11, 0.12, 0.8), Color("#3a3d40"), 2, 10)
		_text_centered("comprada", CARD_H * 0.5, 11, Color("#6a6e72"), CARD_W)
		return
	# Brilho: só com o mouse em cima de uma carta que dá para comprar (verde; dourado se funde). A carta
	# presa ao mouse brilha dourado o tempo todo.
	var playable := _slot.affordable and not _slot.blocked_by_limit
	var glow := Color(0, 0, 0, 0)
	var strength := hover
	if _carried:
		glow = Color("#ffd75e")
		strength = 1.0
	elif playable:
		glow = Color("#ffd75e") if _slot.fuse_star > 0 else Color("#58ff62")

	_box(Rect2(rect.position + Vector2(2.0, 5.0), rect.size), Color(0.0, 0.0, 0.0, 0.45), Color(0, 0, 0, 0), 0, 10)
	if glow.a > 0.0 and strength > 0.01:
		_box(rect.grow(7.0), Color(glow, 0.14 * strength), Color(0, 0, 0, 0), 0, 16)
		_box(rect.grow(4.5), Color(glow, 0.32 * strength), Color(0, 0, 0, 0), 0, 14)
		_box(rect.grow(2.0), Color(glow, 0.85 * strength), Color(0, 0, 0, 0), 0, 12)

	# Moldura.
	var frame := _accent.lerp(Color.WHITE, 0.18 * hover)
	_box(rect, INK, Color(0, 0, 0, 0), 0, 10)
	_box(rect.grow(-2.0), frame, frame.darkened(0.4), 2, 8)

	_draw_art(ART)
	_draw_tags(ART)
	_draw_banner(frame)
	_draw_plate(frame)
	_draw_cost()


func _draw_banner(frame: Color) -> void:
	_box(BANNER, frame.darkened(0.58), frame.lightened(0.25), 1, 6)
	var left := 29.0
	var width := BANNER.end.x - left - 3.0
	var font := UiKit.bold_font()
	var ink := Color("#2a1c0c")
	for font_size: int in [12, 11, 10]:
		if font.get_string_size(_slot.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
			var base := BANNER.position.y + BANNER.size.y * 0.5 + font_size * 0.36
			font.draw_string_outline(get_canvas_item(), Vector2(left, base), _slot.name,
					HORIZONTAL_ALIGNMENT_CENTER, width, font_size, 4, ink)
			font.draw_string(get_canvas_item(), Vector2(left, base), _slot.name,
					HORIZONTAL_ALIGNMENT_CENTER, width, font_size, Color("#fff8e4"))
			return
	# Nome longo: duas linhas.
	var top := BANNER.position.y + 11.0
	font.draw_multiline_string(get_canvas_item(), Vector2(left + 1.0, top + 1.0), _slot.name,
			HORIZONTAL_ALIGNMENT_CENTER, width, 10, 2, ink)
	font.draw_multiline_string(get_canvas_item(), Vector2(left, top), _slot.name,
			HORIZONTAL_ALIGNMENT_CENTER, width, 10, 2, Color("#fff8e4"))


func _draw_cost() -> void:
	CoinIcon.draw_coin(self, COST_CENTER, COST_RADIUS)
	var text := str(_slot.price)
	var font := UiKit.bold_font()
	var font_size := 16 if text.length() <= 2 else 12
	var color := Color.WHITE if _slot.affordable else Color("#ffa595")
	var origin := COST_CENTER + Vector2(-COST_RADIUS, font_size * 0.36)
	font.draw_string_outline(get_canvas_item(), origin, text, HORIZONTAL_ALIGNMENT_CENTER, COST_RADIUS * 2.0,
			font_size, 5, Color("#4a2c06"))
	font.draw_string(get_canvas_item(), origin, text, HORIZONTAL_ALIGNMENT_CENTER, COST_RADIUS * 2.0, font_size, color)


## Ilustração: com arte, a imagem; sem ela, um cenário simples com o medalhão da inicial.
func _draw_art(art: Rect2) -> void:
	if _portrait != null:
		draw_texture_rect(_portrait, art, false)
		draw_rect(art, _accent.darkened(0.5), false, 2.0)
		return
	var top := _accent.darkened(0.2)
	var bottom := _accent.darkened(0.7)
	draw_polygon(
			PackedVector2Array([art.position, Vector2(art.end.x, art.position.y), art.end, Vector2(art.position.x, art.end.y)]),
			PackedColorArray([top, top, bottom, bottom]))
	# Raios de luz saindo de cima.
	var ray_origin := Vector2(art.get_center().x, art.position.y - 5.0)
	for offset in [-36.0, -6.0, 24.0]:
		draw_colored_polygon(PackedVector2Array([ray_origin,
				Vector2(art.get_center().x + offset - 9.0, art.end.y),
				Vector2(art.get_center().x + offset + 14.0, art.end.y)]), Color(1.0, 1.0, 1.0, 0.07))
	# Chão em colina.
	var ground := _accent.darkened(0.82)
	draw_colored_polygon(PackedVector2Array([
			Vector2(art.position.x, art.end.y), Vector2(art.position.x, art.end.y - 15.0),
			Vector2(art.position.x + art.size.x * 0.35, art.end.y - 21.0),
			Vector2(art.position.x + art.size.x * 0.7, art.end.y - 13.0),
			Vector2(art.end.x, art.end.y - 18.0), art.end]), ground)
	var center := art.get_center() + Vector2(0.0, -3.0)
	draw_circle(center, 24.0, Color(0.0, 0.0, 0.0, 0.3))
	draw_arc(center, 24.0, 0.0, TAU, 32, _accent.lightened(0.15), 2.5, true)
	draw_arc(center, 19.0, 0.0, TAU, 32, _accent.darkened(0.35), 1.2, true)
	var font := UiKit.bold_font()
	var base := center + Vector2(-18.0, 11.0)
	font.draw_string_outline(get_canvas_item(), base, _slot.initial(), HORIZONTAL_ALIGNMENT_CENTER, 36.0, 32, 6, INK)
	font.draw_string(get_canvas_item(), base, _slot.initial(), HORIZONTAL_ALIGNMENT_CENTER, 36.0, 32, Color("#fff4d6"))
	draw_rect(art, _accent.darkened(0.5), false, 2.0)


## Etiquetas na ilustração: raridade (menos a comum), subida de ★ e aviso de limite.
func _draw_tags(art: Rect2) -> void:
	var tag := _slot.rarity_tag()
	if tag != "":
		_pill(tag, Vector2(art.end.x - 4.0, art.position.y + 4.0), true, _accent.darkened(0.55), _accent.lightened(0.55), 9)
	if _slot.fuse_star > 0:
		_pill("★%d↑" % _slot.fuse_star, Vector2(art.position.x + 4.0, art.end.y - 4.0), false, Color("#4a3c12"), Color("#ffd75e"), 11, true)
	elif _slot.blocked_by_limit:
		_pill(DataLoader.load_json("ui.json")["texts"]["limitWarning"], Vector2(art.position.x + 4.0, art.end.y - 4.0), false,
				Color("#4a1e18"), Color("#ff7a6b"), 10, true)


## Placa clara embaixo, com as classes (cada uma na sua linha se não couberem numa só).
func _draw_plate(frame: Color) -> void:
	_box(PLATE, Color("#e9dcc0"), frame.darkened(0.5), 2, 6)
	var color := Color("#3b2a14")
	var width := PLATE.size.x - 6.0
	var font := UiKit.bold_font()
	var line := " · ".join(_slot.classes)
	if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x <= width:
		_plate_text(line, PLATE.position.y + 19.0, 10, color)
		return
	var baseline := PLATE.position.y + 13.0
	for name in _slot.classes:
		_plate_text(name, baseline, 9, color)
		baseline += 11.0


func _plate_text(text: String, baseline: float, font_size: int, color: Color) -> void:
	UiKit.bold_font().draw_string(get_canvas_item(), Vector2(PLATE.position.x + 3.0, baseline), text,
			HORIZONTAL_ALIGNMENT_CENTER, PLATE.size.x - 6.0, font_size, color)


## Etiqueta arredondada; `from_right` ancora pela direita e `from_bottom` por baixo.
func _pill(text: String, anchor: Vector2, from_right: bool, bg: Color, fg: Color, font_size: int, from_bottom: bool = false) -> void:
	var font := UiKit.bold_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 12.0
	var height := font_size + 7.0
	var x := anchor.x - width if from_right else anchor.x
	var y := anchor.y - height if from_bottom else anchor.y
	_box(Rect2(x, y, width, height), bg, fg.darkened(0.2), 1, int(height * 0.5))
	font.draw_string(get_canvas_item(), Vector2(x, y + height * 0.5 + font_size * 0.36), text,
			HORIZONTAL_ALIGNMENT_CENTER, width, font_size, fg)


func _text_centered(text: String, baseline: float, font_size: int, color: Color, width: float) -> void:
	ThemeDB.fallback_font.draw_string(get_canvas_item(), Vector2((CARD_W - width) * 0.5, baseline), text,
			HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)


func _box(rect: Rect2, fill: Color, border: Color, border_width: int, radius: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	style.draw(get_canvas_item(), rect)
