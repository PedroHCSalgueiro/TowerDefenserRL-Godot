extends Node3D
## Protótipo 2.5D dos 8 heróis de Valcoroa: ficam parados na casa, em base de pedra 3D com anel da
## classe, e atacam com o efeito descrito no Notion. Cadência, alcance, dano, modo de mira e os
## números de área/gelo/armadilha vêm de data/sets/valcoroa/towers.json.
## NÃO é a simulação: só mostra o visual, e as habilidades "a cada N tiros" ficam de fora. Os inimigos
## e a vida deles são de demonstração.
##   godot --path . res://dev/proto25d/herois.tscn [-- --shot=a.png --shot-at=6 --yaw=45 --pitch=42
##                                                     --dist=13 --focus=6,7]

const ART := "res://dev/proto25d/art/"
const ART_2D := "res://dev/proto2d/art/"
const TOWERS_FILE := "res://data/sets/valcoroa/towers.json"
const MAP_FILE := "res://data/map.json"
const PIXEL := 0.021
const GROUND_PX := 48
const HERO_ANCHOR := Vector2(40, 74)
const GOBLIN_ANCHOR := Vector2(12, 26)
const BASE_HEIGHT := 0.2
## Quadro do ataque em que o disparo sai.
const FIRE_FRAME := 2
## Demonstração: inimigos que passam pelo caminho.
const ENEMY_SPEED := 1.3
const ENEMY_HP := 90.0
## Os inimigos entram já perto dos heróis, para a cena não começar parada.
const ENEMY_START := 10.0
const SPAWN_EVERY := 0.55
const TRAP_DAMAGE_RADIUS := 0.5

## Onde cada herói fica, o efeito e de onde sai o disparo (pixels do sprite em relação aos pés).
const HEROES := {
	"aldric": {"cell": [3, 4], "color": "ffe066", "kind": "beam", "muzzle": [9, 66]},
	"tomas": {"cell": [5, 4], "color": "ffffff", "kind": "light", "muzzle": [14, 67]},
	"lyra": {"cell": [8, 4], "color": "5de35d", "kind": "bolt", "muzzle": [33, 42]},
	"wulf": {"cell": [5, 7], "color": "ff4040", "kind": "arrow", "muzzle": [24, 35]},
	"selene": {"cell": [6, 7], "color": "b25cff", "kind": "orb", "muzzle": [24, 41]},
	"brom": {"cell": [7, 7], "color": "ff8a2a", "kind": "ball", "muzzle": [35, 24]},
	"isolde": {"cell": [4, 8], "color": "9be3ff", "kind": "ice", "muzzle": [33, 42]},
	"mabel": {"cell": [9, 8], "color": "38e8e0", "kind": "trap", "muzzle": [21, 42]},
}

var _w := 0
var _h := 0
var _cam: Camera3D
var _yaw := 45.0
var _pitch := 42.0
var _dist := 15.0
var _focus := Vector2(6.0, 6.5)
var _orbiting := false
var _labels_on := true
var _labels: Array[Label3D] = []
var _shot_path := ""
var _shot_at := 6.0
var _elapsed := 0.0
var _path: Array[Vector2i] = []
var _path_set := {}
var _heroes: Array[Dictionary] = []
var _enemies: Array[Dictionary] = []
var _traps: Array[Dictionary] = []
var _goblin_frames: SpriteFrames
var _spawn_cd := 0.0
var _fired := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.substr(7)
		elif arg.begins_with("--shot-at="):
			_shot_at = float(arg.substr(10))
		elif arg.begins_with("--yaw="):
			_yaw = float(arg.substr(6))
		elif arg.begins_with("--pitch="):
			_pitch = float(arg.substr(8))
		elif arg.begins_with("--dist="):
			_dist = float(arg.substr(7))
		elif arg.begins_with("--focus="):
			var parts := arg.substr(8).split(",")
			_focus = Vector2(float(parts[0]), float(parts[1]))
		elif arg == "--no-labels":
			_labels_on = false
	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP_FILE))
	_w = int(map["width"])
	_h = int(map["height"])
	_build_path(map["path"])
	_build_environment()
	_build_ground()
	_goblin_frames = SpriteFrames.new()
	_goblin_frames.set_animation_speed("default", 8.0)
	for f in 4:
		_goblin_frames.add_frame("default", load(ART_2D + "goblin_%d.png" % f))
	var types: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TOWERS_FILE))["types"]
	for id: String in HEROES:
		_add_hero(id, types[id])
	_cam = Camera3D.new()
	_cam.fov = 30.0
	_cam.near = 0.5
	_cam.far = 200.0
	add_child(_cam)
	_update_camera()
	var hud := CanvasLayer.new()
	var label := Label.new()
	label.text = "Heróis de Valcoroa (2.5D) — botão direito: girar · roda: zoom · setas: mover · N: nomes"
	label.position = Vector2(12, 8)
	hud.add_child(label)
	add_child(hud)


# ---------------------------------------------------------------- cenário

func _build_path(points: Array) -> void:
	var prev := Vector2i(int(points[0]["x"]), int(points[0]["y"]))
	_path.append(prev)
	for i in range(1, points.size()):
		var next := Vector2i(int(points[i]["x"]), int(points[i]["y"]))
		var step := Vector2i(signi(next.x - prev.x), signi(next.y - prev.y))
		while prev != next:
			prev += step
			_path.append(prev)
	for c in _path:
		_path_set[c] = true


func _world(cell: Vector2) -> Vector3:
	return Vector3(cell.x - (_w - 1) * 0.5, 0.0, cell.y - (_h - 1) * 0.5)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("16231a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b8c8d8")
	env.ambient_light_energy = 0.45
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -40, 0)
	sun.light_color = Color("fff0d0")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)


func _build_ground() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _ground_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = 1.0
	var top := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(_w, _h)
	top.mesh = plane
	top.material_override = mat
	add_child(top)
	var base := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(_w, 0.8, _h)
	base.mesh = box
	base.position = Vector3(0, -0.402, 0)
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color("4a3a28")
	dirt.roughness = 1.0
	base.material_override = dirt
	add_child(base)


## Piso de pedra (a direção de arte pede pouca decoração) e caminho de terra escura.
func _ground_texture() -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var size := Vector2i(_w * GROUND_PX, _h * GROUND_PX)
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var floor_tones: Array[Color] = [Color("565c57"), Color("5f6660"), Color("4f5550")]
	var dirt: Array[Color] = [Color("5e4a33"), Color("6b553b"), Color("54422d")]
	var nw := size.x / 2 + 1
	var noise := PackedInt32Array()
	noise.resize(nw * (size.y / 2 + 1))
	for i in noise.size():
		noise[i] = rng.randi() % 3
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x / GROUND_PX, y / GROUND_PX)
			var lx := x % GROUND_PX
			var ly := y % GROUND_PX
			var is_path := _path_set.has(cell)
			var kind := is_path
			if lx < 3 and _path_set.has(cell + Vector2i.LEFT) != is_path and rng.randf() < 0.45:
				kind = not is_path
			elif lx >= GROUND_PX - 3 and _path_set.has(cell + Vector2i.RIGHT) != is_path and rng.randf() < 0.45:
				kind = not is_path
			elif ly < 3 and _path_set.has(cell + Vector2i.UP) != is_path and rng.randf() < 0.45:
				kind = not is_path
			elif ly >= GROUND_PX - 3 and _path_set.has(cell + Vector2i.DOWN) != is_path and rng.randf() < 0.45:
				kind = not is_path
			var c: Color = (dirt if kind else floor_tones)[noise[(y / 2) * nw + x / 2]]
			# junta entre as lajes do piso: mostra a grade onde os heróis ficam
			if not kind and (lx < 1 or ly < 1):
				c = c.darkened(0.3)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Material sem luz, para efeitos e anéis (chamam atenção por cima do cenário escuro).
func _flat_mat(col: Color, alpha: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## Base da região (pedra com azul e ouro) e anel no pé com a cor da classe, como na direção de arte.
func _make_base(col: Color) -> Node3D:
	var root := Node3D.new()
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("a9acb0")
	stone.roughness = 0.9
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.radial_segments = 8
	cyl.rings = 1
	cyl.top_radius = 0.4
	cyl.bottom_radius = 0.46
	cyl.height = BASE_HEIGHT
	body.mesh = cyl
	body.material_override = stone
	body.position.y = BASE_HEIGHT * 0.5
	root.add_child(body)
	var band_mat := StandardMaterial3D.new()
	band_mat.albedo_color = Color("2a4cb0")
	band_mat.roughness = 0.6
	var band := MeshInstance3D.new()
	var band_mesh := CylinderMesh.new()
	band_mesh.radial_segments = 8
	band_mesh.rings = 1
	band_mesh.top_radius = 0.45
	band_mesh.bottom_radius = 0.46
	band_mesh.height = 0.06
	band.mesh = band_mesh
	band.material_override = band_mat
	band.position.y = 0.08
	root.add_child(band)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("e3b53a")
	gold.metallic = 0.4
	gold.roughness = 0.4
	var rim := MeshInstance3D.new()
	var rim_mesh := CylinderMesh.new()
	rim_mesh.radial_segments = 8
	rim_mesh.rings = 1
	rim_mesh.top_radius = 0.4
	rim_mesh.bottom_radius = 0.41
	rim_mesh.height = 0.025
	rim.mesh = rim_mesh
	rim.material_override = gold
	rim.position.y = BASE_HEIGHT
	root.add_child(rim)
	var cap := MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.radial_segments = 8
	cap_mesh.rings = 1
	cap_mesh.top_radius = 0.35
	cap_mesh.bottom_radius = 0.36
	cap_mesh.height = 0.03
	cap.mesh = cap_mesh
	cap.material_override = stone
	cap.position.y = BASE_HEIGHT + 0.02
	root.add_child(cap)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.46
	torus.outer_radius = 0.5
	torus.rings = 32
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = _flat_mat(col)
	ring.position.y = 0.03
	ring.scale = Vector3(1, 0.4, 1)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	return root


func _setup_sprite(s: SpriteBase3D, size: Vector2, anchor: Vector2) -> void:
	s.pixel_size = PIXEL
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	s.double_sided = true
	s.centered = true
	s.offset = Vector2(size.x * 0.5 - anchor.x, anchor.y - size.y * 0.5)


func _blob(scale_xz: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = load(ART_2D + "shadow.png")
	s.pixel_size = PIXEL * scale_xz
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.rotation_degrees = Vector3(-90, 0, 0)
	s.position = Vector3(0, 0.02, 0)
	return s


# ---------------------------------------------------------------- heróis

func _add_hero(id: String, data: Dictionary) -> void:
	var cfg: Dictionary = HEROES[id]
	var cell := Vector2i(cfg["cell"][0], cfg["cell"][1])
	var col := Color(cfg["color"])
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 2.5)
	for f in 2:
		frames.add_frame("idle", load(ART + "%s_idle_%d.png" % [id, f]))
	frames.add_animation("attack")
	frames.set_animation_speed("attack", 12.0)
	frames.set_animation_loop("attack", false)
	for f in 5:
		frames.add_frame("attack", load(ART + "%s_attack_%d.png" % [id, f]))
	var node := Node3D.new()
	node.position = _world(Vector2(cell))
	node.add_child(_make_base(col))
	var sprite := AnimatedSprite3D.new()
	sprite.sprite_frames = frames
	_setup_sprite(sprite, Vector2(80, 80), HERO_ANCHOR)
	sprite.position.y = BASE_HEIGHT + 0.03
	sprite.play("idle")
	sprite.frame = randi() % 2
	node.add_child(sprite)
	var label := Label3D.new()
	label.text = data["name"]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.0042
	label.font_size = 40
	label.outline_size = 12
	label.modulate = col
	label.position.y = BASE_HEIGHT + 1.75
	label.visible = _labels_on
	node.add_child(label)
	_labels.append(label)
	add_child(node)
	var hero := {
		"id": id, "node": node, "sprite": sprite, "cell": cell, "color": col, "kind": cfg["kind"],
		"muzzle": Vector2(cfg["muzzle"][0], cfg["muzzle"][1]), "data": data,
		"period": 1.0 / float(data["shotsPerSecond"]), "range": float(data["range"]),
		"cd": randf() * 0.8, "attacking": false, "target": {},
	}
	sprite.frame_changed.connect(_on_hero_frame.bind(hero))
	sprite.animation_finished.connect(_on_attack_done.bind(hero))
	_heroes.append(hero)


func _find_target(hero: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var strongest: bool = hero["data"]["targetMode"] == "strongest"
	for e in _enemies:
		if (_cell_at(e["d"]) - Vector2(hero["cell"])).length() > hero["range"]:
			continue
		if best.is_empty() or (e["hp"] > best["hp"] if strongest else e["d"] > best["d"]):
			best = e
	return best


func _start_attack(hero: Dictionary, target: Dictionary) -> void:
	if hero["attacking"]:
		return
	hero["attacking"] = true
	hero["target"] = target
	var sprite: AnimatedSprite3D = hero["sprite"]
	_face(sprite, (hero["node"] as Node3D).position, (target["node"] as Node3D).position)
	sprite.play("attack")


func _on_hero_frame(hero: Dictionary) -> void:
	var sprite: AnimatedSprite3D = hero["sprite"]
	if sprite.animation != "attack" or sprite.frame != FIRE_FRAME:
		return
	var target: Dictionary = hero["target"]
	if not _enemies.has(target):
		target = _find_target(hero)
	if not target.is_empty():
		_fire(hero, target)


func _on_attack_done(hero: Dictionary) -> void:
	var sprite: AnimatedSprite3D = hero["sprite"]
	if sprite.animation != "attack":
		return
	hero["attacking"] = false
	sprite.play("idle")


func _face(sprite: AnimatedSprite3D, from: Vector3, to: Vector3) -> void:
	var d := (to - from).dot(_cam.global_transform.basis.x)
	if absf(d) > 0.01:
		sprite.flip_h = d < 0.0


## Ponta da arma no mundo: o sprite encara a câmera, então usa os eixos dela.
func _muzzle(hero: Dictionary) -> Vector3:
	var m: Vector2 = hero["muzzle"]
	var side := -1.0 if (hero["sprite"] as AnimatedSprite3D).flip_h else 1.0
	var basis_cam := _cam.global_transform.basis
	return (hero["node"] as Node3D).position + Vector3(0, BASE_HEIGHT, 0) \
		+ basis_cam.x * m.x * side * PIXEL + basis_cam.y * m.y * PIXEL


# ---------------------------------------------------------------- ataques (um por herói)

func _fire(hero: Dictionary, target: Dictionary) -> void:
	_fired[hero["id"]] = _fired.get(hero["id"], 0) + 1
	var damage := float(hero["data"]["damage"])
	var col: Color = hero["color"]
	var from := _muzzle(hero)
	var speed := float(hero["data"]["projectileSpeed"])
	match hero["kind"]:
		"beam":
			_light_pillar(target, col)
			_damage(target, damage)
		"bolt":
			_projectile(from, target, col, speed, 0.0, 0.9, func() -> void: _damage(target, damage))
		"light":
			_ground_ring((hero["node"] as Node3D).position, 1.3, col, 0.4)
			_projectile(from, target, col, speed, 0.3, 1.1, func() -> void: _damage(target, damage))
		"ball":
			var radius := float(hero["data"]["shot"]["radius"])
			_projectile(from, target, Color("2a2d33"), speed, 1.5, 1.7, func() -> void: _explode(target, radius, damage, col))
			_smoke(from, col)
		"orb":
			_projectile(from, target, col, speed, 0.15, 1.5, func() -> void: _damage(target, damage))
			_activate_neighbors(hero)
		"arrow":
			_projectile(from, target, col, speed, 0.1, 1.0, func() -> void:
				_damage(target, damage)
				_tint(target, Color("ff8080"), float(hero["data"]["onHit"]["bleed"]["seconds"])))
		"trap":
			_throw_trap(hero, target, from, col, damage)
		"ice":
			_ice_chain(hero, target, from, col, damage)


func _damage(enemy: Dictionary, amount: float) -> void:
	if not _enemies.has(enemy):
		return
	enemy["hp"] -= amount
	var sprite: AnimatedSprite3D = enemy["sprite"]
	sprite.modulate = Color(2.5, 2.5, 2.5)
	create_tween().tween_property(sprite, "modulate", enemy["tint"], 0.12)
	if enemy["hp"] <= 0.0:
		_enemies.erase(enemy)
		var node: Node3D = enemy["node"]
		var fade := create_tween().set_parallel()
		fade.tween_property(sprite, "modulate:a", 0.0, 0.3)
		fade.tween_property(node, "scale", Vector3(1.2, 0.2, 1.2), 0.3)
		fade.chain().tween_callback(node.queue_free)


func _tint(enemy: Dictionary, col: Color, seconds: float) -> void:
	if not _enemies.has(enemy):
		return
	enemy["tint"] = col
	(enemy["sprite"] as AnimatedSprite3D).modulate = col
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if _enemies.has(enemy) and enemy["tint"] == col:
			enemy["tint"] = Color.WHITE
			(enemy["sprite"] as AnimatedSprite3D).modulate = Color.WHITE)


func _spark(col: Color, size: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = load(ART_2D + "spark.png")
	s.pixel_size = PIXEL * size
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.modulate = col
	add_child(s)
	return s


## Projétil que persegue o alvo. A duração vem da velocidade do tiro em data/ (casas por segundo).
func _projectile(from: Vector3, target: Dictionary, col: Color, speed: float, arc: float, size: float, on_hit: Callable) -> void:
	var spark := _spark(col, size)
	spark.position = from
	# a função do tween guarda só o dicionário: o nó do alvo pode ser apagado com o tiro no ar
	var last: Vector3 = (target["node"] as Node3D).position + Vector3(0, 0.3, 0)
	var seconds := clampf(from.distance_to(last) / maxf(speed, 0.1), 0.06, 1.2)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		if _enemies.has(target):
			last = (target["node"] as Node3D).position + Vector3(0, 0.3, 0)
		spark.position = from.lerp(last, t) + Vector3(0, sin(t * PI) * arc, 0)
	, 0.0, 1.0, seconds)
	tween.tween_callback(func() -> void:
		spark.queue_free()
		on_hit.call())


## Sir Aldric: coluna de luz que cai do alto sobre o alvo.
func _light_pillar(target: Dictionary, col: Color) -> void:
	var at := (target["node"] as Node3D).position
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.16
	cyl.bottom_radius = 0.1
	cyl.height = 8.0
	cyl.radial_segments = 8
	cyl.rings = 1
	m.mesh = cyl
	var mat := _flat_mat(col, true)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = at + Vector3(0, 4.0, 0)
	add_child(m)
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tween.tween_callback(m.queue_free)
	_ground_ring(at, 0.55, col, 0.28)


func _ground_ring(at: Vector3, radius: float, col: Color, seconds: float) -> void:
	var m := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 6
	m.mesh = torus
	var mat := _flat_mat(col, true)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = at + Vector3(0, 0.05, 0)
	m.scale = Vector3(0.1, 0.1, 0.1)
	add_child(m)
	var tween := create_tween().set_parallel()
	tween.tween_property(m, "scale", Vector3(radius, 0.1, radius), seconds)
	tween.tween_property(mat, "albedo_color:a", 0.0, seconds)
	tween.chain().tween_callback(m.queue_free)


func _explode(target: Dictionary, radius: float, damage: float, col: Color) -> void:
	var at: Vector3 = target["pos"]
	var m := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 12
	ball.rings = 6
	m.mesh = ball
	var mat := _flat_mat(col, true)
	mat.albedo_color.a = 0.75
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = at + Vector3(0, 0.2, 0)
	m.scale = Vector3(0.15, 0.15, 0.15)
	add_child(m)
	var tween := create_tween().set_parallel()
	tween.tween_property(m, "scale", Vector3(radius, radius * 0.7, radius), 0.22)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tween.chain().tween_callback(m.queue_free)
	_ground_ring(at, radius, col, 0.3)
	for e in _enemies.duplicate():
		if (e["node"] as Node3D).position.distance_to(at) <= radius:
			_damage(e, damage)


func _smoke(at: Vector3, col: Color) -> void:
	var s := _spark(col, 3.0)
	s.position = at
	var tween := create_tween().set_parallel()
	tween.tween_property(s, "pixel_size", PIXEL * 5.0, 0.18)
	tween.tween_property(s, "modulate:a", 0.0, 0.18)
	tween.chain().tween_callback(s.queue_free)


## Traço reto e fino entre dois pontos, que some sozinho.
func _ray(a: Vector3, b: Vector3, col: Color, width: float, seconds: float) -> void:
	if a.distance_to(b) < 0.05:
		return
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, width, a.distance_to(b))
	m.mesh = box
	var mat := _flat_mat(col, true)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.position = (a + b) * 0.5
	m.look_at(b, Vector3.UP)
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, seconds)
	tween.tween_callback(m.queue_free)


## Dama Selene: ao disparar, ativa as 4 vizinhas ortogonais, que dão um ataque extra na hora.
func _activate_neighbors(hero: Dictionary) -> void:
	for other in _heroes:
		if other == hero or other["kind"] == "orb":
			continue
		var d: Vector2i = other["cell"] - hero["cell"]
		if absi(d.x) + absi(d.y) != 1:
			continue
		var lift := Vector3(0, 0.7, 0)
		_ray((hero["node"] as Node3D).position + lift, (other["node"] as Node3D).position + lift, hero["color"], 0.05, 0.3)
		var target := _find_target(other)
		if not target.is_empty():
			_start_attack(other, target)


## Rainha Isolde: raio de gelo que deixa Lento e salta para quem já está Lento, até o limite de
## saltos de data/. O Lento empilha até o teto.
func _ice_chain(hero: Dictionary, target: Dictionary, from: Vector3, col: Color, damage: float) -> void:
	var slow: Dictionary = hero["data"]["onHit"]["slow"]
	var chilled: Array = []
	var current := target
	var start := from
	for i in int(slow["bounces"]) + 1:
		var at := (current["node"] as Node3D).position + Vector3(0, 0.35, 0)
		_ray(start, at, col, 0.07 if i == 0 else 0.04, 0.22)
		chilled.append(current)
		current["slow"] = minf(current["slow"] + float(slow["percent"]), float(slow["cap"]))
		_tint(current, Color("a8dcff"), float(slow["seconds"]))
		_damage(current, damage)
		var next: Dictionary = {}
		var best := float(slow["bounceRadius"])
		for e in _enemies:
			if chilled.has(e) or e["slow"] <= 0.0:
				continue
			var dist := (e["node"] as Node3D).position.distance_to(at)
			if dist <= best:
				best = dist
				next = e
		if next.is_empty():
			break
		start = at
		current = next


## Engenheira Mabel: joga um estrepe numa casa do caminho, à frente do alvo. Fica até alguém pisar.
func _throw_trap(hero: Dictionary, target: Dictionary, from: Vector3, col: Color, damage: float) -> void:
	var shot: Dictionary = hero["data"]["shot"]
	if _traps.size() >= int(shot["maxTraps"]):
		return
	var d: float = target["d"] + 1.5 + randf() * 2.0
	if (_cell_at(d) - Vector2(hero["cell"])).length() > hero["range"]:
		d = target["d"]
	var landing := _world(_cell_at(d)) + Vector3(0, 0.08, 0)
	var spark := _spark(col, 1.0)
	spark.position = from
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		spark.position = from.lerp(landing, t) + Vector3(0, sin(t * PI) * 1.0, 0)
	, 0.0, 1.0, 0.4)
	tween.tween_callback(func() -> void:
		_traps.append({"node": spark, "d": d, "damage": damage * float(shot["damagePercent"]) / 100.0, "color": col}))


func _update_traps() -> void:
	for trap in _traps.duplicate():
		for e in _enemies:
			if absf(e["d"] - trap["d"]) <= TRAP_DAMAGE_RADIUS:
				_ground_ring((trap["node"] as Node3D).position, 0.5, trap["color"], 0.25)
				_damage(e, trap["damage"])
				(trap["node"] as Node3D).queue_free()
				_traps.erase(trap)
				break


# ---------------------------------------------------------------- inimigos e laço

func _process(delta: float) -> void:
	_elapsed += delta
	_spawn_cd -= delta
	if _spawn_cd <= 0.0:
		_spawn_cd = SPAWN_EVERY
		_spawn_enemy()
	_move_enemies(delta)
	_update_traps()
	for hero in _heroes:
		hero["cd"] -= delta
		if hero["cd"] > 0.0 or hero["attacking"]:
			continue
		var target := _find_target(hero)
		if not target.is_empty():
			hero["cd"] = hero["period"]
			_start_attack(hero, target)
	_update_camera()
	if _shot_path != "" and _elapsed > _shot_at:
		print("disparos: ", _fired, " | armadilhas no chao: ", _traps.size(), " | inimigos: ", _enemies.size())
		get_viewport().get_texture().get_image().save_png(_shot_path)
		get_tree().quit()


func _spawn_enemy() -> void:
	var node := Node3D.new()
	node.add_child(_blob(0.9))
	var sprite := AnimatedSprite3D.new()
	sprite.sprite_frames = _goblin_frames
	_setup_sprite(sprite, Vector2(24, 28), GOBLIN_ANCHOR)
	sprite.speed_scale = randf_range(0.9, 1.15)
	sprite.play("default")
	sprite.frame = randi() % 4
	node.add_child(sprite)
	node.position = _world(_cell_at(ENEMY_START))
	add_child(node)
	_enemies.append({"node": node, "sprite": sprite, "pos": node.position, "d": ENEMY_START, "hp": ENEMY_HP, "slow": 0.0, "tint": Color.WHITE})


func _cell_at(d: float) -> Vector2:
	var i := clampi(floori(d), 0, _path.size() - 2)
	return Vector2(_path[i]).lerp(Vector2(_path[i + 1]), clampf(d - i, 0.0, 1.0))


func _move_enemies(delta: float) -> void:
	for e in _enemies.duplicate():
		e["d"] += ENEMY_SPEED * (1.0 - e["slow"] / 100.0) * delta
		var node: Node3D = e["node"]
		if e["d"] >= _path.size() - 1:
			_enemies.erase(e)
			node.queue_free()
			continue
		var old := node.position
		node.position = _world(_cell_at(e["d"]))
		e["pos"] = node.position
		_face(e["sprite"], old, node.position)


# ---------------------------------------------------------------- câmera

func _update_camera() -> void:
	var target := _world(_focus) + Vector3(0, 0.6, 0)
	var yaw := deg_to_rad(_yaw)
	var pitch := deg_to_rad(_pitch)
	_cam.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * _dist
	_cam.look_at(target, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if _shot_path != "":
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = clampf(_dist / 1.1, 4.0, 40.0)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = clampf(_dist * 1.1, 4.0, 40.0)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = mb.pressed
	elif event is InputEventMouseMotion and _orbiting:
		var rel := (event as InputEventMouseMotion).relative
		_yaw -= rel.x * 0.3
		_pitch = clampf(_pitch + rel.y * 0.2, 15.0, 85.0)
	elif event is InputEventKey and (event as InputEventKey).pressed:
		match (event as InputEventKey).keycode:
			KEY_N:
				_labels_on = not _labels_on
				for label in _labels:
					label.visible = _labels_on
			KEY_LEFT:
				_focus += Vector2(-0.5, 0.5)
			KEY_RIGHT:
				_focus += Vector2(0.5, -0.5)
			KEY_UP:
				_focus += Vector2(-0.5, -0.5)
			KEY_DOWN:
				_focus += Vector2(0.5, 0.5)
