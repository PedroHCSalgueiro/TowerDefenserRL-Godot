extends "res://dev/proto25d/herois.gd"
## Teste de visual estilizado: os heróis usam as imagens de referência recortadas (dev/proto25d/
## art_ref), em alta resolução, num cenário de cores chapadas. Só Aldric, Lyra e Tomás têm imagem.
## A animação é feita em código (balanço e tranco), porque cada herói é uma imagem só.
##   godot --path . res://dev/proto25d/herois_ref.tscn [-- --shot=a.png --shot-at=6 --dist=8]

const REF_ART := "res://dev/proto25d/art_ref/"
## Altura do herói em casas: maior que o personagem de 50 px do guia, para o traço aparecer.
const HERO_HEIGHT := 1.9
const GOBLIN_HEIGHT := 0.62
## Demonstração: horda mais espaçada e mais fraca que a da cena anterior, para os heróis aparecerem.
const REF_SPAWN_EVERY := 1.1
const REF_ENEMY_HP := 40.0
## Casa, e altura da arma em relação à altura do herói, para o tiro sair dela.
const STYLED := {
	"aldric": {"cell": [4, 5], "color": "ffe066", "kind": "beam", "muzzle": 0.5},
	"tomas": {"cell": [6, 5], "color": "ffffff", "kind": "light", "muzzle": 0.84},
	"lyra": {"cell": [8, 5], "color": "5de35d", "kind": "bolt", "muzzle": 0.85},
}

## Herói renderizado do 3D em 8 direções (render_sheet.py) e cavaleiro do pacote, para comparar.
const ALDRIC_DIR := "res://dev/proto25d/art_aldric/"
const ALDRIC_FIRE_FRAME := 5
const ATTACK_FPS := 15.0
## O render é visto de cima e por isso parece mais baixo que as imagens de frente: compensa aqui.
const RENDER_SCALE := 1.22
## O render tem os pés abaixo do ponto de apoio: aproxima da câmera para a base não cortá-los.
const SPRITE_FORWARD := 0.75
## Altura do cavaleiro dentro do quadro de 128 px do pacote.
const PIXEL_BODY_PX := 90.0
## Heróis em pixel art (render_pixel.py): folhas de 8 direções e 15 quadros, disparo no quadro 5.
const PIXEL_HEROES := {"aldric": "res://dev/proto25d/art_pixel/", "lyra": "res://dev/proto25d/art_lyra/"}
const PIXEL_FIRE_FRAME := 5
const IDLE_FPS := 8.0

var _meta := {}
var _glow_tex: GradientTexture2D


func _ready() -> void:
	_meta = JSON.parse_string(FileAccess.get_file_as_string(REF_ART + "meta.json"))
	_dist = 10.5
	_pitch = 34.0
	_focus = Vector2(6.0, 5.0)
	super()
	_goblin_frames = SpriteFrames.new()
	_goblin_frames.set_animation_speed("default", 8.0)
	for f in 4:
		_goblin_frames.add_frame("default", _tex(REF_ART + "goblin_%d.png" % f))


## Carrega com mipmaps: é o que mantém o traço limpo quando a imagem aparece pequena.
func _tex(path: String) -> ImageTexture:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _setup_sprite(s: SpriteBase3D, size: Vector2, anchor: Vector2) -> void:
	super(s, size, anchor)
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	# goblin: 140 px de altura na imagem
	s.pixel_size = GOBLIN_HEIGHT / 140.0


func _spawn_enemy() -> void:
	super()
	_spawn_cd = REF_SPAWN_EVERY
	var enemy: Dictionary = _enemies[_enemies.size() - 1]
	enemy["hp"] = REF_ENEMY_HP
	_setup_sprite(enemy["sprite"], Vector2(120, 140), Vector2(60, 132))


func _add_hero(id: String, data: Dictionary) -> void:
	if not STYLED.has(id):
		return
	if PIXEL_HEROES.has(id) and FileAccess.file_exists(PIXEL_HEROES[id] + "meta.json"):
		_add_pixel_hero(id, data)
		return
	if id == "aldric" and FileAccess.file_exists(ALDRIC_DIR + "meta.json"):
		_add_aldric_3d(data)
		return
	var cfg: Dictionary = STYLED[id]
	var cell := Vector2i(cfg["cell"][0], cfg["cell"][1])
	var col := Color(cfg["color"])
	var info: Dictionary = _meta[id]
	var tex := _tex(REF_ART + id + ".png")
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("idle")
	frames.add_frame("idle", tex)
	# ataque: a mesma imagem; os quadros só marcam o tempo do disparo
	frames.add_animation("attack")
	frames.set_animation_speed("attack", 12.0)
	frames.set_animation_loop("attack", false)
	for f in 5:
		frames.add_frame("attack", tex)
	var node := Node3D.new()
	node.position = _world(Vector2(cell))
	node.add_child(_make_base(col))
	var sprite := AnimatedSprite3D.new()
	sprite.sprite_frames = frames
	_setup_sprite(sprite, Vector2(info["w"], info["h"]), Vector2(info["anchor_x"], info["h"]))
	sprite.pixel_size = HERO_HEIGHT / float(info["h"])
	sprite.position.y = BASE_HEIGHT + 0.03
	sprite.set_meta("faces_left", id != "tomas")
	sprite.play("idle")
	node.add_child(sprite)
	var label := Label3D.new()
	label.text = data["name"]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.0042
	label.font_size = 40
	label.outline_size = 12
	label.modulate = col
	label.position.y = BASE_HEIGHT + HERO_HEIGHT * 1.22
	label.visible = _labels_on
	node.add_child(label)
	_labels.append(label)
	add_child(node)
	var hero := {
		"id": id, "node": node, "sprite": sprite, "cell": cell, "color": col, "kind": cfg["kind"],
		"muzzle": Vector2.ZERO, "muzzle_h": cfg["muzzle"], "data": data,
		"period": 1.0 / float(data["shotsPerSecond"]), "range": float(data["range"]),
		"cd": randf() * 0.8, "attacking": false, "target": {}, "phase": randf() * TAU,
	}
	sprite.frame_changed.connect(_on_hero_frame.bind(hero))
	sprite.animation_finished.connect(_on_attack_done.bind(hero))
	_heroes.append(hero)


func _add_aldric_3d(data: Dictionary) -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ALDRIC_DIR + "meta.json"))
	var dirs: Array[Dictionary] = []
	for d in meta["angles"].size():
		var frames := SpriteFrames.new()
		frames.remove_animation("default")
		frames.add_animation("idle")
		frames.add_frame("idle", _tex(ALDRIC_DIR + "d%d_f00.png" % d))
		frames.add_animation("attack")
		frames.set_animation_speed("attack", ATTACK_FPS)
		frames.set_animation_loop("attack", false)
		for f in int(meta["frames"]):
			frames.add_frame("attack", _tex(ALDRIC_DIR + "d%d_f%02d.png" % [d, f]))
		dirs.append({"angle": meta["angles"][d], "frames": frames})
	var cell_px := float(meta["cell"])
	# o modelo ocupa `height` unidades e a câmera mostra `ortho_scale` unidades em `cell` pixels
	var pixel: float = float(meta["ortho_scale"]) / cell_px * HERO_HEIGHT / float(meta["height"]) * RENDER_SCALE
	var cfg: Dictionary = STYLED["aldric"]
	var anchor := Vector2(meta["anchor"][0], meta["anchor"][1])
	_add_directional("aldric", data, Vector2i(cfg["cell"][0], cfg["cell"][1]), Color(cfg["color"]), cfg["kind"], dirs, Vector2(cell_px, cell_px), anchor, pixel, ALDRIC_FIRE_FRAME)


func _add_pixel_hero(id: String, data: Dictionary) -> void:
	var folder: String = PIXEL_HEROES[id]
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder + "meta.json"))
	var idle := _tex_plain(folder + "Idle.png")
	var attack := _tex_plain(folder + "Attack.png")
	var cols := int(meta["cols"])
	# o ataque inteiro cabe no intervalo entre tiros de data/, nunca mais lento que ATTACK_FPS
	var attack_fps := maxf(ATTACK_FPS, cols * float(data["shotsPerSecond"]))
	var dirs: Array[Dictionary] = []
	for row in meta["angles"].size():
		var frames := SpriteFrames.new()
		frames.remove_animation("default")
		frames.add_animation("idle")
		frames.set_animation_speed("idle", IDLE_FPS)
		frames.add_animation("attack")
		frames.set_animation_speed("attack", attack_fps)
		frames.set_animation_loop("attack", false)
		for f in cols:
			frames.add_frame("idle", _cell(idle, f, row))
			frames.add_frame("attack", _cell(attack, f, row))
		dirs.append({"angle": meta["angles"][row], "frames": frames})
	var cfg: Dictionary = STYLED[id]
	var anchor := Vector2(meta["anchor"][0], meta["anchor"][1])
	_add_directional(id, data, Vector2i(cfg["cell"][0], cfg["cell"][1]), Color(cfg["color"]), cfg["kind"], dirs, Vector2(128, 128), anchor, HERO_HEIGHT / PIXEL_BODY_PX, PIXEL_FIRE_FRAME)
	(_heroes[_heroes.size() - 1]["sprite"] as AnimatedSprite3D).texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST


func _tex_plain(path: String) -> ImageTexture:
	return ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(path)))


func _cell(sheet: Texture2D, col: int, row: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = sheet
	a.region = Rect2(col * 128, row * 128, 128, 128)
	return a


func _add_directional(id: String, data: Dictionary, cell: Vector2i, col: Color, kind: String, dirs: Array[Dictionary], size: Vector2, anchor: Vector2, pixel: float, fire_frame: int) -> void:
	var node := Node3D.new()
	node.position = _world(Vector2(cell))
	node.add_child(_make_base(col))
	var sprite := AnimatedSprite3D.new()
	sprite.sprite_frames = dirs[0]["frames"]
	_setup_sprite(sprite, size, anchor)
	sprite.pixel_size = pixel
	sprite.position.y = BASE_HEIGHT + 0.03
	sprite.set_meta("has_dirs", true)
	sprite.play("idle")
	node.add_child(sprite)
	var label := Label3D.new()
	label.text = data["name"]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.0042
	label.font_size = 40
	label.outline_size = 12
	label.modulate = col
	label.position.y = BASE_HEIGHT + HERO_HEIGHT * 1.22
	label.visible = _labels_on
	node.add_child(label)
	_labels.append(label)
	add_child(node)
	var hero := {
		"id": id, "node": node, "sprite": sprite, "cell": cell, "color": col, "kind": kind,
		"muzzle": Vector2.ZERO, "muzzle_h": 0.6, "data": data,
		"period": 1.0 / float(data["shotsPerSecond"]), "range": float(data["range"]),
		"cd": randf() * 0.8, "attacking": false, "target": {}, "phase": randf() * TAU,
		"dirs": dirs, "dir": 0, "look": Vector3(1, 0, 1), "fire_frame": fire_frame,
	}
	sprite.frame_changed.connect(_on_hero_frame.bind(hero))
	sprite.animation_finished.connect(_on_attack_done.bind(hero))
	_heroes.append(hero)


## Escolhe a linha da folha conforme para onde o herói olha VISTO PELA CÂMERA: girar a câmera também
## troca a direção, e é isso que faz o sprite parecer 3D.
func _aim(hero: Dictionary) -> void:
	var look: Vector3 = hero["look"]
	var basis_cam := _cam.global_transform.basis
	(hero["sprite"] as AnimatedSprite3D).position = Vector3(0, BASE_HEIGHT + 0.03, 0) + basis_cam.z * SPRITE_FORWARD
	var right := Vector3(basis_cam.x.x, 0, basis_cam.x.z).normalized()
	var to_cam := Vector3(basis_cam.z.x, 0, basis_cam.z.z).normalized()
	var angle := rad_to_deg(atan2(look.dot(right), look.dot(to_cam)))
	var dirs: Array = hero["dirs"]
	var best := 0
	var best_diff := 999.0
	for i in dirs.size():
		var diff := absf(wrapf(angle - float(dirs[i]["angle"]), -180.0, 180.0))
		if diff < best_diff:
			best_diff = diff
			best = i
	if best == hero["dir"]:
		return
	hero["dir"] = best
	var sprite: AnimatedSprite3D = hero["sprite"]
	var anim := sprite.animation
	var frame := sprite.frame
	var progress := sprite.frame_progress
	sprite.sprite_frames = dirs[best]["frames"]
	sprite.play(anim)
	sprite.set_frame_and_progress(frame, progress)


func _on_hero_frame(hero: Dictionary) -> void:
	var sprite: AnimatedSprite3D = hero["sprite"]
	if sprite.animation != "attack" or sprite.frame != int(hero.get("fire_frame", FIRE_FRAME)) or hero.get("fired", false):
		return
	hero["fired"] = true
	var target: Dictionary = hero["target"]
	if not _enemies.has(target):
		target = _find_target(hero)
	if not target.is_empty():
		_fire(hero, target)


func _face(sprite: AnimatedSprite3D, from: Vector3, to: Vector3) -> void:
	if sprite.has_meta("has_dirs"):
		return
	super(sprite, from, to)
	if sprite.has_meta("faces_left"):
		if sprite.get_meta("faces_left"):
			sprite.flip_h = not sprite.flip_h


func _muzzle(hero: Dictionary) -> Vector3:
	return (hero["node"] as Node3D).position + Vector3(0, BASE_HEIGHT + HERO_HEIGHT * float(hero["muzzle_h"]), 0)


## Animação por código: agacha um pouco, estica no disparo e volta.
func _start_attack(hero: Dictionary, target: Dictionary) -> void:
	if hero["attacking"]:
		return
	hero["fired"] = false
	if hero.has("dirs"):
		var d: Vector3 = (target["node"] as Node3D).position - (hero["node"] as Node3D).position
		hero["look"] = Vector3(d.x, 0, d.z)
	super(hero, target)
	if hero.has("dirs"):
		return
	var sprite: AnimatedSprite3D = hero["sprite"]
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector3(1.07, 0.92, 1.0), 0.1)
	tween.tween_property(sprite, "scale", Vector3(0.95, 1.08, 1.0), 0.07)
	tween.tween_property(sprite, "scale", Vector3.ONE, 0.2)


func _process(delta: float) -> void:
	super(delta)
	for hero in _heroes:
		if hero.has("dirs"):
			_aim(hero)
			continue
		if not hero["attacking"]:
			var sway: float = sin(_elapsed * 2.2 + hero["phase"]) * 0.012
			(hero["sprite"] as AnimatedSprite3D).scale = Vector3(1.0 - sway, 1.0 + sway, 1.0)


## Faísca lisa, sem pixel, para combinar com o traço das imagens.
func _spark(col: Color, size: float) -> Sprite3D:
	if _glow_tex == null:
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		grad.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = grad
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
		_glow_tex.width = 64
		_glow_tex.height = 64
	var s := Sprite3D.new()
	s.texture = _glow_tex
	s.pixel_size = 0.0045 * size
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.shaded = false
	s.modulate = col
	add_child(s)
	return s


func _blob(scale_xz: float) -> Sprite3D:
	var s := super(scale_xz)
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return s


## Chão de cores chapadas: lajes em dois tons com junta fina e caminho de terra de borda ondulada.
func _ground_texture() -> ImageTexture:
	var size := Vector2i(_w * GROUND_PX, _h * GROUND_PX)
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var slab_a := Color("4c5a58")
	var slab_b := Color("445250")
	var seam := Color("323d3c")
	var dirt := Color("86704f")
	var dirt_edge := Color("5c4b36")
	for y in size.y:
		for x in size.x:
			var fx := float(x) / GROUND_PX
			var fy := float(y) / GROUND_PX
			var d := _path_distance(fx, fy) + sin(fx * 7.3 + fy * 3.1) * 0.035 + sin(fx * 2.1 - fy * 5.7) * 0.03
			var c: Color
			if d < 0.40:
				c = dirt
			elif d < 0.46:
				c = dirt_edge
			else:
				var cell := Vector2i(int(fx), int(fy))
				c = slab_a if (cell.x + cell.y) % 2 == 0 else slab_b
				if x % GROUND_PX < 2 or y % GROUND_PX < 2:
					c = seam
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Distância (maior eixo) do ponto até a casa do caminho mais próxima dentre as vizinhas.
func _path_distance(fx: float, fy: float) -> float:
	var cx := int(fx)
	var cy := int(fy)
	var best := 9.0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var cell := Vector2i(cx + dx, cy + dy)
			if not _path_set.has(cell):
				continue
			var ox := maxf(absf(fx - (cell.x + 0.5)) - 0.5, 0.0)
			var oy := maxf(absf(fy - (cell.y + 0.5)) - 0.5, 0.0)
			# dentro da faixa central da casa do caminho, ligando com as vizinhas de caminho
			best = minf(best, _band_distance(cell, fx, fy, ox, oy))
	return best


func _band_distance(cell: Vector2i, fx: float, fy: float, _ox: float, _oy: float) -> float:
	var center := Vector2(cell.x + 0.5, cell.y + 0.5)
	var p := Vector2(fx, fy)
	var best := p.distance_to(center)
	for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if _path_set.has(cell + dir):
			var other := center + Vector2(dir)
			best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, center, other)))
	return best
