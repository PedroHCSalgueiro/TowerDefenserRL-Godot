extends SceneTree
## Gera uma torre isométrica detalhada só por código (4 quadros: chama e janelas tremulam).
## Cada face é pintada pixel a pixel por um "shader" que recebe a posição NA FACE (u = distância
## horizontal desde a quina, v = altura em pixels), o que mantém pedras e tábuas na perspectiva.
##   godot --headless --path . -s dev/proto2d/make_tower.gd

const OUT := "res://dev/proto2d/art/"
const W := 112
const H := 190
## Centro do pé da torre na imagem (âncora do sprite).
const BX := 56.0
const BY := 164.0
const OUTLINE := Color("14110f")

const SLATE: Array[Color] = [Color("1c1e23"), Color("292c33"), Color("383c45"), Color("4a4f59"), Color("5f656f"), Color("7a808a"), Color("989ea6")]
const WOOD: Array[Color] = [Color("24150d"), Color("3b2415"), Color("56351e"), Color("74492a"), Color("946238"), Color("b5804c"), Color("d2a06a")]
const TILE: Array[Color] = [Color("4f1e12"), Color("742d16"), Color("9a401c"), Color("bd5a26"), Color("db7a34"), Color("f09c50")]
const MOSS: Array[Color] = [Color("2a4420"), Color("3b612f"), Color("578a41"), Color("7cae55")]
const GLOW: Array[Color] = [Color("c2571a"), Color("e8862a"), Color("f9b13f"), Color("ffd86b"), Color("fff3b0")]
const WARM := Color("f08a2c")
const TILE_BLUE: Array[Color] = [Color("16264f"), Color("1f3a78"), Color("2c55a3"), Color("3f76cc"), Color("5f9ae6"), Color("8cc0f5")]
const GLOW_CYAN: Array[Color] = [Color("1f7fa8"), Color("2fa8cf"), Color("5bd0ea"), Color("9debf7"), Color("e6fdff")]
const WARM_CYAN := Color("4cc4e8")

var _img: Image
var _flick := 0
var _tile := TILE
var _glow := GLOW
var _warm := WARM


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var first: Array[Image] = []
	for variant: Array in [["fine", TILE, GLOW, WARM], ["arcane", TILE_BLUE, GLOW_CYAN, WARM_CYAN]]:
		_tile = variant[1]
		_glow = variant[2]
		_warm = variant[3]
		for f in 4:
			_flick = f
			_img = _outlined(_tower())
			_tufts()
			_img.save_png(OUT + "tower_%s_%d.png" % [variant[0], f])
			if f == 0:
				first.append(_img)
	_preview(first).save_png("res://dev/proto2d/tower_fine_preview.png")
	quit()


# ---------------------------------------------------------------- utilidades

func _rnd(a: int, b: int, s: int) -> float:
	var n := (a * 73856093) ^ (b * 19349663) ^ (s * 83492791)
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xFFFF) / 65535.0


func _ramp(ramp: Array[Color], t: float) -> Color:
	return ramp[clampi(int(t * ramp.size()), 0, ramp.size() - 1)]


func _put(x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		_img.set_pixel(x, y, c)


func _poly(pts: Array, c: Color) -> void:
	var poly := PackedVector2Array(pts)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p: Vector2 in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	for y in range(floori(lo.y), ceili(hi.y) + 1):
		for x in range(floori(lo.x), ceili(hi.x) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly):
				_put(x, y, c)


func _line(a: Vector2, b: Vector2, width: float, c: Color) -> void:
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(width, width)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(width, width)
	for y in range(floori(lo.y), ceili(hi.y) + 1):
		for x in range(floori(lo.x), ceili(hi.x) + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) <= width * 0.5:
				_put(x, y, c)


func _outlined(src: Image) -> Image:
	var out := src.duplicate() as Image
	for y in H:
		for x in W:
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q := Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < W and q.y < H and src.get_pixel(q.x, q.y).a > 0.5:
					out.set_pixel(x, y, OUTLINE)
					break
	return out


func _preview(sprites: Array[Image]) -> Image:
	var bg := Image.create(W * sprites.size(), H, false, Image.FORMAT_RGBA8)
	var greens := [Color("3f6b35"), Color("477a3a"), Color("39602f")]
	for y in H:
		for x in W * sprites.size():
			bg.set_pixel(x, y, greens[int(_rnd(x >> 1, y >> 1, 5) * 2.99)])
	for i in sprites.size():
		bg.blend_rect(sprites[i], Rect2i(0, 0, W, H), Vector2i(i * W, 0))
	bg.resize(bg.get_width() * 3, H * 3, Image.INTERPOLATE_NEAREST)
	return bg


# ---------------------------------------------------------------- caixa isométrica

## Caixa com pé em losango centrado em (cx, cy), meia-largura `a` e altura `h`. Os shaders recebem
## (u, v) na face. Quina da frente e aresta de cima ganham um brilho, para a forma ler bem.
func _box(cx: float, cy: float, a: float, h: float, left: Callable, right: Callable, top: Callable = Callable()) -> void:
	for x in range(floori(cx - a), floori(cx)):
		var u := x + 0.5 - (cx - a)
		var base := cy + u * 0.5
		for y in range(floori(base - h), ceili(base)):
			var v := base - (y + 0.5)
			if v < 0.0 or v > h:
				continue
			var c: Color = left.call(u, v)
			if u > a - 1.0 or v > h - 1.0:
				c = c.lightened(0.14)
			_put(x, y, c)
	for x in range(floori(cx), ceili(cx + a)):
		var u := x + 0.5 - cx
		var base := cy + a * 0.5 - u * 0.5
		for y in range(floori(base - h), ceili(base)):
			var v := base - (y + 0.5)
			if v < 0.0 or v > h:
				continue
			var c: Color = right.call(u, v)
			if u < 1.0 or v > h - 1.0:
				c = c.lightened(0.1)
			_put(x, y, c)
	if top.is_valid():
		var ty := cy - h
		for y in range(floori(ty - a * 0.5), ceili(ty + a * 0.5)):
			for x in range(floori(cx - a), ceili(cx + a)):
				if absf(x + 0.5 - cx) / a + absf(y + 0.5 - ty) / (a * 0.5) <= 1.0:
					_put(x, y, top.call(x + 0.5 - cx, y + 0.5 - ty))


## Ponto na face da caixa, em coordenadas da imagem.
func _on_left(cx: float, cy: float, a: float, u: float, v: float) -> Vector2:
	return Vector2(cx - a + u, cy + u * 0.5 - v)


func _on_right(cx: float, cy: float, a: float, u: float, v: float) -> Vector2:
	return Vector2(cx + u, cy + a * 0.5 - u * 0.5 - v)


# ---------------------------------------------------------------- materiais

## Janela em arco. Devolve a cor se (u, v) cai nela (moldura ou vidro aceso), ou null.
func _window_px(w: Dictionary, u: float, v: float) -> Variant:
	var uc: float = (w["u0"] + w["u1"]) * 0.5
	var half: float = (w["u1"] - w["u0"]) * 0.5
	var du := absf(u - uc)
	var arch := 3.0 * pow(minf(du / (half + 1.5), 1.0), 2.0)
	var top: float = w["v1"] - arch
	if du > half + 1.5 or v < w["v0"] - 1.5 or v > top + 1.5:
		return null
	if du > half or v < w["v0"] or v > top:
		return _ramp(WOOD, 0.3 if v > w["v0"] else 0.55)
	var vc: float = (w["v0"] + w["v1"]) * 0.5
	if du < 0.5 or absf(v - vc) < 0.5:
		return WOOD[0]
	var d := Vector2(du / half, (v - vc) / ((w["v1"] - w["v0"]) * 0.5)).length()
	var bright := 1.0 - d * 0.75 + (0.12 if _flick % 2 == 0 else 0.0)
	return _ramp(_glow, bright)


## Luz da janela sobre a parede, em faixas (fica com cara de pixel art, sem degradê liso).
func _spill(c: Color, windows: Array, u: float, v: float) -> Color:
	var amount := 0.0
	for w: Dictionary in windows:
		var center := Vector2((w["u0"] + w["u1"]) * 0.5, (w["v0"] + w["v1"]) * 0.5)
		var d := Vector2(u, v).distance_to(center) / 15.0
		amount = maxf(amount, 1.0 - d)
	if amount <= 0.0:
		return c
	amount += 0.08 if _flick % 2 == 0 else 0.0
	return c.lerp(_warm, floorf(amount * 4.0) / 4.0 * 0.6)


## Pedra: fiadas com blocos de largura variada, tom por bloco, brilho em cima, sujeira/musgo embaixo.
func _stone(seed_v: int, tone: float, h: float, windows: Array = [], door: Dictionary = {}, moss: float = 0.0, row_h: int = 6) -> Callable:
	return func(u: float, v: float) -> Color:
		for w: Dictionary in windows:
			var px: Variant = _window_px(w, u, v)
			if px != null:
				return px
		if not door.is_empty():
			var dp: Variant = _door_px(door, u, v)
			if dp != null:
				return dp
		var row := floori(v / row_h)
		var lv := v - row * row_h
		var offset := _rnd(row, 3, seed_v) * 11.0
		var bw := 7.0 + floorf(_rnd(row, 9, seed_v) * 4.0)
		var cell := floori((u + offset) / bw)
		var lu := u + offset - cell * bw
		var t := tone + (_rnd(cell, row, seed_v) - 0.5) * 0.24
		# sombra sob o que está em cima e sujeira junto ao chão
		t -= 0.2 if (h - v) < 5.0 else 0.0
		t -= 0.1 if v < 4.0 else 0.0
		if lv > row_h - 1.5:
			t += 0.13
		if lu > bw - 1.5:
			t -= 0.07
		if _rnd(int(u), int(v), seed_v + 7) > 0.93:
			t -= 0.12
		var c := _ramp(SLATE, t)
		if lv < 1.0 or lu < 1.0:
			c = _ramp(SLATE, tone - 0.38)
		elif moss > 0.0 and v < moss and _rnd(int(u / 3.0), int(v / 3.0), seed_v + 21) > 0.35 + v / moss * 0.5:
			c = _ramp(MOSS, _rnd(int(u), int(v), seed_v + 22))
		return _spill(c, windows, u, v)


## Tábuas horizontais com veio, emenda escura e prego de vez em quando.
func _planks(seed_v: int, tone: float, row_h: int = 3) -> Callable:
	return func(u: float, v: float) -> Color:
		var row := floori(v / row_h)
		var lv := v - row * row_h
		if lv < 1.0:
			return _ramp(WOOD, tone - 0.3)
		var cell := floori((u + _rnd(row, 1, seed_v) * 14.0) / 14.0)
		var t := tone + (_rnd(cell, row, seed_v) - 0.5) * 0.2
		if _rnd(int(u / 3.0), row, seed_v + 3) > 0.7:
			t -= 0.1
		if lv > row_h - 1.0:
			t += 0.08
		return _ramp(WOOD, t)


## Tábuas no topo de uma plataforma (correm numa diagonal da grade).
func _deck(seed_v: int, tone: float) -> Callable:
	return func(dx: float, dy: float) -> Color:
		var s := dx * 0.5 + dy
		var row := floori(s / 3.0)
		if s - row * 3.0 < 1.0:
			return _ramp(WOOD, tone - 0.28)
		return _ramp(WOOD, tone + (_rnd(row, floori((dx * 0.5 - dy) / 9.0), seed_v) - 0.5) * 0.18)


## Parede enxaimel do último andar: reboco claro entre vigas, com janela grande.
func _timber(tone: float, a: float, h: float, windows: Array) -> Callable:
	return func(u: float, v: float) -> Color:
		for w: Dictionary in windows:
			var px: Variant = _window_px(w, u, v)
			if px != null:
				return px
		if u < 2.0 or u > a - 2.0 or v < 2.0 or v > h - 2.0 or absf(u - a * 0.5) > a * 0.5 - 2.0:
			return _ramp(WOOD, tone)
		var c := Color("b9a27e").darkened(0.5 - tone * 0.6)
		if _rnd(int(u), int(v), 44) > 0.9:
			c = c.darkened(0.12)
		return _spill(c, windows, u, v)


func _door_px(d: Dictionary, u: float, v: float) -> Variant:
	var uc: float = (d["u0"] + d["u1"]) * 0.5
	var half: float = (d["u1"] - d["u0"]) * 0.5
	var du := absf(u - uc)
	var top: float = d["h"] - 4.0 * pow(minf(du / (half + 2.0), 1.0), 2.0)
	if du > half + 2.0 or v > top + 2.0:
		return null
	if du > half or v > top:
		return _ramp(SLATE, 0.78 if int(v / 3.0) % 2 == 0 else 0.62)
	if absf(v - d["h"] * 0.3) < 0.8 or absf(v - d["h"] * 0.68) < 0.8:
		return SLATE[1]
	if int(u) % 3 == 0:
		return WOOD[1]
	return _ramp(WOOD, 0.42 + _rnd(int(u), int(v / 4.0), 31) * 0.14)


# ---------------------------------------------------------------- a torre

func _tower() -> Image:
	_img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	_ground_detail(true)
	var y := BY

	# embasamento largo de pedra, com degraus de madeira à direita
	_box(BX, y, 31.0, 9.0, _stone(1, 0.66, 99.0, [], {}, 8.0, 5), _stone(2, 0.46, 99.0, [], {}, 8.0, 5),
		func(dx: float, dy: float) -> Color:
			return _ramp(SLATE, 0.58 + (_rnd(floori(dx / 5.0), floori(dy / 3.0), 3) - 0.5) * 0.25))
	y -= 9.0

	# corpo de baixo: porta na direita, janela na esquerda
	var a := 24.0
	var h := 34.0
	var win_l := [{"u0": 8.0, "u1": 15.0, "v0": 16.0, "v1": 27.0}]
	var door := {"u0": 6.0, "u1": 16.0, "h": 19.0}
	_box(BX, y, a, h, _stone(4, 0.66, h, win_l, {}, 7.0), _stone(5, 0.44, h, [], door, 5.0))
	_ivy(y, a)
	_torch(_on_left(BX, y, a, 3.0, 21.0))
	_torch(_on_right(BX, y, a, 20.0, 21.0))
	y -= h

	# cinta de madeira
	_box(BX, y, 26.0, 5.0, _planks(6, 0.62), _planks(7, 0.44),
		func(dx: float, dy: float) -> Color:
			return _ramp(WOOD, 0.5 + _rnd(floori(dx / 4.0), floori(dy / 2.0), 8) * 0.1))
	y -= 5.0

	# corpo de cima: janelas nas duas faces
	a = 23.0
	h = 28.0
	var win_a := [{"u0": 8.0, "u1": 15.0, "v0": 9.0, "v1": 21.0}]
	var win_b := [{"u0": 8.0, "u1": 15.0, "v0": 9.0, "v1": 21.0}]
	_box(BX, y, a, h, _stone(9, 0.64, h, win_a), _stone(10, 0.42, h, win_b))
	var y_upper := y
	y -= h

	# mãos-francesas sob a plataforma
	for u: float in [3.0, 11.5, 20.0]:
		var pl := _on_left(BX, y_upper, a, u, h - 10.0)
		_line(pl, pl + Vector2(-5.0, -7.5), 2.2, WOOD[2])
		var pr := _on_right(BX, y_upper, a, u, h - 10.0)
		_line(pr, pr + Vector2(5.0, -7.5), 2.2, WOOD[1])

	# plataforma de tábuas
	_box(BX, y, 31.0, 5.0, _planks(11, 0.66), _planks(12, 0.46), _deck(13, 0.7))
	y -= 5.0
	var y_deck := y

	# último andar enxaimel, janelões acesos
	a = 23.0
	h = 19.0
	var w1 := [{"u0": 6.0, "u1": 17.0, "v0": 5.0, "v1": 15.0}]
	var w2 := [{"u0": 6.0, "u1": 17.0, "v0": 5.0, "v1": 15.0}]
	_box(BX, y, a, h, _timber(0.5, a, h, w1), _timber(0.34, a, h, w2))
	y -= h

	# beiral e telhado
	_box(BX, y, 30.0, 3.0, _planks(14, 0.4, 2), _planks(15, 0.26, 2))
	y -= 3.0
	_roof(BX, y, 31.0, 27.0)
	var apex := y - 27.0

	# mastro com vela e chama no topo
	_line(Vector2(BX, apex + 3.0), Vector2(BX, apex - 5.0), 2.2, WOOD[1])
	_poly([Vector2(BX - 3, apex - 5), Vector2(BX + 3, apex - 5), Vector2(BX + 2, apex - 7), Vector2(BX - 2, apex - 7)], SLATE[4])
	_flame(Vector2(BX, apex - 7.0), 1.2)

	_railing(y_deck)
	_stairs(y)
	_ground_detail(false)
	return _img


## Telhado em pirâmide com fiadas de telhas; cada telha tem tom próprio e sombra embaixo.
func _roof(cx: float, ey: float, a: float, rh: float) -> void:
	var apex := Vector2(cx, ey - rh)
	var front := Vector2(cx, ey + a * 0.5)
	var lc := Vector2(cx - a, ey)
	var rc := Vector2(cx + a, ey)
	var left := PackedVector2Array([lc, front, apex])
	var right := PackedVector2Array([front, rc, apex])
	for y in range(floori(apex.y), ceili(front.y)):
		for x in range(floori(lc.x), ceili(rc.x)):
			var p := Vector2(x + 0.5, y + 0.5)
			var is_left := Geometry2D.is_point_in_polygon(p, left)
			if not is_left and not Geometry2D.is_point_in_polygon(p, right):
				continue
			var eave := ey + (p.x - lc.x) * 0.5 if is_left else ey + (rc.x - p.x) * 0.5
			var r := eave - p.y
			var row := floori(r / 4.0)
			var lr := r - row * 4.0
			var cell := floori((p.x + row * 3.0) / 5.0)
			var lu := p.x + row * 3.0 - cell * 5.0
			var t := (0.62 if is_left else 0.4) + (_rnd(cell, row, 50) - 0.5) * 0.3
			if lr < 1.0:
				t -= 0.34
			elif lu < 1.0:
				t -= 0.16
			elif lr > 3.0:
				t += 0.12
			if absf(p.x - cx) < 1.0:
				t = 0.86 - float(int(p.y) % 3 == 0) * 0.3
			_put(x, y, _ramp(_tile, t))


func _flame(base: Vector2, size: float) -> void:
	var sway: float = [0.0, 1.0, 0.0, -1.0][_flick] * size
	var tall: float = [9.0, 11.0, 8.0, 10.0][_flick] * size
	var w := 3.2 * size
	_poly([base + Vector2(-w, 0), base + Vector2(w, 0), base + Vector2(w * 0.6, -tall * 0.5), base + Vector2(sway, -tall), base + Vector2(-w * 0.6, -tall * 0.5)], _glow[1])
	_poly([base + Vector2(-w * 0.6, 0), base + Vector2(w * 0.6, 0), base + Vector2(sway * 0.5, -tall * 0.68)], _glow[3])
	_poly([base + Vector2(-w * 0.28, 0), base + Vector2(w * 0.28, 0), base + Vector2(sway * 0.2, -tall * 0.36)], _glow[4])


func _torch(p: Vector2) -> void:
	_line(p + Vector2(0, 3), p + Vector2(0, -2), 2.0, WOOD[1])
	_line(p + Vector2(-2, -2), p + Vector2(2, -2), 1.4, SLATE[4])
	_flame(p + Vector2(0, -3), 0.55)


## Degraus de madeira saindo da porta (face direita) até o chão.
func _stairs(_y: float) -> void:
	var door_ground := _on_right(BX, BY, 31.0, 18.0, 0.0)
	for i in 3:
		var c := door_ground + Vector2(1.0 + i * 5.0, -1.0 + i * 2.5)
		var sh := 9.0 - i * 3.0
		_box(c.x, c.y, 9.0, sh, _planks(60 + i, 0.3, 2), _planks(70 + i, 0.2, 2), _deck(80 + i, 0.8))


## Pedregulhos, tufos e flores em volta do pé (os de trás antes da torre, os da frente depois).
func _ground_detail(behind: bool) -> void:
	var stones := [[-36.0, -2.0, 6.0], [37.0, -3.0, 5.0], [-30.0, 11.0, 5.0], [-16.0, 19.0, 4.0], [33.0, 15.0, 3.5], [8.0, 21.0, 3.0]]
	for s: Array in stones:
		if (s[1] < 0.0) != behind:
			continue
		_rock(Vector2(BX + s[0], BY + s[1]), s[2])


## Tufos e flores: pintados depois do contorno, senão cada folhinha ganha borda preta.
func _tufts() -> void:
	for i in 26:
		var ang := _rnd(i, 1, 90) * TAU
		var rad := 30.0 + _rnd(i, 2, 90) * 12.0
		var p := Vector2(BX + cos(ang) * rad * 1.1, BY + 3.0 + sin(ang) * rad * 0.55)
		if sin(ang) < -0.2:
			continue
		var g: Color = MOSS[int(_rnd(i, 3, 90) * 3.99)]
		_line(p, p + Vector2((_rnd(i, 4, 90) - 0.5) * 3.0, -3.0), 1.0, g)
		_line(p + Vector2(1, 0), p + Vector2(1.0 + (_rnd(i, 5, 90) - 0.5) * 3.0, -2.0), 1.0, g.darkened(0.2))
		if i % 7 == 0:
			_put(int(p.x), int(p.y) - 4, Color("ffe08a") if i % 2 == 0 else Color("f2f2f2"))


## Hera subindo pela quina esquerda: mais densa embaixo e junto à quina.
func _ivy(cy: float, a: float) -> void:
	for i in 70:
		var u := _rnd(i, 1, 70) * 12.0
		var v := _rnd(i, 2, 70) * (30.0 - u * 2.0)
		var p := _on_left(BX, cy, a, u, v)
		var g: Color = MOSS[int(_rnd(i, 3, 70) * 3.99)]
		_put(int(p.x), int(p.y), g)
		_put(int(p.x) + 1, int(p.y), g.darkened(0.15))
		if i % 2 == 0:
			_put(int(p.x), int(p.y) + 1, g.darkened(0.25))


## Guarda-corpo nas duas bordas da frente da plataforma.
func _railing(y: float) -> void:
	var left := Vector2(BX - 29.0, y)
	var right := Vector2(BX + 29.0, y)
	var front := Vector2(BX, y + 14.5)
	for side: Array in [[left, WOOD[4], WOOD[3]], [right, WOOD[3], WOOD[2]]]:
		var from: Vector2 = side[0]
		for i in 5:
			var p := from.lerp(front, i / 4.0)
			_line(p, p + Vector2(0, -6), 1.6, WOOD[2])
		_line(from + Vector2(0, -6), front + Vector2(0, -6), 1.3, side[1])
		_line(from + Vector2(0, -3), front + Vector2(0, -3), 1.0, side[2])


func _rock(c: Vector2, r: float) -> void:
	for y in range(floori(c.y - r * 0.7), ceili(c.y + r * 0.7)):
		for x in range(floori(c.x - r), ceili(c.x + r)):
			var d := Vector2((x + 0.5 - c.x) / r, (y + 0.5 - c.y) / (r * 0.7))
			if d.length() > 1.0:
				continue
			var t := 0.55 + d.dot(Vector2(-0.5, -0.8)) * 0.4 + (_rnd(x, y, 91) - 0.5) * 0.12
			_put(x, y, _ramp(SLATE, t))
