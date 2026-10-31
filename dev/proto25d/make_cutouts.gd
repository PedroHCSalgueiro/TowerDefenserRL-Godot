extends SceneTree
## Recorta as imagens de referência dos heróis (fundo claro → transparente) e desenha um goblin
## "vetorial" no mesmo traço, para o teste de visual estilizado.
##   godot --headless --path . -s dev/proto25d/make_cutouts.gd

const OUT := "res://dev/proto25d/art_ref/"
const REFS := "E:/Programacao/Jogos/TD RogueLite/Assets/personagens/reino/"
## Altura final do sprite e centro do corpo na imagem original (é a âncora dos pés).
const HEIGHT := 512
const SOURCES := {
	"aldric": {"file": "sir-aldric/sir-aldric_v2_ref.jpg", "body_x": 690, "holes": false},
	"lyra": {"file": "lyra/lyra_ref.png", "body_x": 680, "holes": true},
	# o cristal do cajado quase não tem contorno: a área dele é protegida do recorte
	"tomas": {"file": "irmao-tomas/irmao-tomas_ref.png", "body_x": 682, "holes": false,
		"keep": [[870, 127], [889, 135], [893, 160], [878, 192], [858, 192], [850, 160], [853, 138]]},
}
const DARK := Color("1d1a22")
const GOBLIN_S := 4


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var meta := {}
	for id: String in SOURCES:
		meta[id] = _cutout(id, SOURCES[id])
	for f in 4:
		_goblin(f).save_png(OUT + "goblin_%d.png" % f)
	var file := FileAccess.open(OUT + "meta.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(meta))
	file.close()
	print(meta)
	quit()


# ---------------------------------------------------------------- recorte

func _is_bg(d: PackedByteArray, i: int, min_v: int, max_s: int) -> bool:
	var hi := maxi(d[i], maxi(d[i + 1], d[i + 2]))
	var lo := mini(d[i], mini(d[i + 1], d[i + 2]))
	return hi >= min_v and hi - lo <= max_s


func _cutout(id: String, src: Dictionary) -> Dictionary:
	var img := Image.load_from_file(REFS + src["file"])
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var d := img.get_data()
	# inundação a partir das bordas: o contorno preto do desenho impede de vazar para dentro
	var bg := PackedByteArray()
	bg.resize(w * h)
	var stack := PackedInt32Array()
	for x in w:
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in h:
		stack.append(y * w)
		stack.append(y * w + w - 1)
	while not stack.is_empty():
		var p := stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		if bg[p] != 0 or not _is_bg(d, p * 4, 190, 36):
			continue
		bg[p] = 1
		var x := p % w
		var y := p / w
		if x > 0:
			stack.append(p - 1)
		if x < w - 1:
			stack.append(p + 1)
		if y > 0:
			stack.append(p - w)
		if y < h - 1:
			stack.append(p + w)
	# buracos fechados (o vão da besta da Lyra): só quando a roupa não tem branco
	if src["holes"]:
		for p in w * h:
			if bg[p] == 0 and _is_bg(d, p * 4, 238, 14):
				bg[p] = 1
	if src.has("keep"):
		var poly := PackedVector2Array()
		for pt: Array in src["keep"]:
			poly.append(Vector2(pt[0], pt[1]))
		for y in h:
			for x in w:
				if bg[y * w + x] != 0 and Geometry2D.is_point_in_polygon(Vector2(x, y), poly):
					bg[y * w + x] = 0
	var lo := Vector2i(w, h)
	var hi := Vector2i(0, 0)
	for y in h:
		for x in w:
			var p := y * w + x
			var i := p * 4
			if bg[p] != 0:
				# cor escura sob o transparente: reduzir não deixa franja clara em volta
				d[i] = 29
				d[i + 1] = 26
				d[i + 2] = 34
				d[i + 3] = 0
				continue
			lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
			hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	var cut := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, d)
	var crop := cut.get_region(Rect2i(lo, hi - lo + Vector2i.ONE))
	var k := float(HEIGHT) / crop.get_height()
	crop.resize(int(crop.get_width() * k), HEIGHT, Image.INTERPOLATE_LANCZOS)
	crop.save_png(OUT + id + ".png")
	return {"w": crop.get_width(), "h": HEIGHT, "anchor_x": (int(src["body_x"]) - lo.x) * k}


# ---------------------------------------------------------------- goblin no traço das referências
# Desenhado em 4x e reduzido, para a borda sair lisa. Cada peça leva contorno escuro próprio.

var _g: Image


func _capsule(a: Vector2, b: Vector2, r: float, col: Color, outline: float = 5.0) -> void:
	var m := r + outline
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(m, m)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(m, m)
	for y in range(maxi(0, floori(lo.y)), mini(_g.get_height(), ceili(hi.y) + 1)):
		for x in range(maxi(0, floori(lo.x)), mini(_g.get_width(), ceili(hi.x) + 1)):
			var p := Vector2(x + 0.5, y + 0.5)
			var c := Geometry2D.get_closest_point_to_segment(p, a, b)
			var dist := p.distance_to(c)
			if dist > m:
				continue
			if dist > r:
				_g.set_pixel(x, y, DARK)
			else:
				# sombra em bloco do lado direito de cada peça
				var side := (p - c).x / maxf(r, 0.001)
				_g.set_pixel(x, y, col.darkened(0.28) if side > 0.35 else col)


func _tri(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	var center := (a + b + c) / 3.0
	var outer := PackedVector2Array([center + (a - center) * 1.3, center + (b - center) * 1.3, center + (c - center) * 1.3])
	var inner := PackedVector2Array([a, b, c])
	for y in _g.get_height():
		for x in _g.get_width():
			var p := Vector2(x + 0.5, y + 0.5)
			if Geometry2D.is_point_in_polygon(p, inner):
				_g.set_pixel(x, y, col)
			elif Geometry2D.is_point_in_polygon(p, outer):
				_g.set_pixel(x, y, DARK)


func _goblin(f: int) -> Image:
	_g = Image.create(240, 280, false, Image.FORMAT_RGBA8)
	var skin := Color("7fb342")
	var cloth := Color("7a4a2a")
	var bob: float = [0.0, -4.0, 0.0, -4.0][f]
	var step: float = [14.0, 0.0, -14.0, 0.0][f]
	_capsule(Vector2(100, 190 + bob), Vector2(100 - step, 252), 13.0, skin.darkened(0.2))
	_capsule(Vector2(140, 190 + bob), Vector2(140 + step, 252), 13.0, skin.darkened(0.2))
	_capsule(Vector2(92 - step, 256), Vector2(112 - step, 256), 10.0, cloth.darkened(0.3))
	_capsule(Vector2(132 + step, 256), Vector2(152 + step, 256), 10.0, cloth.darkened(0.3))
	_capsule(Vector2(120, 130 + bob), Vector2(120, 185 + bob), 34.0, cloth)
	_capsule(Vector2(80, 135 + bob), Vector2(70, 185 + bob), 11.0, skin)
	# adaga
	_tri(Vector2(166, 120 + bob), Vector2(180, 120 + bob), Vector2(173, 72 + bob), Color("d5dae2"))
	_capsule(Vector2(160, 135 + bob), Vector2(172, 170 + bob), 11.0, skin)
	_capsule(Vector2(172, 122 + bob), Vector2(172, 172 + bob), 5.0, cloth.darkened(0.2), 3.0)
	# orelhas e cabeça
	_tri(Vector2(84, 66 + bob), Vector2(24, 40 + bob), Vector2(82, 96 + bob), skin)
	_tri(Vector2(156, 66 + bob), Vector2(216, 40 + bob), Vector2(158, 96 + bob), skin)
	_capsule(Vector2(112, 72 + bob), Vector2(128, 72 + bob), 46.0, skin)
	# olhos, sobrancelha e boca
	_capsule(Vector2(100, 70 + bob), Vector2(100, 70 + bob), 9.0, Color("ffe14a"), 3.0)
	_capsule(Vector2(140, 70 + bob), Vector2(140, 70 + bob), 9.0, Color("ffe14a"), 3.0)
	_capsule(Vector2(102, 72 + bob), Vector2(102, 72 + bob), 3.5, DARK, 0.0)
	_capsule(Vector2(142, 72 + bob), Vector2(142, 72 + bob), 3.5, DARK, 0.0)
	_capsule(Vector2(100, 96 + bob), Vector2(142, 94 + bob), 2.5, DARK, 0.0)
	_g.resize(120, 140, Image.INTERPOLATE_LANCZOS)
	return _g
