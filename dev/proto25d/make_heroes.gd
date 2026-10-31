extends SceneTree
## Gera os sprites dos 8 heróis de Valcoroa só por código (protótipo, não é a arte final).
## Segue "Fichas Visuais dos Personagens" e o "Guia de Estilo" do Notion: cel shading em blocos,
## contorno fino, roupa pela região (branco, prata, azul-real, dourado), cor do efeito pela classe.
## Cada herói: 2 quadros parado + 5 de ataque (o disparo acontece no quadro 2).
##   godot --headless --path . -s dev/proto25d/make_heroes.gd

const OUT := "res://dev/proto25d/art/"
const W := 80
const H := 80
## Pés do personagem na imagem (âncora do sprite).
const O := Vector2(40, 74)
const OUTLINE := Color("221c20")

## Paletas: [base, sombra, luz].
const WHITE := [Color("ecebe6"), Color("aeb3c0"), Color("ffffff")]
const SILVER := [Color("bcc2cc"), Color("868d9b"), Color("e6eaef")]
const STONE := [Color("8f949c"), Color("666a73"), Color("b4b8bf")]
const BLUE := [Color("2a4cb0"), Color("1b327c"), Color("4770da")]
const GOLD := [Color("e3b53a"), Color("a67b1f"), Color("ffe27c")]
const LEATHER := [Color("8a5a33"), Color("5f3c22"), Color("ac7842")]
const WOOD := [Color("b58b58"), Color("86633a"), Color("d6ae78")]
const IRON := [Color("5c616b"), Color("3a3e47"), Color("838994")]
const BRONZE := [Color("b5752f"), Color("7f4f1e"), Color("e0a355")]
const SKIN := [Color("f0c6a0"), Color("cf9a78"), Color("fbdcbc")]
const H_WHITE := [Color("f2f1ec"), Color("c3c4cc"), Color("ffffff")]
const H_BROWN := [Color("7a4a28"), Color("54301a"), Color("9c653a")]
const H_ASH := [Color("8a7c6e"), Color("665a50"), Color("a89a8a")]
const H_DARK := [Color("3f2e4a"), Color("2a1e33"), Color("5a4468")]
const H_RED := [Color("b0522a"), Color("7e3618"), Color("d0713f")]

const FX_YELLOW := Color("ffe066")
const FX_GREEN := Color("5de35d")
const FX_WHITE := Color("ffffff")
const FX_ORANGE := Color("ff8a2a")
const FX_PURPLE := Color("b25cff")
const FX_RED := Color("ff4040")
const FX_CYAN := Color("38e8e0")
const FX_ICE := Color("9be3ff")

var _img: Image


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var draw := {
		"aldric": _aldric, "lyra": _lyra, "tomas": _tomas, "brom": _brom,
		"selene": _selene, "wulf": _wulf, "mabel": _mabel, "isolde": _isolde,
	}
	var sheet := Image.create(W * 8, H * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("4a5a48"))
	var col := 0
	for id: String in draw:
		var fn: Callable = draw[id]
		for f in 2:
			var img := _render(fn, float(f), -1.0)
			img.save_png(OUT + "%s_idle_%d.png" % [id, f])
			if f == 0:
				sheet.blend_rect(img, Rect2i(0, 0, W, H), Vector2i(col * W, 0))
		for f in 5:
			var img := _render(fn, 0.0, f / 4.0)
			img.save_png(OUT + "%s_attack_%d.png" % [id, f])
			if f == 2:
				sheet.blend_rect(img, Rect2i(0, 0, W, H), Vector2i(col * W, H))
		col += 1
	sheet.resize(sheet.get_width() * 3, sheet.get_height() * 3, Image.INTERPOLATE_NEAREST)
	sheet.save_png("res://dev/proto25d/herois_folha.png")
	quit()


func _render(fn: Callable, breath: float, t: float) -> Image:
	_img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	fn.call(breath, t)
	return _outlined(_img)


# ---------------------------------------------------------------- utilidades de desenho

func _p(x: float, y: float) -> Vector2:
	return O + Vector2(x, y)


func _put(x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		_img.set_pixel(x, y, c)


## Quanto o golpe está "aberto": 0 → 1 → 0 ao longo do ataque (0 quando parado).
func _k(t: float) -> float:
	return sin(PI * t) if t >= 0.0 else 0.0


func _line(a: Vector2, b: Vector2, width: float, c: Color) -> void:
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(width, width)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(width, width)
	for y in range(floori(lo.y), ceili(hi.y) + 1):
		for x in range(floori(lo.x), ceili(hi.x) + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) <= width * 0.5:
				_put(x, y, c)


## Polígono em cel shading: à direita de `shade_x` usa a sombra e à esquerda de `light_x` a luz
## (em coordenadas relativas aos pés). A luz vem de cima e da esquerda em todos os personagens.
func _cel(pts: Array, pal: Array, shade_x: float = 99.0, light_x: float = -99.0) -> void:
	var poly := PackedVector2Array(pts)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p: Vector2 in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	for y in range(floori(lo.y), ceili(hi.y) + 1):
		for x in range(floori(lo.x), ceili(hi.x) + 1):
			var at := Vector2(x + 0.5, y + 0.5)
			if not Geometry2D.is_point_in_polygon(at, poly):
				continue
			var rel := at.x - O.x
			_put(x, y, pal[1] if rel > shade_x else (pal[2] if rel < light_x else pal[0]))


## Membro ou haste: sombra por baixo e a cor base deslocada para a luz.
func _limb(a: Vector2, b: Vector2, w: float, pal: Array) -> void:
	_line(a, b, w, pal[1])
	_line(a + Vector2(-0.5, -0.4), b + Vector2(-0.5, -0.4), maxf(w - 1.2, 1.0), pal[0])


func _ball(c: Vector2, r: float, pal: Array) -> void:
	for y in range(floori(c.y - r), ceili(c.y + r) + 1):
		for x in range(floori(c.x - r), ceili(c.x + r) + 1):
			var d := Vector2(x + 0.5, y + 0.5) - c
			if d.length() > r:
				continue
			var t := d.normalized().dot(Vector2(-0.6, -0.8)) if d.length() > 0.1 else 0.0
			_put(x, y, pal[2] if t > 0.5 else (pal[1] if t < -0.3 else pal[0]))


## Abre um buraco no que já foi desenhado.
func _erase(pts: Array) -> void:
	_cel(pts, [Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0)])


func _flat_ball(c: Vector2, r: float, col: Color) -> void:
	for y in range(floori(c.y - r), ceili(c.y + r) + 1):
		for x in range(floori(c.x - r), ceili(c.x + r) + 1):
			if (Vector2(x + 0.5, y + 0.5) - c).length() <= r:
				_put(x, y, col)


## Brilho da cor da classe na arma: núcleo claro e faíscas em cruz.
func _flare(c: Vector2, r: float, col: Color) -> void:
	_line(c + Vector2(-r * 1.8, 0), c + Vector2(r * 1.8, 0), 1.0, col)
	_line(c + Vector2(0, -r * 1.8), c + Vector2(0, r * 1.8), 1.0, col)
	_flat_ball(c, r, col)
	_flat_ball(c, r * 0.5, Color.WHITE)


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


# ---------------------------------------------------------------- peças comuns

func _leg(hip: Vector2, foot: Vector2, w: float, pal: Array, boot: Array, boot_h: float = 6.0) -> void:
	_limb(hip, foot + Vector2(0, -2), w, pal)
	_cel([foot + Vector2(-w * 0.5 - 0.5, -boot_h), foot + Vector2(w * 0.5 + 0.5, -boot_h), foot + Vector2(w * 0.5 + 2.5, 0), foot + Vector2(-w * 0.5 - 0.5, 0)], boot, foot.x - O.x + 1.0)


## Cabeça em três quartos, olhando para a direita (o sprite é espelhado para o outro lado).
func _head(c: Vector2, r: float, skin: Array = SKIN) -> void:
	_ball(c, r, skin)
	_put(int(c.x), int(c.y), Color("2a2030"))
	_put(int(c.x) + 3, int(c.y), Color("2a2030"))
	_put(int(c.x) + 2, int(c.y) + 2, skin[1])


## Cabelo: calota sobre a metade de cima da cabeça, com a frente recuada para mostrar o rosto.
func _hair_cap(c: Vector2, r: float, pal: Array) -> void:
	_cel([c + Vector2(-r - 0.5, 1.5), c + Vector2(-r, -r * 0.6), c + Vector2(-r * 0.3, -r - 1.0), c + Vector2(r * 0.7, -r - 0.5), c + Vector2(r + 0.5, -r * 0.5), c + Vector2(r * 0.4, -r * 0.45), c + Vector2(-r * 0.4, -r * 0.2), c + Vector2(-r * 0.5, 2.0)], pal, c.x - O.x + r * 0.5, c.x - O.x - r * 0.3)


func _arm(shoulder: Vector2, hand: Vector2, w: float, pal: Array, glove: Array) -> void:
	_limb(shoulder, hand, w, pal)
	_ball(hand, w * 0.55 + 0.6, glove)


# ---------------------------------------------------------------- Sir Aldric: guardião, amarelo
# Veterano de cabelo e barba brancos, placas brancas com dourado, leão no peito, capa azul,
# espada e escudo. Ergue a espada e o raio de luz cai no alvo.

func _aldric(breath: float, t: float) -> void:
	var b := -breath
	var k := _k(t)
	_cel([_p(-8, -41 + b), _p(8, -41 + b), _p(12, -5), _p(-13, -5)], BLUE, 3.0, -7.0)
	_leg(_p(-4, -24 + b), _p(-6, 0), 6.5, SILVER, SILVER)
	_leg(_p(4, -24 + b), _p(5, 0), 6.5, SILVER, SILVER)
	_cel([_p(-8, -26 + b), _p(8, -26 + b), _p(9, -17 + b), _p(-9, -17 + b)], WHITE, 4.0, -5.0)
	_cel([_p(-9, -41 + b), _p(9, -41 + b), _p(7, -24 + b), _p(-7, -24 + b)], WHITE, 4.0, -5.0)
	_line(_p(-7, -24.5 + b), _p(7, -24.5 + b), 2.0, GOLD[0])
	_line(_p(-8.5, -40.5 + b), _p(8.5, -40.5 + b), 1.4, GOLD[1])
	# leão dourado: juba + focinho
	_flat_ball(_p(0, -33 + b), 3.6, GOLD[1])
	_flat_ball(_p(0, -33 + b), 2.6, GOLD[0])
	_flat_ball(_p(0.5, -32.5 + b), 1.1, GOLD[2])
	var c := _p(1, -48 + b)
	_limb(_p(0, -41 + b), _p(0, -44 + b), 4.0, SKIN)
	_head(c, 5.4)
	_hair_cap(c, 5.4, H_WHITE)
	_cel([c + Vector2(-4, 3), c + Vector2(5, 3), c + Vector2(3.5, 7.5), c + Vector2(-0.5, 8.5), c + Vector2(-3.5, 6)], H_WHITE, c.x - O.x + 2.0)
	_put(int(c.x) + 1, int(c.y) + 3, Color("8a6a60"))
	_put(int(c.x) + 2, int(c.y) + 3, Color("8a6a60"))
	_ball(_p(-10, -40 + b), 5.0, WHITE)
	_ball(_p(10, -40 + b), 5.0, WHITE)
	_line(_p(-14, -37 + b), _p(-6, -37 + b), 1.2, GOLD[0])
	_line(_p(6, -37 + b), _p(14, -37 + b), 1.2, GOLD[0])
	# escudo azul com aro e cruz douradas à frente do braço esquerdo
	var sh := _p(-14, -31 + b)
	_cel([sh + Vector2(-8, -11), sh + Vector2(8, -11), sh + Vector2(8, 1), sh + Vector2(0, 12), sh + Vector2(-8, 1)], GOLD)
	_cel([sh + Vector2(-6.5, -9.5), sh + Vector2(6.5, -9.5), sh + Vector2(6.5, 0.5), sh + Vector2(0, 9.5), sh + Vector2(-6.5, 0.5)], BLUE, sh.x - O.x + 1.0)
	_line(sh + Vector2(0, -8), sh + Vector2(0, 7), 2.0, GOLD[0])
	_line(sh + Vector2(-4.5, -3), sh + Vector2(4.5, -3), 2.0, GOLD[0])
	# braço e espada: sobe para o alto no golpe
	var shoulder := _p(10, -39 + b)
	var hand := shoulder.lerp(_p(9, -50 + b), k) + Vector2(4.0 * (1.0 - k), 8.0 * (1.0 - k))
	var dir := Vector2.from_angle(deg_to_rad(lerpf(-68.0, -90.0, k)))
	_arm(shoulder, hand, 4.4, WHITE, SILVER)
	_sword(hand, dir, 19.0)
	if k > 0.8:
		_flare(hand + dir * 19.0, 2.2, FX_YELLOW)


func _sword(hand: Vector2, dir: Vector2, length: float) -> void:
	var perp := dir.orthogonal()
	_line(hand - dir * 3.0, hand, 2.2, LEATHER[1])
	_line(hand + dir * 1.5 - perp * 4.0, hand + dir * 1.5 + perp * 4.0, 2.0, GOLD[0])
	_line(hand + dir * 2.0, hand + dir * length, 3.2, SILVER[1])
	_line(hand + dir * 2.0 + perp * 0.5, hand + dir * (length - 1.0) + perp * 0.5, 1.4, Color.WHITE)


# ---------------------------------------------------------------- Lyra: atiradora, verde
# Jovem e leve, cabelo castanho solto, gibão azul-real com arreios de couro, ombreiras de metal,
# botas altas, besta de mão erguida e aljava na cintura.

func _lyra(breath: float, t: float) -> void:
	var b := -breath
	var k := _k(t)
	var c := _p(1, -48 + b)
	# cabelo solto atrás da cabeça, é parte da silhueta
	_cel([c + Vector2(-6, -3), c + Vector2(2, -3), c + Vector2(1, 11), c + Vector2(-3, 13), c + Vector2(-8, 10)], H_BROWN, c.x - O.x - 2.0)
	# aljava na cintura, com as penas dos virotes
	_limb(_p(-8, -30 + b), _p(-11, -19 + b), 5.0, LEATHER)
	_line(_p(-7, -33 + b), _p(-8, -30 + b), 1.0, FX_GREEN)
	_line(_p(-9, -33 + b), _p(-9.5, -30 + b), 1.0, WHITE[0])
	_leg(_p(-3, -24 + b), _p(-5, 0), 4.6, LEATHER, LEATHER, 12.0)
	_leg(_p(3, -24 + b), _p(4, 0), 4.6, LEATHER, LEATHER, 12.0)
	_cel([_p(-6, -40 + b), _p(6, -40 + b), _p(5, -25 + b), _p(7, -18 + b), _p(-7, -18 + b), _p(-5, -25 + b)], BLUE, 2.0, -3.5)
	# arreios de couro em X e cinto
	_line(_p(-5, -39 + b), _p(4, -26 + b), 1.4, LEATHER[1])
	_line(_p(5, -39 + b), _p(-4, -26 + b), 1.4, LEATHER[1])
	_line(_p(-6, -25 + b), _p(6, -25 + b), 2.0, LEATHER[0])
	_flat_ball(_p(0, -25 + b), 1.2, GOLD[0])
	_limb(_p(0, -40 + b), _p(0.5, -43 + b), 3.0, SKIN)
	_head(c, 5.0)
	_hair_cap(c, 5.0, H_BROWN)
	_ball(_p(-7, -39 + b), 3.4, SILVER)
	_arm(_p(-6, -38 + b), _p(-2, -30 + b), 3.4, BLUE, LEATHER)
	# braço estendido com a besta; sobe para mirar e recua no disparo
	var shoulder := _p(7, -39 + b)
	_ball(shoulder, 3.4, SILVER)
	var recoil := -2.0 if t >= 0.45 and t <= 0.55 else 0.0
	var hand := _p(14 + 4.0 * k + recoil, lerpf(-31.0, -40.0, k) + b)
	var dir := Vector2.from_angle(deg_to_rad(lerpf(14.0, -6.0, k)))
	_arm(shoulder, hand, 3.4, BLUE, LEATHER)
	var perp := dir.orthogonal()
	_line(hand - dir * 2.0, hand + dir * 12.0, 2.4, WOOD[1])
	_line(hand - dir * 1.0, hand + dir * 11.0, 1.2, WOOD[0])
	var tip := hand + dir * 10.0
	_line(tip - perp * 6.5 - dir * 1.5, tip, 1.6, IRON[0])
	_line(tip + perp * 6.5 - dir * 1.5, tip, 1.6, IRON[0])
	_line(tip - perp * 6.5 - dir * 1.5, tip + perp * 6.5 - dir * 1.5, 1.0, WHITE[1])
	_line(hand + dir * 1.0, hand + dir * 13.5, 1.0, FX_GREEN)
	if k > 0.8:
		_flare(hand + dir * 15.0, 1.8, FX_GREEN)


# ---------------------------------------------------------------- Irmão Tomás: suporte, branco
# Sacerdote sereno, cabelo curto cinza-castanho, manto azul-real (de propósito, para o branco ficar
# só no cristal), capuz abaixado, cinto dourado, estola branca com leão, cajado claro.

func _tomas(breath: float, t: float) -> void:
	var b := -breath
	var k := _k(t)
	# manto até o chão, com barra dourada
	_cel([_p(-7, -41 + b), _p(7, -41 + b), _p(8, -24 + b), _p(12, 0), _p(-12, 0), _p(-8, -24 + b)], BLUE, 3.0, -5.0)
	_line(_p(-11.5, -1.5), _p(11.5, -1.5), 2.2, GOLD[0])
	_line(_p(-11, -4), _p(11, -4), 0.8, GOLD[1])
	# estola branca
	_cel([_p(-4, -40 + b), _p(-1, -40 + b), _p(-1, -9), _p(-4, -9)], WHITE)
	_cel([_p(1, -40 + b), _p(4, -40 + b), _p(4, -9), _p(1, -9)], WHITE, 2.5)
	_line(_p(-4.5, -9), _p(-0.5, -9), 1.0, GOLD[0])
	_line(_p(0.5, -9), _p(4.5, -9), 1.0, GOLD[0])
	_flat_ball(_p(-2.5, -15), 1.4, GOLD[0])
	_flat_ball(_p(2.5, -15), 1.4, GOLD[0])
	_line(_p(-8, -25 + b), _p(8, -25 + b), 2.2, GOLD[0])
	# capuz abaixado atrás do pescoço
	_cel([_p(-7, -42 + b), _p(7, -42 + b), _p(5, -38 + b), _p(-5, -38 + b)], BLUE, 2.0)
	_limb(_p(0, -41 + b), _p(0.5, -44 + b), 3.6, SKIN)
	var c := _p(1, -48 + b)
	_head(c, 5.0)
	_hair_cap(c, 5.0, H_ASH)
	# mão livre aberta, em bênção; sobe no golpe
	var free := _p(-14.0, lerpf(-29.0, -37.0, k) + b)
	_arm(_p(-7, -38 + b), free, 4.4, BLUE, SKIN)
	_line(free + Vector2(-1, -1), free + Vector2(-2, -4), 1.0, SKIN[0])
	_line(free + Vector2(1, -1), free + Vector2(1, -4), 1.0, SKIN[0])
	# cajado plantado ao lado do corpo; ergue um pouco ao atacar
	var lift := 4.0 * k
	var hand := _p(13, -30 + b - lift)
	_arm(_p(7, -38 + b), hand, 4.4, BLUE, SKIN)
	_limb(_p(14, -lift), _p(14, -58 - lift), 2.6, WOOD)
	_cel([_p(11, -56 - lift), _p(17, -56 - lift), _p(16, -59 - lift), _p(12, -59 - lift)], GOLD, 15.0)
	var crystal := _p(14, -63 - lift)
	_cel([crystal + Vector2(0, -4.5), crystal + Vector2(3, 0), crystal + Vector2(0, 4), crystal + Vector2(-3, 0)], [FX_WHITE, Color("cfe0ff"), FX_WHITE], 15.0)
	if k > 0.3:
		_flare(crystal, 1.0 + 2.2 * k, FX_WHITE)


# ---------------------------------------------------------------- Mestre Brom: artilheiro, laranja
# "Guerreiro padrão com um canhãozinho ao lado". Baixo e largo, elmo de aço, barba, cota de malha
# e tabardo do Reino. Encosta o bota-fogo no canhão, que dá um tranco para trás.

func _brom(breath: float, t: float) -> void:
	var b := -breath
	var k := _k(t)
	var fired := t >= 0.45 and t <= 0.8
	var kick := -2.5 if fired else 0.0
	# canhãozinho de bronze em carreta de madeira, à frente dele
	var mouth := _p(30 + kick, -22)
	var breech := _p(10 + kick, -13)
	_cel([_p(9 + kick, -11), _p(26 + kick, -11), _p(24 + kick, -5), _p(11 + kick, -5)], WOOD, 18.0 + kick)
	_ball(_p(13 + kick, -5), 5.0, IRON)
	_ball(_p(13 + kick, -5), 2.0, WOOD)
	_ball(_p(23 + kick, -5), 4.0, IRON)
	_ball(_p(23 + kick, -5), 1.6, WOOD)
	_line(breech, mouth, 8.0, BRONZE[1])
	_line(breech + Vector2(-0.4, -1.0), mouth + Vector2(-0.4, -1.0), 5.6, BRONZE[0])
	_line(breech + Vector2(-0.4, -2.2), mouth + Vector2(-0.4, -2.2), 1.6, BRONZE[2])
	_line(mouth + Vector2(-1, -5), mouth + Vector2(1, 4), 2.2, BRONZE[2])
	_ball(breech, 4.0, BRONZE)
	if fired:
		_flare(mouth + Vector2(5, -2), 3.0 if t < 0.6 else 1.6, FX_ORANGE)
	# corpo, deslocado para a esquerda para deixar o canhão à vista
	var x := -8.0
	_leg(_p(x - 5, -20 + b), _p(x - 7, 0), 7.0, STONE, LEATHER, 8.0)
	_leg(_p(x + 5, -20 + b), _p(x + 7, 0), 7.0, STONE, LEATHER, 8.0)
	_cel([_p(x - 11, -37 + b), _p(x + 11, -37 + b), _p(x + 10, -15 + b), _p(x - 10, -15 + b)], SILVER, x + 5.0, x - 6.0)
	_cel([_p(x - 5, -37 + b), _p(x + 5, -37 + b), _p(x + 6, -13 + b), _p(x - 6, -13 + b)], BLUE, x + 2.0)
	_line(_p(x - 10.5, -22 + b), _p(x + 10.5, -22 + b), 3.0, LEATHER[0])
	_flat_ball(_p(x, -22 + b), 2.0, GOLD[0])
	_flat_ball(_p(x, -30 + b), 2.4, GOLD[0])
	var c := _p(x + 1, -43 + b)
	_head(c, 5.6)
	# barba castanha cheia e elmo de aço com aba
	_cel([c + Vector2(-5, 3), c + Vector2(6, 3), c + Vector2(4.5, 8.5), c + Vector2(-3, 9.5)], H_BROWN, c.x - O.x + 2.0, c.x - O.x - 2.0)
	_cel([c + Vector2(-6, -3), c + Vector2(-5, -7), c + Vector2(0, -9), c + Vector2(5, -7), c + Vector2(6, -3)], SILVER, c.x - O.x + 2.0, c.x - O.x - 3.0)
	_line(c + Vector2(-8, -3), c + Vector2(8, -3), 2.0, IRON[0])
	_ball(_p(x - 11, -35 + b), 5.0, SILVER)
	_ball(_p(x + 11, -35 + b), 5.0, SILVER)
	_arm(_p(x - 12, -33 + b), _p(x - 14, -20 + b), 5.4, SILVER, LEATHER)
	# bota-fogo: a mão desce até o ouvido do canhão
	var hand := _p(x + 15.0, lerpf(-32.0, -24.0, k) + b)
	_arm(_p(x + 12, -33 + b), hand, 5.4, SILVER, LEATHER)
	var match_tip := hand + Vector2(5.0 + 2.0 * k, -5.0 + 8.0 * k)
	_line(hand, match_tip, 1.6, WOOD[1])
	_flare(match_tip, 1.2, FX_ORANGE)


# ---------------------------------------------------------------- Dama Selene: maga, roxo
# "Maga de cajado e capa". Alta e fina, gola alta, vestido prateado, capa azul-real, cajado com
# meia-lua dourada. O gesto da mão solta o orbe arcano.

func _selene(breath: float, t: float) -> void:
	var b := -breath
	var k := _k(t)
	_cel([_p(-8, -42 + b), _p(8, -42 + b), _p(13, -3), _p(-15, -3)], BLUE, 2.0, -9.0)
	_cel([_p(-5, -40 + b), _p(5, -40 + b), _p(5, -25 + b), _p(9, 0), _p(-9, 0), _p(-5, -25 + b)], SILVER, 2.0, -3.0)
	_cel([_p(-2, -24 + b), _p(2, -24 + b), _p(3, 0), _p(-3, 0)], BLUE, 1.0)
	_line(_p(-5, -25 + b), _p(5, -25 + b), 1.8, GOLD[0])
	_line(_p(-8.5, -1), _p(8.5, -1), 1.4, GOLD[1])
	_flat_ball(_p(0, -34 + b), 1.6, FX_PURPLE)
	_limb(_p(0, -40 + b), _p(0.5, -44 + b), 3.0, SKIN)
	var c := _p(1, -49 + b)
	_head(c, 4.8)
	_hair_cap(c, 4.8, H_DARK)
	# coque e tiara
	_ball(c + Vector2(-4, -5), 2.8, H_DARK)
	_line(c + Vector2(-4, -3.6), c + Vector2(4, -4), 1.0, GOLD[0])
	# gola alta: a marca da silhueta
	_cel([_p(-8, -46 + b), _p(-3, -42 + b), _p(-5, -38 + b), _p(-10, -39 + b)], BLUE, 99.0, -7.0)
	_cel([_p(9, -46 + b), _p(4, -42 + b), _p(6, -38 + b), _p(11, -39 + b)], BLUE, 6.0)
	# cajado na mão de trás
	var staff_x := -13.0
	_arm(_p(-5, -38 + b), _p(staff_x, -30 + b), 3.2, SILVER, SKIN)
	_limb(_p(staff_x, 0), _p(staff_x, -60), 2.4, WOOD)
	var top := _p(staff_x, -63)
	for i in 9:
		var a := deg_to_rad(120.0 + i * 37.5)
		_line(top + Vector2.from_angle(a) * 5.0, top + Vector2.from_angle(a + 0.65) * 5.0, 1.6, GOLD[0])
	_flat_ball(top, 2.2, FX_PURPLE)
	# gesto: a mão vai à frente e o orbe nasce nela
	var hand := _p(lerpf(11.0, 20.0, k), lerpf(-30.0, -40.0, k) + b)
	_arm(_p(5, -38 + b), hand, 3.2, SILVER, SKIN)
	if k > 0.3:
		_flare(hand + Vector2(4, -1), 1.0 + 2.4 * k, FX_PURPLE)


# ---------------------------------------------------------------- Wulf: caçador, vermelho
# "Caçador com arco e flecha". Capuz cinza-azulado, gibão de couro com placa prateada, faixa azul,
# broche dourado, aljava às costas, arco longo. Puxa a corda e solta.

func _wulf(breath: float, t: float) -> void:
	var b := -breath
	# 0 parado, 1 corda toda puxada; solta no quadro do disparo
	var pull := 0.0
	if t > 0.1 and t < 0.4:
		pull = 1.0
	var released := t >= 0.45 and t <= 0.6
	# aljava às costas: as flechas passam do ombro
	_limb(_p(-9, -44 + b), _p(-4, -24 + b), 5.0, LEATHER)
	_line(_p(-10, -48 + b), _p(-9, -44 + b), 1.0, FX_RED)
	_line(_p(-7, -49 + b), _p(-7, -44 + b), 1.0, WHITE[0])
	_cel([_p(-7, -41 + b), _p(7, -41 + b), _p(10, -12), _p(-11, -12)], STONE, 2.0, -6.0)
	_leg(_p(-4, -24 + b), _p(-6, 0), 5.2, LEATHER, IRON, 12.0)
	_leg(_p(4, -24 + b), _p(5, 0), 5.2, LEATHER, IRON, 12.0)
	_cel([_p(-7, -41 + b), _p(7, -41 + b), _p(6, -24 + b), _p(8, -18 + b), _p(-8, -18 + b), _p(-6, -24 + b)], LEATHER, 2.0, -4.0)
	_cel([_p(-5, -40 + b), _p(5, -40 + b), _p(4, -31 + b), _p(-4, -31 + b)], SILVER, 2.0)
	_line(_p(-7, -24 + b), _p(7, -24 + b), 2.4, BLUE[0])
	_flat_ball(_p(0, -40 + b), 1.6, GOLD[0])
	var c := _p(1, -48 + b)
	_head(c, 5.0)
	_cel([c + Vector2(-4, 3), c + Vector2(4.5, 3), c + Vector2(3, 6.5), c + Vector2(-2, 6.5)], H_BROWN, c.x - O.x + 2.0)
	# capuz pontudo caído para trás
	_cel([c + Vector2(-11, -2), c + Vector2(-5, -6), c + Vector2(1, -7.5), c + Vector2(6, -4), c + Vector2(6.5, -1.5), c + Vector2(3, -3), c + Vector2(-2, -2), c + Vector2(-3, 5), c + Vector2(-7, 5)], STONE, c.x - O.x + 2.0, c.x - O.x - 6.0)
	# arco longo na mão da frente
	var bow_hand := _p(16, -35 + b)
	_arm(_p(6, -38 + b), bow_hand, 3.8, LEATHER, LEATHER)
	var top := bow_hand + Vector2(-5, -22)
	var bottom := bow_hand + Vector2(-5, 22)
	var prev := top
	for i in range(1, 11):
		var u := i / 10.0
		var q := top.lerp(bottom, u) + Vector2(sin(u * PI) * 7.0, 0)
		_line(prev, q, 2.0, WOOD[1])
		prev = q
	# corda e mão que puxa
	var nock := top.lerp(bottom, 0.5) + Vector2(-8.0 * pull, 0)
	_line(top, nock, 0.8, WHITE[0])
	_line(bottom, nock, 0.8, WHITE[0])
	var draw_hand := nock if pull > 0.0 else _p(5, -30 + b)
	_arm(_p(-5, -38 + b), draw_hand, 3.8, LEATHER, LEATHER)
	if not released:
		_line(nock, bow_hand + Vector2(8, 0), 1.2, WOOD[0])
		_line(bow_hand + Vector2(6, 0), bow_hand + Vector2(9, 0), 1.6, FX_RED)
	else:
		_flare(bow_hand + Vector2(7, 0), 2.0, FX_RED)


# ---------------------------------------------------------------- Engenheira Mabel: invocadora, ciano
# A ficha do Notion está vazia: desenho proposto. Baixa e prática, óculos de latão na testa, camisa
# branca, jardineira azul, avental de couro, cinto de ferramentas, mochila com engrenagem, chave
# inglesa enorme. Atira estrepes no caminho.

func _mabel(breath: float, t: float) -> void:
	var b := -breath
	var k := _k(t)
	# mochila com engrenagem: marca da silhueta
	_cel([_p(-13, -44 + b), _p(-1, -44 + b), _p(-1, -24 + b), _p(-13, -24 + b)], LEATHER, -5.0, -11.0)
	var gear := _p(-13, -38 + b)
	for i in 8:
		var a := i * TAU / 8.0
		_line(gear + Vector2.from_angle(a) * 4.0, gear + Vector2.from_angle(a) * 7.0, 2.2, GOLD[1])
	_ball(gear, 4.6, GOLD)
	_flat_ball(gear, 1.6, LEATHER[1])
	_line(_p(-11, -44 + b), _p(-11, -49 + b), 2.0, IRON[0])
	_flare(_p(-11, -50 + b), 1.0, FX_CYAN)
	_leg(_p(-4, -21 + b), _p(-5, 0), 5.6, STONE, LEATHER, 7.0)
	_leg(_p(4, -21 + b), _p(5, 0), 5.6, STONE, LEATHER, 7.0)
	_cel([_p(-7, -37 + b), _p(7, -37 + b), _p(7, -20 + b), _p(-7, -20 + b)], WHITE, 3.0)
	_cel([_p(-5, -35 + b), _p(5, -35 + b), _p(7, -14 + b), _p(-7, -14 + b)], BLUE, 2.0, -4.0)
	_cel([_p(-3.5, -30 + b), _p(3.5, -30 + b), _p(5, -11 + b), _p(-5, -11 + b)], LEATHER, 1.5, -3.0)
	_line(_p(-8, -21 + b), _p(8, -21 + b), 2.4, LEATHER[1])
	_flat_ball(_p(0, -21 + b), 1.2, GOLD[0])
	_cel([_p(4, -23 + b), _p(8, -23 + b), _p(8, -17 + b), _p(4, -17 + b)], LEATHER, 6.5)
	var c := _p(1, -43 + b)
	_limb(_p(0, -37 + b), _p(0.5, -39 + b), 3.4, SKIN)
	_head(c, 5.2)
	_hair_cap(c, 5.2, H_RED)
	# cabelo preso e óculos de latão na testa
	_ball(c + Vector2(-5, -3), 2.8, H_RED)
	_line(c + Vector2(-5, -3), c + Vector2(5.5, -3), 1.4, LEATHER[1])
	_flat_ball(c + Vector2(0.5, -3.5), 1.9, GOLD[0])
	_flat_ball(c + Vector2(4, -3.5), 1.9, GOLD[0])
	_flat_ball(c + Vector2(0.5, -3.5), 0.9, FX_CYAN)
	_flat_ball(c + Vector2(4, -3.5), 0.9, FX_CYAN)
	# chave inglesa enorme apoiada no chão
	_arm(_p(-6, -35 + b), _p(-15, -26 + b), 3.8, WHITE, SKIN)
	_limb(_p(-16, -2), _p(-16, -38), 3.4, SILVER)
	_ball(_p(-16, -42), 6.2, SILVER)
	_erase([_p(-19, -50), _p(-13, -50), _p(-14, -41), _p(-18, -41)])
	_ball(_p(-16, -1), 3.0, SILVER)
	# mão que arremessa: de baixo para cima e para a frente
	var hand := _p(lerpf(10.0, 19.0, k), lerpf(-24.0, -40.0, k) + b)
	_arm(_p(6, -35 + b), hand, 3.8, WHITE, SKIN)
	if k > 0.2:
		_flare(hand + Vector2(2, -2), 1.0 + 1.4 * k, FX_CYAN)


# ---------------------------------------------------------------- Rainha Isolde: controladora, gelo
# "Rainha; raio de gelo que empilha Lento". Alta, coroa, cabelo prateado longo, vestido branco em
# sino com painel azul e dourado, gola de arminho, cetro com cristal de gelo.

func _isolde(breath: float, t: float) -> void:
	var b := -breath
	var k := _k(t)
	# capa longa azul
	_cel([_p(-8, -42 + b), _p(8, -42 + b), _p(17, -1), _p(-19, -1)], BLUE, 4.0, -11.0)
	# vestido em sino
	_cel([_p(-5, -41 + b), _p(5, -41 + b), _p(5, -27 + b), _p(14, 0), _p(-14, 0), _p(-5, -27 + b)], WHITE, 3.0, -6.0)
	_cel([_p(-2.5, -27 + b), _p(2.5, -27 + b), _p(6, 0), _p(-6, 0)], BLUE, 1.5, -3.0)
	_line(_p(-3.5, -27 + b), _p(-7, 0), 1.2, GOLD[0])
	_line(_p(3.5, -27 + b), _p(7, 0), 1.2, GOLD[0])
	_line(_p(-13.5, -1.2), _p(13.5, -1.2), 2.2, GOLD[0])
	_line(_p(-5.5, -27 + b), _p(5.5, -27 + b), 1.8, GOLD[0])
	_flat_ball(_p(0, -34 + b), 2.0, FX_ICE)
	# cabelo prateado atrás
	var c := _p(1, -49 + b)
	_cel([c + Vector2(-6, -2), c + Vector2(1, -2), c + Vector2(0, 12), c + Vector2(-8, 13)], H_WHITE, c.x - O.x - 3.0)
	_limb(_p(0, -41 + b), _p(0.5, -44 + b), 3.0, SKIN)
	_head(c, 4.8)
	_hair_cap(c, 4.8, H_WHITE)
	# gola de arminho: faixa branca com pintinhas escuras
	_cel([_p(-9, -44 + b), _p(9, -44 + b), _p(8, -39 + b), _p(-8, -39 + b)], WHITE, 4.0)
	for x: float in [-6.0, -2.0, 2.0, 6.0]:
		_put(int(O.x + x), int(O.y - 41 + b), Color("2a2030"))
	# coroa dourada alta, com pontas e gema de gelo: reconhecível de longe
	var cr := c + Vector2(0, -5)
	_cel([cr + Vector2(-5, 1), cr + Vector2(5, 1), cr + Vector2(5.5, -2), cr + Vector2(6, -7), cr + Vector2(3, -3.5), cr + Vector2(0, -8), cr + Vector2(-3, -3.5), cr + Vector2(-6, -7), cr + Vector2(-5.5, -2)], GOLD, cr.x - O.x + 2.0, cr.x - O.x - 3.0)
	_flat_ball(cr + Vector2(0, -2), 1.3, FX_ICE)
	_arm(_p(-7, -38 + b), _p(-11, -25 + b), 3.2, WHITE, SKIN)
	# cetro de gelo: aponta para o alvo no golpe
	var hand := _p(lerpf(11.0, 17.0, k), lerpf(-29.0, -39.0, k) + b)
	var dir := Vector2.from_angle(deg_to_rad(lerpf(-78.0, -14.0, k)))
	_arm(_p(7, -38 + b), hand, 3.2, WHITE, SKIN)
	_limb(hand - dir * 4.0, hand + dir * 13.0, 2.2, GOLD)
	var tip := hand + dir * 16.0
	var perp := dir.orthogonal()
	_cel([tip + dir * 5.0, tip + perp * 2.8, tip - dir * 3.5, tip - perp * 2.8], [FX_ICE, Color("5fb6e8"), Color("eafaff")], tip.x - O.x + 0.5)
	if k > 0.6:
		_flare(tip + dir * 2.0, 1.2 + 1.6 * k, FX_ICE)
