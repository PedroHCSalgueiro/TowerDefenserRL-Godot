extends SceneTree
## Gera os sprites PLACEHOLDER do protótipo 2D isométrico (descartável, não faz parte do jogo).
## Serve só para provar a técnica (tiles 2:1, sprites com ordenação por Y, animação por quadros);
## a arte final viria de IA/Blender/pack. Rodar:
##   godot --headless --path . -s dev/proto2d/make_art.gd

const OUT := "res://dev/proto2d/art/"
const OUTLINE := Color("1d1f21")

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 7
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save(_tiles(), "tiles.png")
	_save(_tower(Color("5d6166"), Color("80858a"), Color("9c3f2a"), Color("c25a38"), Color("ffcf5a")), "tower_archer.png")
	_save(_tower(Color("565b6b"), Color("777d90"), Color("2f5fa8"), Color("4a82d6"), Color("7fe3ff")), "tower_arcane.png")
	_save(_tree(), "tree.png")
	for f in 4:
		_save(_goblin(f), "goblin_%d.png" % f)
	_save(_shadow(), "shadow.png")
	_save(_spark(), "spark.png")
	for f in 2:
		_save(_knight(-1.0, -1.0, float(f)), "knight_idle_%d.png" % f)
	for f in 6:
		_save(_knight(f / 6.0, -1.0, 0.0), "knight_walk_%d.png" % f)
	for f in 5:
		_save(_knight(-1.0, f / 4.0, 0.0), "knight_attack_%d.png" % f)
	quit()


func _save(img: Image, file: String) -> void:
	var err := img.save_png(OUT + file)
	if err != OK:
		push_error("falhou ao salvar %s (%d)" % [file, err])


# ---------------------------------------------------------------- helpers

func _in_diamond(x: float, y: float, w: int, h: int) -> bool:
	return absf(x + 0.5 - w * 0.5) / (w * 0.5) + absf(y + 0.5 - h * 0.5) / (h * 0.5) <= 1.0


func _poly(img: Image, pts: Array, col: Color) -> void:
	var poly := PackedVector2Array(pts)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p: Vector2 in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	for y in range(maxi(0, floori(lo.y)), mini(img.get_height(), ceili(hi.y) + 1)):
		for x in range(maxi(0, floori(lo.x)), mini(img.get_width(), ceili(hi.x) + 1)):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly):
				img.set_pixel(x, y, col)


func _rect(img: Image, r: Rect2i, col: Color) -> void:
	for y in range(maxi(0, r.position.y), mini(img.get_height(), r.end.y)):
		for x in range(maxi(0, r.position.x), mini(img.get_width(), r.end.x)):
			img.set_pixel(x, y, col)


func _outlined(src: Image) -> Image:
	var out := src.duplicate() as Image
	for y in src.get_height():
		for x in src.get_width():
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q := Vector2i(x, y) + d
				if q.x < 0 or q.y < 0 or q.x >= src.get_width() or q.y >= src.get_height():
					continue
				if src.get_pixel(q.x, q.y).a > 0.5:
					out.set_pixel(x, y, OUTLINE)
					break
	return out


# ---------------------------------------------------------------- chão

func _tiles() -> Image:
	var atlas := Image.create(256, 32, false, Image.FORMAT_RGBA8)
	var grass: Array[Color] = [Color("3f6b35"), Color("477a3a"), Color("39602f")]
	var dirt: Array[Color] = [Color("a58b5c"), Color("b29a69"), Color("957c50")]
	for i in 3:
		atlas.blit_rect(_ground_tile(grass, Color("62a04b")), Rect2i(0, 0, 64, 32), Vector2i(i * 64, 0))
	atlas.blit_rect(_ground_tile(dirt, Color("d2bc88")), Rect2i(0, 0, 64, 32), Vector2i(192, 0))
	return atlas


func _ground_tile(shades: Array[Color], speck: Color) -> Image:
	var img := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	var noise := PackedInt32Array()
	noise.resize(32 * 16)
	for i in noise.size():
		noise[i] = _rng.randi() % shades.size()
	for y in 32:
		for x in 64:
			if _in_diamond(x, y, 64, 32):
				img.set_pixel(x, y, shades[noise[(y >> 1) * 32 + (x >> 1)]])
	for i in 16:
		var p := Vector2i(_rng.randi_range(10, 52), _rng.randi_range(6, 24))
		if _in_diamond(p.x, p.y, 64, 32) and _in_diamond(p.x + 2, p.y + 1, 64, 32):
			img.set_pixel(p.x, p.y, speck)
			img.set_pixel(p.x + 1, p.y, speck)
	return img


# ---------------------------------------------------------------- torre

func _tower(wall_l: Color, wall_r: Color, roof_l: Color, roof_r: Color, win: Color) -> Image:
	var img := Image.create(48, 92, false, Image.FORMAT_RGBA8)
	var bx := 24.0
	var by := 80.0
	var a := 17.0
	var b := 8.5
	var hh := 44.0
	var corner_l := Vector2(bx - a, by)
	var corner_b := Vector2(bx, by + b)
	var corner_r := Vector2(bx + a, by)
	var up := Vector2(0, -hh)
	_poly(img, [corner_l, corner_b, corner_b + up, corner_l + up], wall_l)
	_poly(img, [corner_b, corner_r, corner_r + up, corner_b + up], wall_r)

	# fiadas de pedra: linhas paralelas à base de cada face + juntas verticais alternadas
	for y in 92:
		for x in 48:
			var p := img.get_pixel(x, y)
			if p.a == 0.0:
				continue
			var phase := (y - 0.5 * (x - corner_l.x)) if x < bx else (y + 0.5 * (x - bx))
			var row := floori(phase / 6.0)
			if posmod(floori(phase), 6) == 0 or posmod(x + (row % 2) * 4, 9) == 0:
				img.set_pixel(x, y, p.darkened(0.22))

	_window(img, bx - 13.0, bx - 5.0, true, by + b, win)
	_window(img, bx + 5.0, bx + 13.0, false, by + b, win)

	# telhado em pirâmide, com fiadas de telha
	var roof := Image.create(48, 92, false, Image.FORMAT_RGBA8)
	var c := Vector2(bx, by - hh)
	var a2 := 21.0
	var b2 := 10.5
	var apex := Vector2(bx, c.y - 30.0)
	_poly(roof, [c + Vector2(-a2, 0), c + Vector2(0, b2), apex], roof_l)
	_poly(roof, [c + Vector2(0, b2), c + Vector2(a2, 0), apex], roof_r)
	for y in 92:
		for x in 48:
			var p := roof.get_pixel(x, y)
			if p.a == 0.0:
				continue
			var phase := (y - 0.5 * (x - (bx - a2))) if x < bx else (y + 0.5 * (x - bx) - b2)
			if posmod(floori(phase), 5) == 0:
				roof.set_pixel(x, y, p.darkened(0.2))
	img.blend_rect(roof, Rect2i(0, 0, 48, 92), Vector2i.ZERO)
	return _outlined(img)


func _window(img: Image, x0: float, x1: float, left_face: bool, base_y: float, win: Color) -> void:
	var yb0 := base_y + (0.5 * (x0 - 24.0) if left_face else -0.5 * (x0 - 24.0))
	var yb1 := base_y + (0.5 * (x1 - 24.0) if left_face else -0.5 * (x1 - 24.0))
	var frame := Color("2a2622")
	_poly(img, [Vector2(x0 - 1, yb0 - 17), Vector2(x1 + 1, yb1 - 17), Vector2(x1 + 1, yb1 - 33), Vector2(x0 - 1, yb0 - 33)], frame)
	_poly(img, [Vector2(x0, yb0 - 18), Vector2(x1, yb1 - 18), Vector2(x1, yb1 - 32), Vector2(x0, yb0 - 32)], win)


# ---------------------------------------------------------------- árvore

func _tree() -> Image:
	var img := Image.create(44, 60, false, Image.FORMAT_RGBA8)
	_rect(img, Rect2i(19, 40, 6, 14), Color("5b3d27"))
	_rect(img, Rect2i(19, 40, 2, 14), Color("73502f"))
	var blobs := [[22.0, 28.0, 15.0], [13.0, 33.0, 11.0], [31.0, 33.0, 11.0], [22.0, 17.0, 12.0]]
	for blob: Array in blobs:
		var c := Vector2(blob[0], blob[1])
		var r: float = blob[2]
		for y in range(maxi(0, floori(c.y - r)), mini(60, ceili(c.y + r) + 1)):
			for x in range(maxi(0, floori(c.x - r)), mini(44, ceili(c.x + r) + 1)):
				var d := Vector2(x + 0.5, y + 0.5) - c
				if d.length() > r:
					continue
				var t := d.normalized().dot(Vector2(-0.6, -0.8))
				var col := Color("2f6a33")
				if t > 0.35:
					col = Color("4a8f43")
				elif t < -0.4:
					col = Color("25502a")
				img.set_pixel(x, y, col)
	for i in 30:
		var p := Vector2i(_rng.randi_range(8, 36), _rng.randi_range(8, 38))
		if img.get_pixel(p.x, p.y).a > 0.0:
			img.set_pixel(p.x, p.y, Color("6bb35a"))
	return _outlined(img)


# ---------------------------------------------------------------- goblin (4 quadros de caminhada)

func _goblin(f: int) -> Image:
	var img := Image.create(24, 28, false, Image.FORMAT_RGBA8)
	var skin := Color("6fae3d")
	var skin_dark := Color("4a7d28")
	var cloth := Color("7a4e2a")
	var bob: int = [0, -1, 0, -1][f]
	var lift_l: int = [2, 0, 0, 0][f]
	var lift_r: int = [0, 0, 2, 0][f]
	_rect(img, Rect2i(8, 20 - lift_l, 3, 6 - 0), skin_dark)
	_rect(img, Rect2i(13, 20 - lift_r, 3, 6 - 0), skin_dark)
	_rect(img, Rect2i(7, 12 + bob, 10, 9), cloth)
	_rect(img, Rect2i(7, 12 + bob, 10, 2), cloth.lightened(0.15))
	_rect(img, Rect2i(5, 13 + bob, 2, 6), skin)
	_rect(img, Rect2i(17, 13 + bob, 2, 6), skin)
	_rect(img, Rect2i(18, 11 + bob, 2, 8), Color("b8bcc2"))
	for y in range(3, 16):
		for x in range(6, 18):
			var d := Vector2(x + 0.5, y + 0.5) - Vector2(12, 9 + bob)
			if d.length() <= 5.2:
				img.set_pixel(x, y, skin)
	_poly(img, [Vector2(7, 9 + bob), Vector2(2, 5 + bob), Vector2(7, 7 + bob)], skin)
	_poly(img, [Vector2(17, 9 + bob), Vector2(22, 5 + bob), Vector2(17, 7 + bob)], skin)
	img.set_pixel(10, 8 + bob, Color("ffe14a"))
	img.set_pixel(14, 8 + bob, Color("ffe14a"))
	_rect(img, Rect2i(10, 11 + bob, 4, 1), skin_dark)
	return _outlined(img)


func _shadow() -> Image:
	var img := Image.create(24, 10, false, Image.FORMAT_RGBA8)
	for y in 10:
		for x in 24:
			var d := Vector2((x + 0.5 - 12.0) / 12.0, (y + 0.5 - 5.0) / 5.0).length()
			if d <= 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0.38 * (1.0 - d * 0.5)))
	return img


func _spark() -> Image:
	var img := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	for y in 10:
		for x in 10:
			var d := Vector2(x + 0.5 - 5.0, y + 0.5 - 5.0).length() / 5.0
			if d <= 1.0:
				var core := d < 0.45
				img.set_pixel(x, y, Color(1, 1, 1, 1.0) if core else Color(1, 1, 1, 0.55 * (1.0 - d)))
	return img


# ---------------------------------------------------------------- cavaleiro (herói)
# Desenhado por partes (pernas, capa, tronco, elmo, escudo, espada) e animado por parâmetros:
# `walk` = fase da caminhada (0..1, ou -1 parado), `attack` = progresso do golpe (0..1, ou -1 sem
# golpe), `breath` = respiração do idle. Imagem 64x56, pés em (28, 52), virado para a direita.

const KO := Vector2(28, 52)


func _line(img: Image, a: Vector2, b: Vector2, width: float, col: Color) -> void:
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(width, width)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(width, width)
	for y in range(maxi(0, floori(lo.y)), mini(img.get_height(), ceili(hi.y) + 1)):
		for x in range(maxi(0, floori(lo.x)), mini(img.get_width(), ceili(hi.x) + 1)):
			var p := Vector2(x + 0.5, y + 0.5)
			var closest := Geometry2D.get_closest_point_to_segment(p, a, b)
			if p.distance_to(closest) <= width * 0.5:
				img.set_pixel(x, y, col)


func _disc(img: Image, c: Vector2, r: float, col: Color, hi_col: Color, lo_col: Color) -> void:
	for y in range(maxi(0, floori(c.y - r)), mini(img.get_height(), ceili(c.y + r) + 1)):
		for x in range(maxi(0, floori(c.x - r)), mini(img.get_width(), ceili(c.x + r) + 1)):
			var d := Vector2(x + 0.5, y + 0.5) - c
			if d.length() > r:
				continue
			var t := d.normalized().dot(Vector2(-0.6, -0.8)) if d.length() > 0.1 else 0.0
			img.set_pixel(x, y, hi_col if t > 0.45 else (lo_col if t < -0.35 else col))


## Pose do braço da espada: ângulo da lâmina (graus, 0 = direita, negativo = para cima), quanto a
## mão avança e quanto o corpo se inclina. Armar → golpe rápido → recuperar.
func _atk_pose(t: float) -> Dictionary:
	if t < 0.0:
		return {"angle": -70.0, "reach": 0.0, "lean": 0.0}
	if t < 0.3:
		var k := t / 0.3
		return {"angle": lerpf(-70.0, -135.0, k), "reach": lerpf(0.0, -2.0, k), "lean": lerpf(0.0, -1.0, k)}
	if t < 0.65:
		var k := (t - 0.3) / 0.35
		k = k * k
		return {"angle": lerpf(-135.0, 40.0, k), "reach": lerpf(-2.0, 6.0, k), "lean": lerpf(-1.0, 3.0, k)}
	var k2 := (t - 0.65) / 0.35
	return {"angle": lerpf(40.0, -70.0, k2), "reach": lerpf(6.0, 0.0, k2), "lean": lerpf(3.0, 0.0, k2)}


func _knight(walk: float, attack: float, breath: float) -> Image:
	var img := Image.create(64, 56, false, Image.FORMAT_RGBA8)
	var steel := Color("a9afb8")
	var steel_d := Color("7d838c")
	var steel_l := Color("d3d8de")
	var blue := Color("2f5fa8")
	var blue_d := Color("244b86")
	var gold := Color("d8b24a")
	var boot := Color("4a3425")
	var moving := walk >= 0.0
	var ph := walk * TAU if moving else 0.0
	var bob := -absf(sin(ph)) * 1.5 if moving else -breath
	var sway := sin(ph + 1.0) * 2.0 if moving else breath * 0.6
	var pose := _atk_pose(attack)
	var lean: float = pose["lean"]
	var body := Vector2(lean, bob)

	# capa (atrás de tudo)
	_poly(img, [KO + Vector2(-6, -33) + body, KO + Vector2(6, -33) + body, KO + Vector2(9 + sway - lean, -7), KO + Vector2(-9 + sway - lean, -7)], blue)
	_poly(img, [KO + Vector2(0, -33) + body, KO + Vector2(6, -33) + body, KO + Vector2(9 + sway - lean, -7), KO + Vector2(2 + sway * 0.5, -7)], blue_d)

	# pernas
	for side in [-1, 1]:
		var leg_ph := ph + (0.0 if side > 0 else PI)
		var swing := sin(leg_ph) * 5.0 if moving else 0.0
		var lift := maxf(0.0, cos(leg_ph)) * 3.0 if moving else 0.0
		var hip := KO + Vector2(side * 3.5 + lean * 0.5, -19.0 + bob * 0.5)
		var foot := KO + Vector2(side * 3.5 + swing, -lift)
		_line(img, hip, foot - Vector2(0, 3), 4.5, steel_d)
		_rect(img, Rect2i(int(foot.x) - 3, int(foot.y) - 4, 7, 4), boot)

	# tronco: peitoral de aço, saia de tabardo azul, cinto
	_rect(img, Rect2i(int(KO.x + lean) - 7, int(KO.y + bob) - 33, 14, 14), steel)
	_rect(img, Rect2i(int(KO.x + lean) - 7, int(KO.y + bob) - 33, 5, 14), steel_l)
	_rect(img, Rect2i(int(KO.x + lean) + 4, int(KO.y + bob) - 33, 3, 14), steel_d)
	_rect(img, Rect2i(int(KO.x + lean) - 3, int(KO.y + bob) - 31, 6, 17), blue)
	_rect(img, Rect2i(int(KO.x + lean) - 7, int(KO.y + bob) - 21, 14, 3), boot)
	_rect(img, Rect2i(int(KO.x + lean) - 1, int(KO.y + bob) - 21, 3, 3), gold)
	_rect(img, Rect2i(int(KO.x + lean) - 1, int(KO.y + bob) - 28, 2, 5), gold)
	_rect(img, Rect2i(int(KO.x + lean) - 2, int(KO.y + bob) - 26, 4, 1), gold)

	# ombreiras
	for side in [-1, 1]:
		_disc(img, KO + Vector2(side * 8.0, -32.0) + body, 3.6, steel, steel_l, steel_d)

	# elmo com viseira e penacho
	var head := KO + Vector2(0, -41) + body
	_poly(img, [head + Vector2(-1, -6), head + Vector2(2, -6), head + Vector2(6 + sway, -9), head + Vector2(1, -10), head + Vector2(-4 + sway, -8)], Color("c0392b"))
	_disc(img, head, 6.6, steel, steel_l, steel_d)
	_rect(img, Rect2i(int(head.x) - 4, int(head.y) - 1, 9, 2), Color("22262b"))
	_rect(img, Rect2i(int(head.x), int(head.y) + 2, 1, 3), Color("22262b"))

	# escudo (braço de trás, à esquerda na tela)
	var sh := KO + Vector2(-12, -23) + body
	_line(img, KO + Vector2(-8, -31) + body, sh, 3.0, steel)
	_poly(img, [sh + Vector2(-6, -10), sh + Vector2(6, -10), sh + Vector2(6, 0), sh + Vector2(0, 10), sh + Vector2(-6, 0)], gold)
	_poly(img, [sh + Vector2(-4.5, -8.5), sh + Vector2(4.5, -8.5), sh + Vector2(4.5, -0.5), sh + Vector2(0, 7.5), sh + Vector2(-4.5, -0.5)], blue)
	_rect(img, Rect2i(int(sh.x) - 1, int(sh.y) - 6, 2, 9), gold)
	_rect(img, Rect2i(int(sh.x) - 3, int(sh.y) - 4, 6, 2), gold)

	# braço da espada + espada
	var shoulder := KO + Vector2(8, -31) + body
	var angle: float = pose["angle"]
	var arm_swing := sin(ph) * 1.5 if moving else 0.0
	var hand := shoulder + Vector2(5.0 + float(pose["reach"]), 6.0 + arm_swing)
	_line(img, shoulder, hand, 3.4, steel)
	var dir := Vector2.from_angle(deg_to_rad(angle))
	var perp := dir.orthogonal()
	_line(img, hand - dir * 3.0, hand, 2.4, boot)
	_line(img, hand + dir * 1.0 - perp * 3.0, hand + dir * 1.0 + perp * 3.0, 1.6, gold)
	_line(img, hand + dir * 2.0, hand + dir * 19.0, 2.8, steel_l)
	_line(img, hand + dir * 2.0 + perp * 0.8, hand + dir * 18.0 + perp * 0.8, 1.0, Color("ffffff"))

	var out := _outlined(img)
	# rastro do golpe, por cima do contorno
	if attack >= 0.35 and attack <= 0.8:
		var a0 := -135.0
		var steps := int(absf(angle - a0) / 3.0)
		for i in steps:
			var ang := deg_to_rad(lerpf(a0, angle, i / float(maxi(steps, 1))))
			for r: float in [16.0, 17.0, 18.0]:
				var p := shoulder + Vector2.from_angle(ang) * (r + 3.0)
				if p.x >= 0 and p.y >= 0 and p.x < 64 and p.y < 56:
					out.set_pixel(int(p.x), int(p.y), Color(1, 1, 1, 0.55))
	return out
